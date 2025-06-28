if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}

# Load shared variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"
. "$PSScriptRoot\_service-config.ps1" # This file contains the $services hashtable

# Required Inputs
$acrResourceGroup = $script:resourceGroupNameCommon
$acrName = "sportdeets"
$roleName = "AcrPull"

if (-not $acrName)  { throw "acrName is not set." }
if (-not $roleName) { throw "roleName is not set." }

# Get ACR ID
Write-Host "Fetching ACR ID for '$acrName' in '$acrResourceGroup'..."
$acrId = az acr show --name $acrName --resource-group $acrResourceGroup --query id --output tsv

if (-not $acrId) {
    throw "Failed to fetch ACR ID. Check if the ACR exists in the correct resource group."
}
Write-Host "✅ ACR ID: $acrId"

# Iterate through each App Service in the hashtable
foreach ($appName in $services.Keys) {
    Write-Host "Processing $appName..."

    # You can infer the resource group if needed, or assume they're all in Primary:
    $resourceGroup = $script:resourceGroupNamePrimary

    $principalId = az webapp identity show `
        --name $appName `
        --resource-group $resourceGroup `
        --query principalId `
        --output tsv

    if (-not $principalId) {
        Write-Warning "No managed identity enabled for $appName. Skipping."
        continue
    }

    Write-Host "Assigning $roleName to $appName for ACR scope..."
    az role assignment create `
        --assignee $principalId `
        --role $roleName `
        --scope $acrId `
        --only-show-errors | Out-Null

    Write-Host "✅ Granted $roleName to $appName"
}
