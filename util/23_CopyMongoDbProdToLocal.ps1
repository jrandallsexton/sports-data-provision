# =========================
# 23_CopyMongoDbProdToLocal.ps1
# End-to-End script to copy production MongoDB data to local MongoDB
# =========================
<#
.SYNOPSIS
    Complete pipeline to copy production MongoDB data to local MongoDB.

.DESCRIPTION
    Copies all collections from production MongoDB to local MongoDB using 
    mongodump and mongorestore for optimal performance.
    
    This script:
    1. Validates source (prod) and destination (local) MongoDB connectivity
    2. Dumps production database to local disk
    3. Optionally clears destination database before restoring
    4. Restores dump to local MongoDB

.PARAMETER Force
    When specified, automatically clears destination database before restoring
    without prompting for confirmation.

.PARAMETER SourceHost
    Source MongoDB host (default: 192.168.0.3 - production MongoDB NUC)

.PARAMETER SourcePort
    Source MongoDB port (default: 27017)

.PARAMETER SourceDatabase
    Source database name (default: Provider-Prod)

.PARAMETER DestHost
    Destination MongoDB host (default: localhost)

.PARAMETER DestPort
    Destination MongoDB port (default: 27017)

.PARAMETER DestDatabase
    Destination database name (default: Provider-Local)

.PARAMETER Collections
    Array of specific collection names to copy. If not specified, copies all collections.

.NOTES
    This script requires:
    - mongodump and mongorestore CLI tools installed
    - Network access to production MongoDB (192.168.0.250:27017)
    - Local MongoDB instance running
    - SPORTDEETS_SECRETS_PATH environment variable set
#>
[CmdletBinding()]
param(
    [switch]$Force,

    [string]$Sport = "",

    [string[]]$Collections = @()
)

if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startTime = Get-Date

# Load secrets
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

# Parse connection strings from secrets (values sourced from _common-variables.ps1)
$SourceConnectionString = $script:mongoDbProd
$DestConnectionString = $script:mongoDbLocal

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "COPY MONGODB PROD TO LOCAL" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source: Production MongoDB (192.168.0.250:27017)" -ForegroundColor White
Write-Host "Destination: Local MongoDB (localhost:27017)" -ForegroundColor White
Write-Host ""

# Verify mongodump and mongorestore are available
if (-not (Get-Command "mongodump" -ErrorAction SilentlyContinue)) {
    throw "ERROR: mongodump CLI not found. Please install MongoDB Database Tools."
}

if (-not (Get-Command "mongorestore" -ErrorAction SilentlyContinue)) {
    throw "ERROR: mongorestore CLI not found. Please install MongoDB Database Tools."
}

# Final confirmation
if (-not $Force) {
    Write-Host "WARNING: This will overwrite all data in the destination MongoDB database!" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Type 'YES' to continue with MongoDB data copy"
    if ($confirm -ne "YES") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""

# Database to copy — defaults to FootballNcaa, use -Sport to override
$validSports = @("FootballNcaa", "FootballNfl")
if ($Sport -and $Sport -notin $validSports) {
    throw "ERROR: Unknown sport '$Sport'. Valid values: $($validSports -join ', ')"
}

$SourceDatabase = if ($Sport) { $Sport } else { "FootballNcaa" }
$DestDatabase = $SourceDatabase

# =========================
# Step 1: Verify Connectivity
# =========================

Write-Host "[STEP 1/2] Verifying MongoDB connectivity..." -ForegroundColor Cyan
Write-Host ""

# Test source connectivity (production)
Write-Host "  Testing source MongoDB (192.168.0.250:27017)..."
try {
    $sourceTest = mongosh "$SourceConnectionString" --quiet --eval "db.adminCommand('ping')" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to connect to source MongoDB"
    }
    Write-Host "  ✓ Source MongoDB is accessible" -ForegroundColor Green
}
catch {
    throw "ERROR: Cannot connect to source MongoDB at 192.168.0.250:27017 - $_"
}

# Test destination connectivity (local)
Write-Host "  Testing destination MongoDB (localhost:27017)..."
try {
    $destTest = mongosh "$DestConnectionString" --quiet --eval "db.adminCommand('ping')" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to connect to destination MongoDB"
    }
    Write-Host "  ✓ Destination MongoDB is accessible" -ForegroundColor Green
}
catch {
    throw "ERROR: Cannot connect to destination MongoDB at localhost:27017 - $_"
}

Write-Host ""
Write-Host "Connectivity verification completed" -ForegroundColor Green
Write-Host ""

# =========================
# Step 2/2: Pipe mongodump directly to mongorestore (no intermediate disk)
# =========================

Write-Host "[STEP 2/2] Piping production MongoDB directly to local (--archive)..." -ForegroundColor Cyan
Write-Host ""

if ($Collections.Count -gt 0) {
    Write-Host "  Copying specific collections: $($Collections -join ', ')" -ForegroundColor Gray
} else {
    Write-Host "  Copying all collections from $SourceDatabase" -ForegroundColor Gray
}

# Build mongodump arguments for archive-to-stdout
$dumpArgs = @(
    "--uri=`"$SourceConnectionString`""
    "--authenticationDatabase=admin"
    "--db=$SourceDatabase"
    "--archive"
)

if ($Collections.Count -gt 0) {
    foreach ($collection in $Collections) {
        $dumpArgs += "--collection=$collection"
    }
}

# Build mongorestore arguments for archive-from-stdin
$restoreArgs = @(
    "--uri=`"$DestConnectionString`""
    "--authenticationDatabase=admin"
    "--nsFrom=`"$SourceDatabase.*`""
    "--nsTo=`"$DestDatabase.*`""
    "--archive"
    "--drop"
)

Write-Host "  Executing: mongodump --archive | mongorestore --archive --drop" -ForegroundColor Gray
Write-Host "  (This streams data directly without writing to disk)" -ForegroundColor Gray

# Use cmd /c to create a proper pipe between the two processes
$dumpCmd = "mongodump $($dumpArgs -join ' ')"
$restoreCmd = "mongorestore $($restoreArgs -join ' ')"
$pipeCmd = "$dumpCmd | $restoreCmd"

& cmd /c $pipeCmd

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: mongodump | mongorestore pipeline failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Pipeline completed successfully" -ForegroundColor Green
Write-Host ""

# =========================
# Summary
# =========================

$duration = (Get-Date) - $startTime

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "MONGODB COPY COMPLETE!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Duration: $($duration.ToString())" -ForegroundColor White
Write-Host ""
Write-Host "Source DB: $SourceDatabase (production)" -ForegroundColor White
Write-Host "Dest DB:   $DestDatabase (local)" -ForegroundColor White
Write-Host "Method:    Streamed via --archive pipe (no intermediate disk)" -ForegroundColor White
Write-Host ""
Write-Host "Your local MongoDB database now contains production data." -ForegroundColor Green
Write-Host ""
