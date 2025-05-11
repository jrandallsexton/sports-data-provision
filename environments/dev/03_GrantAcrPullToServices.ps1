. "$PSScriptRoot\..\_secrets\_common-variables.ps1"

# Corrected Config
$acrResourceGroup = $script:resourceGroupNameCommon
$appServiceResourceGroup = $script:resourceGroupNamePrimary
$acrName = "sportdeets"
$roleName = "AcrPull"

if (-not $acrName) { throw "acrName is not set." }
if (-not $roleName) { throw "roleName is not set." }

# Echo for debug
Write-Host "Fetching ACR ID for '$acrName' in '$acrResourceGroup'..."

# Get ACR ID (guarded)
$acrId = az acr show --name $acrName --resource-group $acrResourceGroup --query id --output tsv

if (-not $acrId) {
    throw "Failed to fetch ACR ID. Check if the ACR exists in the correct resource group."
}

Write-Host "✅ ACR ID: $acrId"

# Get list of App Services
$appServices = az webapp list --resource-group $appServiceResourceGroup --query "[].{name:name}" --output tsv

foreach ($appName in $appServices) {
    Write-Host "Processing $appName..."

    $principalId = az webapp identity show `
        --name $appName `
        --resource-group $appServiceResourceGroup `
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

    Write-Host "Granted $roleName to $appName"
}
