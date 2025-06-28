if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}

# Load shared variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"
. ./_service-config.ps1

# Resource group and location
$resourceGroup = $script:resourceGroupNamePrimary
$keyVaultResourceGroup = $script:resourceGroupNameCommon  # Key vault is in a different resource group
$keyVaultName = $script:keyVaultName

# Role definition ID for Key Vault Secrets User
#$roleDefinitionId = "4633458b-17de-408a-b874-0445c86b69e6"

# Grant access to each service
foreach ($serviceName in $services.Keys) {
    Write-Host "`nGranting access to $serviceName..."
    
    # Get the service's managed identity
    $principalId = az webapp identity show --name $serviceName --resource-group $resourceGroup --query principalId -o tsv
    
    if ($principalId) {
        # Grant access using RBAC role assignment
        az role assignment create `
            --role "Key Vault Secrets User" `
            --assignee-object-id $principalId `
            --assignee-principal-type "ServicePrincipal" `
            --scope "/subscriptions/$script:subscriptionIdPrimary/resourceGroups/$keyVaultResourceGroup/providers/Microsoft.KeyVault/vaults/$keyVaultName"
    } else {
        Write-Host "Could not find managed identity for $serviceName"
    }
}

Write-Host "`nAll services have been granted access to the key vault!"
