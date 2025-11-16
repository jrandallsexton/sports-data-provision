# Grant Role Assignments to Service Principal
# This script grants the service principal access to Key Vault and App Configuration

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalAppId = "0202896e-cfb6-46b5-9545-d6452f0ca16d",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionName = "vsprem0_150",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-sportDeets",
    
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = "sportsdatakv",
    
    [Parameter(Mandatory = $false)]
    [string]$AppConfigName = "sportdeetsappconfig"
)

$ErrorActionPreference = "Stop"

Write-Host "Granting Role Assignments to Service Principal" -ForegroundColor Cyan
Write-Host "  App ID: $ServicePrincipalAppId" -ForegroundColor Gray
Write-Host "  Subscription: $SubscriptionName" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "  Key Vault: $KeyVaultName" -ForegroundColor Gray
Write-Host "  App Configuration: $AppConfigName" -ForegroundColor Gray
Write-Host ""

# Set subscription
Write-Host "Setting subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionName

$subscriptionId = az account show --query id -o tsv
Write-Host "Subscription ID: $subscriptionId" -ForegroundColor Gray
Write-Host ""

# Grant Key Vault Secrets User role
Write-Host "Granting Key Vault Secrets User role..." -ForegroundColor Yellow
$kvScope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName"

az role assignment create `
    --assignee $ServicePrincipalAppId `
    --role "Key Vault Secrets User" `
    --scope $kvScope

if ($LASTEXITCODE -eq 0) {
    Write-Host "Key Vault role assigned successfully" -ForegroundColor Green
} else {
    Write-Host "Failed to assign Key Vault role" -ForegroundColor Red
}
Write-Host ""

# Grant App Configuration Data Reader role
Write-Host "Granting App Configuration Data Reader role..." -ForegroundColor Yellow
$appConfigScope = "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.AppConfiguration/configurationStores/$AppConfigName"

az role assignment create `
    --assignee $ServicePrincipalAppId `
    --role "App Configuration Data Reader" `
    --scope $appConfigScope

if ($LASTEXITCODE -eq 0) {
    Write-Host "App Configuration role assigned successfully" -ForegroundColor Green
} else {
    Write-Host "Failed to assign App Configuration role" -ForegroundColor Red
}
Write-Host ""

Write-Host "Role assignments complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Verifying role assignments..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Key Vault assignments:" -ForegroundColor Cyan
az role assignment list --assignee $ServicePrincipalAppId --scope $kvScope --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
Write-Host ""
Write-Host "App Configuration assignments:" -ForegroundColor Cyan
az role assignment list --assignee $ServicePrincipalAppId --scope $appConfigScope --query "[].{Role:roleDefinitionName, Scope:scope}" -o table
