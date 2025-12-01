#!/usr/bin/env pwsh
param(
    [string]$SubscriptionId = "vsprem0_150",
    [string]$ResourceGroupName = "rg-sportDeets"
)

Write-Host "Deploying analytics.sportdeets.com subdomain to Front Door..." -ForegroundColor Cyan

# Set subscription
az account set --subscription $SubscriptionId

$result = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file analytics-subdomain.bicep `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
    
    $validationToken = $result.properties.outputs.validationToken.value
    $customDomain = $result.properties.outputs.customDomainHostname.value
    
    Write-Host "`nCustom Domain: $customDomain" -ForegroundColor Yellow
    Write-Host "`nDNS Configuration Required:" -ForegroundColor Yellow
    Write-Host "1. Add CNAME record:" -ForegroundColor White
    Write-Host "   Host: analytics" -ForegroundColor Gray
    Write-Host "   Value: (Front Door endpoint hostname)" -ForegroundColor Gray
    Write-Host "`n2. Add TXT record for validation:" -ForegroundColor White
    Write-Host "   Host: _dnsauth.analytics" -ForegroundColor Gray
    Write-Host "   Value: $validationToken" -ForegroundColor Gray
} else {
    Write-Host "`nDeployment failed!" -ForegroundColor Red
    exit 1
}
