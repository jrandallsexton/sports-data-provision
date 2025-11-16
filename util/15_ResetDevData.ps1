<#
.SYNOPSIS
    Fully reset DEV environment data for SportDeets.

.DESCRIPTION
    Drops PostgreSQL tables and Hangfire schemas in DEV.
    Clears Service Bus queues and topics in DEV.
    Deletes the single Cosmos DB container used in DEV.
#>

if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: SPORTDEETS_SECRETS_PATH environment variable is not set."
}

Write-Host "Starting DEV data reset..." -ForegroundColor Cyan

# Load secrets file (PowerShell .ps1 that defines $script:* variables)
$secretsPath = $env:SPORTDEETS_SECRETS_PATH
. "$secretsPath\_common-variables.ps1"

# PostgreSQL connection values
$pgHost = $script:pgHostDev
$pgUser = $script:pgUserDev
$pgPass = $script:pgPasswordDev
$pgDatabases = $script:pgDatabasesDev

# Cosmos DB values
$cosmosAccount = $script:environments["dev"]["cosmosAccount"]
$cosmosDatabase = $script:environments["dev"]["cosmosDatabase"]
$cosmosContainer = $script:environments["dev"]["cosmosContainer"]
$cosmosSubscription = $script:subscriptionIdSecondary
$comsmoResourceGroup = $script:resourceGroupNameSecondary = "rg-sportDeets-dev2"

# Service Bus values
$sbNamespaceName = $script:svcBusNamespaceNameDev
$sbResourceGroup = $script:resourceGroupNameSecondary
$sbSubscriptionId = $script:subscriptionIdSecondary

# Confirm prompt
$confirm = Read-Host "This will delete all DEV data. Type YES to continue"
if ($confirm -ne "YES") {
    Write-Host "Cancelled."
    exit
}

# Write SQL to temp file
function Write-TempSqlFile($sql) {
    $tempPath = [System.IO.Path]::GetTempFileName()
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $writer = New-Object System.IO.StreamWriter($tempPath, $false, $utf8NoBom)
    $writer.Write($sql)
    $writer.Close()
    return $tempPath
}

# SQL statements
$dropTablesSql = @'
DO $$
DECLARE
    stmt TEXT;
BEGIN
    FOR stmt IN
        SELECT 'DROP TABLE IF EXISTS "' || tablename || '" CASCADE;'
        FROM pg_tables
        WHERE schemaname = 'public'
    LOOP
        EXECUTE stmt;
    END LOOP;
END
$$;
'@

$dropHangfireSql = "DROP SCHEMA IF EXISTS hangfire CASCADE;"

function Reset-PgDb($label, $dbName) {
    Write-Host "Dropping $label ($dbName) PostgreSQL tables and Hangfire schema..."

    $dropFile = Write-TempSqlFile $dropTablesSql
    $hangfireFile = Write-TempSqlFile $dropHangfireSql

    if (-not $pgHost) { throw "pgHost is null or empty." }
    if (-not $pgUser) { throw "pgUser is null or empty." }
    if (-not $pgPass) { throw "pgPass is null or empty." }
    if (-not $dbName) { throw "pgDb (actual: $label) is null or empty." }

    Write-Host "  Host: $pgHost"
    Write-Host "  User: $pgUser"
    Write-Host "  DB:   $dbName"

    $argsDrop = @("-h", $pgHost, "-U", $pgUser, "-d", $dbName, "-f", $dropFile)
    $argsHangfire = @("-h", $pgHost, "-U", $pgUser, "-d", $dbName, "-f", $hangfireFile)

    Write-Host "  Running psql drop: $($argsDrop -join ' ')"
    & psql @argsDrop
    Write-Host "  Running psql hangfire: $($argsHangfire -join ' ')"
    & psql @argsHangfire

    Remove-Item $dropFile, $hangfireFile
}

# Set PGPASSWORD for psql
$env:PGPASSWORD = $pgPass

# Run PG drops for each defined database
foreach ($dbName in $pgDatabases) {
    Reset-PgDb -label $dbName -dbName $dbName
}

# === Reset Cosmos DB ===
Write-Host "Resetting Cosmos DB..." -ForegroundColor Cyan
az account set --subscription $cosmosSubscription

if (-not $cosmosAccount -or -not $cosmosDatabase -or -not $cosmosContainer) {
    throw "Cosmos DEV configuration is incomplete. Check _common-variables.ps1."
}

Write-Host "  Deleting container '$cosmosContainer' from database '$cosmosDatabase'..."

az cosmosdb sql container delete `
    --resource-group $comsmoResourceGroup `
    --account-name $cosmosAccount `
    --database-name $cosmosDatabase `
    --name $cosmosContainer `
    --yes `
    --only-show-errors

Write-Host "Re-creating container '$cosmosContainer' in database '$cosmosDatabase'..."

az cosmosdb sql container create `
    --resource-group $comsmoResourceGroup `
    --account-name $cosmosAccount `
    --database-name $cosmosDatabase `
    --name $cosmosContainer `
    --partition-key-path "/RoutingKey" `
    --throughput 400 `
    --only-show-errors | Out-Null

Write-Host "Cosmos container recreated." -ForegroundColor Green

Write-Host "Cosmos DB reset complete." -ForegroundColor Green

# === Reset Azure Service Bus ===
Write-Host "Cleaning Azure Service Bus namespace: $sbNamespaceName ..." -ForegroundColor Cyan

az account set --subscription $sbSubscriptionId | Out-Null

# Delete all queues
$queues = az servicebus queue list `
    --resource-group $sbResourceGroup `
    --namespace-name $sbNamespaceName `
    --query "[].name" -o tsv

if ($queues) {
    foreach ($q in $queues) {
        Write-Host "  Deleting queue: $q"
        az servicebus queue delete `
            --resource-group $sbResourceGroup `
            --namespace-name $sbNamespaceName `
            --name $q --only-show-errors
    }
}
else {
    Write-Host "  No queues found."
}

# Delete all topics (deletes associated subscriptions)
$topics = az servicebus topic list `
    --resource-group $sbResourceGroup `
    --namespace-name $sbNamespaceName `
    --query "[].name" -o tsv

if ($topics) {
    foreach ($t in $topics) {
        Write-Host "  Deleting topic: $t"
        az servicebus topic delete `
            --resource-group $sbResourceGroup `
            --namespace-name $sbNamespaceName `
            --name $t --only-show-errors
    }
}
else {
    Write-Host "  No topics found."
}

Write-Host "Service Bus cleanup complete." -ForegroundColor Green
Write-Host "DEV reset complete." -ForegroundColor Green