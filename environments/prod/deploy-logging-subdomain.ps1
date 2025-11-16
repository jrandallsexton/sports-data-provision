# Deploy logging subdomain to Azure Front Door
# This creates logging.sportdeets.com custom domain

$ErrorActionPreference = "Stop"

# Load common variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

$resourceGroupName = "rg-sportDeets"
$deploymentName = "logging-subdomain-$(Get-Date -Format 'yyyyMMddHHmmss')"

Write-Host "Deploying logging subdomain to Front Door..." -ForegroundColor Cyan

$deployment = az deployment group create `
    --resource-group $resourceGroupName `
    --template-file "./logging-subdomain.bicep" `
    --name $deploymentName `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Host "Deployment failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`nDeployment successful!" -ForegroundColor Green
Write-Host "`nCustom Domain: $($deployment.properties.outputs.customDomainHostname.value)" -ForegroundColor Yellow
Write-Host "`nDNS Configuration Required:" -ForegroundColor Yellow
Write-Host "  Add CNAME record:" -ForegroundColor White
Write-Host "    Name: logging" -ForegroundColor Cyan
Write-Host "    Value: default-azdrehfsasbrc9a5.z01.azurefd.net" -ForegroundColor Cyan
Write-Host "`n  Add TXT record for validation:" -ForegroundColor White
Write-Host "    Name: _dnsauth.logging" -ForegroundColor Cyan
Write-Host "    Value: $($deployment.properties.outputs.validationToken.value)" -ForegroundColor Cyan
Write-Host "`nOnce DNS records are added, the SSL certificate will be provisioned automatically." -ForegroundColor Yellow
