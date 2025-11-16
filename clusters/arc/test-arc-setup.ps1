# Test Azure CLI and install connectedk8s extension
# Run this script AFTER the Azure CLI upgrade completes and you've opened a NEW terminal

Write-Host "Testing Azure CLI after upgrade..." -ForegroundColor Cyan
Write-Host ""

# Check Azure CLI version
Write-Host "Checking Azure CLI version..." -ForegroundColor Yellow
az version --output json | ConvertFrom-Json | Select-Object -ExpandProperty "azure-cli"
Write-Host ""

# Try to install connectedk8s extension
Write-Host "Installing connectedk8s extension..." -ForegroundColor Yellow
az extension add --name connectedk8s --upgrade

if ($LASTEXITCODE -eq 0) {
    Write-Host "Extension installed successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Verify extension
    Write-Host "Verifying extension..." -ForegroundColor Yellow
    az extension show --name connectedk8s --query "{Name:name, Version:version}" -o table
    Write-Host ""
    
    Write-Host "Ready to connect cluster to Azure Arc!" -ForegroundColor Green
    Write-Host "Run: .\connect-cluster.ps1" -ForegroundColor Cyan
} else {
    Write-Host "Extension installation failed. Error code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting steps:" -ForegroundColor Yellow
    Write-Host "1. Check Python version: python --version" -ForegroundColor Gray
    Write-Host "2. Try manual install: pip install azure-cli-extension" -ForegroundColor Gray
    Write-Host "3. Use Azure Cloud Shell as alternative" -ForegroundColor Gray
}
