# Load shared variables
. "$PSScriptRoot\..\_secrets\_common-variables.ps1"

# Required variables
$resourceGroupName = $script:resourceGroupNamePrimary
$location = "eastus2"
$appServicePlanName = "ASP-rgsportDeetsdev-b389"
$webAppName = "logging-svc"
$storageAccountName = "seqlogsdevsa"

# Create storage (optional)
az storage account create `
  --name $storageAccountName `
  --resource-group $resourceGroupName `
  --location $location `
  --sku Standard_LRS

# Create the web app with specific parameters
az webapp create `
  --name $webAppName `
  --resource-group $resourceGroupName `
  --plan $appServicePlanName `
  --deployment-container-image-name "datalust/seq:latest" `
  --https-only true `
  --tags "Environment=Development"

# Configure environment
az webapp config appsettings set `
  --name $webAppName `
  --resource-group $resourceGroupName `
  --settings ACCEPT_EULA=Y

az webapp restart `
  --name $webAppName `
  --resource-group $resourceGroupName
