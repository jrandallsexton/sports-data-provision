# Delete Athlete Image Cache Documents from Cosmos DB
# Deletes all documents where DocumentType = 1 (AthleteImage) and Sport = 2 (FootballNcaa)

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroup,

    [Parameter(Mandatory = $false)]
    [string]$AccountName,

    [Parameter(Mandatory = $false)]
    [string]$DatabaseName = "FootballNcaa",

    [Parameter(Mandatory = $false)]
    [string]$ContainerName = "FootballNcaa",

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [int]$BatchSize = 100
)

# Script configuration
$ErrorActionPreference = "Stop"

# Display banner
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Cosmos DB Athlete Image Cache Cleanup" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Prompt for required parameters if not provided
if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
    $ResourceGroup = Read-Host "Enter Resource Group name"
}

if ([string]::IsNullOrWhiteSpace($AccountName)) {
    $AccountName = Read-Host "Enter Cosmos DB Account name"
}

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host "  Account Name:   $AccountName" -ForegroundColor White
Write-Host "  Database:       $DatabaseName" -ForegroundColor White
Write-Host "  Container:      $ContainerName" -ForegroundColor White
Write-Host "  Mode:           $(if ($DryRun) { 'DRY RUN (no changes)' } else { 'LIVE DELETE' })" -ForegroundColor $(if ($DryRun) { 'Green' } else { 'Red' })
Write-Host ""

# Verify Azure CLI is installed
try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    Write-Host "✓ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
}
catch {
    Write-Host "✗ Azure CLI is not installed or not in PATH" -ForegroundColor Red
    Write-Host "  Please install from: https://docs.microsoft.com/cli/azure/install-azure-cli" -ForegroundColor Yellow
    exit 1
}

# Verify logged in to Azure
try {
    $account = az account show 2>$null | ConvertFrom-Json
    Write-Host "✓ Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "✓ Subscription: $($account.name) ($($account.id))" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "✗ Not logged in to Azure CLI" -ForegroundColor Red
    Write-Host "  Run: az login" -ForegroundColor Yellow
    exit 1
}

# Verify Cosmos DB account exists
Write-Host "Verifying Cosmos DB account..." -ForegroundColor Cyan
try {
    $cosmosAccount = az cosmosdb show `
        --name $AccountName `
        --resource-group $ResourceGroup `
        --output json 2>$null | ConvertFrom-Json

    if ($null -eq $cosmosAccount) {
        throw "Account not found"
    }

    Write-Host "✓ Found Cosmos DB account: $($cosmosAccount.name)" -ForegroundColor Green
    Write-Host "  Location: $($cosmosAccount.location)" -ForegroundColor Gray
    Write-Host "  Endpoint: $($cosmosAccount.documentEndpoint)" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host "✗ Cosmos DB account not found or access denied" -ForegroundColor Red
    Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Yellow
    Write-Host "  Account Name:   $AccountName" -ForegroundColor Yellow
    exit 1
}

# Verify database exists
Write-Host "Verifying database..." -ForegroundColor Cyan
try {
    $databases = az cosmosdb sql database list `
        --account-name $AccountName `
        --resource-group $ResourceGroup `
        --output json | ConvertFrom-Json

    $database = $databases | Where-Object { $_.name -eq $DatabaseName }
    if ($null -eq $database) {
        throw "Database not found"
    }

    Write-Host "✓ Found database: $DatabaseName" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "✗ Database '$DatabaseName' not found" -ForegroundColor Red
    Write-Host "  Available databases:" -ForegroundColor Yellow
    $databases | ForEach-Object { Write-Host "    - $($_.name)" -ForegroundColor Gray }
    exit 1
}

# Verify container exists
Write-Host "Verifying container..." -ForegroundColor Cyan
try {
    $containers = az cosmosdb sql container list `
        --account-name $AccountName `
        --resource-group $ResourceGroup `
        --database-name $DatabaseName `
        --output json | ConvertFrom-Json

    $container = $containers | Where-Object { $_.name -eq $ContainerName }
    if ($null -eq $container) {
        throw "Container not found"
    }

    Write-Host "✓ Found container: $ContainerName" -ForegroundColor Green
    Write-Host "  Partition Key: $($container.resource.partitionKey.paths -join ', ')" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host "✗ Container '$ContainerName' not found" -ForegroundColor Red
    Write-Host "  Available containers:" -ForegroundColor Yellow
    $containers | ForEach-Object { Write-Host "    - $($_.name)" -ForegroundColor Gray }
    exit 1
}

