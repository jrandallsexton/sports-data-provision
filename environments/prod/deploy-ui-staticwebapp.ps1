# Deploy UI Static Web App for production
# This creates the sportdeets Static Web App

$ErrorActionPreference = "Stop"

# Load common variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

$resourceGroupName = "rg-sportDeets"
$location = "eastus2"
$deploymentName = "ui-swa-$(Get-Date -Format 'yyyyMMddHHmmss')"

Write-Host "Deploying UI Static Web App..." -ForegroundColor Cyan

$deployment = az deployment group create `
    --resource-group $resourceGroupName `
    --template-file "./ui-staticwebapp.bicep" `
    --parameters location=$location `
    --name $deploymentName `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`nDeployment successful!" -ForegroundColor Green
Write-Host "`nStatic Web App Details:" -ForegroundColor Yellow
Write-Host "  Name: $($deployment.properties.outputs.staticWebAppName.value)" -ForegroundColor Cyan
Write-Host "  Default Hostname: $($deployment.properties.outputs.defaultHostname.value)" -ForegroundColor Cyan
Write-Host "  Resource ID: $($deployment.properties.outputs.staticWebAppId.value)" -ForegroundColor Cyan

Write-Host "`nDeployment Token (add to GitHub Secrets as AZURE_STATIC_WEB_APPS_API_TOKEN_SPORTDEETS):" -ForegroundColor Yellow
Write-Host "  $($deployment.properties.outputs.deploymentToken.value)" -ForegroundColor Green

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "  1. Add the deployment token to GitHub repository secrets" -ForegroundColor White
Write-Host "  2. Create GitHub Actions workflow for automatic deployments" -ForegroundColor White
Write-Host "  3. Configure custom domain if needed" -ForegroundColor White
