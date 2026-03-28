# Azure App Configuration IaC

Infrastructure as Code for managing Azure App Configuration entries.

## Files

| File | Purpose |
|------|---------|
| `manifest.json` | Source of truth for all App Config key-value entries, grouped by label |
| `Export-AppConfig.ps1` | Export current App Config state to `manifest.json` |
| `Apply-AppConfig.ps1` | Apply `manifest.json` to App Config (idempotent) |
| `Clone-Label.ps1` | Clone entries from one label to another (for onboarding new sports) |
| `New-AppConfigStore.ps1` | Provision a new App Config store via Azure CLI |
| `azure-pipelines.yml` | Azure DevOps pipeline for automated validation and apply |

## Local Usage

```powershell
# Export current state (do this first to seed the manifest)
.\Export-AppConfig.ps1

# Preview what would be applied (dry run)
.\Apply-AppConfig.ps1 -DryRun

# Apply all labels
.\Apply-AppConfig.ps1

# Apply a specific label
.\Apply-AppConfig.ps1 -Label "Prod.FootballNcaa"

# Apply all NFL labels
.\Apply-AppConfig.ps1 -Label "*.FootballNfl*"

# Target a different store (e.g., the new replacement store)
.\Apply-AppConfig.ps1 -StoreName "sportdeetsappconfig2"
```

## Azure DevOps Pipeline

The pipeline is defined in `azure-pipelines.yml`. Create it in Azure DevOps by pointing a new pipeline at this file in the `sports-data-provision` repo.

### Pipeline Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `storeName` | `sportdeetsappconfig2` | Target App Config store name. Change this to point at whichever store you want to manage. |
| `label` | `*` | Label filter. Use `*` for all labels, or a specific label like `Prod.FootballNfl`. Supports wildcards. |
| `dryRun` | `true` | When true, the pipeline only validates and previews changes. Set to `false` to apply. |

### Pipeline Stages

1. **Validate** — Parses `manifest.json`, checks every entry has a `key` field, warns on null values. Runs on every trigger (PR and push).
2. **Dry Run** — Runs `Apply-AppConfig.ps1 -DryRun` against the target store to preview what would change. Runs on every trigger.
3. **Apply** — Applies the manifest to the store. Only runs when `dryRun` is `false` AND the branch is `main` (or manually triggered). Uses an Azure DevOps environment (`appconfig-{storeName}`) so you can add approval gates.

### Pipeline Triggers

- **Automatic**: Runs on any push to `main` that modifies `util/appconfig/manifest.json`
- **PR validation**: Runs Validate and Dry Run stages on PRs that touch `util/appconfig/**`
- **Manual**: Run from Azure DevOps UI with custom parameters (label filter, dry run toggle, store name)

### Prerequisites

- Azure DevOps service connection `dev-sports-data-api-svc-conn` must have permission to manage the target App Config store in the `vsprem0_150` subscription
- The pipeline runs on the self-hosted agent `Bender` (pool `Default`), matching existing service pipelines
- `az` CLI and PowerShell Core must be available on the agent (already the case for Bender)

## Adding a New Sport (e.g., NFL)

```powershell
# 1. Clone existing config for each environment
.\Clone-Label.ps1 -Source "Local.FootballNcaa" -Target "Local.FootballNfl"
.\Clone-Label.ps1 -Source "Prod.FootballNcaa" -Target "Prod.FootballNfl"

# 2. Edit manifest.json — adjust sport-specific values:
#    - CommonConfig:Messaging:RabbitMq:Host (dedicated broker per sport)
#    - ProviderDocDatabaseConfig:DatabaseName (separate Mongo DB)
#    - Any other sport-specific overrides

# 3. Apply to the new store
.\Apply-AppConfig.ps1 -StoreName "sportdeetsappconfig2" -Label "*.FootballNfl*"

# Or commit manifest.json and let the pipeline handle it
```

## Blue/Green Store Swap

To migrate to a new App Config store without risk to the running cluster:

```powershell
# 1. Create the new store
.\New-AppConfigStore.ps1 -Name "sportdeetsappconfig2"

# 2. Populate it from the manifest
.\Apply-AppConfig.ps1 -StoreName "sportdeetsappconfig2"

# 3. Verify
.\Apply-AppConfig.ps1 -StoreName "sportdeetsappconfig2" -DryRun

# 4. Update APPCONFIG_ENDPOINT in service deployments to point to the new store

# 5. Validate services are reading config correctly

# 6. Delete the old store
# az appconfig delete --name sportdeetsappconfig --resource-group rg-sportdeets --yes
```

## Label Convention

Labels follow the pattern: `{Environment}[.{Sport}[.{Application}]]`

| Label | Scope |
|-------|-------|
| `Local` | Local development defaults |
| `Prod` | Production defaults |
| `Dev.FootballNcaa` | Dev environment, NCAA football specific |
| `Prod.FootballNfl` | Production, NFL football specific |
| `Prod.All` | Production, shared across all sports |
| `Local.FootballNcaa.SportsData.Provider` | Local, NCAA, Provider service specific |

The App Config SDK resolves labels in a specific order (most specific wins). See `AppConfiguration.cs` in the Core project for the full resolution chain.

## Secrets

Secrets are stored in Azure Key Vault (`sportsdatakv`) and referenced in the manifest via:

```json
{
  "key": "CommonConfig:SqlBaseConnectionString",
  "value": "{\"uri\": \"https://sportsdatakv.vault.azure.net/secrets/SqlBaseConnectionString\"}",
  "content_type": "application/vnd.microsoft.appconfig.keyvaultref+json;charset=utf-8"
}
```

The `content_type` field identifies Key Vault references. The actual secret values never appear in the manifest — only the vault URI. These are safe to commit.
