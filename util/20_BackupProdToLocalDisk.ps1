# =========================
# Backup Production PostgreSQL databases to local directory
# - Dumps sd* databases using pg_dump with custom format
# - Downloads backups to local directory (overwrites existing)
# - Compatible with 18_RestoreLocalFromLocalDumps.ps1
#
# Usage:
#   .\20_BackupProdToLocalDisk.ps1                          # All databases
#   .\20_BackupProdToLocalDisk.ps1 -Sport FootballNfl       # NFL only
#   .\20_BackupProdToLocalDisk.ps1 -Sport FootballNcaa      # NCAA only
# =========================

param(
    [string]$Sport = ""
)

# === Load secrets ===
$secretsPath = $env:SPORTDEETS_SECRETS_PATH
if (-not $secretsPath) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}
. "$secretsPath\_common-variables.ps1"

# -------- CONFIG --------
$backupFolder = "D:\Backups\FromProd"   # Local destination for backup files
$pgUser       = $script:pgUserProd
$pgPassword   = $script:pgPasswordProd
$pgHost       = $script:pgHostProd

# PostgreSQL binaries (adjust path if needed)
$psqlPath      = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$pgDumpPath    = "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe"

# PostgreSQL port
$pgPort = 5432
# ------------------------

$sportDisplay = if ($Sport) { $Sport } else { "all sports" }

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Production Database Backup to Local ($sportDisplay)" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

# Ensure local backup folder exists
if (-not (Test-Path $backupFolder)) {
    Write-Host "[INFO] Creating backup folder: $backupFolder" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
}

Write-Host "[INFO] Backup destination: $backupFolder" -ForegroundColor White
Write-Host "[INFO] Source: $($pgUser)@$($pgHost):$($pgPort) (production NUC)" -ForegroundColor White
Write-Host ""

# Pre-flight checks
if (-not (Test-Path $psqlPath)) {
    throw "ERROR: psql.exe not found at: $psqlPath"
}
if (-not (Test-Path $pgDumpPath)) {
    throw "ERROR: pg_dump.exe not found at: $pgDumpPath"
}

# Set password for pg_dump
$env:PGPASSWORD = $pgPassword

# Step 1: Get list of databases
Write-Host "[Step 1] Querying databases on production server..." -ForegroundColor Yellow

# Filter by sport if specified, otherwise get all sd* databases
$dbListQuery = if ($Sport) {
    "SELECT datname FROM pg_database WHERE datname LIKE 'sd%' AND (datname LIKE '%.$Sport%' OR datname LIKE '%All%') ORDER BY datname"
} else {
    "SELECT datname FROM pg_database WHERE datname LIKE 'sd%' ORDER BY datname"
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

# Step 2: Dump databases in parallel
Write-Host "[Step 2] Dumping databases in parallel..." -ForegroundColor Yellow

$dumpJobs = @()
foreach ($dbName in $dbList) {
    $backupFile = Join-Path $backupFolder "$dbName.backup"
    Write-Host "  - Starting dump for $dbName..." -ForegroundColor Gray

    $job = Start-Job -ScriptBlock {
        param($pgDumpExe, $host_, $port_, $user_, $password_, $backupFile_, $dbName_)
        $env:PGPASSWORD = $password_
        & $pgDumpExe -h $host_ -p $port_ -U $user_ -Fc -f $backupFile_ $dbName_ 2>&1
        return @{ ExitCode = $LASTEXITCODE; DbName = $dbName_; BackupFile = $backupFile_ }
    } -ArgumentList $pgDumpPath, $pgHost, $pgPort, $pgUser, $pgPassword, $backupFile, $dbName

    $dumpJobs += $job
}

Write-Host "  Waiting for $($dumpJobs.Count) parallel dump jobs to complete..." -ForegroundColor Gray
$dumpJobs | Wait-Job | Out-Null

$dumpCount = 0
foreach ($job in $dumpJobs) {
    $result = Receive-Job -Job $job
    # The last item in the output is our hashtable
    $info = $result | Where-Object { $_ -is [hashtable] } | Select-Object -Last 1
    if ($info -and $info.ExitCode -eq 0) {
        $dumpCount++
        if (Test-Path $info.BackupFile) {
            $fileSize = (Get-Item $info.BackupFile).Length / 1MB
            Write-Host "    $($info.DbName) dumped ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
        }
    } else {
        $dbNameFromJob = if ($info) { $info.DbName } else { "(unknown)" }
        Write-Warning "  Failed to dump $dbNameFromJob"
        # Print any output for diagnostics
        $result | Where-Object { $_ -isnot [hashtable] } | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    }
    Remove-Job -Job $job
}

Write-Host ""
Write-Host "  Dumped $dumpCount of $($dbList.Count) databases" -ForegroundColor Green
Write-Host ""

# Clean up password
$env:PGPASSWORD = $null

# Summary
$duration = (Get-Date) - $startTime

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "BACKUP COMPLETE" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Backup Location:  $backupFolder" -ForegroundColor White
Write-Host "Files Dumped:     $dumpCount" -ForegroundColor White
Write-Host "Total Duration:   $($duration.ToString())" -ForegroundColor White
Write-Host ""
