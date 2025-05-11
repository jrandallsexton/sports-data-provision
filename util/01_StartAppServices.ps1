# Config
$subscriptionId = "a11f8d2b-4f9b-4d85-ac2c-3b8e768cd8e0"
$resourceGroup = "rg-sportDeets-dev"

# Set active subscription
az account set --subscription $subscriptionId

# Get all App Service names in the resource group
$appServices = az webapp list `
  --resource-group $resourceGroup `
  --query "[].name" `
  --output tsv

# Start each one
foreach ($appName in $appServices) {
    Write-Host "Starting $appName..."
    az webapp start `
        --name $appName `
        --resource-group $resourceGroup `
        --only-show-errors
}
Write-Host "`nAll App Services started in $resourceGroup."
