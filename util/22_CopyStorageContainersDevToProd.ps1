#!/usr/bin/env pwsh
# Copy blob containers from dev storage account to prod storage account

param(
    [switch]$WhatIf
)

# Source (Dev) Configuration
$sourceAccount = "sportdeetssadev"
$sourceResourceGroup = "rg-sportDeets-dev2"
$sourceSubscription = "vsprem1_150"

# Target (Prod) Configuration
$targetAccount = "sportdeetssa"
$targetResourceGroup = "rg-sportDeets-prod"
$targetSubscription = "vspro_50"

Write-Host "Storage Account Container Copy Plan" -ForegroundColor Cyan
Write-Host "Source:      $sourceAccount (in $sourceResourceGroup)" -ForegroundColor Yellow
Write-Host "Destination: $targetAccount (in $targetResourceGroup)" -ForegroundColor Green
Write-Host ""

# Get source containers
Write-Host "Fetching containers from source storage account..." -ForegroundColor Cyan
az account set --subscription $sourceSubscription | Out-Null

$sourceContainers = az storage container list `
    --account-name $sourceAccount `
    --auth-mode key `
    --query "[].name" `
    --output json | ConvertFrom-Json

if ($sourceContainers.Count -eq 0) {
    Write-Host "No containers found in source storage account" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($sourceContainers.Count) containers to copy:" -ForegroundColor White
foreach ($container in $sourceContainers) {
    # Replace dev- prefix with prod- for target
    $targetContainer = $container -replace '^dev-', 'prod-'
    Write-Host "  $container -> $targetContainer" -ForegroundColor Gray
}

if ($WhatIf) {
    Write-Host ""
    Write-Host "WhatIf mode - no changes will be made" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
$confirmation = Read-Host "Proceed with container copy? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Copy cancelled" -ForegroundColor Red
    exit 0
}

# Copy containers
Write-Host ""
Write-Host "Starting container copy..." -ForegroundColor Cyan
$successCount = 0
$errorCount = 0

foreach ($container in $sourceContainers) {
    # Replace dev- prefix with prod- for target
    $targetContainer = $container -replace '^dev-', 'prod-'
    
    Write-Host ""
    Write-Host "Processing: $container -> $targetContainer" -ForegroundColor Yellow
    
    # Create target container
    Write-Host "  Creating target container..." -ForegroundColor Gray
    az account set --subscription $targetSubscription | Out-Null
    az storage container create `
        --account-name $targetAccount `
        --name $targetContainer `
        --auth-mode key `
        2>&1 | Out-Null
    
    # Get source storage account key
    az account set --subscription $sourceSubscription | Out-Null
    $sourceKey = az storage account keys list `
        --account-name $sourceAccount `
        --resource-group $sourceResourceGroup `
        --query "[0].value" -o tsv
    
    # Get target storage account key
    az account set --subscription $targetSubscription | Out-Null
    $targetKey = az storage account keys list `
        --account-name $targetAccount `
        --resource-group $targetResourceGroup `
        --query "[0].value" -o tsv
    
    # Copy entire container using server-side copy
    Write-Host "  Starting server-side copy..." -ForegroundColor Gray
    
    # Get list of blobs in source container
    az account set --subscription $sourceSubscription | Out-Null
    $blobs = az storage blob list `
        --account-name $sourceAccount `
        --account-key $sourceKey `
        --container-name $container `
        --query "[].name" -o json | ConvertFrom-Json
    
    $totalBlobs = $blobs.Count
    Write-Host "    Found $totalBlobs blobs to copy" -ForegroundColor DarkGray
    
    if ($totalBlobs -eq 0) {
        Write-Host "    No blobs to copy" -ForegroundColor Yellow
        $successCount++
        continue
    }
    
    # Get list of existing blobs in target container
    az account set --subscription $targetSubscription | Out-Null
    $existingBlobs = az storage blob list `
        --account-name $targetAccount `
        --account-key $targetKey `
        --container-name $targetContainer `
        --query "[].name" -o json 2>$null | ConvertFrom-Json
    
    if (-not $existingBlobs) {
        $existingBlobs = @()
    }
    
    # Filter blobs to only copy those that don't exist
    $blobsToCopy = @()
    foreach ($blob in $blobs) {
        if ($blob -notin $existingBlobs) {
            $blobsToCopy += $blob
        }
    }
    
    $skippedCount = $totalBlobs - $blobsToCopy.Count
    
    if ($skippedCount -gt 0) {
        Write-Host "    Skipping $skippedCount blobs that already exist" -ForegroundColor DarkGray
    }
    
    if ($blobsToCopy.Count -eq 0) {
        Write-Host "    All blobs already exist in target" -ForegroundColor Green
        $successCount++
        continue
    }
    
    Write-Host "    Copying $($blobsToCopy.Count) new blobs" -ForegroundColor DarkGray
    
    # Start async copy for all blobs
    $copyJobs = @()
    $blobNum = 0
    foreach ($blob in $blobsToCopy) {
        $blobNum++
        az account set --subscription $targetSubscription | Out-Null
        
        $result = az storage blob copy start `
            --account-name $targetAccount `
            --account-key $targetKey `
            --destination-container $targetContainer `
            --destination-blob $blob `
            --source-account-name $sourceAccount `
            --source-account-key $sourceKey `
            --source-container $container `
            --source-blob $blob `
            -o json 2>$null | ConvertFrom-Json
        
        if ($result) {
            $copyJobs += @{
                Blob = $blob
                CopyId = $result.copy.id
            }
        }
        
        if ($blobNum % 100 -eq 0) {
            Write-Host "    Started copy for $blobNum/$($blobsToCopy.Count) blobs..." -ForegroundColor DarkGray
        }
    }
    
    Write-Host "    Started $($copyJobs.Count) copy operations" -ForegroundColor DarkGray
    Write-Host "    Waiting for copies to complete..." -ForegroundColor Gray
    
    # Wait for all copies to complete
    $completed = 0
    $maxRetries = 60
    $retryCount = 0
    
    while ($completed -lt $copyJobs.Count -and $retryCount -lt $maxRetries) {
        Start-Sleep -Seconds 5
        $retryCount++
        
        $stillPending = 0
        foreach ($job in $copyJobs) {
            $status = az storage blob show `
                --account-name $targetAccount `
                --account-key $targetKey `
                --container-name $targetContainer `
                --name $job.Blob `
                --query "properties.copy.status" -o tsv 2>$null
            
            if ($status -eq "pending") {
                $stillPending++
            }
        }
        
        $completed = $copyJobs.Count - $stillPending
        
        if ($completed % 50 -eq 0 -or $stillPending -eq 0) {
            Write-Host "    Progress: $completed/$($copyJobs.Count) complete" -ForegroundColor DarkGray
        }
        
        if ($stillPending -eq 0) {
            break
        }
    }
    
    if ($completed -eq $copyJobs.Count) {
        Write-Host "    All $($blobsToCopy.Count) new blobs copied successfully ($skippedCount skipped)" -ForegroundColor DarkGray
        $successCount++
        Write-Host "  Completed successfully" -ForegroundColor Green
    } else {
        Write-Host "    Copy timed out or incomplete: $completed/$($blobsToCopy.Count)" -ForegroundColor Yellow
        $errorCount++
        Write-Host "  Completed with warnings" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Container Copy Complete!" -ForegroundColor Green
Write-Host "  Successfully copied: $successCount containers" -ForegroundColor Green
Write-Host "  Errors:             $errorCount containers" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
Write-Host ""
