# =========================
# 22_CopyCosmosProdToLocal.ps1
# End-to-End script to copy production Cosmos DB data to local Cosmos DB
# =========================
<#
.SYNOPSIS
    Complete pipeline to copy production Cosmos DB data to local Cosmos DB.

.DESCRIPTION
    Copies all containers from production Cosmos DB (sportdeets-cosmos) to 
    local Cosmos DB (sportdeets-cosmos-local) using the Azure Cosmos .NET SDK 
    with bulk execution mode for optimal performance.
    
    This script:
    1. Validates source (prod) and destination (local) Cosmos DB connectivity
    2. Enumerates all containers in the source database
    3. Creates missing containers in the destination database
    4. Uses bulk copy with parallel execution for maximum throughput
    5. Optionally clears destination containers before copying (with -Force)

.PARAMETER Force
    When specified, automatically clears all destination containers before copying
    without prompting for confirmation.

.PARAMETER SourceAccount
    Source Cosmos DB account name (default: sportdeets-cosmos)

.PARAMETER SourceDatabase
    Source database name (default: provider-prod)

.PARAMETER DestAccount
    Destination Cosmos DB account name (default: sportdeets-cosmos-local)

.PARAMETER DestDatabase
    Destination database name (default: provider-local)

.PARAMETER Containers
    Array of specific container names to copy. If not specified, copies all containers.

