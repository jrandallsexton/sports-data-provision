<#
.SYNOPSIS
    Deploys the Production Service Bus namespace
.DESCRIPTION
    Creates an Azure Service Bus namespace for production use.
    MassTransit will automatically create queues as needed.
.PARAMETER SubscriptionId
    The Azure subscription ID (defaults to vspro_50)
.PARAMETER ResourceGroup
    The resource group for the Service Bus namespace
.EXAMPLE
    .\deploy-servicebus.ps1
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
Write-Host "Deploy Production Service Bus Namespace" -ForegroundColor Cyan
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
Write-Host "Deploying Service Bus namespace..." -ForegroundColor Yellow
Write-Host "  Name: sb-prod-sportdeets" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "  Location: $Location" -ForegroundColor Gray
Write-Host "  SKU: Standard (Zone Redundant)" -ForegroundColor Gray
Write-Host ""

$deployment = az deployment group create `
    --name "deploy-servicebus-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --resource-group $ResourceGroup `
    --template-file "$PSScriptRoot\servicebus-namespace.bicep" `
    --parameters namespaceName='sb-prod-sportdeets' `
                 location=$Location `
                 sku='Standard' `
                 zoneRedundant=$true `
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
$namespaceName = $deployment.properties.outputs.namespaceName.value
$serviceBusEndpoint = $deployment.properties.outputs.serviceBusEndpoint.value

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Service Bus Details" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Namespace Name: $namespaceName" -ForegroundColor Green
Write-Host "Endpoint: $serviceBusEndpoint" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Retrieve the connection string:" -ForegroundColor White
Write-Host "     az servicebus namespace authorization-rule keys list --resource-group $ResourceGroup --namespace-name $namespaceName --name RootManageSharedAccessKey --query primaryConnectionString --output tsv" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Add the connection string to Azure Key Vault as a secret" -ForegroundColor White
Write-Host ""
Write-Host "  3. Reference it in App Configuration for the 'Prod' label" -ForegroundColor White
Write-Host ""
Write-Host "  4. MassTransit will automatically create queues when the application starts" -ForegroundColor White
Write-Host ""