# Query for matching documents
Write-Host "Querying for athlete image documents..." -ForegroundColor Cyan
Write-Host "  WHERE DocumentType = 1 (AthleteImage) AND Sport = 2 (FootballNcaa)" -ForegroundColor Gray
Write-Host ""

# Get Cosmos DB connection info
$keys = az cosmosdb keys list `
    --name $AccountName `
    --resource-group $ResourceGroup `
    --type keys `
    --output json | ConvertFrom-Json

$primaryKey = $keys.primaryMasterKey
$endpoint = $cosmosAccount.documentEndpoint

# Query using Data Plane REST API
$query = "SELECT c.id, c.RoutingKey FROM c WHERE c.DocumentType = 1 AND c.Sport = 2"

try {
    # Build the query request
    $queryBody = @{
        query = $query
        parameters = @()
    } | ConvertTo-Json -Compress

    # Use PowerShell to call Cosmos REST API directly
    $verb = "POST"
    $resourceType = "docs"
    $resourceLink = "dbs/$DatabaseName/colls/$ContainerName"
    $dateTime = [DateTime]::UtcNow.ToString("r")
    
    # Generate authorization signature
    $keyBytes = [Convert]::FromBase64String($primaryKey)
    $text = @($verb.ToLowerInvariant() + "`n" + $resourceType.ToLowerInvariant() + "`n" + $resourceLink + "`n" + $dateTime.ToLowerInvariant() + "`n" + "" + "`n")
    $body = [Text.Encoding]::UTF8.GetBytes($text)
    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.Key = $keyBytes
    $signature = [Convert]::ToBase64String($hmacsha.ComputeHash($body))
    $authHeader = [System.Web.HttpUtility]::UrlEncode("type=master&ver=1.0&sig=$signature")
    
    # Query documents
    $uri = "$endpoint$resourceLink/docs"
    $headers = @{
        "Authorization" = $authHeader
        "x-ms-date" = $dateTime
        "x-ms-version" = "2018-12-31"
        "Content-Type" = "application/query+json"
        "x-ms-documentdb-isquery" = "True"
        "x-ms-documentdb-query-enablecrosspartition" = "True"
        "x-ms-max-item-count" = "1000"
    }

    # Handle pagination with continuation tokens
    $allDocuments = @()
    $continuationToken = $null
    $pageCount = 0
    
    do {
        $pageCount++
        Write-Host "  Fetching page $pageCount..." -ForegroundColor Gray
        
        # Update headers for this request
        $requestHeaders = $headers.Clone()
        if ($continuationToken) {
            $requestHeaders["x-ms-continuation"] = $continuationToken
        }
        
        $response = Invoke-WebRequest -Method Post -Uri $uri -Headers $requestHeaders -Body $queryBody -UseBasicParsing
        $responseData = $response.Content | ConvertFrom-Json
        $allDocuments += $responseData.Documents
        
        # Get continuation token from response headers (case-insensitive lookup)
        $continuationToken = $null
        foreach ($header in $response.Headers.Keys) {
            if ($header -eq 'x-ms-continuation') {
                $continuationToken = $response.Headers[$header] | Select-Object -First 1
                break
            }
        }
        
        Write-Host "    Retrieved $($responseData.Documents.Count) documents (total: $($allDocuments.Count))" -ForegroundColor Gray
        
    } while ($continuationToken)
    
    $documents = $allDocuments
    $documentCount = $documents.Count
    Write-Host ""

    Write-Host "✓ Found $documentCount documents to delete" -ForegroundColor $(if ($documentCount -gt 0) { 'Yellow' } else { 'Green' })
    Write-Host ""

    if ($documentCount -eq 0) {
        Write-Host "No documents found matching criteria. Exiting." -ForegroundColor Green
        exit 0
    }
}
catch {
    Write-Host "✗ Failed to query documents" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    exit 1
}

# Display sample of documents that will be deleted
Write-Host "Sample of documents to delete (first 5):" -ForegroundColor Yellow
$documents | Select-Object -First 5 | ForEach-Object {
    Write-Host "  - ID: $($_.id), RoutingKey: $($_.RoutingKey)" -ForegroundColor Gray
}
if ($documentCount -gt 5) {
    Write-Host "  ... and $($documentCount - 5) more documents" -ForegroundColor Gray
}
Write-Host ""

