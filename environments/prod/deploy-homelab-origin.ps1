# Deploy homelab origin group to Front Door
# This updates the homelab-cluster origin with current IP and host header configuration

$resourceGroup = "rg-sportDeets"
$bicepFile = "homelab-origin.bicep"

Write-Host "Deploying homelab origin configuration to Front Door..." -ForegroundColor Cyan

az deployment group create `
  --resource-group $resourceGroup `
  --template-file $bicepFile `
  --verbose

Write-Host "✓ Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Current configuration:" -ForegroundColor Yellow
Write-Host "  Origin Group: homelab-cluster" -ForegroundColor White
Write-Host "  Origin IP: 67.7.88.82" -ForegroundColor White
Write-Host "  Origin Host Header: api-int.sportdeets.com" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: Update homelabIp parameter if your public IP changes" -ForegroundColor Yellow
