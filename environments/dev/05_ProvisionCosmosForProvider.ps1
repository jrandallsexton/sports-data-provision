. "$PSScriptRoot\..\_secrets\_common-variables.ps1"

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
