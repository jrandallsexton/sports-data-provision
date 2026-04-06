# =========================
# Restore .backup files into EXISTING local databases
# - Skips roles.sql on error
# - pg_restore drops/recreates objects in-place
#
# Usage:
#   .\18_RestoreLocalFromLocalDumps.ps1                          # All databases
#   .\18_RestoreLocalFromLocalDumps.ps1 -Sport FootballNfl       # NFL only
#   .\18_RestoreLocalFromLocalDumps.ps1 -Sport FootballNcaa      # NCAA only
# =========================

param(
    [string]$Sport = ""
)

# === Load secrets ===
$secretsPath = $env:SPORTDEETS_SECRETS_PATH
. "$secretsPath\_common-variables.ps1"

# -------- CONFIG --------
$backupFolder = "D:\Backups\FromProd"   # folder with *.backup (and optional roles.sql)
$pgUser       = $script:pgUserLocal
$pgPassword   = $script:pgPasswordLocal
$pgHost       = $script:pgHostLocal
$pgPort       = 5432

# Postgres binaries
$psqlPath      = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$pgRestorePath = "C:\Program Files\PostgreSQL\17\bin\pg_restore.exe"

# Parallel workers per pg_restore (scales with CPU cores)
$jobs = [Math]::Max(1, [Environment]::ProcessorCount - 2)
# ------------------------

# Pre-flight
if (-not (Test-Path $backupFolder)) { throw "Backup folder not found: $backupFolder" }
if (-not (Test-Path $psqlPath))     { throw "psql.exe not found at: $psqlPath" }
if (-not (Test-Path $pgRestorePath)){ throw "pg_restore.exe not found at: $pgRestorePath" }

$env:PGPASSWORD = $pgPassword
$startTime = Get-Date

$sportDisplay = if ($Sport) { $Sport } else { "all sports" }

Write-Host "`n[INFO] Restoring from: $backupFolder ($sportDisplay)"
Write-Host "[INFO] Target: $($pgUser)@$($pgHost):$($pgPort) (local)"

# 1) roles.sql (optional; skip on error)
$rolesFile = Join-Path $backupFolder "roles.sql"
if (Test-Path $rolesFile) {
  Write-Host "[ROLES] Attempting to restore roles from roles.sql..."
  try {
    & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d postgres -v ON_ERROR_STOP=1 -f $rolesFile
    if ($LASTEXITCODE -ne 0) { throw "psql exited code $LASTEXITCODE" }
    Write-Host "[ROLES] Roles restored."
  } catch {
    Write-Warning "[ROLES] Skipping roles.sql due to error: $($_.Exception.Message)"
  }
} else {
  Write-Host "[ROLES] roles.sql not found. Skipping role restore."
}

# 2) restore each .backup into existing DB (clean in place)
$dumpFiles = Get-ChildItem -Path $backupFolder -Filter "*.backup" | Sort-Object Name

# Filter by sport if specified — only include matching sport and shared (All) databases
# Exclude other sports' databases that may exist in the same folder
if ($Sport) {
    $otherSports = @("FootballNcaa", "FootballNfl", "BasketballNba", "BaseballMlb", "GolfPga") | Where-Object { $_ -ne $Sport }
    $dumpFiles = $dumpFiles | Where-Object {
        $name = $_.Name
        ($name -like "*.$Sport.*" -or $name -like "*All*") -and
        -not ($otherSports | Where-Object { $name -like "*.$_.*" })
    }
}

if (-not $dumpFiles) { throw "No .backup files found in $backupFolder matching filter" }

Write-Host "`n[INFO] Restoring $($dumpFiles.Count) databases:"
$dumpFiles | ForEach-Object { Write-Host "    $($_.Name)" -ForegroundColor Gray }

Write-Host "[INFO] Using $jobs parallel workers per pg_restore (CPU cores: $([Environment]::ProcessorCount))"

# Launch parallel restore jobs for each database
$restoreJobs = @()
foreach ($dump in $dumpFiles) {
  $dbName = [System.IO.Path]::GetFileNameWithoutExtension($dump.Name)
  Write-Host "  Starting parallel restore for $dbName..." -ForegroundColor Gray

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
      ExitCode = $LASTEXITCODE
      DbName = $dbName_
      Output = ($output | Out-String)
    }
  } -ArgumentList $pgRestorePath, $pgHost, $pgPort, $pgUser, $pgPassword, $dbName, $dump.FullName, $jobs

  $restoreJobs += $job
}

Write-Host "`n[INFO] Waiting for $($restoreJobs.Count) parallel restore jobs to complete..." -ForegroundColor Yellow
$restoreJobs | Wait-Job | Out-Null

$failCount = 0
foreach ($job in $restoreJobs) {
  $result = Receive-Job -Job $job
  $info = $result | Where-Object { $_ -is [hashtable] } | Select-Object -Last 1
  if ($info) {
    if ($info.ExitCode -ne 0) {
      $failCount++
      Write-Warning "[FAIL] pg_restore failed for $($info.DbName) (exit code $($info.ExitCode))"
      if ($info.Output) { Write-Host $info.Output -ForegroundColor Gray }
    } else {
      Write-Host "[OK] $($info.DbName) restored." -ForegroundColor Green
    }
  }
  Remove-Job -Job $job
}

if ($failCount -gt 0) {
  throw "$failCount database restore(s) failed. See warnings above."
}

Write-Host "`n[OK] All databases restored to local instance."
$duration = (Get-Date) - $startTime
Write-Host "[TIME] Total duration: $($duration.ToString())"
