#!/usr/bin/env pwsh
# Deploy Azure Storage Account for Production

param(
    [string]$SubscriptionId = "vspro_50",
    [string]$ResourceGroup = "rg-sportDeets-prod",
    [string]$Location = "eastus2"
)

Write-Host "Deploying Azure Storage Account for Production..." -ForegroundColor Cyan

# Set subscription context
Write-Host "Setting subscription to $SubscriptionId..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId

# Deploy the Bicep template
Write-Host "Deploying Bicep template..." -ForegroundColor Yellow
$deployment = az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "storage-provider.bicep" `
    --parameters location=$Location `
    --query "properties.outputs" `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    Write-Host "Deployment successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Storage Account Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($deployment.storageAccountName.value)" -ForegroundColor White
    Write-Host "  Blob Endpoint: $($deployment.primaryEndpoints.value.blob)" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  Run the container copy script to migrate data from dev to prod"
} else {
    Write-Host "Deployment failed!" -ForegroundColor Red
    exit 1
}
