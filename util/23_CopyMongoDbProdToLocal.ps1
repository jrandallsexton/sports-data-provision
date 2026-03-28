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

# Database name - using FootballNcaa for both environments
# Connection strings are admin connections, so database must be specified separately
$SourceDatabase = "FootballNcaa"
$DestDatabase = "FootballNcaa"

# =========================
# Step 1: Verify Connectivity
# =========================

Write-Host "[STEP 1/4] Verifying MongoDB connectivity..." -ForegroundColor Cyan
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
# Step 2: Dump Production Database
# =========================

Write-Host "[STEP 2/4] Dumping production MongoDB database..." -ForegroundColor Cyan
Write-Host ""

$dumpDir = "C:\Backups\FromProd\MongoDB\$SourceDatabase"

# Create dump directory
if (Test-Path $dumpDir) {
    Write-Host "  Removing existing dump directory..."
    Remove-Item $dumpDir -Recurse -Force
}

New-Item -ItemType Directory -Path $dumpDir -Force | Out-Null
Write-Host "  Dump directory: $dumpDir" -ForegroundColor Gray

# Build mongodump command with connection string
$dumpArgs = @(
    "--uri=`"$SourceConnectionString`""
    "--authenticationDatabase=admin"
    "--db=$SourceDatabase"
    "--out=$dumpDir"
)

# Add specific collections if specified
if ($Collections.Count -gt 0) {
    Write-Host "  Copying specific collections: $($Collections -join ', ')" -ForegroundColor Gray
    foreach ($collection in $Collections) {
        $dumpArgs += "--collection=$collection"
    }
}
else {
    Write-Host "  Copying all collections" -ForegroundColor Gray
}

Write-Host "  Executing mongodump..."
& mongodump @dumpArgs

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: mongodump failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Production database dump completed" -ForegroundColor Green
Write-Host ""

# =========================
# Step 3: Clear Destination Database (Optional)
# =========================

if ($Force) {
    Write-Host "[STEP 3/4] Clearing destination database..." -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  Dropping database '$DestDatabase' on localhost:27017..."
    
    $dropCmd = "db.getSiblingDB('$DestDatabase').dropDatabase()"
    mongosh "$DestConnectionString" --quiet --eval $dropCmd
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Destination database cleared" -ForegroundColor Green
    }
    else {
        Write-Warning "  Failed to clear destination database (may not exist yet)"
    }

    Write-Host ""
    Write-Host "Destination database cleared" -ForegroundColor Green
    Write-Host ""
}
else {
    Write-Host "[STEP 3/4] Skipping destination database clear (use -Force to enable)" -ForegroundColor Yellow
    Write-Host ""
}

# =========================
# Step 4: Restore to Local Database
# =========================

Write-Host "[STEP 4/4] Restoring to local MongoDB database..." -ForegroundColor Cyan
Write-Host ""

# Build mongorestore command with connection string
$restoreArgs = @(
    "--uri=`"$DestConnectionString`""
    "--authenticationDatabase=admin"
    "--db=$DestDatabase"
    "--dir=$dumpDir\$SourceDatabase"
    "--drop"  # Drop collections before restoring
)

Write-Host "  Executing mongorestore..."
& mongorestore @restoreArgs

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: mongorestore failed with exit code $LASTEXITCODE"
}

Write-Host ""
Write-Host "Restore to local database completed" -ForegroundColor Green
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
Write-Host "Source: $SourceHost`:$SourcePort / $SourceDatabase" -ForegroundColor White
Write-Host "Destination: $DestHost`:$DestPort / $DestDatabase" -ForegroundColor White
Write-Host "Dump Location: $dumpDir" -ForegroundColor White
Write-Host ""
Write-Host "Your local MongoDB database now contains production data." -ForegroundColor Green
Write-Host ""
