if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}

# Load shared variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

# ---- CONFIG ----
$subscriptionIdPrimary      = $script:subscriptionIdPrimary
$resourceGroupNamePrimary   = $script:resourceGroupNamePrimary

$subscriptionIdTertiary     = $script:subscriptionIdTertiary
$resourceGroupNameTertiary  = $script:resourceGroupNameTertiary

$nsgName                    = "sportdeets-pgsql-devNSG"
$port                       = 5432
$priorityBase               = 1100

$appServices = @(
    "api-public-dev",
    "provider-football-ncaa-dev",
    "producer-football-ncaa-dev"
)

# ---- PHASE 1: Get App Service outbound IPs from Primary subscription ----
az account set --subscription $subscriptionIdPrimary

$ips = @()

foreach ($app in $appServices) {
    Write-Host "Fetching outbound IPs for $app..."
    $outbound = az webapp show `
        --name $app `
        --resource-group $resourceGroupNamePrimary `
        --query "outboundIpAddresses" `
        --output tsv

    $ips += $outbound.Split(",") | ForEach-Object { $_.Trim() }
}

$uniqueIps = $ips | Sort-Object -Unique

Write-Host ""
Write-Host "Found $($uniqueIps.Count) unique outbound IPs:"
$uniqueIps | ForEach-Object { Write-Host "  $_" }

# ---- PHASE 2: Switch to Tertiary and add NSG rules ----
az account set --subscription $subscriptionIdTertiary

$i = 0
foreach ($ip in $uniqueIps) {
    $ruleName = "Allow-AppSvc-$i"

    Write-Host "Adding NSG rule for $ip as $ruleName..."

    az network nsg rule create `
      --resource-group $resourceGroupNameTertiary `
      --nsg-name $nsgName `
      --name $ruleName `
      --priority ($priorityBase + $i) `
      --destination-port-ranges $port `
      --access Allow `
      --direction Inbound `
      --protocol Tcp `
      --source-address-prefixes $ip `
      --description "Allow App Services to access PGSQL"

    $i++
}

Write-Host ""
Write-Host "All NSG rules added successfully."
