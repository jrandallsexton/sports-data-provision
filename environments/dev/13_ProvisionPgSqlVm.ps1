# =========================
# sportDeets Dev PG VM (East US 2, private-only)
# - Uses secrets/config from SPORTDEETS_SECRETS_PATH\_common-variables.ps1
# - NIC on pg-subnet (NO public IP)
# - VM (Ubuntu 22.04)
# - Premium SSD data disk
# - Private DNS A record: pg-dev.pg.dev.internal -> <private IP>
# =========================

# ---- Guard + Secrets ----
if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

# ---- Config (from your standards) ----
$subscriptionId     = $script:subscriptionIdSecondary
$resourceGroupName  = "$($script:resourceGroupNameSecondary)-eus2"
$location           = "eastus2"

$vnetName           = "sd-dev-eus2-vnet"
$pgSubnetName       = "pg-subnet"

$privateDnsZone     = "pg.dev.internal"
$pgHostName         = "pg-dev"              # FQDN = pg-dev.pg.dev.internal

$vmName             = "sportdeets-pgsql-dev-eus2"
$adminUsername      = $script:pgUserDev     # from secrets
#$postgresPassword   = $script:pgPasswordDev # (not used in this script; kept for parity)

$nicName            = "$vmName-nic"
$vmSize             = "Standard_D2s_v5"

# Data disk for PG data (Premium SSD)
$pgDataDisk         = "$vmName-data"
$diskSizeGb         = 128

# ---- Azure Context ----
az account set --subscription $subscriptionId | Out-Null

# ---- Get subnet ID ----
$pgSubnetId = az network vnet subnet show `
  --resource-group $resourceGroupName `
  --vnet-name $vnetName `
  --name $pgSubnetName `
  --query id -o tsv

if (-not $pgSubnetId) { throw "pg-subnet not found in VNet '$vnetName' RG '$resourceGroupName'." }

# ---- NIC (no public IP) ----
az network nic create `
  --resource-group $resourceGroupName `
  --name $nicName `
  --subnet $pgSubnetId | Out-Null

# ---- VM (no --public-ip-address) ----
az vm create `
  --resource-group $resourceGroupName `
  --name $vmName `
  --location $location `
  --image "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest" `
  --admin-username $adminUsername `
  --generate-ssh-keys `
  --size $vmSize `
  --nics $nicName `
  --authentication-type ssh | Out-Null

# ---- Attach data disk ----
az vm disk attach `
  --resource-group $resourceGroupName `
  --vm-name $vmName `
  --new `
  --name $pgDataDisk `
  --size-gb $diskSizeGb `
  --sku Premium_LRS | Out-Null

# ---- Get the VM's private IP ----
$vmPrivIp = az network nic show `
  --resource-group $resourceGroupName `
  --name $nicName `
  --query "ipConfigurations[0].privateIpAddress" -o tsv

if (-not $vmPrivIp) { throw "Could not resolve VM private IP from NIC '$nicName'." }

# ---- Private DNS A record: pg-dev.pg.dev.internal -> private IP ----
# (Assumes the private DNS zone + VNet link already exist from your VNet script.)

# Ensure record set exists; if it already exists, this will just succeed with no change
# If your CLI errors on 'create' when it exists, we can guard, but new env shouldn't have it.
try {
  az network private-dns record-set a create `
    --resource-group $resourceGroupName `
    --zone-name $privateDnsZone `
    --name $pgHostName | Out-Null
} catch {
  # no-op if it already exists
}

# Remove any stale A records (idempotent safety)
$existingIps = az network private-dns record-set a show `
  --resource-group $resourceGroupName `
  --zone-name $privateDnsZone `
  --name $pgHostName `
  --query "arecords[].ipv4Address" -o tsv

if ($existingIps) {
  foreach ($ip in $existingIps) {
    if ($ip -and $ip -ne $vmPrivIp) {
      az network private-dns record-set a remove-record `
        --resource-group $resourceGroupName `
        --zone-name $privateDnsZone `
        --record-set-name $pgHostName `
        --ipv4-address $ip | Out-Null
    }
  }
}

# Add (or re-add) the current IP
az network private-dns record-set a add-record `
  --resource-group $resourceGroupName `
  --zone-name $privateDnsZone `
  --record-set-name $pgHostName `
  --ipv4-address $vmPrivIp | Out-Null

# ---- Output ----
Write-Host ("`n✅ VM created (private-only) in {0}" -f $location)
Write-Host ("   VM: {0}" -f $vmName)
Write-Host ("   NIC: {0}" -f $nicName)
Write-Host ("   Private IP: {0}" -f $vmPrivIp)
Write-Host ("   Data Disk: {0} ({1} GiB)" -f $pgDataDisk, $diskSizeGb)
Write-Host ("   FQDN: {0}.{1}" -f $pgHostName, $privateDnsZone)

Write-Host "`nNext:"
Write-Host "  • Script #3: install/configure PostgreSQL, mount data disk, bind to private IP, tighten pg_hba."
Write-Host "  • App Service (API/Producer/Provider) → Regional VNet Integration into 'appsvc-int-subnet'."
Write-Host ("  • Connection strings will be Host={0}.{1};Port=5432" -f $pgHostName, $privateDnsZone)
