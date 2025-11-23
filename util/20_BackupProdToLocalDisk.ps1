# =========================
# Backup Production PostgreSQL databases to local directory
# - Connects to prod VM via SSH
# - Dumps all sd* databases using pg_dump with custom format
# - Downloads backups to local directory (overwrites existing)
# - Compatible with 18_RestoreLocalFromLocalDumps.ps1
# =========================

# === Load secrets ===
$secretsPath = $env:SPORTDEETS_SECRETS_PATH
if (-not $secretsPath) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}
. "$secretsPath\_common-variables.ps1"

# -------- CONFIG --------
$backupFolder = "C:\Backups\FromProd"   # Local destination for backup files
$pgUser       = $script:pgUserProd
$pgPassword   = $script:pgPasswordProd
$pgHost       = $script:pgHostProd

# PostgreSQL binaries (adjust path if needed)
$psqlPath      = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$pgDumpPath    = "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe"

# PostgreSQL port
$pgPort = 5432
# ------------------------

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Production Database Backup to Local" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

$startTime = Get-Date

# Ensure local backup folder exists
if (-not (Test-Path $backupFolder)) {
    Write-Host "[INFO] Creating backup folder: $backupFolder" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $backupFolder -Force | Out-Null
}

Write-Host "[INFO] Backup destination: $backupFolder" -ForegroundColor White
Write-Host "[INFO] Source: $($pgUser)@$($pgHost):$($pgPort) (production VM)" -ForegroundColor White
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

$dbListQuery = "SELECT datname FROM pg_database WHERE datname LIKE 'sd%' ORDER BY datname"
$databases = & $psqlPath -h $pgHost -p $pgPort -U $pgUser -d postgres -t -A -c $dbListQuery

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: Failed to query databases with exit code $LASTEXITCODE"
}

$dbList = $databases -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() }

if (-not $dbList) {
    throw "ERROR: No databases found matching 'sd%' pattern"
}

Write-Host "  ✅ Found $($dbList.Count) databases" -ForegroundColor Green
Write-Host ""

# Step 2: Dump each database
Write-Host "[Step 2] Dumping databases..." -ForegroundColor Yellow

$dumpCount = 0
foreach ($dbName in $dbList) {
    $backupFile = Join-Path $backupFolder "$dbName.backup"
    
    Write-Host "  - Dumping $dbName..." -ForegroundColor Gray
    
    & $pgDumpPath -h $pgHost -p $pgPort -U $pgUser -Fc -f $backupFile $dbName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "  ⚠️  Failed to dump $dbName"
    } else {
        $dumpCount++
        $fileSize = (Get-Item $backupFile).Length / 1MB
        Write-Host "    ✅ $dbName dumped ($([math]::Round($fileSize, 2)) MB)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "  ✅ Dumped $dumpCount databases" -ForegroundColor Green
Write-Host ""

# Clean up password
$env:PGPASSWORD = $null

# Summary
$duration = (Get-Date) - $startTime

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "BACKUP COMPLETE! 🎉" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Backup Location:  $backupFolder" -ForegroundColor White
Write-Host "Files Dumped:     $dumpCount" -ForegroundColor White
Write-Host "Total Duration:   $($duration.ToString())" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  Run: .\18_RestoreLocalFromLocalDumps.ps1" -ForegroundColor White
Write-Host "  (Update backup folder to: $backupFolder)" -ForegroundColor Gray
Write-Host ""
