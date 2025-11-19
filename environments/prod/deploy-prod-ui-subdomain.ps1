#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Deploys the production UI Front Door configuration for sportdeets.com and www.sportdeets.com

.DESCRIPTION
    Creates the origin group and origin for the production Static Web App,
    and updates the default route to point sportdeets.com and www.sportdeets.com to production.

.EXAMPLE
    .\deploy-prod-ui-subdomain.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# Configuration
$resourceGroup = 'rg-sportDeets'
$deploymentName = "prod-ui-subdomain-$(Get-Date -Format 'yyyyMMddHHmmss')"
$templateFile = Join-Path $PSScriptRoot 'prod-ui-subdomain.bicep'

Write-Host "Deploying production UI Front Door configuration..." -ForegroundColor Cyan
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
    Write-Host "  Origin Group ID: $($deployment.properties.outputs.originGroupId.value)" -ForegroundColor Gray
    Write-Host "  Route ID: $($deployment.properties.outputs.routeId.value)" -ForegroundColor Gray
    Write-Host "  Origin Hostname: $($deployment.properties.outputs.originHostname.value)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "The following domains now point to production UI:" -ForegroundColor Yellow
    Write-Host "  - https://sportdeets.com" -ForegroundColor Gray
    Write-Host "  - https://www.sportdeets.com" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Error "Deployment failed: $_"
    exit 1
}
