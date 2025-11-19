<#
.SYNOPSIS
    Deploys the Production Cosmos DB account
.DESCRIPTION
    Creates an Azure Cosmos DB account for production use.
    This is used by the Provider service to store raw game data from ESPN.
.PARAMETER SubscriptionId
    The Azure subscription ID (defaults to vspro_50)
.PARAMETER ResourceGroup
    The resource group for the Cosmos DB account
.EXAMPLE
    .\deploy-cosmos.ps1
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "vspro_50",

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-sportDeets-prod",

    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2"
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Deploy Production Cosmos DB" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription context
Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Yellow
az account set --subscription $SubscriptionId

# Check if resource group exists, create if not
$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "false") {
    Write-Host "Creating resource group: $ResourceGroup" -ForegroundColor Yellow
    az group create --name $ResourceGroup --location $Location
}

# Deploy the Bicep template
Write-Host ""
Write-Host "Deploying Cosmos DB account..." -ForegroundColor Yellow
Write-Host "  Account Name: sportdeets-cosmos" -ForegroundColor Gray
Write-Host "  Database Name: provider-prod" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "  Location: $Location" -ForegroundColor Gray
Write-Host "  Free Tier: Enabled" -ForegroundColor Gray
Write-Host ""

$deployment = az deployment group create `
    --name "deploy-cosmos-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --resource-group $ResourceGroup `
    --template-file "$PSScriptRoot\cosmos-provider.bicep" `
    --parameters `
        location=$Location `
        enableFreeTier=$true `
        databaseName='provider-prod' `
        cosmosAccountName='sportdeets-cosmos' `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Deployment successful!" -ForegroundColor Green
Write-Host ""

# Extract outputs
$cosmosAccountName = $deployment.properties.outputs.cosmosAccountName.value
$cosmosEndpoint = $deployment.properties.outputs.cosmosEndpoint.value
$databaseName = $deployment.properties.outputs.databaseName.value

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Cosmos DB Details" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Account Name: $cosmosAccountName" -ForegroundColor Green
Write-Host "Endpoint: $cosmosEndpoint" -ForegroundColor Green
Write-Host "Database Name: $databaseName" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Retrieve the primary key:" -ForegroundColor White
Write-Host "     az cosmosdb keys list --name $cosmosAccountName --resource-group $ResourceGroup --type keys --query primaryMasterKey --output tsv" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Add the connection string to Azure Key Vault as 'CosmosDb--ConnectionString':" -ForegroundColor White
Write-Host "     AccountEndpoint=$cosmosEndpoint;AccountKey=<PRIMARY_KEY>" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Reference it in App Configuration for the 'Prod' label" -ForegroundColor White
Write-Host ""
Write-Host "  4. Update the cluster config to use production Cosmos DB" -ForegroundColor White
Write-Host ""

