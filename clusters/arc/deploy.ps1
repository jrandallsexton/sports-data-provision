# Deploy Azure Arc Infrastructure for Kubernetes Workload Identity
# This script deploys:
# - Resource Group (rg-sportdeets-arc)
# - Managed Identity (id-sportdeets-workload)

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionName = "vspro_50",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-sportDeets-prod",
    
    [Parameter(Mandatory = $false)]
    [string]$ManagedIdentityName = "id-sportdeets-workload"
)

$ErrorActionPreference = "Stop"

Write-Host "Deploying Azure Arc Infrastructure" -ForegroundColor Cyan
Write-Host "   Subscription: $SubscriptionName" -ForegroundColor Gray
Write-Host "   Location: $Location" -ForegroundColor Gray
Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "   Managed Identity: $ManagedIdentityName" -ForegroundColor Gray
Write-Host ""

# Set subscription
Write-Host "Setting Azure subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionName
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set subscription. Please run 'az login' first."
    exit 1
}

Write-Host "✓ Subscription set" -ForegroundColor Green
Write-Host ""

# Deploy Bicep template
Write-Host "Deploying Bicep template..." -ForegroundColor Yellow
$deploymentName = "arc-infra-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

$result = az deployment sub create `
    --name $deploymentName `
    --location $Location `
    --template-file "./main.bicep" `
    --parameters resourceGroupName=$ResourceGroupName `
                 managedIdentityName=$ManagedIdentityName `
                 location=$Location `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed!"
    exit 1
}

Write-Host "✓ Deployment completed successfully" -ForegroundColor Green
Write-Host ""

# Display outputs
Write-Host "Deployment Outputs:" -ForegroundColor Cyan
Write-Host "   Resource Group: $($result.properties.outputs.resourceGroupName.value)" -ForegroundColor Gray
Write-Host "   Managed Identity: $($result.properties.outputs.managedIdentityName.value)" -ForegroundColor Gray
Write-Host "   Client ID: $($result.properties.outputs.managedIdentityClientId.value)" -ForegroundColor Gray
Write-Host "   Principal ID: $($result.properties.outputs.managedIdentityPrincipalId.value)" -ForegroundColor Gray
Write-Host ""

# Save outputs to file for later use
$outputs = @{
    resourceGroupName = $result.properties.outputs.resourceGroupName.value
    managedIdentityName = $result.properties.outputs.managedIdentityName.value
    managedIdentityClientId = $result.properties.outputs.managedIdentityClientId.value
    managedIdentityPrincipalId = $result.properties.outputs.managedIdentityPrincipalId.value
    managedIdentityId = $result.properties.outputs.managedIdentityId.value
}

$outputFile = "deployment-outputs.json"
$outputs | ConvertTo-Json | Out-File $outputFile -Encoding utf8
Write-Host "Outputs saved to: $outputFile" -ForegroundColor Green
Write-Host ""

Write-Host "Azure Arc infrastructure deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Connect your k3s cluster to Azure Arc" -ForegroundColor Gray
Write-Host "2. Enable Workload Identity on the Arc cluster" -ForegroundColor Gray
Write-Host "3. Grant the managed identity permissions to Key Vault and App Configuration" -ForegroundColor Gray
Write-Host "4. Create federated credential to link K8s service account to managed identity" -ForegroundColor Gray