# Confirmation
if ($DryRun) {
    Write-Host "DRY RUN MODE - No documents will be deleted" -ForegroundColor Green
    Write-Host "Remove -DryRun flag to actually delete documents" -ForegroundColor Yellow
    Write-Host ""
}
else {
    Write-Host "WARNING: This will permanently delete $documentCount documents!" -ForegroundColor Red
    Write-Host ""
    $confirmation = Read-Host "Type 'DELETE' to confirm deletion"

    if ($confirmation -ne 'DELETE') {
        Write-Host "Deletion cancelled by user" -ForegroundColor Yellow
        exit 0
    }
    Write-Host ""
}

# Delete documents
if (-not $DryRun) {
    Write-Host "Deleting documents..." -ForegroundColor Cyan
    Write-Host ""

    $deletedCount = 0
    $failedCount = 0
    $batchNumber = 0
    $totalBatches = [Math]::Ceiling($documentCount / $BatchSize)

    for ($i = 0; $i -lt $documentCount; $i += $BatchSize) {
        $batchNumber++
        $batch = $documents | Select-Object -Skip $i -First $BatchSize
        $batchCount = $batch.Count

        Write-Host "Processing batch $batchNumber of $totalBatches ($batchCount documents)..." -ForegroundColor Cyan

        foreach ($doc in $batch) {
            try {
                # Delete document using REST API
                $verb = "DELETE"
                $resourceType = "docs"
                $resourceLink = "dbs/$DatabaseName/colls/$ContainerName/docs/$($doc.id)"
                $dateTime = [DateTime]::UtcNow.ToString("r")
                
                # Generate authorization signature
                $keyBytes = [Convert]::FromBase64String($primaryKey)
                $text = @($verb.ToLowerInvariant() + "`n" + $resourceType.ToLowerInvariant() + "`n" + $resourceLink + "`n" + $dateTime.ToLowerInvariant() + "`n" + "" + "`n")
                $body = [Text.Encoding]::UTF8.GetBytes($text)
                $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
                $hmacsha.Key = $keyBytes
                $signature = [Convert]::ToBase64String($hmacsha.ComputeHash($body))
                $authHeader = [System.Web.HttpUtility]::UrlEncode("type=master&ver=1.0&sig=$signature")
                
                # Delete document
                $uri = "$endpoint$resourceLink"
                $headers = @{
                    "Authorization" = $authHeader
                    "x-ms-date" = $dateTime
                    "x-ms-version" = "2018-12-31"
                    "x-ms-documentdb-partitionkey" = "[`"$($doc.RoutingKey)`"]"
                }

                Invoke-RestMethod -Method Delete -Uri $uri -Headers $headers | Out-Null

                $deletedCount++

                # Show progress every 10 documents
                if ($deletedCount % 10 -eq 0) {
                    $progress = [Math]::Round(($deletedCount / $documentCount) * 100, 1)
                    Write-Host "  Progress: $deletedCount/$documentCount ($progress%)" -ForegroundColor Gray
                }
            }
            catch {
                $failedCount++
                Write-Host "  ✗ Failed to delete document: $($doc.id)" -ForegroundColor Red
                Write-Host "    Error: $_" -ForegroundColor Red
            }
        }

        Write-Host "  ✓ Batch $batchNumber complete: $deletedCount deleted, $failedCount failed" -ForegroundColor Green
        Write-Host ""

        # Small delay between batches to avoid throttling
        if ($i + $BatchSize -lt $documentCount) {
            Start-Sleep -Milliseconds 500
        }
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Deletion Complete" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Total Documents: $documentCount" -ForegroundColor White
    Write-Host "  Successfully Deleted: $deletedCount" -ForegroundColor Green
    Write-Host "  Failed: $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}
else {
    Write-Host "DRY RUN - Would delete $documentCount documents" -ForegroundColor Green
    Write-Host ""
    Write-Host "Documents grouped by partition key (RoutingKey):" -ForegroundColor Yellow
    $partitionGroups = $documents | Group-Object -Property RoutingKey | Sort-Object Count -Descending
    $partitionGroups | Select-Object -First 10 | ForEach-Object {
        Write-Host "  RoutingKey '$($_.Name)': $($_.Count) documents" -ForegroundColor Gray
    }
    if ($partitionGroups.Count -gt 10) {
        Write-Host "  ... and $($partitionGroups.Count - 10) more partition keys" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Run without -DryRun to execute deletion" -ForegroundColor Yellow
    Write-Host ""
}
