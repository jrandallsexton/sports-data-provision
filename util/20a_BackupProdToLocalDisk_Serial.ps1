# =========================
# Serial variant of 20_BackupProdToLocalDisk.ps1
#
# Same behavior as the original except:
#   * pg_dump runs SEQUENTIALLY per database, not in parallel. Three
#     concurrent COPY streams against a failing drive multiply the
#     thermal + I/O stress; serial gives the backend a chance to
#     finish one DB before stressing the next.
#   * Continues past failed dumps instead of bailing. One DB's bad
#     block doesn't poison the rescue for the others.
#   * Supports -ExcludeTable to skip specific tables that are known
#     to die mid-COPY. Pass schema-qualified, quoted exactly as
#     pg_dump expects.
#   * Per-DB elapsed time printed so you can see where it's slow.
#
# Usage:
#   .\20a_BackupProdToLocalDisk_Serial.ps1 -Sport BaseballMlb -NoHangfire
#   .\20a_BackupProdToLocalDisk_Serial.ps1 -Sport BaseballMlb -NoHangfire `
#       -ExcludeTable 'public."CompetitionCompetitorRecordStat"'
#   .\20a_BackupProdToLocalDisk_Serial.ps1 -Sport BaseballMlb -NoHangfire `
#       -ExcludeTable 'public."CompetitionCompetitorRecordStat"', 'public."SomeOtherBadTable"'
# =========================

param(
    [string]$Sport = "",
    [switch]$NoHangfire,
    [string[]]$ExcludeTable = @()
)

# === Load secrets ===
$secretsPath = $env:SPORTDEETS_SECRETS_PATH
if (-not $secretsPath) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}
. "$secretsPath\_common-variables.ps1"

# -------- CONFIG --------
$backupFolder = "D:\Backups\FromProd"
$pgUser       = $script:pgUserProd
$pgPassword   = $script:pgPasswordProd
$pgHost       = $script:pgHostProd

$psqlPath      = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$pgDumpPath    = "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe"

$pgPort = 5432
# ------------------------

$sportDisplay = if ($Sport) { $Sport } else { "all sports" }

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Production Database Backup to Local — SERIAL ($sportDisplay)" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

if (-not (Test-Path $backupFolder)) {
    Write-Host "[INFO] Creating backup folder: $backupFolder" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
}

Write-Host "[INFO] Backup destination: $backupFolder" -ForegroundColor White
Write-Host "[INFO] Source: $($pgUser)@$($pgHost):$($pgPort) (production NUC)" -ForegroundColor White
Write-Host "[INFO] Mode: serial (one DB at a time)" -ForegroundColor White
if ($ExcludeTable.Count -gt 0) {
    Write-Host "[INFO] Excluded tables ($($ExcludeTable.Count)):" -ForegroundColor White
    foreach ($t in $ExcludeTable) {
        Write-Host "         $t" -ForegroundColor Gray
    }
}
Write-Host ""

if (-not (Test-Path $psqlPath)) {
    throw "ERROR: psql.exe not found at: $psqlPath"
}
if (-not (Test-Path $pgDumpPath)) {
    throw "ERROR: pg_dump.exe not found at: $pgDumpPath"
}

$env:PGPASSWORD = $pgPassword

# Step 1: Get list of databases (unchanged from original).
Write-Host "[Step 1] Querying databases on production server..." -ForegroundColor Yellow

$hangfireFilter = if ($NoHangfire) { " AND datname NOT LIKE '%.Hangfire'" } else { "" }

$dbListQuery = if ($Sport) {
    "SELECT datname FROM pg_database WHERE datname LIKE 'sd%' AND (datname LIKE '%.$Sport%' OR datname LIKE '%All%')$hangfireFilter ORDER BY datname"
} else {
    "SELECT datname FROM pg_database WHERE datname LIKE 'sd%'$hangfireFilter ORDER BY datname"
}

$databases = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d postgres -t -A -c $dbListQuery

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: Failed to query databases with exit code $LASTEXITCODE"
}

$dbList = $databases -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() }

if (-not $dbList) {
    throw "ERROR: No databases found matching filter"
}

Write-Host "  Found $($dbList.Count) databases:" -ForegroundColor Green
$dbList | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
Write-Host ""

# Step 2: Dump databases SERIALLY, continuing past failures.
Write-Host "[Step 2] Dumping databases one at a time..." -ForegroundColor Yellow
Write-Host ""

# Pre-build the exclude-table arg list once — pg_dump accepts repeated
# --exclude-table=PATTERN flags. Patterns are passed through verbatim
# (caller is responsible for quoting / schema-qualifying correctly).
$excludeArgs = @()
foreach ($t in $ExcludeTable) {
    $excludeArgs += "--exclude-table=$t"
}

$dumpCount = 0
$failCount = 0
$results = @()

foreach ($dbName in $dbList) {
    $backupFile = Join-Path $backupFolder "$dbName.backup"
    Write-Host "  >>> Dumping $dbName ..." -ForegroundColor Cyan
    $dbStart = Get-Date

    # Build the full pg_dump argument list. Format=custom (-Fc) matches
    # the original script and is what 18_RestoreLocalFromLocalDumps.ps1
    # expects on the restore side.
    $pgDumpArgs = @(
        "-h", $pgHost,
        "-p", $pgPort,
        "-U", $pgUser,
        "-Fc",
        "-f", $backupFile
    )
    $pgDumpArgs += $excludeArgs
    $pgDumpArgs += $dbName

    # 2>&1 merges stderr so the per-table failure messages show up in
    # the same stream and we can surface them on failure.
    $output = & $pgDumpPath @pgDumpArgs 2>&1
    $exitCode = $LASTEXITCODE
    $dbElapsed = (Get-Date) - $dbStart

    if ($exitCode -eq 0 -and (Test-Path $backupFile)) {
        $fileSize = (Get-Item $backupFile).Length / 1MB
        Write-Host "      OK   $dbName ($([math]::Round($fileSize, 2)) MB, $($dbElapsed.ToString('hh\:mm\:ss')))" -ForegroundColor Green
        $dumpCount++
        $results += [pscustomobject]@{ Db = $dbName; Status = 'OK'; SizeMB = [math]::Round($fileSize, 2); Elapsed = $dbElapsed }
    } else {
        Write-Warning "      FAIL $dbName (exit=$exitCode, $($dbElapsed.ToString('hh\:mm\:ss')))"
        # Surface the actual pg_dump error so we know which table /
        # which kind of failure it was.
        $output | ForEach-Object { Write-Host "         $_" -ForegroundColor DarkYellow }
        $failCount++
        $results += [pscustomobject]@{ Db = $dbName; Status = 'FAIL'; SizeMB = 0; Elapsed = $dbElapsed }
        # Keep going — the next DB may still succeed.
    }
    Write-Host ""
}

# Clean up password
$env:PGPASSWORD = $null

# Summary
$duration = (Get-Date) - $startTime

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "BACKUP COMPLETE — $dumpCount ok, $failCount failed" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Backup Location:  $backupFolder" -ForegroundColor White
Write-Host "Files Dumped:     $dumpCount of $($dbList.Count)" -ForegroundColor White
Write-Host "Total Duration:   $($duration.ToString())" -ForegroundColor White
Write-Host ""

Write-Host "Per-database result:" -ForegroundColor White
$results | Format-Table -AutoSize | Out-String | Write-Host

# Exit non-zero only if EVERY db failed. A partial rescue is still
# a win — we don't want the orchestrator script to throw and prevent
# the restore step from processing the dumps that did succeed.
if ($dumpCount -eq 0) {
    exit 1
} else {
    exit 0
}
