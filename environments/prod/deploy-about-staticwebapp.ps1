<#
.SYNOPSIS
    Deploys the about.sportdeets.com Static Web App
.DESCRIPTION
    Creates an Azure Static Web App for the about subdomain
.PARAMETER SubscriptionId
    The Azure subscription ID (defaults to vsprem0_150)
.PARAMETER ResourceGroup
    The resource group for the static web app
.EXAMPLE
    .\deploy-about-staticwebapp.ps1
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "vsprem0_150",

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-sportDeets",

    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus2"
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Deploy about Static Web App" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription context
Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Yellow
az account set --subscription $SubscriptionId

# Deploy the Bicep template
Write-Host ""
Write-Host "Deploying Static Web App..." -ForegroundColor Yellow
Write-Host "  Name: about-sportdeets" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "  Location: $Location" -ForegroundColor Gray
Write-Host ""

$deployment = az deployment group create `
    --name "deploy-about-staticwebapp-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --resource-group $ResourceGroup `
    --template-file "$PSScriptRoot\about-staticwebapp.bicep" `
    --parameters name='about-sportdeets' `
                 location=$Location `
                 sku='Free' `
                 environment='prod' `
                 repositoryUrl='https://github.com/jrandallsexton/sports-data' `
                 branch='main' `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Deployment successful!" -ForegroundColor Green
Write-Host ""

# Extract outputs
$defaultHostname = $deployment.properties.outputs.defaultHostname.value
$deploymentToken = $deployment.properties.outputs.deploymentToken.value

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Deployment Details" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Default Hostname: $defaultHostname" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  GitHub Actions Configuration Required" -ForegroundColor Yellow
Write-Host ""
Write-Host "Add the deployment token as a GitHub secret:" -ForegroundColor White
Write-Host "  Secret Name: AZURE_STATIC_WEB_APPS_API_TOKEN_ABOUT" -ForegroundColor Gray
Write-Host "  Secret Value: $deploymentToken" -ForegroundColor Gray
Write-Host ""
Write-Host "The workflow file should already exist at:" -ForegroundColor White
Write-Host "  .github/workflows/azure-static-web-apps-about.yml" -ForegroundColor Gray
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Add the GitHub secret" -ForegroundColor White
Write-Host "  2. Push changes to trigger the workflow" -ForegroundColor White
Write-Host "  3. Run the Front Door deployment script with:" -ForegroundColor White
Write-Host "     .\frontdoor\deploy-about-subdomain.ps1 -OriginHost '$defaultHostname'" -ForegroundColor Gray
Write-Host ""
