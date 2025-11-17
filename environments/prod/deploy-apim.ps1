# Deploy Azure API Management (Consumption tier)
# This script provisions APIM to sit behind Azure Front Door

$resourceGroup = "rg-sportDeets"
$location = "eastus2"

Write-Host "Deploying Azure API Management..." -ForegroundColor Cyan

$deployment = az deployment group create `
    --resource-group $resourceGroup `
    --template-file .\apim.bicep `
    --parameters location=$location `
    --query "properties.outputs" `
    -o json | ConvertFrom-Json

Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
Write-Host "APIM Hostname: $($deployment.apimHostname.value)" -ForegroundColor Yellow
Write-Host "APIM Resource ID: $($deployment.apimResourceId.value)" -ForegroundColor Yellow
Write-Host "Backend URL: $($deployment.backendUrl.value)" -ForegroundColor Yellow
Write-Host "`nSubscription Key (Primary): $($deployment.subscriptionKey.value)" -ForegroundColor Magenta
Write-Host "Subscription ID: $($deployment.subscriptionId.value)" -ForegroundColor Yellow

Write-Host "`nNext steps:" -ForegroundColor Cyan
Write-Host "1. Add Front Door route for api.sportdeets.com -> APIM hostname"
Write-Host "2. Create DNS CNAME: api.sportdeets.com -> Front Door endpoint"
Write-Host "3. Create api-int.sportdeets.com Front Door route -> k3s cluster"
Write-Host "4. Update UI production workflow with subscription key"
