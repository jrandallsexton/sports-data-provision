if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}

# Load shared variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

$deploymentName = "deploy-cosmos-provider-dev"
$subscriptionId = $script:subscriptionIdSecondary
$resourceGroup = $script:resourceGroupNameSecondary
$location = "eastus2"
$enableFreeTier = $true
$cosmosAccountName = "sportdeets-cosmos-dev"
$databaseName = "provider-dev"
$templateFile = "cosmos-provider.bicep"

az deployment group create `
  --name $deploymentName `
  --subscription $subscriptionId `
  --resource-group $resourceGroup `
  --template-file $templateFile `
  --parameters `
    location=$location `
    enableFreeTier=$enableFreeTier `
    databaseName=$databaseName `
    cosmosAccountName=$cosmosAccountName `
  --only-show-errors
