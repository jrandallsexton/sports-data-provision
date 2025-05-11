# Script to provision SportDeets services with key vault access
Write-Host "Deploying SportDeets Services with Key Vault Access..."

# Import shared service configuration
. ./_service-config.ps1

# Debug: Show all services that will be processed
Write-Host "`nServices to be processed:"
$services.GetEnumerator() | ForEach-Object {
    Write-Host "  Service: $($_.Key) -> Image: $($_.Value)"
}
Write-Host "`n"

# Resource group and location
$environment = "dev"
$resourceGroup = "rg-sportDeets-$environment"
$location = "East US 2"
$keyVaultName = "sportsdatakv"
$serverFarmId = "/subscriptions/a11f8d2b-4f9b-4d85-ac2c-3b8e768cd8e0/resourceGroups/rg-sportDeets-$environment/providers/Microsoft.Web/serverfarms/ASP-rgsportDeets$environment-b389"

# Deploy each service
foreach ($serviceName in $services.Keys) {
    $imageName = $services[$serviceName]
    Write-Host "`nProcessing service: $serviceName (Image: $imageName)"
    
    # Check if service exists
    $existingService = az webapp show --name $serviceName --resource-group $resourceGroup --query "name" -o tsv 2>$null
    
    if ($existingService) {
        Write-Host "$serviceName already exists. Skipping deployment."
    } else {
        Write-Host "Deploying $serviceName..."
        
        # Deploy using bicep template
        az deployment group create `
            --resource-group $resourceGroup `
            --template-file "../../templates/service-template.bicep" `
            --parameters `
                appName=$serviceName `
                imageName="ghcr.io/sportdeets/$imageName:latest" `
                environment=$environment `
                location=$location `
                serverFarmId=$serverFarmId `
                keyVaultName=$keyVaultName
    }
}

Write-Host "`nAll services deployment process completed!"