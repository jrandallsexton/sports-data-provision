. "$PSScriptRoot\..\_secrets\_common-variables.ps1"
. "$PSScriptRoot\_service-config.ps1"

# Configuration
$resourceGroup = $script:resourceGroupNamePrimary
$acrLoginServer = $script:acrName

# Process each service in the configuration
foreach ($service in $services.GetEnumerator()) {
    $appName = $service.Key
    $imageName = $service.Value
    $imageTag = "latest"

    Write-Host "Patching $appName..."

    az webapp config container set `
        --name $appName `
        --resource-group $resourceGroup `
        --docker-custom-image-name="${acrLoginServer}/${imageName}:${imageTag}" `
        --docker-registry-server-url="https://${acrLoginServer}" `
        --only-show-errors | Out-Null

    az webapp restart `
        --name $appName `
        --resource-group $resourceGroup `
        --only-show-errors | Out-Null

    Write-Host "$appName patched and restarted."
}
