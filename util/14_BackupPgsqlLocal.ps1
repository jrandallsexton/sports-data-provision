# === Configuration ===
$pgBinPath = "C:\Program Files\PostgreSQL\17\bin"  # Adjust version/path as needed
$backupRoot = "C:\Backups\Postgres"
$pgUser = "postgres"

# === Prep backup folder ===
$timestamp = Get-Date -Format "yyyyMMdd-HHmm"
$backupFolder = Join-Path $backupRoot "sd-backup-$timestamp"
New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null

# === Get list of databases starting with 'sd' ===
$psqlPath = Join-Path $pgBinPath "psql.exe"
$pgDumpPath = Join-Path $pgBinPath "pg_dump.exe"

Write-Host "Retrieving list of SportDeets databases..."
$dbList = & $psqlPath -U $pgUser -d postgres -t -c "SELECT datname FROM pg_database WHERE datname LIKE 'sd%'" 2>$null
$dbList = $dbList | Where-Object { $_ -and $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }

# === Backup each database ===
foreach ($db in $dbList) {
    $backupFile = Join-Path $backupFolder "$db.sql"
    Write-Host "Backing up $db to $backupFile ..."
    & $pgDumpPath -U $pgUser -d $db -f $backupFile
}

Write-Host "`n✅ All SportDeets databases backed up to: $backupFolder"
