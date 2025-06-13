# File: 11_ProvisionStorageAccounts.ps1

# Import shared variables
. "$PSScriptRoot\..\_secrets\_common-variables.ps1"

# Explicitly set subscription using Azure CLI
$subscriptionId = $script:subscriptionIdSecondary  # vsprem1_150
az account set --subscription $subscriptionId
Write-Host "`nUsing subscription: $subscriptionId`n" -ForegroundColor Cyan

# Resource group where storage will be created
$resourceGroup = $script:resourceGroupNameSecondary

# Define accounts to provision
$storageAccounts = @(
    @{ name = "sportdeetssalocal"; container = "local-footballncaavenueimage" },
    @{ name = "sportdeetssadev"; container = "dev-footballncaavenueimage" }
)

foreach ($entry in $storageAccounts) {
    $accountName = $entry.name
    $containerName = $entry.container

    Write-Host "`nChecking storage account: $accountName" -ForegroundColor Yellow

    $existingAccount = az storage account show `
        --name $accountName `
        --resource-group $resourceGroup `
        --query "name" `
        --output tsv 2>$null

    if (-not $existingAccount) {
        Write-Host "Creating storage account: $accountName" -ForegroundColor Green
        az storage account create `
            --name $accountName `
            --resource-group $resourceGroup `
            --sku Standard_LRS `
            --kind StorageV2 `
            --location eastus `
            --output none
    }
    else {
        Write-Host "⚠ Already exists: $accountName" -ForegroundColor DarkGray
    }

    # Get the storage key
    $storageKey = az storage account keys list `
        --account-name $accountName `
        --resource-group $resourceGroup `
        --query "[0].value" `
        --output tsv

    # Ensure the container exists
    az storage container create `
        --name $containerName `
        --account-name $accountName `
        --account-key $storageKey `
        --output none

    Write-Host "✓ Container ensured: $containerName in $accountName" -ForegroundColor Cyan
}

Write-Host "All storage accounts and containers processed." -ForegroundColor Green
