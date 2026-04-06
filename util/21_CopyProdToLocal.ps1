# =========================
# 21_CopyProdToLocal.ps1
# End-to-End script to copy production data to local development environment
# =========================
<#
.SYNOPSIS
    Complete pipeline to copy production data to local PostgreSQL and MongoDB.

.DESCRIPTION
    Executes the following steps:
    1. Backup production databases to local disk (20_BackupProdToLocalDisk.ps1)
    2. Reset local databases (10_ResetLocalData.ps1 with forced YES)
    3. Restore backups to local databases (18_RestoreLocalFromLocalDumps.ps1)
    4. Copy production MongoDB to local MongoDB (23_CopyMongoDbProdToLocal.ps1)

.PARAMETER Sport
    Optional sport filter (e.g., FootballNfl, FootballNcaa).
    When specified, only backs up/restores databases for that sport.
    When omitted, processes all sports.

.PARAMETER Force
    Skip the confirmation prompt

.PARAMETER NoBackup
    Skip the production backup step (Step 1). Useful for testing the reset/restore steps.

.NOTES
    This script will DESTROY local data for the targeted sport(s) and replace it with production data.
    Use with caution.
#>
[CmdletBinding()]
param(
    [string]$Sport = "",
    [switch]$Force,
    [switch]$NoBackup
)

if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startTime = Get-Date

$sportDisplay = if ($Sport) { $Sport } else { "all sports" }

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "COPY PRODUCTION TO LOCAL E2E ($sportDisplay)" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "WARNING: This will DESTROY local data for $sportDisplay!" -ForegroundColor Red
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

# Build sport args for sub-scripts
$sportParams = @{}
if ($Sport) { $sportParams["Sport"] = $Sport }

# =========================
# Step 1: Backup Production to Local Disk
# =========================

if ($NoBackup) {
    Write-Host "[STEP 1/4] SKIPPED - NoBackup flag set" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "[STEP 1/4] Backing up production databases to local disk..." -ForegroundColor Cyan
    Write-Host ""

    $backupScript = Join-Path $scriptDir "20_BackupProdToLocalDisk.ps1"
    if (-not (Test-Path $backupScript)) {
        throw "ERROR: Backup script not found: $backupScript"
    }

    & $backupScript @sportParams

    if ($LASTEXITCODE -ne 0) {
        throw "ERROR: Production backup failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "Production backup completed" -ForegroundColor Green
    Write-Host ""
}

# =========================
# Step 2: Reset Local Data (Auto-confirm YES)
# =========================

Write-Host "[STEP 2/4] Resetting local databases..." -ForegroundColor Cyan
Write-Host ""

$resetScript = Join-Path $scriptDir "10_ResetLocalData.ps1"
if (-not (Test-Path $resetScript)) {
    throw "ERROR: Reset script not found: $resetScript"
}

Write-Host "  Automatically confirming local data reset..." -ForegroundColor Gray
& $resetScript -Force @sportParams

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: Local data reset failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Local data reset completed" -ForegroundColor Green
Write-Host ""

# =========================
# Step 3+4: Restore PG and Copy MongoDB IN PARALLEL
# =========================

$restoreScript = Join-Path $scriptDir "18_RestoreLocalFromLocalDumps.ps1"
if (-not (Test-Path $restoreScript)) {
    throw "ERROR: Restore script not found: $restoreScript"
}

$mongoScript = Join-Path $scriptDir "23_CopyMongoDbProdToLocal.ps1"
if (-not (Test-Path $mongoScript)) {
    throw "ERROR: MongoDB copy script not found: $mongoScript"
}

Write-Host "[STEP 3+4] Running PG restore and MongoDB copy in parallel..." -ForegroundColor Cyan
Write-Host ""

# Build argument strings for sub-scripts
$sportArg = if ($Sport) { "-Sport `"$Sport`"" } else { "" }

$pgRestoreJob = Start-Job -ScriptBlock {
    param($script_, $sportArg_)
    $expr = "& `"$script_`" $sportArg_"
    $output = Invoke-Expression $expr 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $output; Step = "PG Restore" }
} -ArgumentList $restoreScript, $sportArg

$mongoJob = Start-Job -ScriptBlock {
    param($script_, $sportArg_)
    $expr = "& `"$script_`" -Force $sportArg_"
    $output = Invoke-Expression $expr 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $output; Step = "MongoDB Copy" }
} -ArgumentList $mongoScript, $sportArg

Write-Host "  [PG Restore]  Job started (ID: $($pgRestoreJob.Id))" -ForegroundColor Gray
Write-Host "  [MongoDB Copy] Job started (ID: $($mongoJob.Id))" -ForegroundColor Gray
Write-Host ""
Write-Host "  Waiting for both jobs to complete..." -ForegroundColor Yellow

@($pgRestoreJob, $mongoJob) | Wait-Job | Out-Null

$anyFailed = $false
foreach ($job in @($pgRestoreJob, $mongoJob)) {
    $result = Receive-Job -Job $job
    $info = $result | Where-Object { $_ -is [hashtable] } | Select-Object -Last 1

    if ($info) {
        Write-Host ""
        Write-Host "--- $($info.Step) Output ---" -ForegroundColor Cyan
        Write-Host $info.Output
        if ($info.ExitCode -ne 0) {
            $anyFailed = $true
            Write-Warning "$($info.Step) failed with exit code $($info.ExitCode)"
        } else {
            Write-Host "$($info.Step) completed successfully" -ForegroundColor Green
        }
    }
    Remove-Job -Job $job
}

if ($anyFailed) {
    throw "ERROR: One or more parallel steps failed. See output above."
}

Write-Host ""

# =========================
# Summary
# =========================

$duration = (Get-Date) - $startTime

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "E2E COPY COMPLETE ($sportDisplay)" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Duration: $($duration.ToString())" -ForegroundColor White
Write-Host ""
Write-Host "Your local databases now contain production data." -ForegroundColor Green
Write-Host ""
