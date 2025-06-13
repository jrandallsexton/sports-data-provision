param (
    [string]$labelLocal = "Local",
    [string]$labelDev = "Dev"
)

# === Declare required local variables (do NOT assign yet) ===
$subscriptionId = $null
$appConfigName = $null
$kvConnectionSecretUri = $null

# === Import shared variables (this will assign the above vars) ===
. "$PSScriptRoot\..\_secrets\_common-variables.ps1"

# === Assign values from the script scope ===
$subscriptionId = $script:subscriptionIdPrimary
$appConfigName = $script:appConfigName
$kvConnectionSecretUri = $script:providerCosmosKvConnectionSecretUri

# === Sanity checks ===
if (-not $subscriptionId)        { throw "Missing required variable: subscriptionId" }
if (-not $appConfigName)         { throw "Missing required variable: appConfigName" }
if (-not $kvConnectionSecretUri) { throw "Missing required variable: kvConnectionSecretUri" }

# === Set subscription ===
az account set --subscription $subscriptionId

# === Local (Mongo) Values ===
$localValues = @(
    @{ Key = "SportsData.Provider:ProviderDocDatabaseConfig:ConnectionString"; Value = "localhost" },
    @{ Key = "SportsData.Provider:ProviderDocDatabaseConfig:DatabaseName";     Value = "Provider-Development" },
    @{ Key = "SportsData.Provider:ProviderDocDatabaseConfig:Username";         Value = "sdProvider" },
    @{ Key = "SportsData.Provider:ProviderDocDatabaseConfig:Password";         Value = "sesame1?" },
    @{ Key = "SportsData.Provider:ProviderDocDatabaseConfig:Provider";         Value = "Mongo" }
)

foreach ($setting in $localValues) {
    az appconfig kv set `
        --name $appConfigName `
        --key $setting.Key `
        --value $setting.Value `
        --label $labelLocal `
        --yes
}

# === Dev (Cosmos) Non-Secret Values ===
$devNonSecrets = @(
    @{ Key = "SportsData.Provider:ProviderDocDatabaseConfig:DatabaseName"; Value = "provider-db" },
    @{ Key = "SportsData.Provider:ProviderDocDatabaseConfig:Provider";     Value = "Cosmos" }
)

foreach ($setting in $devNonSecrets) {
    az appconfig kv set `
        --name $appConfigName `
        --key $setting.Key `
        --value $setting.Value `
        --label $labelDev `
        --yes
}

# === Dev (Cosmos) ConnectionString via Key Vault ===
az appconfig kv set-keyvault `
    --name $appConfigName `
    --key "SportsData.Provider:ProviderDocDatabaseConfig:ConnectionString" `
    --label $labelDev `
    --secret-identifier $kvConnectionSecretUri `
    --yes
