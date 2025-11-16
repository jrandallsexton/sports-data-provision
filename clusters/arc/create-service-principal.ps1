# Create Service Principal for Kubernetes Apps
# This script creates a service principal and grants it access to Key Vault and App Configuration
# The credentials are stored in a Kubernetes secret for the pods to use

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalName = "sp-sportdeets-k8s-apps",
    
    [Parameter(Mandatory = $false)]
    [string]$SubscriptionName = "vsprem0_150",
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-sportDeets",
    
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName = "sportsdatakv",
    
    [Parameter(Mandatory = $false)]
    [string]$AppConfigName = "sportdeetsappconfig",
    
    [Parameter(Mandatory = $false)]
    [string]$K8sSecretName = "azure-identity",
    
    [Parameter(Mandatory = $false)]
    [string]$K8sNamespace = "default"
)

$ErrorActionPreference = "Stop"

Write-Host "Creating Service Principal for Kubernetes Apps" -ForegroundColor Cyan
Write-Host "  Subscription: $SubscriptionName" -ForegroundColor Gray
Write-Host "  Service Principal: $ServicePrincipalName" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor Gray
Write-Host "  Key Vault: $KeyVaultName" -ForegroundColor Gray
Write-Host "  App Configuration: $AppConfigName" -ForegroundColor Gray
Write-Host ""

# Set subscription
az account set --subscription $SubscriptionName

# Check if SP already exists
Write-Host "Checking if service principal already exists..." -ForegroundColor Yellow
$existingSp = az ad sp list --display-name $ServicePrincipalName --query "[0]" -o json | ConvertFrom-Json

if ($existingSp) {
    Write-Host "Service principal already exists. Resetting credentials..." -ForegroundColor Yellow
    $sp = az ad sp credential reset --id $existingSp.appId --query "{appId:appId, password:password, tenant:tenant}" -o json | ConvertFrom-Json
} else {
    Write-Host "Creating new service principal..." -ForegroundColor Yellow
    # Get subscription ID
    $subscriptionId = az account show --query id -o tsv
    
    # Create SP without role assignment initially
    $sp = az ad sp create-for-rbac `
        --name $ServicePrincipalName `
        --skip-assignment `
        --query "{appId:appId, password:password, tenant:tenant}" `
        -o json | ConvertFrom-Json
}

Write-Host "Service Principal created/updated" -ForegroundColor Green
Write-Host "  App ID: $($sp.appId)" -ForegroundColor Gray
Write-Host "  Tenant: $($sp.tenant)" -ForegroundColor Gray
Write-Host ""

# Grant Key Vault Secrets User role
Write-Host "Granting Key Vault Secrets User role..." -ForegroundColor Yellow
az role assignment create `
    --assignee $sp.appId `
    --role "Key Vault Secrets User" `
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.KeyVault/vaults/$KeyVaultName" `
    --output none

Write-Host "Key Vault role assigned" -ForegroundColor Green

# Grant App Configuration Data Reader role
Write-Host "Granting App Configuration Data Reader role..." -ForegroundColor Yellow
az role assignment create `
    --assignee $sp.appId `
    --role "App Configuration Data Reader" `
    --scope "/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$ResourceGroupName/providers/Microsoft.AppConfiguration/configurationStores/$AppConfigName" `
    --output none

Write-Host "App Configuration role assigned" -ForegroundColor Green
Write-Host ""

# Create Kubernetes secret
Write-Host "Creating Kubernetes secret '$K8sSecretName' in namespace '$K8sNamespace'..." -ForegroundColor Yellow

# Delete existing secret if it exists
kubectl delete secret $K8sSecretName -n $K8sNamespace --ignore-not-found=true

# Create new secret
kubectl create secret generic $K8sSecretName `
    --namespace=$K8sNamespace `
    --from-literal=AZURE_TENANT_ID=$($sp.tenant) `
    --from-literal=AZURE_CLIENT_ID=$($sp.appId) `
    --from-literal=AZURE_CLIENT_SECRET=$($sp.password)

if ($LASTEXITCODE -eq 0) {
    Write-Host "Kubernetes secret created successfully" -ForegroundColor Green
} else {
    Write-Host "Failed to create Kubernetes secret" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Save credentials to file (encrypted)
$outputFile = "service-principal-credentials.json"
$credentials = @{
    servicePrincipalName = $ServicePrincipalName
    tenantId = $sp.tenant
    appId = $sp.appId
    clientSecret = $sp.password
    keyVaultName = $KeyVaultName
    appConfigName = $AppConfigName
    createdDate = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

$credentials | ConvertTo-Json | Out-File $outputFile -Encoding utf8

Write-Host "Credentials saved to: $outputFile" -ForegroundColor Cyan
Write-Host "WARNING: This file contains secrets. Do not commit to source control!" -ForegroundColor Red
Write-Host ""

Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Update your deployments to reference the '$K8sSecretName' secret" -ForegroundColor Gray
Write-Host "2. Add environment variables for AZURE_TENANT_ID, AZURE_CLIENT_ID, AZURE_CLIENT_SECRET" -ForegroundColor Gray
Write-Host "3. Your apps can now authenticate to Azure using the service principal" -ForegroundColor Gray
