. "$PSScriptRoot/../../environments/_secrets/_common-variables.ps1"

$resourceGroupName = $script:resourceGroupNamePrimary

Get-AzSqlServer -ResourceGroupName $resourceGroupName | ForEach-Object {
    $server = $_
    Get-AzSqlDatabase -ServerName $server.ServerName -ResourceGroupName $resourceGroupName | Select-Object DatabaseName, Edition, RequestedServiceObjectiveName, Status, Location
}
