# Deploy Front Door custom domain for api-int.sportdeets.com
# This exposes the k3s API for APIM backend access

$resourceGroup = "rg-sportDeets"

Write-Host "Deploying Front Door custom domain for api-int.sportdeets.com..." -ForegroundColor Cyan

$deployment = az deployment group create `
    --resource-group $resourceGroup `
    --template-file .\api-internal-subdomain.bicep `
    --query "properties.outputs" `
    -o json | ConvertFrom-Json

Write-Host "`nDeployment completed!" -ForegroundColor Green
Write-Host "Custom Domain: $($deployment.customDomainName.value)" -ForegroundColor Yellow
Write-Host "Validation State: $($deployment.domainValidationState.value)" -ForegroundColor Yellow

Write-Host "`nDNS Configuration Required:" -ForegroundColor Cyan
Write-Host "Add these records in Namecheap:" -ForegroundColor White
Write-Host "  CNAME: api-int -> default-azdrehfsasbrc9a5.z01.azurefd.net" -ForegroundColor Yellow
Write-Host "`nTo get validation token, run:" -ForegroundColor Cyan
Write-Host "  az afd custom-domain show --profile-name fd-sportdeets -g rg-sportDeets --custom-domain-name api-int-sportdeets-com --query validationProperties.validationToken -o tsv" -ForegroundColor White
