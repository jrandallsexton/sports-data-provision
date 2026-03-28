#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Monitors Hangfire queues for Producer and Provider until both drain to zero
.DESCRIPTION
    Queries PostgreSQL Hangfire databases every 60 seconds and records when queues empty
#>

$ErrorActionPreference = 'Stop'

# Load secrets
if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

# PostgreSQL connection details
$pgHost = $script:pgHostProd
$pgPort = "5432"
$pgUser = $script:pgUserProd
$pgPassword = $script:pgPasswordProd

$producerDb = "sdProducer.FootballNcaa.Hangfire"
$providerDb = "sdProvider.FootballNcaa.Hangfire"

# Results
$results = @{
    StartTime = Get-Date
    ProducerEmptyTime = $null
    ProviderEmptyTime = $null
    ProducerStartCount = $null
    ProviderStartCount = $null
}

$logFile = "C:\Projects\sports-data-provision\util\hangfire-drain-log.txt"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage
    Add-Content -Path $logFile -Value $logMessage
}

function Get-QueueCount {
    param(
        [string]$Database
    )
    
    $env:PGPASSWORD = $pgPassword
    $query = "SELECT COUNT(*)::int FROM hangfire.jobqueue WHERE fetchedat IS NULL AND queue = 'default';"
    
    try {
        $result = & psql -h $pgHost -p $pgPort -U $pgUser -d $Database -t -A -c $query 2>$null
        return [int]$result.Trim()
    }
    catch {
        Write-Log "ERROR querying $Database : $_"
        return -1
    }
    finally {
        Remove-Item Env:\PGPASSWORD -ErrorAction SilentlyContinue
    }
}

Write-Log "========================================="
Write-Log "Starting Hangfire Queue Monitor"
Write-Log "========================================="

# Get initial counts
$producerCount = Get-QueueCount -Database $producerDb
$providerCount = Get-QueueCount -Database $providerDb

$results.ProducerStartCount = $producerCount
$results.ProviderStartCount = $providerCount

Write-Log "Initial counts:"
Write-Log "  Producer: $($producerCount.ToString('N0')) jobs"
Write-Log "  Provider: $($providerCount.ToString('N0')) jobs"
Write-Log ""

$iteration = 0

while ($true) {
    Start-Sleep -Seconds 60
    $iteration++
    
    # Check Producer queue
    if ($null -eq $results.ProducerEmptyTime) {
        $producerCount = Get-QueueCount -Database $producerDb
        if ($producerCount -eq 0) {
            $results.ProducerEmptyTime = Get-Date
            Write-Log "🎉 PRODUCER QUEUE EMPTY at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Write-Log "   Duration: $(($results.ProducerEmptyTime - $results.StartTime).ToString('hh\:mm\:ss'))"
        }
    }
    
    # Check Provider queue
    if ($null -eq $results.ProviderEmptyTime) {
        $providerCount = Get-QueueCount -Database $providerDb
        if ($providerCount -eq 0) {
            $results.ProviderEmptyTime = Get-Date
            Write-Log "🎉 PROVIDER QUEUE EMPTY at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
            Write-Log "   Duration: $(($results.ProviderEmptyTime - $results.StartTime).ToString('hh\:mm\:ss'))"
        }
    }
    
    # Log progress every 10 minutes (10 iterations)
    if ($iteration % 10 -eq 0) {
        $elapsed = (Get-Date) - $results.StartTime
        Write-Log "Progress check (elapsed: $($elapsed.ToString('hh\:mm\:ss'))):"
        if ($null -eq $results.ProducerEmptyTime) {
            $processed = $results.ProducerStartCount - $producerCount
            $rate = if ($elapsed.TotalMinutes -gt 0) { [math]::Round($processed / $elapsed.TotalMinutes, 1) } else { 0 }
            Write-Log "  Producer: $($producerCount.ToString('N0')) remaining ($($processed.ToString('N0')) processed, $rate jobs/min)"
        }
        if ($null -eq $results.ProviderEmptyTime) {
            $processed = $results.ProviderStartCount - $providerCount
            $rate = if ($elapsed.TotalMinutes -gt 0) { [math]::Round($processed / $elapsed.TotalMinutes, 1) } else { 0 }
            Write-Log "  Provider: $($providerCount.ToString('N0')) remaining ($($processed.ToString('N0')) processed, $rate jobs/min)"
        }
    }
    
    # Exit when both queues are empty
    if ($null -ne $results.ProducerEmptyTime -and $null -ne $results.ProviderEmptyTime) {
        Write-Log ""
        Write-Log "========================================="
        Write-Log "BOTH QUEUES DRAINED - MONITORING COMPLETE"
        Write-Log "========================================="
        Write-Log "Summary:"
        Write-Log "  Started: $($results.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Log "  Producer emptied: $($results.ProducerEmptyTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Log "  Provider emptied: $($results.ProviderEmptyTime.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Log "  Producer processed: $($results.ProducerStartCount.ToString('N0')) jobs in $(($results.ProducerEmptyTime - $results.StartTime).ToString('hh\:mm\:ss'))"
        Write-Log "  Provider processed: $($results.ProviderStartCount.ToString('N0')) jobs in $(($results.ProviderEmptyTime - $results.StartTime).ToString('hh\:mm\:ss'))"
        
        # Save final results to JSON
        $resultsFile = "C:\Projects\sports-data-provision\util\hangfire-drain-results.json"
        $results | ConvertTo-Json | Set-Content -Path $resultsFile
        Write-Log "Results saved to: $resultsFile"
        
        break
    }
}
