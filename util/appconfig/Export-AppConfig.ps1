#Requires -Version 7.0
# Export-AppConfig.ps1
# Exports all key-value entries from Azure App Configuration to manifest.json.
# Run this to capture the current state of App Config as the IaC baseline.
#
# Usage:
#   .\Export-AppConfig.ps1                                # Export from default store
#   .\Export-AppConfig.ps1 -StoreName "sportdeetsappconfig2"  # Export from specific store

param(
    [string]$StoreName = "sportdeetsappconfig2"
)

$ErrorActionPreference = "Stop"

Write-Host "Exporting from App Config store: $StoreName" -ForegroundColor Cyan

# Export all entries with all fields
$raw = az appconfig kv list `
    --name $StoreName `
    --all `
    --fields key value label content_type `
    -o json 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to export from App Config: $raw"
    exit 1
}

$entries = $raw | ConvertFrom-Json

# Group by label, sorted
$manifest = [ordered]@{}
foreach ($entry in $entries | Sort-Object label, key) {
    $label = if ($entry.label) { $entry.label } else { "(no label)" }

    if (-not $manifest.Contains($label)) {
        $manifest[$label] = @()
    }

    $item = [ordered]@{
        key   = $entry.key
        value = $entry.value
    }

    if ($entry.content_type) {
        $item["content_type"] = $entry.content_type
    }

    $manifest[$label] += $item
}

# Write manifest
$outputPath = Join-Path $PSScriptRoot "manifest.json"
$manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath -Encoding UTF8

# Summary
$totalEntries = ($entries | Measure-Object).Count
$kvRefs = ($entries | Where-Object { $_.content_type -like "*keyvaultref*" } | Measure-Object).Count
$labels = ($manifest.Keys | Measure-Object).Count

Write-Host ""
Write-Host "Export complete:" -ForegroundColor Green
Write-Host "  Store:            $StoreName"
Write-Host "  Total entries:    $totalEntries"
Write-Host "  Key Vault refs:   $kvRefs"
Write-Host "  Labels:           $labels"
Write-Host "  Output:           $outputPath"
Write-Host ""

foreach ($label in $manifest.Keys) {
    $count = $manifest[$label].Count
    $secrets = ($manifest[$label] | Where-Object { $_.content_type -like "*keyvaultref*" } | Measure-Object).Count
    Write-Host "  $("{0,4}" -f $count) entries ($secrets KV refs)  $label"
}
