if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}

# Load shared variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

# Configuration from common variables
$cosmosAccountName = $script:cosmosAccount
$cosmosDatabaseName = "provider-dev"
$resourceGroup = $script:resourceGroupNameSecondary

# Updated container to provision
$containersToCreate = @("RawEspnDocuments")  # <- New unified container
$partitionKey = "/routingKey"                # <- Stable partition key strategy
$throughput = 400                            # Minimum RU/s for standard manual throughput

# Set subscription context
az account set --subscription $script:subscriptionIdSecondary

foreach ($container in $containersToCreate) {
    $exists = az cosmosdb sql container show `
        --account-name $cosmosAccountName `
        --database-name $cosmosDatabaseName `
        --name $container `
        --resource-group $resourceGroup `
        --query "id" `
        --output tsv `
        2>$null

    if ($exists) {
        Write-Host "Container '$container' already exists. Skipping..."
        continue
    }

    Write-Host "Creating container '$container' with partition key '$partitionKey'..."

    az cosmosdb sql container create `
        --account-name $cosmosAccountName `
        --database-name $cosmosDatabaseName `
        --name $container `
        --partition-key-path $partitionKey `
        --throughput $throughput `
        --resource-group $resourceGroup `
        --output none
}

Write-Host "Container provisioning complete."
