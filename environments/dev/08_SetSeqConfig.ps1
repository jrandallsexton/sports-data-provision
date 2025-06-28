if (-not $env:SPORTDEETS_SECRETS_PATH) {
    throw "ERROR: The environment variable SPORTDEETS_SECRETS_PATH is not set. Please set it before running this script."
}

# Load shared variables
. "$env:SPORTDEETS_SECRETS_PATH\_common-variables.ps1"

# Define keys and values
$commonKey = "CommonConfig:SeqUri"

# Local URI (Seq running locally in Docker or desktop)
az appconfig kv set `
  --name $appConfigName `
  --key $commonKey `
  --value "http://localhost:8090/#/events?range=1d" `
  --label "Local" `
  --yes

# Dev URI (publicly accessible hosted Seq instance)
az appconfig kv set `
  --name $appConfigName `
  --key $commonKey `
  --value "https://logging-dev.sportdeets.com" `
  --label "Dev" `
  --yes