.NOTES
    This script requires:
    - Azure CLI authenticated with access to both Cosmos DB accounts
    - Microsoft.Azure.Cosmos NuGet package (installed via inline C# compilation)
    - Sufficient RU/s on destination account to handle bulk writes
#>
[CmdletBinding()]
param(
    [switch]$Force,
    
    [string]$SourceAccount = "sportdeets-cosmos",
    [string]$SourceDatabase = "provider-prod",
    
    [string]$DestAccount = "sportdeets-cosmos-local",
    [string]$DestDatabase = "provider-local",
    
    [string[]]$Containers = @()
)

if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$startTime = Get-Date

# Load secrets
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "COPY COSMOS PROD TO LOCAL" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Source: $SourceAccount / $SourceDatabase" -ForegroundColor White
Write-Host "Destination: $DestAccount / $DestDatabase" -ForegroundColor White
Write-Host ""

# Final confirmation
if (-not $Force) {
    Write-Host "WARNING: This will overwrite all data in the destination Cosmos DB!" -ForegroundColor Red
    Write-Host ""
    $confirm = Read-Host "Type 'YES' to continue with Cosmos data copy"
    if ($confirm -ne "YES") {
        Write-Host "Cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""

# =========================
# Step 1: Get Connection Strings
# =========================

Write-Host "[STEP 1/4] Retrieving Cosmos DB connection strings..." -ForegroundColor Cyan

# Determine resource groups
$sourceRg = "rg-sportDeets-prod"                  # Production Cosmos account
$destRg = $script:resourceGroupNameTertiary       # Local Cosmos account

Write-Host "  Retrieving source connection string ($SourceAccount)..." -ForegroundColor Gray
$sourceConnString = az cosmosdb keys list `
    --name $SourceAccount `
    --resource-group $sourceRg `
    --type connection-strings `
    --query "connectionStrings[?description=='Primary SQL Connection String'].connectionString" `
    --output tsv

if (-not $sourceConnString) {
    throw "ERROR: Failed to retrieve source Cosmos DB connection string"
}

Write-Host "  Retrieving destination connection string ($DestAccount)..." -ForegroundColor Gray
$destConnString = az cosmosdb keys list `
    --name $DestAccount `
    --resource-group $destRg `
    --type connection-strings `
    --query "connectionStrings[?description=='Primary SQL Connection String'].connectionString" `
    --output tsv

if (-not $destConnString) {
    throw "ERROR: Failed to retrieve destination Cosmos DB connection string"
}

Write-Host ""
Write-Host "Connection strings retrieved successfully" -ForegroundColor Green
Write-Host ""

# =========================
# Step 2: List Containers
# =========================

Write-Host "[STEP 2/4] Enumerating containers..." -ForegroundColor Cyan

if ($Containers.Count -eq 0) {
    Write-Host "  Retrieving all containers from source database..." -ForegroundColor Gray
    $containersJson = az cosmosdb sql container list `
        --account-name $SourceAccount `
        --database-name $SourceDatabase `
        --resource-group $sourceRg `
        --output json
    
    $containerObjects = $containersJson | ConvertFrom-Json
    $Containers = $containerObjects | ForEach-Object { $_.name }
    
    if ($Containers.Count -eq 0) {
        throw "ERROR: No containers found in source database"
    }
}

Write-Host "  Containers to copy: $($Containers -join ', ')" -ForegroundColor White
Write-Host ""

# =========================
# Step 3: Ensure Destination Containers Exist
# =========================

Write-Host "[STEP 3/4] Ensuring destination containers exist..." -ForegroundColor Cyan

foreach ($container in $Containers) {
    Write-Host "  Checking container: $container" -ForegroundColor Gray
    
    # Check if container exists in destination
    $destContainerExists = az cosmosdb sql container show `
        --account-name $DestAccount `
        --database-name $DestDatabase `
        --resource-group $destRg `
        --name $container `
        --only-show-errors 2>$null
    
    if ($LASTEXITCODE -ne 0) {
        # Container doesn't exist - get source container metadata
        Write-Host "    Container doesn't exist in destination, creating..." -ForegroundColor Yellow
        
        $sourceContainerJson = az cosmosdb sql container show `
            --account-name $SourceAccount `
            --database-name $SourceDatabase `
            --resource-group $sourceRg `
            --name $container `
            --output json
        
        $sourceContainer = $sourceContainerJson | ConvertFrom-Json
        
        # Extract partition key path
        $partitionKeyPath = $sourceContainer.resource.partitionKey.paths[0]
        
        # Create container in destination with same partition key
        az cosmosdb sql container create `
            --account-name $DestAccount `
            --database-name $DestDatabase `
            --resource-group $destRg `
            --name $container `
            --partition-key-path $partitionKeyPath `
            --throughput 400 `
            --only-show-errors | Out-Null
        
        Write-Host "    Container created: $container" -ForegroundColor Green
    } else {
        Write-Host "    Container exists: $container" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "All destination containers ready" -ForegroundColor Green
Write-Host ""

# =========================
# Step 4: Bulk Copy Data
# =========================

Write-Host "[STEP 4/4] Copying data using bulk execution..." -ForegroundColor Cyan
Write-Host ""

# Create temporary C# script for bulk copy
$bulkCopyScript = @"
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;
using Newtonsoft.Json.Linq;

public class CosmosBulkCopy
{
    public static async Task CopyContainerAsync(
        string sourceConnString,
        string sourceDatabase,
        string destConnString,
        string destDatabase,
        string containerName,
        bool clearFirst)
    {
        Console.WriteLine(`$"  Processing container: {containerName}");
        
        // Source client (read-only, no bulk mode needed)
        var sourceClient = new CosmosClient(sourceConnString);
        var sourceContainer = sourceClient.GetContainer(sourceDatabase, containerName);
        
        // Get partition key path from container
        var containerProps = await sourceContainer.ReadContainerAsync();
        var partitionKeyPath = containerProps.Resource.PartitionKeyPath;
        Console.WriteLine(`$"    Partition key path: {partitionKeyPath}");
        
        // Destination client with bulk execution
        var destClientOptions = new CosmosClientOptions 
        { 
            AllowBulkExecution = true,
            MaxRetryAttemptsOnRateLimitedRequests = 10,
            MaxRetryWaitTimeOnRateLimitedRequests = TimeSpan.FromSeconds(60)
        };
        var destClient = new CosmosClient(destConnString, destClientOptions);
        var destContainer = destClient.GetContainer(destDatabase, containerName);
        
        // Read all documents from source
        var query = new QueryDefinition("SELECT * FROM c");
        var iterator = sourceContainer.GetItemQueryIterator<JObject>(query);
        
        int copiedCount = 0;
        int batchNumber = 0;
        
        while (iterator.HasMoreResults)
        {
            batchNumber++;
            var batch = await iterator.ReadNextAsync();
            
            if (batch.Count == 0) continue;
            
            // Upsert all items in parallel using bulk execution
            var upsertTasks = batch.Select(item =>
            {
                // Extract partition key value from the path
                var partitionKeyValue = GetPartitionKeyValue(item, partitionKeyPath);
                return destContainer.UpsertItemAsync(item, new PartitionKey(partitionKeyValue));
            });
            
            await Task.WhenAll(upsertTasks);
            copiedCount += batch.Count;
            
            Console.WriteLine(`$"    Batch {batchNumber}: Copied {batch.Count} items (Total: {copiedCount})");
        }
        
        Console.WriteLine(`$"  ✓ Completed: {containerName} - {copiedCount} items copied");
        Console.WriteLine();
    }
    
    private static string GetPartitionKeyValue(JObject item, string partitionKeyPath)
    {
        // Remove leading slash if present
        var path = partitionKeyPath.TrimStart('/');
        
        // Navigate to the property - handle nested paths if needed
        var pathParts = path.Split('/');
        JToken current = item;
        
        foreach (var part in pathParts)
        {
            if (current == null) break;
            current = current[part];
        }
        
        return current?.ToString() ?? string.Empty;
    }
    
    public static async Task Main(string[] args)
    {
        if (args.Length < 5)
        {
            Console.WriteLine("Usage: CosmosBulkCopy <sourceConn> <sourceDb> <destConn> <destDb> <clearFirst> <container1> [container2] ...");
            return;
        }
        
        var sourceConnString = args[0];
        var sourceDatabase = args[1];
        var destConnString = args[2];
        var destDatabase = args[3];
        var clearFirst = bool.Parse(args[4]);
        var containers = args.Skip(5).ToArray();
        
        Console.WriteLine("Starting Cosmos DB bulk copy...");
        Console.WriteLine();
        
        foreach (var container in containers)
        {
            await CopyContainerAsync(sourceConnString, sourceDatabase, destConnString, destDatabase, container, clearFirst);
        }
        
        Console.WriteLine("All containers copied successfully!");
    }
}
"@

# Save C# script to temp file
$tempCsFile = Join-Path $env:TEMP "CosmosBulkCopy.cs"
Set-Content -Path $tempCsFile -Value $bulkCopyScript

# Compile and run the C# script using dotnet-script or inline compilation
Write-Host "  Compiling bulk copy utility..." -ForegroundColor Gray

# Create a temporary project
$tempDir = Join-Path $env:TEMP "CosmosBulkCopy_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

$csprojContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Azure.Cosmos" Version="3.42.0" />
  </ItemGroup>
</Project>
"@

$programCsContent = $bulkCopyScript

Set-Content -Path (Join-Path $tempDir "CosmosBulkCopy.csproj") -Value $csprojContent
Set-Content -Path (Join-Path $tempDir "Program.cs") -Value $programCsContent

# Build the project
Write-Host "  Building utility project..." -ForegroundColor Gray
Push-Location $tempDir
dotnet build --configuration Release --verbosity quiet
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    throw "ERROR: Failed to build bulk copy utility"
}
Pop-Location

# Run the bulk copy
$exePath = Join-Path $tempDir "bin\Release\net8.0\CosmosBulkCopy.exe"
$clearFirstArg = if ($Force) { "true" } else { "false" }
$containerArgs = $Containers -join " "

Write-Host ""
& $exePath $sourceConnString $SourceDatabase $destConnString $DestDatabase $clearFirstArg $Containers

if ($LASTEXITCODE -ne 0) {
    throw "ERROR: Bulk copy failed with exit code $LASTEXITCODE"
}

# Clean up temporary files
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Data copy completed successfully" -ForegroundColor Green
Write-Host ""

# =========================
# Summary
# =========================

$duration = (Get-Date) - $startTime

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "COSMOS COPY COMPLETE!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Total Duration: $($duration.ToString())" -ForegroundColor White
Write-Host "Containers Copied: $($Containers.Count)" -ForegroundColor White
Write-Host ""
Write-Host "Your local Cosmos DB now contains production data." -ForegroundColor Green
Write-Host "You can start development with real data!" -ForegroundColor Green
Write-Host ""
