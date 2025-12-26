# =========================
# 21_CopyProdToLocal.ps1
# End-to-End script to copy production data to local development environment
# =========================
<#
.SYNOPSIS
    Complete pipeline to copy production data to local PostgreSQL.

.DESCRIPTION
    Executes the following steps:
    1. Backup production databases to local disk (20_BackupProdToLocalDisk.ps1)
    2. Reset local databases (10_ResetLocalData.ps1 with forced YES)
    3. Restore backups to local databases (18_RestoreLocalFromLocalDumps.ps1)

.NOTES
    This script will DESTROY all local data and replace it with production data.
    Use with caution.
#>
[CmdletBinding()]
param(
    [switch]$Force
)

if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startTime = Get-Date

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "COPY PRODUCTION TO LOCAL E2E" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "WARNING: This will DESTROY all local data!" -ForegroundColor Red
Write-Host ""

# Final confirmation
if (-not $Force) {
    $confirm = Read-Host "Type 'YES' to continue with production data copy"
    if ($confirm -ne "YES") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""

# =========================
# Step 1: Backup Production to Local Disk
# =========================

Write-Host "[STEP 1/3] Backing up production databases to local disk..." -ForegroundColor Cyan
Write-Host ""

$backupScript = Join-Path $scriptDir "20_BackupProdToLocalDisk.ps1"
if (-not (Test-Path $backupScript)) {
    throw "ERROR: Backup script not found: $backupScript"
}

& $backupScript

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: Production backup failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Production backup completed" -ForegroundColor Green
Write-Host ""

# =========================
# Step 2: Reset Local Data (Auto-confirm YES)
# =========================

Write-Host "[STEP 2/3] Resetting local databases..." -ForegroundColor Cyan
Write-Host ""

$resetScript = Join-Path $scriptDir "10_ResetLocalData.ps1"
if (-not (Test-Path $resetScript)) {
    throw "ERROR: Reset script not found: $resetScript"
}

# Auto-confirm by using -Force switch
Write-Host "  Automatically confirming local data reset..." -ForegroundColor Gray
& $resetScript -Force

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: Local data reset failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Local data reset completed" -ForegroundColor Green
Write-Host ""

# =========================
# Step 3: Restore from Local Dumps
# =========================

Write-Host "[STEP 3/3] Restoring production backups to local databases..." -ForegroundColor Cyan
Write-Host ""

$restoreScript = Join-Path $scriptDir "18_RestoreLocalFromLocalDumps.ps1"
if (-not (Test-Path $restoreScript)) {
    throw "ERROR: Restore script not found: $restoreScript"
}

# Update the restore script to use FromProd backup folder
$restoreContent = Get-Content $restoreScript -Raw
$restoreContent = $restoreContent -replace 'C:\\Backups\\FromDev', 'C:\Backups\FromProd'
$tempRestoreScript = Join-Path $env:TEMP "18_RestoreLocalFromLocalDumps_Prod.ps1"
Set-Content -Path $tempRestoreScript -Value $restoreContent

& $tempRestoreScript

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: Restore failed with exit code $LASTEXITCODE"
}

# Clean up temp script
Remove-Item $tempRestoreScript -Force

Write-Host ""
Write-Host "Restore completed" -ForegroundColor Green
Write-Host ""

# =========================
# Summary
# =========================

$duration = (Get-Date) - $startTime

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "E2E COPY COMPLETE!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Duration: $($duration.ToString())" -ForegroundColor White
Write-Host ""
Write-Host "Your local databases now contain production data." -ForegroundColor Green
Write-Host "You can start development with real data!" -ForegroundColor Green
Write-Host ""