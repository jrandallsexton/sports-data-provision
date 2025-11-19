#!/usr/bin/env pwsh
param(
    [string]$ResourceGroupName = "rg-sportdeets-prod"
)

Write-Host "Deploying admin.sportdeets.com subdomain to Front Door..." -ForegroundColor Cyan

$result = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file admin-subdomain.bicep `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nDeployment completed successfully!" -ForegroundColor Green
    
    $validationToken = $result.properties.outputs.validationToken.value
    $customDomain = $result.properties.outputs.customDomainHostname.value
    
    Write-Host "`nCustom Domain: $customDomain" -ForegroundColor Yellow
    Write-Host "`nDNS Configuration Required:" -ForegroundColor Yellow
    Write-Host "1. Add CNAME record:" -ForegroundColor White
    Write-Host "   Host: admin" -ForegroundColor Gray
    Write-Host "   Value: (Front Door endpoint hostname)" -ForegroundColor Gray
    Write-Host "`n2. Add TXT record for validation:" -ForegroundColor White
    Write-Host "   Host: _dnsauth.admin" -ForegroundColor Gray
    Write-Host "   Value: $validationToken" -ForegroundColor Gray
} else {
    Write-Host "`nDeployment failed!" -ForegroundColor Red
    exit 1
}
