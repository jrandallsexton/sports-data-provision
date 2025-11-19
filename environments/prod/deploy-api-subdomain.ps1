#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Deploys the API Front Door configuration for api.sportdeets.com

.DESCRIPTION
    Creates the origin group and origin for APIM,
    and creates a route to point api.sportdeets.com to APIM.

.EXAMPLE
    .\deploy-api-subdomain.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Configuration
$resourceGroup = 'rg-sportDeets'
$deploymentName = "api-subdomain-$(Get-Date -Format 'yyyyMMddHHmmss')"
$templateFile = Join-Path $PSScriptRoot 'api-subdomain.bicep'

Write-Host "Deploying API Front Door configuration..." -ForegroundColor Cyan
Write-Host "Resource Group: $resourceGroup" -ForegroundColor Gray
Write-Host "Template: $templateFile" -ForegroundColor Gray
Write-Host ""

try {
    # Deploy the Bicep template
    $deployment = az deployment group create `
        --resource-group $resourceGroup `
        --name $deploymentName `
        --template-file $templateFile `
        --output json | ConvertFrom-Json

    if ($LASTEXITCODE -ne 0) {
        throw "Deployment failed with exit code $LASTEXITCODE"
    }

    Write-Host ""
    Write-Host "Deployment completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Outputs:" -ForegroundColor Cyan
    Write-Host "  Custom Domain ID: $($deployment.properties.outputs.customDomainId.value)" -ForegroundColor Gray
    Write-Host "  Origin Group ID: $($deployment.properties.outputs.originGroupId.value)" -ForegroundColor Gray
    Write-Host "  Route ID: $($deployment.properties.outputs.routeId.value)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "DNS Validation Required:" -ForegroundColor Yellow
    Write-Host "  Domain: api.sportdeets.com" -ForegroundColor Gray
    Write-Host "  Validation Token: $($deployment.properties.outputs.validationToken.value)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Create the following DNS records:" -ForegroundColor Yellow
    Write-Host "  CNAME: api.sportdeets.com -> default-azdrehfsasbrc9a5.z01.azurefd.net" -ForegroundColor Gray
    Write-Host "  TXT: _dnsauth.api.sportdeets.com -> $($deployment.properties.outputs.validationToken.value)" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Error "Deployment failed: $_"
    exit 1
}
