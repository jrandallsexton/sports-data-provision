# === Start timing ===
$startTime = Get-Date

# === Load secrets ===
$secretsPath = $env:SPORTDEETS_SECRETS_PATH
. "$secretsPath\_common-variables.ps1"

# DEV settings (from secrets)
$devHost = $script:pgHostDev
$devPort = $script:pgPortDev
$devUser = $script:pgUserDev
$devPassword = $script:pgPasswordDev

# Local settings
$pgBinPathLocal = "C:\Program Files\PostgreSQL\17\bin"
$pgBinPathDev = $pgBinPathLocal
$pgRestoreTargetUser = "postgres"
$env:PGPASSWORD = $devPassword

# Backup path
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$backupFolder = Join-Path "C:\Backups\FromDev" "sd-dev-backup-$timestamp"
New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

$psqlPath = Join-Path $pgBinPathDev "psql.exe"
$pgDumpPath = Join-Path $pgBinPathDev "pg_dump.exe"

# === Get list of DEV databases matching 'sd%' ===
Write-Host "[INFO] Getting database list from DEV..."
$dbList = & $psqlPath -h $devHost -p $devPort -U $devUser -d postgres -t -c "SELECT datname FROM pg_database WHERE datname LIKE 'sd%'" 2>$null
$dbList = $dbList | Where-Object { $_ -and $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }

if (-not $dbList) {
    Write-Host "[ERROR] No SportDeets databases found on DEV."
    exit 1
}

# === Backup each DEV database ===
foreach ($db in $dbList) {
    $backupFile = Join-Path $backupFolder "$db.sql"
    Write-Host "[DOWN] Pulling $db from DEV to $backupFile ..."
    & $pgDumpPath -h $devHost -p $devPort -U $devUser -d $db -f $backupFile
}

Write-Host "`n[OK] DEV databases backed up to: $backupFolder"

# === Restore to local ===
$env:PGPASSWORD = $script:pgPasswordLocal  # local password

foreach ($sqlFile in Get-ChildItem -Path $backupFolder -Filter "*.sql") {
    $dbName = [System.IO.Path]::GetFileNameWithoutExtension($sqlFile.Name).Trim().TrimEnd(';')

    Write-Host "[RESTORE] Restoring $dbName to local Postgres..."

    & $psqlPath -U $pgRestoreTargetUser -d postgres -c "DROP DATABASE IF EXISTS `"$dbName`";"
    & $psqlPath -U $pgRestoreTargetUser -d postgres -c "CREATE DATABASE `"$dbName`";"
    & $psqlPath -U $pgRestoreTargetUser -d $dbName -f $sqlFile.FullName
}

Write-Host "`n[OK] All databases restored to local instance."

# === End timing ===
$endTime = Get-Date
$duration = $endTime - $startTime
Write-Host "`n[TIME] Total duration: $($duration.ToString())"
