# =========================
# Restore local PostgreSQL from the NIGHTLY prod backup on Bender.
# (MongoDB restore lives in 18a_RestoreLocalMongoFromNightly.ps1 - the two
#  are independent so they can run simultaneously in separate terminals and
#  be re-run individually.)
#
# Source (produced by the on-box systemd backup timer, pulled nightly):
#   D:\sdprod-backups\sdprod-data-01\<stamp>.tar  (per-db *.dump custom-format + globals.sql)
# The tar's .sha256 sidecar is verified before anything is touched.
#
# Dumps restore in parallel (one pg_restore job per db, --clean --if-exists
# in place), with live per-database completion output. After restore, the
# MassTransit outbox tables are truncated in the app DBs - a restored outbox
# replays every undelivered prod message at next app start (2.7M-message
# lesson, 2026-08-30).
#
# TIP: stop the local app stack first - live Hangfire pools compete for IO
# and the in-place clean runs under any connected services.
#
# Usage:
#   .\18_RestoreLocalFromProdBackup.ps1                               # all DBs, latest nightly
#   .\18_RestoreLocalFromProdBackup.ps1 -Sport FootballNcaa           # one sport (+ shared All DBs)
#   .\18_RestoreLocalFromProdBackup.ps1 -NoHangfire                   # skip *.Hangfire dumps
#   .\18_RestoreLocalFromProdBackup.ps1 -BackupDate 2026-09-05        # specific nightly (prefix match)
#   .\18_RestoreLocalFromProdBackup.ps1 -KeepExtracted                # leave extracted files
# =========================

param(
    [string]$Sport = "",
    [switch]$NoHangfire,
    [string]$BackupDate = "",
    [switch]$KeepExtracted
)

# === Load secrets ===
$secretsPath = $env:SPORTDEETS_SECRETS_PATH
. "$secretsPath\_common-variables.ps1"

# -------- CONFIG --------
$pgBackupDir = "D:\sdprod-backups\sdprod-data-01"
$extractRoot = "D:\Backups\FromProdNightly\pg"   # scratch; wiped unless -KeepExtracted

$pgUser     = $script:pgUserLocal
$pgPassword = $script:pgPasswordLocal
$pgHost     = $script:pgHostLocal
$pgPort     = 5432

$psqlPath      = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$pgRestorePath = "C:\Program Files\PostgreSQL\17\bin\pg_restore.exe"

# Never restored locally: umami is Bender-hosted analytics, not app data.
$pgExcludeDbs = @("umami")

# Parallel workers per pg_restore (scales with CPU cores)
$jobs = [Math]::Max(1, [Environment]::ProcessorCount - 2)
# ------------------------

# Pre-flight
if (-not (Test-Path $pgBackupDir))  { throw "PG backup folder not found: $pgBackupDir" }
if (-not (Test-Path $psqlPath))     { throw "psql.exe not found at: $psqlPath" }
if (-not (Test-Path $pgRestorePath)){ throw "pg_restore.exe not found at: $pgRestorePath" }

function Get-VerifiedTar {
    param([string]$Dir, [string]$DatePrefix)
    $tars = Get-ChildItem -Path $Dir -Filter "*.tar" | Sort-Object Name -Descending
    if ($DatePrefix) { $tars = $tars | Where-Object { $_.Name -like "$DatePrefix*" } }
    if (-not $tars) { throw "No .tar backups found in $Dir$(if ($DatePrefix) { " matching '$DatePrefix*'" })" }
    $tar = $tars | Select-Object -First 1

    $sidecar = "$($tar.FullName).sha256"
    if (-not (Test-Path $sidecar)) { throw "Missing sha256 sidecar for $($tar.Name)" }
    $expected = ((Get-Content $sidecar -First 1) -split '\s+')[0]
    Write-Host "  Verifying $($tar.Name) ($([Math]::Round($tar.Length/1GB, 2)) GB)..." -ForegroundColor Gray
    $actual = (Get-FileHash -Path $tar.FullName -Algorithm SHA256).Hash
    if (-not [string]::Equals($actual, $expected, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "SHA256 MISMATCH for $($tar.Name) - backup may be corrupt. Expected $expected, got $actual."
    }
    Write-Host "  [OK] Checksum verified." -ForegroundColor Green
    return $tar
}

$env:PGPASSWORD = $pgPassword
$startTime = Get-Date
$sportDisplay = if ($Sport) { $Sport } else { "all sports" }

Write-Host "`n[INFO] Restoring local PostgreSQL from nightly prod backup ($sportDisplay)"
Write-Host "[INFO] Target: $($pgUser)@$($pgHost):$($pgPort) (local)"

Write-Host "`n[VERIFY] PostgreSQL nightly ($pgBackupDir):"
$pgTar = Get-VerifiedTar -Dir $pgBackupDir -DatePrefix $BackupDate

# Decide which dumps to restore (filter BEFORE extraction)
$dumpNames = (& tar -tf $pgTar.FullName) |
    ForEach-Object { $_.TrimStart('.', '/') } |
    Where-Object { $_ -like "*.dump" }

if ($Sport) {
    $otherSports = @("FootballNcaa", "FootballNfl", "BasketballNba", "BaseballMlb", "GolfPga") | Where-Object { $_ -ne $Sport }
    $dumpNames = $dumpNames | Where-Object {
        $name = $_
        ($name -like "*.$Sport.*" -or $name -like "*.$Sport.dump" -or $name -like "*All*") -and
        -not ($otherSports | Where-Object { $name -like "*.$_.*" -or $name -like "*.$_.dump" })
    }
}
if ($NoHangfire) {
    $dumpNames = $dumpNames | Where-Object { $_ -notlike "*.Hangfire.dump" }
}
$dumpNames = $dumpNames | Where-Object {
    [System.IO.Path]::GetFileNameWithoutExtension($_) -notin $pgExcludeDbs
} | Sort-Object

if (-not $dumpNames) { throw "No .dump files in $($pgTar.Name) match the filter" }

# Extract (bsdtar matches member names EXACTLY as stored; entries carry "./")
if (Test-Path $extractRoot) { Remove-Item -Recurse -Force $extractRoot }
New-Item -ItemType Directory -Force $extractRoot | Out-Null

$pgMembers = $dumpNames | ForEach-Object { "./$_" }
Write-Host "`n[EXTRACT] $($dumpNames.Count) PG dumps + globals.sql from $($pgTar.Name)..."
& tar -xf $pgTar.FullName -C $extractRoot ($pgMembers + @("./globals.sql")) 2>$null
if ($LASTEXITCODE -ne 0) {
    & tar -xf $pgTar.FullName -C $extractRoot $pgMembers
    if ($LASTEXITCODE -ne 0) { throw "tar extraction failed for $($pgTar.Name)" }
    Write-Warning "[EXTRACT] globals.sql not extracted; continuing without role restore."
}

# globals.sql (roles) - attempt, skip on error
$globalsFile = Join-Path $extractRoot "globals.sql"
if (Test-Path $globalsFile) {
    Write-Host "`n[ROLES] Attempting globals.sql (skip-on-error)..."
    try {
        & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d postgres -v ON_ERROR_STOP=1 -f $globalsFile | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "psql exited code $LASTEXITCODE" }
        Write-Host "[ROLES] Globals restored."
    } catch {
        Write-Warning "[ROLES] Skipping globals.sql: $($_.Exception.Message)"
    }
}

