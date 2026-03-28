#Requires -Version 7.0
# Apply-AppConfig.ps1
# Applies the manifest.json to Azure App Configuration.
# Idempotent: az appconfig kv set overwrites existing values.
# Key Vault references are applied via az appconfig kv set-keyvault.
#
# Usage:
#   .\Apply-AppConfig.ps1                          # Apply all labels
#   .\Apply-AppConfig.ps1 -Label "Local"           # Apply a single label
#   .\Apply-AppConfig.ps1 -Label "Prod*"           # Apply labels matching a pattern
#   .\Apply-AppConfig.ps1 -DryRun                  # Preview without applying
#   .\Apply-AppConfig.ps1 -Label "*.FootballNfl*"  # Apply only NFL labels

param(
    [string]$StoreName = "sportdeetsappconfig2",
    [string]$Label = "*",
    [string]$ManifestPath = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $PSScriptRoot "manifest.json"
}

if (-not (Test-Path $ManifestPath)) {
    Write-Error "Manifest not found: $ManifestPath"
    exit 1
}

$manifest = Get-Content -Path $ManifestPath -Raw | ConvertFrom-Json -AsHashtable

# Filter labels
$targetLabels = $manifest.Keys | Where-Object { $_ -like $Label } | Sort-Object

if ($targetLabels.Count -eq 0) {
    Write-Host "No labels match pattern: $Label" -ForegroundColor Yellow
    exit 0
}

$mode = if ($DryRun) { "DRY RUN" } else { "APPLY" }
Write-Host "[$mode] Targeting $($targetLabels.Count) label(s) in store: $StoreName" -ForegroundColor Cyan
Write-Host ""

$totalApplied = 0
$totalSkipped = 0
$totalErrors = 0

foreach ($lbl in $targetLabels) {
    $entries = $manifest[$lbl]
    $count = $entries.Count
    Write-Host "  Label: $lbl ($count entries)" -ForegroundColor White

    foreach ($entry in $entries) {
        $key = $entry["key"]
        $value = $entry["value"]
        $contentType = $entry["content_type"]
        $isKvRef = $contentType -like "*keyvaultref*"

        if ($DryRun) {
            $displayVal = if ($isKvRef) { "(Key Vault reference)" } else { $value.Substring(0, [Math]::Min(60, $value.Length)) + $(if ($value.Length -gt 60) { "..." } else { "" }) }
            Write-Host "    [DRY] $key = $displayVal" -ForegroundColor DarkGray
            $totalSkipped++
            continue
        }

        try {
            if ($isKvRef) {
                # Key Vault reference: extract the secret URI and use set-keyvault
                $kvJson = $value | ConvertFrom-Json
                $secretUri = $kvJson.uri

                $null = az appconfig kv set-keyvault `
                    --name $StoreName `
                    --key $key `
                    --label $lbl `
                    --secret-identifier $secretUri `
                    --yes `
                    --only-show-errors 2>&1

                if ($LASTEXITCODE -ne 0) {
                    Write-Host "    [ERROR] $key (KV ref)" -ForegroundColor Red
                    $totalErrors++
                }
                else {
                    $totalApplied++
                }
            }
            else {
                # Plain value: use standard set
                $setArgs = @(
                    "appconfig", "kv", "set",
                    "--name", $StoreName,
                    "--key", $key,
                    "--label", $lbl,
                    "--value", $value,
                    "--yes",
                    "--only-show-errors"
                )

                if ($contentType) {
                    $setArgs += "--content-type"
                    $setArgs += $contentType
                }

                $null = az @setArgs 2>&1

                if ($LASTEXITCODE -ne 0) {
                    Write-Host "    [ERROR] $key" -ForegroundColor Red
                    $totalErrors++
                }
                else {
                    $totalApplied++
                }
            }
        }
        catch {
            Write-Host "    [ERROR] $key : $_" -ForegroundColor Red
            $totalErrors++
        }
    }
}

Write-Host ""
Write-Host "[$mode] Complete:" -ForegroundColor $(if ($totalErrors -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Applied: $totalApplied"
Write-Host "  Skipped: $totalSkipped"
Write-Host "  Errors:  $totalErrors"
