#!/usr/bin/env pwsh
# Deploy Azure Data Factory for Cosmos DB migration

param(
    [string]$SubscriptionId = "vspro_50",
    [string]$ResourceGroup = "rg-sportDeets-prod",
    [string]$Location = "eastus2"
)

Write-Host "🚀 Deploying Azure Data Factory for Cosmos DB Migration..." -ForegroundColor Cyan

# Set subscription context
Write-Host "Setting subscription to $SubscriptionId..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId

# Deploy the Bicep template
Write-Host "Deploying Bicep template..." -ForegroundColor Yellow
$deployment = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "adf-cosmos-migration.bicep" `
    --parameters location=$Location `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Azure Data Factory Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($deployment.dataFactoryName.value)" -ForegroundColor White
    Write-Host "  Pipeline: $($deployment.pipelineName.value)" -ForegroundColor White
    Write-Host "  Principal ID: $($deployment.dataFactoryPrincipalId.value)" -ForegroundColor White
    Write-Host ""
    Write-Host "🔑 Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Ensure Provider-CosmosConnString-DEV exists in Key Vault"
    Write-Host "  2. Run the pipeline manually in Azure Portal or via:"
    Write-Host "     az datafactory pipeline create-run --factory-name $($deployment.dataFactoryName.value) --name $($deployment.pipelineName.value) --resource-group $ResourceGroup"
    Write-Host "  3. Monitor pipeline run in Azure Portal"
} else {
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    exit 1
}
