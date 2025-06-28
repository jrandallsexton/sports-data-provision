if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}

# Load shared variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

# ---- CONFIG ----
$subscriptionId     = $script:subscriptionIdTertiary
$resourceGroupName  = $script:resourceGroupNameTertiary
$location           = "eastus"
$vmName             = "sportdeets-pgsql-dev"
$adminUsername      = $script:pgUser
$postgresPassword   = $script:pgPassword
$publicIpName       = "$vmName-ip"
$ipRule             = (Invoke-RestMethod -Uri "https://api.ipify.org") + "/32"

# ---- SET SUBSCRIPTION ----
az account set --subscription $subscriptionId

# Create Resource Group
az group create `
  --name $resourceGroupName `
  --location $location

# Inject postgres password into cloud-init
$cloudInitPath = "$PSScriptRoot\\09b_ProvisionPgSql.yaml"
$cloudInitTemp = "$PSScriptRoot\\cloud-init-temp.yaml"
(Get-Content $cloudInitPath) -replace '__REPLACE__PASSWORD__', $postgresPassword | Set-Content $cloudInitTemp

# Create VM with cloud-init
az vm create `
  --name $vmName `
  --resource-group $resourceGroupName `
  --image "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest" `
  --admin-username $adminUsername `
  --generate-ssh-keys `
  --size Standard_B1s `
  --public-ip-address $publicIpName `
  --authentication-type ssh `
  --custom-data $cloudInitTemp

# Open port 5432 to your current IP only
$nicName = az vm show `
  --resource-group $resourceGroupName `
  --name $vmName `
  --query "networkProfile.networkInterfaces[0].id" `
  --output tsv |
  ForEach-Object { ($_ -split "/")[-1] }

$nsgName = az network nic show `
  --name $nicName `
  --resource-group $resourceGroupName `
  --query "networkSecurityGroup.id" `
  --output tsv |
  ForEach-Object { ($_ -split "/")[-1] }

az network nsg rule create `
  --resource-group $resourceGroupName `
  --nsg-name $nsgName `
  --name "AllowPostgres" `
  --priority 1001 `
  --destination-port-ranges 5432 `
  --access Allow `
  --direction Inbound `
  --protocol Tcp `
  --source-address-prefixes $ipRule `
  --description "Allow PostgreSQL from my IP"

# Get public IP
$vmIp = az vm show `
  --resource-group $resourceGroupName `
  --name $vmName `
  --show-details `
  --query "publicIps" `
  --output tsv

Write-Host "`n✅ PostgreSQL VM is ready!"
Write-Host "👉 Connect using pgAdmin or psql:"
Write-Host "   Host: $vmIp"
Write-Host "   Port: 5432"
Write-Host "   Username: postgres"
Write-Host "   Password: (from secrets)"