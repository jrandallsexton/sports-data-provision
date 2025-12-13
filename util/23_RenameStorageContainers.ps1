# Rename storage containers by copying to new names within sportdeetssa
# All new containers are configured for anonymous blob access (public read access for blobs)

param(
    [string]$SubscriptionName = "vspro_50",
    [string]$ResourceGroup = "rg-sportDeets-prod",
    [string]$StorageAccount = "sportdeetssa"
)

$ErrorActionPreference = "Stop"

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Rename Storage Containers (Copy to New Names)" -ForegroundColor Cyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Subscription: $SubscriptionName" -ForegroundColor Gray
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "Storage Account: $StorageAccount" -ForegroundColor Gray
Write-Host ""

# Set subscription context
Write-Host "Setting Azure subscription context..." -ForegroundColor Yellow
az account set --subscription $SubscriptionName

# Define container mappings (source => destination)
$containerMappings = @{
    "football-ncaa-athlete-image" = "athlete-image-football-ncaa"
    "football-ncaa-athlete-image-2025" = "athlete-image-football-ncaa-2025"
    "football-ncaa-franchise-logo" = "franchise-logo-football-ncaa"
    "football-ncaa-franchise-logo-2025" = "franchise-logo-football-ncaa-2025"
    "football-ncaa-team-by-season-logo-2025" = "team-by-season-logo-football-ncaa-2025"
    "football-ncaa-venue-image" = "venue-image-football-ncaa"
}

# Get storage account key
Write-Host "Retrieving storage account key..." -ForegroundColor Yellow
$storageKey = az storage account keys list `
    --resource-group $ResourceGroup `
    --account-name $StorageAccount `
    --query "[0].value" `
    --output tsv

if (-not $storageKey) {
    Write-Host "Failed to retrieve storage account key!" -ForegroundColor Red
    exit 1
}

Write-Host "Storage account key retrieved successfully" -ForegroundColor Green
Write-Host ""

# Process each container mapping
foreach ($mapping in $containerMappings.GetEnumerator()) {
    $sourceContainer = $mapping.Key
    $destContainer = $mapping.Value
    
    Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
    Write-Host "Processing: $sourceContainer => $destContainer" -ForegroundColor Cyan
    Write-Host "------------------------------------------------------------------" -ForegroundColor Cyan
    
    # Check if source container exists
    Write-Host "Checking if source container exists..." -ForegroundColor Yellow
    $sourceExists = az storage container exists `
        --account-name $StorageAccount `
        --account-key $storageKey `
        --name $sourceContainer `
        --query "exists" `
        --output tsv
    
    if ($sourceExists -ne "true") {
        Write-Host "Source container '$sourceContainer' does not exist. Skipping..." -ForegroundColor Red
        Write-Host ""
        continue
    }
    
    # Check if destination container already exists
    Write-Host "Checking if destination container exists..." -ForegroundColor Yellow
    $destExists = az storage container exists `
        --account-name $StorageAccount `
        --account-key $storageKey `
        --name $destContainer `
        --query "exists" `
        --output tsv
    
    if ($destExists -eq "true") {
        Write-Host "Destination container '$destContainer' already exists. Skipping creation..." -ForegroundColor Yellow
    } else {
        # Create destination container with anonymous blob access
        Write-Host "Creating destination container with public blob access..." -ForegroundColor Yellow
        az storage container create `
            --account-name $StorageAccount `
            --account-key $storageKey `
            --name $destContainer `
            --public-access blob
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Destination container created successfully" -ForegroundColor Green
        } else {
            Write-Host "Failed to create destination container!" -ForegroundColor Red
            continue
        }
    }
    
    # Get blob count for progress indication
    Write-Host "Counting blobs in source container..." -ForegroundColor Yellow
    $blobList = az storage blob list `
        --account-name $StorageAccount `
        --account-key $storageKey `
        --container-name $sourceContainer `
        --query "[].name" `
        --output tsv
    
    if (-not $blobList) {
        Write-Host "No blobs found in source container. Moving to next..." -ForegroundColor Yellow
        Write-Host ""
        continue
    }
    
    $blobCount = ($blobList | Measure-Object -Line).Lines
    Write-Host "Found $blobCount blobs to copy" -ForegroundColor Green
    
    # Copy blobs using Azure CLI batch copy
    Write-Host "Starting blob copy operation (this may take a while for large containers)..." -ForegroundColor Yellow
    
    $blobNames = az storage blob list `
        --account-name $StorageAccount `
        --account-key $storageKey `
        --container-name $sourceContainer `
        --query "[].name" `
        --output tsv
    
    $copiedCount = 0
    $failedCount = 0
    
    foreach ($blobName in $blobNames) {
        $sourceUrl = "https://$StorageAccount.blob.core.windows.net/$sourceContainer/$blobName"
        
        az storage blob copy start `
            --account-name $StorageAccount `
            --account-key $storageKey `
            --destination-container $destContainer `
            --destination-blob $blobName `
            --source-uri $sourceUrl `
            --output none
        
        if ($LASTEXITCODE -eq 0) {
            $copiedCount++
            if ($copiedCount % 100 -eq 0) {
                Write-Host "  Copied $copiedCount of $blobCount blobs..." -ForegroundColor Gray
            }
        } else {
            $failedCount++
        }
    }
    
    Write-Host "Blob copy initiated: $copiedCount successful, $failedCount failed" -ForegroundColor Green
    Write-Host "Note: Copies may still be in progress. Large blobs can take time." -ForegroundColor Yellow
    
    # Verify destination container has public access
    Write-Host "Verifying public access on destination container..." -ForegroundColor Yellow
    az storage container set-permission `
        --account-name $StorageAccount `
        --account-key $storageKey `
        --name $destContainer `
        --public-access blob
    
    Write-Host "Container '$destContainer' is configured for anonymous blob access" -ForegroundColor Green
    Write-Host ""
}

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Container copy operation completed!" -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary of new containers created:" -ForegroundColor Yellow
foreach ($mapping in $containerMappings.GetEnumerator()) {
    Write-Host "  - $($mapping.Value)" -ForegroundColor Gray
}
Write-Host ""
Write-Host "NOTE: All new containers are configured with anonymous blob access (public-access: blob)" -ForegroundColor Cyan
