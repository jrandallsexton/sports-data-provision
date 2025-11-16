# Start_DEV.ps1
if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}

# Load shared variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

# Config
$subscriptionId_AppServices = $script:subscriptionIdPrimary
$subscriptionId_VM = $script:subscriptionIdTertiary
$resourceGroup_AppServices = $script:resourceGroupNamePrimary
$resourceGroup_VM = $script:resourceGroupNameTertiary
$vmName = $script:pgsqlVmNameDev
$appServicePlanName = "ASP-rgsportDeetsdev-b389"  # Default name assigned by Azure

# Set subscription and scale App Service Plan
az account set --subscription $subscriptionId_AppServices

Write-Host "Scaling App Service Plan '$appServicePlanName' to P1mv3..."
az appservice plan update `
    --name $appServicePlanName `
    --resource-group $resourceGroup_AppServices `
    --sku P1mv3 `
    --only-show-errors

# Start App Services and enable Always On
$appServices = az webapp list `
  --resource-group $resourceGroup_AppServices `
  --query "[].name" `
  --output tsv

foreach ($appName in $appServices) {
    Write-Host "Starting $appName..."
    az webapp start `
        --name $appName `
        --resource-group $resourceGroup_AppServices `
        --only-show-errors

    Write-Host "Enabling Always On for $appName..."
    az webapp config set `
        --name $appName `
        --resource-group $resourceGroup_AppServices `
        --always-on true `
        --only-show-errors
}

Write-Host "All App Services started and configured with Always On in $resourceGroup_AppServices."

# Start PostgreSQL VM
az account set --subscription $subscriptionId_VM

Write-Host "Starting VM: $vmName..."
az vm start `
    --name $vmName `
    --resource-group $resourceGroup_VM `
    --only-show-errors

Write-Host "VM $vmName has been started."