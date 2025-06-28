if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}

# Load shared variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

$subscriptionId_VM = $script:subscriptionIdTertiary
$resourceGroup_VM = $script:resourceGroupNameTertiary
$vmName = $script:pgsqlVmName
$desiredSize = "Standard_B2s"

# Set active subscription
az account set --subscription $subscriptionId_VM

function Set-VmSizeIfDifferent {
    param (
        [string]$VmName,
        [string]$ResourceGroup,
        [string]$DesiredSize
    )

    Write-Host "`nChecking current size of VM '$VmName'..."
    $currentSize = az vm show `
        --name $VmName `
        --resource-group $ResourceGroup `
        --query "hardwareProfile.vmSize" `
        --output tsv

    if ($currentSize -eq $DesiredSize) {
        Write-Host "VM '$VmName' is already size '$DesiredSize'. No action needed."
    }
    else {
        Write-Host "Resizing VM '$VmName' from '$currentSize' to '$DesiredSize'..."
        az vm resize `
            --name $VmName `
            --resource-group $ResourceGroup `
            --size $DesiredSize `
            --only-show-errors

        Write-Host "Resize complete. VM will restart automatically."
    }
}

Set-VmSizeIfDifferent -VmName $vmName -ResourceGroup $resourceGroup_VM -DesiredSize $desiredSize
