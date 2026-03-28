# New-AppConfigStore.ps1
# Creates a new Azure App Configuration store.
# Use this to provision the replacement store before swapping over.
#
# Usage: .\New-AppConfigStore.ps1 -Name "sportdeetsappconfig2" -ResourceGroup "rg-sportdeets"

param(
    [Parameter(Mandatory)]
    [string]$Name,

    [string]$ResourceGroup = "rg-sportdeets",
    [string]$Location = "eastus",
    [string]$Sku = "Standard"
)

$ErrorActionPreference = "Stop"

Write-Host "Creating App Configuration store:" -ForegroundColor Cyan
Write-Host "  Name:           $Name"
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  Location:       $Location"
Write-Host "  SKU:            $Sku"
Write-Host ""

# Check if it already exists
$existing = az appconfig show --name $Name --resource-group $ResourceGroup -o json 2>$null
if ($existing) {
    Write-Host "Store '$Name' already exists." -ForegroundColor Yellow
    exit 0
}

# Create the store
az appconfig create `
    --name $Name `
    --resource-group $ResourceGroup `
    --location $Location `
    --sku $Sku `
    --enable-public-network `
    -o json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create App Configuration store."
    exit 1
}

Write-Host ""
Write-Host "Store '$Name' created successfully." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Apply the manifest:  .\Apply-AppConfig.ps1 -StoreName '$Name'"
Write-Host "  2. Verify:              .\Apply-AppConfig.ps1 -StoreName '$Name' -DryRun"
Write-Host "  3. Update APPCONFIG_ENDPOINT in your services to point to the new store"
Write-Host "  4. Delete the old store when validated"
