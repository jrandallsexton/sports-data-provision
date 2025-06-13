# Load shared variables
. "$PSScriptRoot\..\environments\_secrets\_common-variables.ps1"

# Config
$subscriptionId_AppServices = $script:subscriptionIdPrimary
$subscriptionId_VM = $script:subscriptionIdTertiary
$resourceGroup_AppServices = $script:resourceGroupNamePrimary
$resourceGroup_VM = $script:resourceGroupNameTertiary
$vmName = $script:pgsqlVmName
$appServicePlanName = "ASP-rgsportDeetsdev-b389"  # Confirmed default plan name

# Set subscription for App Services
az account set --subscription $subscriptionId_AppServices

# Scale down App Service Plan to B1 (lowest tier with custom domains)
Write-Host "Scaling App Service Plan '$appServicePlanName' to B1..."
az appservice plan update `
    --name $appServicePlanName `
    --resource-group $resourceGroup_AppServices `
    --sku B1 `
    --only-show-errors

# Get all App Service names in the resource group
$appServices = az webapp list `
  --resource-group $resourceGroup_AppServices `
  --query "[].name" `
  --output tsv

# Disable Always On and stop each App Service
foreach ($appName in $appServices) {
    Write-Host "Disabling Always On for $appName..."
    az webapp config set `
        --name $appName `
        --resource-group $resourceGroup_AppServices `
        --always-on false `
        --only-show-errors

    Write-Host "Stopping $appName..."
    az webapp stop `
        --name $appName `
        --resource-group $resourceGroup_AppServices `
        --only-show-errors
}
Write-Host "All App Services stopped in $resourceGroup_AppServices."

# Set subscription for VM
az account set --subscription $subscriptionId_VM

# Deallocate the PostgreSQL VM
Write-Host "Deallocating VM: $vmName..."
az vm deallocate `
    --name $vmName `
    --resource-group $resourceGroup_VM `
    --only-show-errors

Write-Host "`n✅ All shutdown operations complete. App Service Plan scaled to B1, Always On disabled, apps stopped, and VM deallocated."
