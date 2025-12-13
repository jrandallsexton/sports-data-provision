# =========================
# Restore .dump files into EXISTING local databases
# - Skips roles.sql on error
# - pg_restore drops/recreates objects in-place
# =========================

# === Load secrets ===
$secretsPath = $env:SPORTDEETS_SECRETS_PATH
. "$secretsPath\_common-variables.ps1"

# -------- CONFIG --------
$backupFolder = "C:\Backups\FromProd"   # folder with *.dump (and optional roles.sql)
$pgUser       = $script:pgUserLocal
$pgPassword   = $script:pgPasswordLocal
$pgHost       = $script:pgHostLocal
$pgPort       = 5432

# Postgres binaries
$psqlPath      = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$pgRestorePath = "C:\Program Files\PostgreSQL\17\bin\pg_restore.exe"

# Parallel workers
$jobs = 4
# ------------------------

# Pre-flight
if (-not (Test-Path $backupFolder)) { throw "Backup folder not found: $backupFolder" }
if (-not (Test-Path $psqlPath))     { throw "psql.exe not found at: $psqlPath" }
if (-not (Test-Path $pgRestorePath)){ throw "pg_restore.exe not found at: $pgRestorePath" }

$env:PGPASSWORD = $pgPassword
$startTime = Get-Date

Write-Host "`n[INFO] Restoring from: $backupFolder"
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

# 2) restore each .dump into existing DB (clean in place)
$dumpFiles = Get-ChildItem -Path $backupFolder -Filter "*.backup" | Sort-Object Name
if (-not $dumpFiles) { throw "No .dump files found in $backupFolder" }

foreach ($dump in $dumpFiles) {
  $dbName = [System.IO.Path]::GetFileNameWithoutExtension($dump.Name)

  Write-Host "`n[DB] Restoring $dbName from $($dump.Name) (in-place clean)..."

  # Build libpq connection string to avoid quoting issues
  $connStr = "host=$pgHost port=$pgPort user=$pgUser dbname=$dbName"

  # Restore (drop/recreate objects), keep ownership/privs unchanged locally
  & $pgRestorePath `
    --dbname "$connStr" `
    --clean --if-exists `
    --no-owner --no-privileges `
    -j $jobs `
    $dump.FullName

  if ($LASTEXITCODE -ne 0) { throw "pg_restore failed for $dbName" }
  Write-Host "[OK] $dbName restored."
}

Write-Host "`n[OK] All databases restored to local instance."
$duration = (Get-Date) - $startTime
Write-Host "[TIME] Total duration: $($duration.ToString())"
