<#
.SYNOPSIS
    Deploys the about.sportdeets.com subdomain to Azure Front Door
.DESCRIPTION
    This script deploys a new custom domain (about.sportdeets.com) to the existing 
    Azure Front Door instance, including origin group, origin, custom domain, and route.
.PARAMETER SubscriptionId
    The Azure subscription ID (defaults to vsprem0_150)
.PARAMETER ResourceGroup
    The resource group containing the Front Door profile
.PARAMETER OriginHost
    The hostname of the origin where traffic will be routed (e.g., about-app.azurewebsites.net)
.EXAMPLE
    .\deploy-about-subdomain.ps1 -OriginHost "about-app.azurewebsites.net"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId = "vsprem0_150",

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-sportDeets",

    [Parameter(Mandatory=$true, HelpMessage="The origin hostname (e.g., about-app.azurewebsites.net or your container app FQDN)")]
    [string]$OriginHost
)

$ErrorActionPreference = "Stop"

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "Deploy about.sportdeets.com to Front Door" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Set subscription context
Write-Host "Setting subscription context to: $SubscriptionId" -ForegroundColor Yellow
az account set --subscription $SubscriptionId

# Deploy the Bicep template
Write-Host ""
Write-Host "Deploying about subdomain configuration..." -ForegroundColor Yellow
Write-Host "  Profile: fd-sportdeets" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "  Hostname: about.sportdeets.com" -ForegroundColor Gray
Write-Host "  Origin: $OriginHost" -ForegroundColor Gray
Write-Host ""

$deployment = az deployment group create `
    --name "deploy-about-subdomain-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --resource-group $ResourceGroup `
    --template-file "$PSScriptRoot\about-subdomain.bicep" `
    --parameters profileName='fd-sportdeets' `
                 hostname='about.sportdeets.com' `
                 endpointName='default' `
                 originHost=$OriginHost `
                 originGroupName='about-origin-group' `
                 minimumTlsVersion='TLS12' `
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
$validationToken = $deployment.properties.outputs.validationToken.value
$customDomainId = $deployment.properties.outputs.customDomainId.value

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "DNS Configuration Required" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To complete the setup, add the following DNS records:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. CNAME Record:" -ForegroundColor White
Write-Host "   Name:  about" -ForegroundColor Gray
Write-Host "   Type:  CNAME" -ForegroundColor Gray
Write-Host "   Value: default-azdrehfsasbrc9a5.z01.azurefd.net" -ForegroundColor Gray
Write-Host ""
Write-Host "2. TXT Record (for domain validation):" -ForegroundColor White
Write-Host "   Name:  _dnsauth.about" -ForegroundColor Gray
Write-Host "   Type:  TXT" -ForegroundColor Gray
Write-Host "   Value: $validationToken" -ForegroundColor Gray
Write-Host ""
Write-Host "After adding these DNS records, Azure Front Door will automatically" -ForegroundColor Yellow
Write-Host "validate the domain and provision a managed SSL certificate." -ForegroundColor Yellow
Write-Host ""
Write-Host "You can check the validation status with:" -ForegroundColor Cyan
Write-Host "  az afd custom-domain show --resource-group $ResourceGroup --profile-name fd-sportdeets --custom-domain-name about-sportdeets-com" -ForegroundColor Gray
Write-Host ""
