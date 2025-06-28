if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}

# Load shared variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

# Configurable parameters (from _common-variables.ps1 or override here)
$cosmosAccountName = $script:cosmosAccount
$cosmosDatabaseName = "provider-dev"
$cosmosContainersToClear = @("Venue", "VenueImage")

$storageAccountName = $script:imageStorageAccountName
$storageImageContainer = $script:imageStorageContainer # e.g. "images"

$resourceGroupSecondary = $script:resourceGroupNameSecondary
$resourceGroupPrimary = $script:resourceGroupNamePrimary

$pgHost = $script:pgHost
$pgUser = $script:pgUser
$pgPassword = $script:pgPassword
$pgDatabase = "sdProducer.FootballNcaa"

# List of related tables to truncate for this DTO vertical
$pgVenueTables = @(
    "Venues",
    "VenueExternalIds",
    "VenueImages"
)

# Ensure logged into Azure
#az login --only-show-errors | Out-Null

az account set --subscription $script:subscriptionIdSecondary

foreach ($container in $cosmosContainersToClear) {
    Write-Host "Deleting entire Cosmos container: $container"
    az cosmosdb sql container delete `
        --account-name $cosmosAccountName `
        --database-name $cosmosDatabaseName `
        --name $container `
        --resource-group $resourceGroupSecondary `
        --yes `
        --only-show-errors
}

Write-Host "Cosmos container deletion complete."

az account set --subscription $script:subscriptionIdPrimary

Write-Host "Deleting all blobs from container '$storageImageContainer'..."
$storageKey = az storage account keys list `
  --account-name $storageAccountName `
  --resource-group $resourceGroupPrimary `
  --query "[0].value" -o tsv

az storage blob delete-batch `
  --account-name $storageAccountName `
  --account-key $storageKey `
  --source $storageImageContainer

Write-Host "Truncating canonical venue tables in PostgreSQL..."
$env:PGPASSWORD = $pgPassword

foreach ($table in $pgVenueTables) {
    Write-Host "Truncating table: $table"
    psql -h $pgHost -U $pgUser -d $pgDatabase -c "TRUNCATE TABLE \"$table\" CASCADE;"
}

# Optional: Clear sensitive environment variable
Remove-Item Env:PGPASSWORD

Write-Host "Reset complete."
