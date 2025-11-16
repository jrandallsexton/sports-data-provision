# === Start timing ===
$startTime = Get-Date

# === Load secrets ===
$secretsPath = $env:SPORTDEETS_SECRETS_PATH
. "$secretsPath\_common-variables.ps1"

# DEV settings
$devHost = $script:pgHostDev
$devPort = $script:pgPortDev
$devUser = $script:pgUserDev
$devPassword = $script:pgPasswordDev

# Local settings
$pgBinPathLocal = "C:\Program Files\PostgreSQL\17\bin"
$pgRestoreTargetUser = "postgres"
$env:PGPASSWORD = $devPassword

# Paths
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$backupFolder = Join-Path "C:\Backups\FromDev" "sd-dev-backup-$timestamp"
New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

$psqlPath = Join-Path $pgBinPathLocal "psql.exe"
$pgDumpPath = Join-Path $pgBinPathLocal "pg_dump.exe"
$pgRestorePath = Join-Path $pgBinPathLocal "pg_restore.exe"

# === Get list of DEV databases matching 'sd%' ===
Write-Host "[INFO] Getting database list from DEV..."
$dbList = & $psqlPath -h $devHost -p $devPort -U $devUser -d postgres -t -c "SELECT datname FROM pg_database WHERE datname LIKE 'sd%'" 2>$null
$dbList = $dbList | Where-Object { $_ -and $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }

if (-not $dbList) {
    Write-Host "[ERROR] No SportDeets databases found on DEV."
    exit 1
}

# === Parallel backup using jobs ===
Write-Host "[INFO] Starting parallel backups..."
foreach ($db in $dbList) {
    Start-Job -ScriptBlock {
        param($pgDumpPath, $devHost, $devPort, $devUser, $db, $backupFolder)
        $env:PGPASSWORD = $using:devPassword
        $backupFile = Join-Path $backupFolder "$db.dump"
        & $pgDumpPath -h $devHost -p $devPort -U $devUser -d $db -Fc --no-owner --no-acl -f $backupFile
    } -ArgumentList $pgDumpPath, $devHost, $devPort, $devUser, $db, $backupFolder
}
Get-Job | Wait-Job
Write-Host "`n[OK] All backups completed to: $backupFolder"

# === Restore to local ===
$env:PGPASSWORD = $script:pgPasswordLocal  # local password

foreach ($dumpFile in Get-ChildItem -Path $backupFolder -Filter "*.dump") {
    $dbName = [System.IO.Path]::GetFileNameWithoutExtension($dumpFile.Name).Trim().TrimEnd(';')
    $quotedDbName = '"' + $dbName.Replace('"', '""') + '"'

    Write-Host "[RESTORE] Restoring $dbName to local Postgres..."

    & $psqlPath -U $pgRestoreTargetUser -d postgres -c "DROP DATABASE IF EXISTS $quotedDbName;"
    & $psqlPath -U $pgRestoreTargetUser -d postgres -c "CREATE DATABASE $quotedDbName;"
    & $pgRestorePath -U $pgRestoreTargetUser -d $dbName -j 4 -Fc $dumpFile.FullName
}

Write-Host "`n[OK] All databases restored to local instance."

# === End timing ===
$endTime = Get-Date
$duration = $endTime - $startTime
Write-Host "`n[TIME] Total duration: $($duration.ToString())"