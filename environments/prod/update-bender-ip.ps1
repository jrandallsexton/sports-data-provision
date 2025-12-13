# Update Bender's IP address in Azure Front Door
# Old IP: 71.208.137.250
# New IP: 67.7.88.82

param(
    [string]$ResourceGroup = 'rg-sportDeets-prod',
    [string]$FrontDoorName = 'fd-sportdeets',
    [string]$OriginGroupName = 'homelab-cluster',
    [string]$OriginName = 'bender-k3s',
    [string]$NewIP = '67.7.88.82'
)

Write-Host "Updating Bender IP in Azure Front Door..." -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "  Front Door: $FrontDoorName" -ForegroundColor Gray
Write-Host "  Origin Group: $OriginGroupName" -ForegroundColor Gray
Write-Host "  New IP: $NewIP" -ForegroundColor Gray

# Update the origin with the new IP address
az afd origin update `
    --resource-group $ResourceGroup `
    --profile-name $FrontDoorName `
    --origin-group-name $OriginGroupName `
    --origin-name $OriginName `
    --host-name $NewIP `
    --http-port 80 `
    --https-port 443 `
    --priority 1 `
    --weight 1000 `
    --enabled-state Enabled

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nOrigin updated successfully!" -ForegroundColor Green
    Write-Host "Verifying the change..." -ForegroundColor Cyan
    
    az afd origin show `
        --resource-group $ResourceGroup `
        --profile-name $FrontDoorName `
        --origin-group-name $OriginGroupName `
        --origin-name $OriginName `
        --query '{name:name, hostName:hostName, enabledState:enabledState}' `
        --output table
} else {
    Write-Host "`nFailed to update origin. Error code: $LASTEXITCODE" -ForegroundColor Red
    Write-Host "Trying to list origins to verify the names..." -ForegroundColor Yellow
    
    az afd origin list `
        --resource-group $ResourceGroup `
        --profile-name $FrontDoorName `
        --origin-group-name $OriginGroupName `
        --output table
}
