# Script to rename prod-provider-* containers to kebab-case naming convention
# This creates new containers with simplified names and copies all blobs over

# Import common variables
. "$PSScriptRoot\_common-variables.ps1"

$sourceAccount = "sportdeetssa"
$targetAccount = "sportdeetssa"  # Same account, different container names

# Define explicit container mappings
$containerMappings = @{
    "prod-provider-footballncaa-athleteimage" = "football-ncaa-athlete-image"
    "prod-provider-footballncaa-athleteimage-2025" = "football-ncaa-athlete-image-2025"
    "prod-provider-footballncaa-franchiselogo" = "football-ncaa-franchise-logo"
    "prod-provider-footballncaa-franchiselogo-2025" = "football-ncaa-franchise-logo-2025"
    "prod-provider-footballncaa-teambyseasonlogo-2025" = "football-ncaa-team-by-season-logo-2025"
    "prod-provider-footballncaa-venueimage" = "football-ncaa-venue-image"
}

Write-Host "`nContainer rename plan:" -ForegroundColor Cyan
foreach ($mapping in $containerMappings.GetEnumerator()) {
    Write-Host "  $($mapping.Key) -> $($mapping.Value)"
}

$confirmation = Read-Host "`nProceed with container creation and blob copy? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Operation cancelled." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nStarting container rename process...`n" -ForegroundColor Green

foreach ($mapping in $containerMappings.GetEnumerator()) {
    $sourceContainer = $mapping.Key
    $targetContainer = $mapping.Value
    
    Write-Host "Processing: $sourceContainer -> $targetContainer" -ForegroundColor Cyan
    
    # Check if target container already exists
    $existingContainer = az storage container exists `
        --account-name $targetAccount `
        --name $targetContainer `
        --auth-mode key `
        --output tsv 2>$null
    
    if ($existingContainer -eq "True") {
        Write-Host "  Target container already exists, will sync blobs" -ForegroundColor Yellow
    } else {
        # Create target container
        Write-Host "  Creating target container..." -ForegroundColor Gray
        az storage container create `
            --account-name $targetAccount `
            --name $targetContainer `
            --auth-mode key `
            --output none
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ERROR: Failed to create target container" -ForegroundColor Red
            continue
        }
    }
    
    # Get all blobs from source container
    Write-Host "  Listing blobs from source container..." -ForegroundColor Gray
    $sourceBlobs = @()
    $marker = $null
    
    do {
        if ($marker) {
            $blobBatch = az storage blob list `
                --account-name $sourceAccount `
                --container-name $sourceContainer `
                --auth-mode key `
                --marker $marker `
                --output json | ConvertFrom-Json
        } else {
            $blobBatch = az storage blob list `
                --account-name $sourceAccount `
                --container-name $sourceContainer `
                --auth-mode key `
                --output json | ConvertFrom-Json
        }
        
        if ($blobBatch) {
            $sourceBlobs += $blobBatch
            $marker = $blobBatch[-1].nextMarker
        } else {
            $marker = $null
        }
    } while ($marker)
    
    $totalBlobs = $sourceBlobs.Count
    Write-Host "  Found $totalBlobs blobs to copy" -ForegroundColor Gray
    
    if ($totalBlobs -eq 0) {
        Write-Host "  No blobs to copy, skipping" -ForegroundColor Yellow
        continue
    }
    
    # Check which blobs already exist in target
    Write-Host "  Checking for existing blobs in target..." -ForegroundColor Gray
    $existingBlobs = az storage blob list `
        --account-name $targetAccount `
        --container-name $targetContainer `
        --auth-mode key `
        --query "[].name" `
        --output json | ConvertFrom-Json
    
    $existingBlobSet = @{}
    if ($existingBlobs) {
        foreach ($blob in $existingBlobs) {
            $existingBlobSet[$blob] = $true
        }
    }
    
    # Filter to only new blobs
    $blobsToCopy = $sourceBlobs | Where-Object { -not $existingBlobSet.ContainsKey($_.name) }
    $skippedCount = $totalBlobs - $blobsToCopy.Count
    
    if ($skippedCount -gt 0) {
        Write-Host "  Skipping $skippedCount blobs that already exist" -ForegroundColor Yellow
    }
    
    if ($blobsToCopy.Count -eq 0) {
        Write-Host "  All blobs already exist in target" -ForegroundColor Green
        continue
    }
    
    Write-Host "  Copying $($blobsToCopy.Count) new blobs" -ForegroundColor Gray
    
    # Start async copy operations
    $copyJobs = @()
    $batchSize = 100
    $processed = 0
    
    foreach ($blob in $blobsToCopy) {
        $sourceUrl = "https://$sourceAccount.blob.core.windows.net/$sourceContainer/$($blob.name)"
        
        $copyResult = az storage blob copy start `
            --account-name $targetAccount `
            --destination-container $targetContainer `
            --destination-blob $blob.name `
            --source-uri $sourceUrl `
            --auth-mode key `
            --output json 2>$null | ConvertFrom-Json
        
        if ($copyResult) {
            $copyJobs += @{
                BlobName = $blob.name
                CopyId = $copyResult.id
            }
        }
        
        $processed++
        if ($processed % $batchSize -eq 0) {
            Write-Host "  Started copy for $processed/$($blobsToCopy.Count) blobs..." -ForegroundColor Gray
        }
    }
    
    Write-Host "  Started $($copyJobs.Count) copy operations" -ForegroundColor Gray
    
    # Wait for copies to complete
    Write-Host "  Waiting for copies to complete..." -ForegroundColor Gray
    $maxRetries = 120  # 10 minutes max
    $retryCount = 0
    $completed = 0
    
    while ($completed -lt $copyJobs.Count -and $retryCount -lt $maxRetries) {
        Start-Sleep -Seconds 5
        $retryCount++
        
        $stillPending = 0
        foreach ($job in $copyJobs) {
            $status = az storage blob show `
                --account-name $targetAccount `
                --container-name $targetContainer `
                --name $job.BlobName `
                --auth-mode key `
                --query "properties.copy.status" `
                --output tsv 2>$null
            
            if ($status -eq "pending") {
                $stillPending++
            }
        }
        
        $completed = $copyJobs.Count - $stillPending
        
        if ($stillPending -gt 0 -and $retryCount % 6 -eq 0) {
            Write-Host "  Progress: $completed/$($copyJobs.Count) complete, $stillPending pending (waited $($retryCount * 5)s)" -ForegroundColor Gray
        }
    }
    
    if ($completed -eq $copyJobs.Count) {
        Write-Host "  All $($blobsToCopy.Count) new blobs copied successfully ($skippedCount skipped)" -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Copy operation timed out. $completed/$($copyJobs.Count) completed" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

Write-Host "`n=== Container Rename Summary ===" -ForegroundColor Green
Write-Host "All container creation and blob copy operations completed." -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Update database URLs to use new container names" -ForegroundColor White
Write-Host "2. Test application with new URLs" -ForegroundColor White
Write-Host "3. Delete old prod-provider-* containers once verified" -ForegroundColor White
