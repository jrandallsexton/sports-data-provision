# Set fixed parameters
$resourceGroup = "rg-sportDeets-dev"
$location = "centralus"
$serverName = "sql-sportdeets-dev"
$bicepFile = "../../templates/sql_db_template.bicep"

# List of databases to deploy
$databases = @(
    "sdApi.All",
    "sdContest.FootballNcaa",
    "sdContest.FootballNfl",
    "sdFranchise.FootballNcaa",
    "sdFranchise.FootballNfl",
    "sdNotification.All",
    "sdPlayer.FootballNcaa",
    "sdPlayer.FootballNfl",
    "sdProducer.FootballNcaa",
    "sdProducer.FootballNcaa.Hangfire",
    "sdProducer.FootballNfl",
    "sdProducer.FootballNfl.Hangfire",
    "sdProvider.FootballNcaa",
    "sdProvider.FootballNcaa.Hangfire",
    "sdProvider.FootballNfl",
    "sdProvider.FootballNfl.Hangfire",
    "sdSeason.FootballNcaa",
    "sdSeason.FootballNfl",
    "sdVenue.All"
)

foreach ($dbName in $databases) {
    Write-Host "`nChecking database: $dbName"

    $exists = az sql db show `
        --name $dbName `
        --server $serverName `
        --resource-group $resourceGroup `
        --query "name" `
        --output tsv 2>$null

    if ($exists) {
        Write-Host "Already exists: $dbName - skipping..."
        continue
    }

    Write-Host "Deploying: $dbName"

    az deployment group create `
        --resource-group $resourceGroup `
        --template-file $bicepFile `
        --parameters serverName=$serverName dbName=$dbName location=$location `
        --only-show-errors

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Deployment failed for $dbName"
    }
}
