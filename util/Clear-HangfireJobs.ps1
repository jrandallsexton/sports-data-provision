#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deletes all queued Hangfire jobs from Producer and/or Provider databases
.DESCRIPTION
    Truncates Hangfire job tables to clear all pending jobs. Use with caution.
.PARAMETER Database
    Which database to clear: Producer, Provider, or Both (default)
.PARAMETER Sport
    Sport mode: FootballNcaa (default), FootballNfl, GolfPga, etc.
.PARAMETER Target
    Environment target: Local (default) or Prod
.PARAMETER WhatIf
    Show what would be deleted without actually deleting
.EXAMPLE
    .\Clear-HangfireJobs.ps1 -Database Provider -Target Local
    .\Clear-HangfireJobs.ps1 -Database Both -Sport FootballNcaa -Target Prod
    .\Clear-HangfireJobs.ps1 -WhatIf
#>

param(
    [ValidateSet('Producer', 'Provider', 'Both')]
    [string]$Database = 'Both',
    
    [ValidateSet('FootballNcaa', 'FootballNfl', 'GolfPga')]
    [string]$Sport = 'FootballNcaa',
    
    [ValidateSet('Local', 'Prod')]
    [string]$Target = 'Local',
    
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# Load secrets file
if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}

$secretsPath = $env:SPORTDEETS_SECRETS_PATH
. "$secretsPath\_common-variables.ps1"

# PostgreSQL connection details from secrets based on target
if ($Target -eq 'Local') {
    $pgHost = $script:pgHostLocal
    $pgPort = "5432"
    $pgUser = $script:pgUserLocal
    $pgPassword = $script:pgPasswordLocal
} else {
    $pgHost = $script:pgHostProd
    $pgPort = "5432"
    $pgUser = $script:pgUserProd
    $pgPassword = $script:pgPasswordProd
}

$producerDb = "sdProducer.$Sport.Hangfire"
$providerDb = "sdProvider.$Sport.Hangfire"

function Write-ColorLog {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Get-QueueCount {
    param([string]$DatabaseName)
    
    $env:PGPASSWORD = $pgPassword
    $query = "SELECT COUNT(*)::int FROM hangfire.job WHERE statename = 'Enqueued';"
    
    try {
        $result = & psql -h $pgHost -p $pgPort -U $pgUser -d $DatabaseName -t -A -c $query 2>$null
        return [int]$result.Trim()
    }
    catch {
        Write-ColorLog "ERROR querying $DatabaseName : $_" -Color Red
        return -1
    }
    finally {
        Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
    }
}

function Clear-HangfireDatabase {
    param(
        [string]$DatabaseName,
        [string]$Label
    )
    
    Write-ColorLog "`n=========================================" -Color Cyan
    Write-ColorLog "Processing: $Label ($DatabaseName)" -Color Cyan
    Write-ColorLog "=========================================" -Color Cyan
    
    # Get current count
    $beforeCount = Get-QueueCount -DatabaseName $DatabaseName
    
    if ($beforeCount -lt 0) {
        Write-ColorLog "Failed to query database. Skipping." -Color Red
        return
    }
    
    Write-ColorLog "Jobs queued before clearing: $($beforeCount.ToString('N0'))" -Color Yellow
    
    if ($beforeCount -eq 0) {
        Write-ColorLog "No jobs to clear." -Color Green
        return
    }
    
    if ($WhatIf) {
        Write-ColorLog "[WHATIF] Would delete $($beforeCount.ToString('N0')) jobs from hangfire.jobqueue" -Color Magenta
        Write-ColorLog "[WHATIF] Would delete related records from hangfire.job" -Color Magenta
        Write-ColorLog "[WHATIF] Would delete related records from hangfire.jobparameter" -Color Magenta
        Write-ColorLog "[WHATIF] Would delete related records from hangfire.state" -Color Magenta
        return
    }
    
    # Confirm deletion
    Write-ColorLog "`nWARNING: About to delete $($beforeCount.ToString('N0')) jobs from $DatabaseName" -Color Red
    $confirm = Read-Host "Type 'YES' to confirm deletion"
    
    if ($confirm -ne 'YES') {
        Write-ColorLog "Deletion cancelled." -Color Yellow
        return
    }
    
    Write-ColorLog "`nDeleting jobs..." -Color Yellow
    
    $env:PGPASSWORD = $pgPassword
    
    try {
        # Truncate tables in correct order (respect foreign keys)
        $queries = @(
            "DELETE FROM hangfire.jobqueue;",
            "DELETE FROM hangfire.state;",
            "DELETE FROM hangfire.jobparameter;",
            "DELETE FROM hangfire.job;"
        )
        
        foreach ($query in $queries) {
            Write-ColorLog "  Executing: $query" -Color Gray
            & psql -h $pgHost -p $pgPort -U $pgUser -d $DatabaseName -c $query 2>$null | Out-Null
        }
        
        # Vacuum to reclaim space
        Write-ColorLog "  Vacuuming tables..." -Color Gray
        & psql -h $pgHost -p $pgPort -U $pgUser -d $DatabaseName -c "VACUUM FULL hangfire.jobqueue, hangfire.state, hangfire.jobparameter, hangfire.job;" 2>$null | Out-Null
        
        # Verify deletion
        $afterCount = Get-QueueCount -DatabaseName $DatabaseName
        
        Write-ColorLog "`n✓ Deletion complete!" -Color Green
        Write-ColorLog "  Jobs before: $($beforeCount.ToString('N0'))" -Color Gray
        Write-ColorLog "  Jobs after:  $($afterCount.ToString('N0'))" -Color Gray
        Write-ColorLog "  Deleted:     $($beforeCount - $afterCount | ForEach-Object { $_.ToString('N0') })" -Color Green
    }
    catch {
        Write-ColorLog "ERROR during deletion: $_" -Color Red
    }
    finally {
        Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
    }
}

# Main execution
Write-ColorLog "`n╔════════════════════════════════════════╗" -Color Cyan
Write-ColorLog "║   Hangfire Job Deletion Utility        ║" -Color Cyan
Write-ColorLog "╚════════════════════════════════════════╝" -Color Cyan
Write-ColorLog "Target Environment: $Target" -Color White
Write-ColorLog "PostgreSQL Host: $pgHost" -Color White
Write-ColorLog "Sport: $Sport" -Color White
Write-ColorLog "Database(s): $Database" -Color White

if ($WhatIf) {
    Write-ColorLog "Mode: WHATIF (no changes will be made)" -Color Magenta
}

# Process databases
if ($Database -eq 'Producer' -or $Database -eq 'Both') {
    Clear-HangfireDatabase -DatabaseName $producerDb -Label "Producer"
}

if ($Database -eq 'Provider' -or $Database -eq 'Both') {
    Clear-HangfireDatabase -DatabaseName $providerDb -Label "Provider"
}

Write-ColorLog "`n=========================================" -Color Cyan
Write-ColorLog "Operation Complete" -Color Cyan
Write-ColorLog "=========================================" -Color Cyan
