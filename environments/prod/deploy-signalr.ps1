<#
.SYNOPSIS
    Deploys the Production Azure SignalR Service
.DESCRIPTION
    Creates an Azure SignalR Service for production use.
.PARAMETER SubscriptionId
    The Azure subscription ID (defaults to vsprem0_150)
.PARAMETER ResourceGroup
    The resource group for the SignalR service
.EXAMPLE
    .\deploy-signalr.ps1
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "vsprem0_150",

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-sportDeets-prod",

    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus"
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Deploy Production Azure SignalR Service" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription context
Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Yellow
az account set --subscription $SubscriptionId

# Check if resource group exists, create if not
$rgExists = az group exists --name $ResourceGroup --subscription $SubscriptionId
if ($rgExists -eq "false") {
    Write-Host "Creating resource group: $ResourceGroup" -ForegroundColor Yellow
    az group create --name $ResourceGroup --location $Location --subscription $SubscriptionId
}

# Deploy the Bicep template
Write-Host ""
Write-Host "Deploying SignalR service..." -ForegroundColor Yellow
Write-Host "  Name: sportdeets-prod" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "  Location: $Location" -ForegroundColor Gray
Write-Host "  SKU: Free_F1" -ForegroundColor Gray
Write-Host ""

$deployment = az deployment group create `
    --name "deploy-signalr-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId `
    --template-file "$PSScriptRoot\signalr.bicep" `
    --parameters signalRName='sportdeets-prod' `
                 location=$Location `
                 skuName='Free_F1' `
                 capacity=1 `
                 serviceMode='Default' `
                 environment='prod' `
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
$signalRName = $deployment.properties.outputs.signalRName.value
$hostname = $deployment.properties.outputs.hostname.value

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "SignalR Service Details" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "SignalR Name: $signalRName" -ForegroundColor Green
Write-Host "Hostname: $hostname" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Retrieve the connection string:" -ForegroundColor White
Write-Host "     az signalr key list --name $signalRName --resource-group $ResourceGroup --subscription $SubscriptionId --query primaryConnectionString --output tsv" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Add the connection string to App Configuration for the 'Prod' label" -ForegroundColor White
Write-Host ""
