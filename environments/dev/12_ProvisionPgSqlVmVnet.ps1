# =========================
# sportDeets Dev Networking (East US 2)
# - RG
# - VNet + subnets (pg, appsvc-int, bastion, gateway)
# - NSG on pg-subnet (allow 5432 from appsvc-int only; deny Internet inbound)
# - Private DNS zone + VNet link
# =========================

# ---- Guard + Secrets ----
if (-not $env:SPORTDEETS_SECRETS_PATH) { throw "ERROR: Set SPORTDEETS_SECRETS_PATH first." }
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

# ---- Config ----
$subscriptionId     = $script:subscriptionIdSecondary          # your 150-credit sub
$resourceGroupName  = "$($script:resourceGroupNameSecondary)-eus2"
$location           = "eastus2"

$vnetName           = "sd-dev-eus2-vnet"
$vnetCidr           = "10.50.0.0/16"

$pgSubnetName       = "pg-subnet"
$pgSubnetCidr       = "10.50.1.0/24"

$appIntSubnetName   = "appsvc-int-subnet"
$appIntSubnetCidr   = "10.50.10.0/26"                          # /26 recommended for App Service VNet Integration

# Optional (reserve now so you don't collide later)
$bastionSubnetName  = "AzureBastionSubnet"
$bastionSubnetCidr  = "10.50.255.0/27"

$gatewaySubnetName  = "GatewaySubnet"
$gatewaySubnetCidr  = "10.50.254.0/27"

$pgNsgName          = "pg-subnet-nsg"

$privateDnsZone     = "pg.dev.internal"                        # FQDNs like pg-dev.pg.dev.internal later

# ---- Azure Context ----
az account set --subscription $subscriptionId | Out-Null

# ---- Resource Group ----
az group create --name $resourceGroupName --location $location | Out-Null

# ---- VNet + Primary Subnet ----
az network vnet create `
  --resource-group $resourceGroupName `
  --name $vnetName `
  --location $location `
  --address-prefixes $vnetCidr `
  --subnet-name $pgSubnetName `
  --subnet-prefixes $pgSubnetCidr | Out-Null

# ---- App Service Integration Subnet (delegated) ----
# Create separately so we can apply delegation
az network vnet subnet create `
  --resource-group $resourceGroupName `
  --vnet-name $vnetName `
  --name $appIntSubnetName `
  --address-prefixes $appIntSubnetCidr `
  --delegations Microsoft.Web/serverFarms | Out-Null

# ---- (Optional) Reserve Bastion + Gateway Subnets ----
# You won't use them immediately, but reserving avoids future overlap headaches
az network vnet subnet create `
  --resource-group $resourceGroupName `
  --vnet-name $vnetName `
  --name $bastionSubnetName `
  --address-prefixes $bastionSubnetCidr | Out-Null

az network vnet subnet create `
  --resource-group $resourceGroupName `
  --vnet-name $vnetName `
  --name $gatewaySubnetName `
  --address-prefixes $gatewaySubnetCidr | Out-Null

# ---- NSG for pg-subnet ----
az network nsg create `
  --resource-group $resourceGroupName `
  --name $pgNsgName `
  --location $location | Out-Null

# Allow Postgres (5432) ONLY from App Service Integration subnet
az network nsg rule create `
  --resource-group $resourceGroupName `
  --nsg-name $pgNsgName `
  --name "Allow-Postgres-from-AppSvc" `
  --priority 100 `
  --access Allow `
  --direction Inbound `
  --protocol Tcp `
  --source-address-prefixes $appIntSubnetCidr `
  --destination-port-ranges 5432 | Out-Null

# Explicitly deny inbound Internet (defense-in-depth)
az network nsg rule create `
  --resource-group $resourceGroupName `
  --nsg-name $pgNsgName `
  --name "Deny-Internet-Inbound" `
  --priority 200 `
  --access Deny `
  --direction Inbound `
  --protocol "*" `
  --source-address-prefixes Internet `
  --destination-port-ranges "*" | Out-Null

# Attach NSG to pg-subnet
az network vnet subnet update `
  --resource-group $resourceGroupName `
  --vnet-name $vnetName `
  --name $pgSubnetName `
  --network-security-group $pgNsgName | Out-Null

# ---- Private DNS Zone + Link (use VNet ID, not name) ----
az network private-dns zone create `
  --resource-group $resourceGroupName `
  --name $privateDnsZone | Out-Null

$vnetId = az network vnet show `
  --resource-group $resourceGroupName `
  --name $vnetName `
  --query id -o tsv

az network private-dns link vnet create `
  --resource-group $resourceGroupName `
  --zone-name $privateDnsZone `
  --name "${vnetName}-link" `
  --virtual-network $vnetId `
  --registration-enabled false | Out-Null

# ---- Outputs / Sanity Checks ----
Write-Host ("`n✅ Networking provisioned in {0}:" -f $location)
Write-Host ("   Resource Group: {0}" -f $resourceGroupName)
Write-Host ("   VNet: {0} ({1})" -f $vnetName, $vnetCidr)

Write-Host "`nSubnets:"
az network vnet subnet list -g $resourceGroupName --vnet-name $vnetName -o table

Write-Host "`nDelegations (appsvc-int-subnet):"
az network vnet subnet show -g $resourceGroupName --vnet-name $vnetName -n $appIntSubnetName --query "delegations[].serviceName" -o tsv

Write-Host "`nNSG on pg-subnet:"
az network vnet subnet show -g $resourceGroupName --vnet-name $vnetName -n $pgSubnetName --query "networkSecurityGroup.id" -o tsv
az network nsg rule list -g $resourceGroupName --nsg-name $pgNsgName -o table

Write-Host "`nPrivate DNS zone + link:"
az network private-dns zone show -g $resourceGroupName -n $privateDnsZone -o table
az network private-dns link vnet list -g $resourceGroupName -z $privateDnsZone -o table

Write-Host "`nNext:"
Write-Host "  1) Create PG VM in '$pgSubnetName' (NO public IP)."
Write-Host "  2) Add A record in '$privateDnsZone' (e.g., 'pg-dev') pointing to the VM's private IP."
Write-Host "  3) App Service (API/Producer/Provider) -> Regional VNet Integration into '$appIntSubnetName'."
Write-Host "  4) Point connection strings at 'pg-dev.$privateDnsZone:5432'."
