<#
.SYNOPSIS
    Provisions the local Cosmos DB account for development.

.DESCRIPTION
    Creates a new Azure Cosmos DB for NoSQL account named 'sportdeets-cosmos-local'
    with the database 'provider-local'. This is used as a local copy of production
    data for development and testing purposes.
    
    The account is created in subscriptionIdTertiary and resourceGroupNameTertiary
    to match the local development infrastructure pattern.

.NOTES
    This uses the same cosmos-provider.bicep template as dev/prod environments.
    Free tier is enabled to minimize costs for local development account.
#>

if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}

# Load shared variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

$deploymentName = "deploy-cosmos-provider-local"
$subscriptionId = $script:subscriptionIdTertiary
$resourceGroup = $script:resourceGroupNameTertiary
$location = "eastus2"
$enableFreeTier = $false  # Free tier already used by another account in this subscription
$cosmosAccountName = "sportdeets-cosmos-local"
$databaseName = "provider-local"

# Use the same template as dev/prod
$templateFile = Join-Path $PSScriptRoot "..\prod\cosmos-provider.bicep"

if (-not (Test-Path $templateFile)) {
    throw "ERROR: Bicep template not found at: $templateFile"
}

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Provision Local Cosmos DB" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Subscription: $subscriptionId" -ForegroundColor White
Write-Host "Resource Group: $resourceGroup" -ForegroundColor White
Write-Host "Location: $location" -ForegroundColor White
Write-Host "Account Name: $cosmosAccountName" -ForegroundColor White
Write-Host "Database Name: $databaseName" -ForegroundColor White
Write-Host ""

# Set subscription context
az account set --subscription $subscriptionId

# Deploy Cosmos DB account and database
Write-Host "Deploying Cosmos DB account..." -ForegroundColor Cyan
Write-Host ""

az deployment group create `
  --name $deploymentName `
  --subscription $subscriptionId `
  --resource-group $resourceGroup `
  --template-file $templateFile `
  --parameters `
    location=$location `
    enableFreeTier=$enableFreeTier `
    databaseName=$databaseName `
    cosmosAccountName=$cosmosAccountName `
  --output table

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Deployment successful!" -ForegroundColor Green
Write-Host ""

# Retrieve connection string
Write-Host "Retrieving connection string..." -ForegroundColor Cyan

$connectionString = az cosmosdb keys list `
    --name $cosmosAccountName `
    --resource-group $resourceGroup `
    --type connection-strings `
    --query "connectionStrings[?description=='Primary SQL Connection String'].connectionString" `
    --output tsv

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Cosmos DB Details" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Account Name: $cosmosAccountName" -ForegroundColor Green
Write-Host "Database Name: $databaseName" -ForegroundColor Green
Write-Host ""
Write-Host "Connection String (first 50 chars):" -ForegroundColor Yellow
Write-Host "  $($connectionString.Substring(0, [Math]::Min(50, $connectionString.Length)))..." -ForegroundColor Gray
Write-Host ""
Write-Host "⚠️  Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Add connection string to Azure Key Vault (if using)" -ForegroundColor White
Write-Host "  2. Update Azure App Configuration for Local label:" -ForegroundColor White
Write-Host "     Key: SportsData.Provider:ProviderDocDatabaseConfig:ConnectionString" -ForegroundColor Gray
Write-Host "     Label: Local" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Run 22_CopyCosmosProdToLocal.ps1 to populate with production data" -ForegroundColor White
Write-Host ""