# Launch parallel restores, then report each completion LIVE as it lands
Write-Host "`n[INFO] Restoring $($dumpNames.Count) databases ($jobs workers each):"
$dumpNames | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }

$restoreJobs = @{}
foreach ($dumpName in $dumpNames) {
  $dbName = [System.IO.Path]::GetFileNameWithoutExtension($dumpName)
  $dumpFile = Join-Path $extractRoot $dumpName

  $job = Start-Job -ScriptBlock {
    param($pgRestoreExe, $host_, $port_, $user_, $password_, $dbName_, $dumpFile_, $workers_)
    $env:PGPASSWORD = $password_

    $connStr = "host=$host_ port=$port_ user=$user_ dbname=$dbName_"
    $output = & $pgRestoreExe `
      --dbname "$connStr" `
      --clean --if-exists `
      --no-owner --no-privileges `
      -j $workers_ `
      $dumpFile_ 2>&1

    return @{
      ExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
      DbName = $dbName_
      Output = ($output | Out-String)
    }
  } -ArgumentList $pgRestorePath, $pgHost, $pgPort, $pgUser, $pgPassword, $dbName, $dumpFile, $jobs

  $restoreJobs[$job.Id] = @{ Job = $job; Db = $dbName; Started = Get-Date }
}

Write-Host "`n[INFO] $($restoreJobs.Count) restore jobs running - completions report live:" -ForegroundColor Yellow
$failCount = 0
$restoredPgDbs = @()
$pending = @($restoreJobs.Values.Job)
while ($pending.Count -gt 0) {
  $done = Wait-Job -Job $pending -Any
  $meta = $restoreJobs[$done.Id]
  $elapsed = ((Get-Date) - $meta.Started).ToString("hh\:mm\:ss")
  $result = Receive-Job -Job $done
  $info = $result | Where-Object { $_ -is [hashtable] } | Select-Object -Last 1

  if ($info -and $info.ExitCode -eq 0) {
    Write-Host "[OK] $($meta.Db) restored in $elapsed  ($($pending.Count - 1) remaining)" -ForegroundColor Green
    $restoredPgDbs += $meta.Db
  } else {
    $failCount++
    Write-Warning "[FAIL] $($meta.Db) failed after $elapsed (exit code $(if ($info) { $info.ExitCode } else { '?' }))"
    if ($info -and $info.Output) { Write-Host $info.Output -ForegroundColor Gray }
  }
  Remove-Job -Job $done
  $pending = @($pending | Where-Object { $_.Id -ne $done.Id })
}

# Truncate MassTransit outbox tables in restored app DBs. A restored outbox
# holds every message prod had not yet delivered at dump time; the first
# local app start would fire ALL of them at local RabbitMQ (2026-08-30: 2.7M).
$outboxDbs = $restoredPgDbs | Where-Object { $_ -notlike "*.Hangfire" }
if ($outboxDbs) {
    Write-Host "`n[OUTBOX] Truncating MassTransit outbox/inbox tables..."
    foreach ($db in $outboxDbs) {
        $sql = 'DO $$ BEGIN IF to_regclass(''public."OutboxMessage"'') IS NOT NULL THEN TRUNCATE TABLE "OutboxMessage", "OutboxState", "InboxState"; END IF; END $$;'
        & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d $db -v ON_ERROR_STOP=1 -c $sql | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "[OUTBOX] Could not truncate outbox in $db (see above)."
        } else {
            Write-Host "[OUTBOX] $db clean." -ForegroundColor Green
        }
    }
}

if (-not $KeepExtracted) {
    Remove-Item -Recurse -Force $extractRoot -ErrorAction SilentlyContinue
} else {
    Write-Host "`n[INFO] Extracted files kept at $extractRoot"
}

if ($failCount -gt 0) {
  throw "$failCount database restore(s) failed. See warnings above."
}

Write-Host "`n[OK] Local PostgreSQL restored from $($pgTar.Name)."
$duration = (Get-Date) - $startTime
Write-Host "[TIME] Total duration: $($duration.ToString())"
