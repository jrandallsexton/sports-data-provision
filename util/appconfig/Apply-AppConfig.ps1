#Requires -Version 7.0
# Apply-AppConfig.ps1
# Applies the manifest.json to Azure App Configuration.
# Idempotent: imports overwrite existing values.
#
# Strategy:
#   - Plain values: exported to temp JSON files and imported via az appconfig kv import
#   - Key Vault references: applied individually via az appconfig kv set-keyvault
#     (import doesn't preserve the keyvaultref content_type)
#
# Usage:
#   .\Apply-AppConfig.ps1                          # Apply all labels
#   .\Apply-AppConfig.ps1 -Label "Local"           # Apply a single label
#   .\Apply-AppConfig.ps1 -Label "Prod*"           # Apply labels matching a pattern
#   .\Apply-AppConfig.ps1 -DryRun                  # Preview without applying
#   .\Apply-AppConfig.ps1 -Label "*.FootballNfl*"  # Apply only NFL labels

param(
    [string]$StoreName = "sportdeetsappconfig2",
    [string]$ConnectionString = "",
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

# Build the store identifier args used for all az commands
# Prefer --connection-string (data-plane direct) over --name (requires ARM read permission)
$storeArgs = if ($ConnectionString) {
    @("--connection-string", $ConnectionString)
} else {
    @("--name", $StoreName)
}
$storeDisplay = if ($ConnectionString) { "$StoreName (via connection string)" } else { $StoreName }

$mode = if ($DryRun) { "DRY RUN" } else { "APPLY" }
Write-Host "[$mode] Targeting $($targetLabels.Count) label(s) in store: $storeDisplay" -ForegroundColor Cyan
Write-Host ""

$totalPlain = 0
$totalKvRefs = 0
$totalErrors = 0

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "appconfig-apply-$([guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    foreach ($lbl in $targetLabels) {
        $entries = $manifest[$lbl]

        # Separate plain values from KV references
        $plainEntries = @{}
        $kvRefEntries = @()

        foreach ($entry in $entries) {
            $ct = $entry["content_type"]
            if ($ct -like "*keyvaultref*") {
                $kvRefEntries += $entry
            }
            else {
                $plainEntries[$entry["key"]] = $entry["value"]
            }
        }

        $plainCount = $plainEntries.Count
        $kvCount = $kvRefEntries.Count
        Write-Host "  Label: $lbl ($plainCount plain, $kvCount KV refs)" -ForegroundColor White

        if ($DryRun) {
            foreach ($entry in $entries) {
                $ct = $entry["content_type"]
                $isKv = $ct -like "*keyvaultref*"
                $val = $entry["value"]
                $displayVal = if ($isKv) { "(Key Vault reference)" } else { $val.Substring(0, [Math]::Min(60, $val.Length)) + $(if ($val.Length -gt 60) { "..." } else { "" }) }
                Write-Host "    [DRY] $($entry["key"]) = $displayVal" -ForegroundColor DarkGray
            }
            $totalPlain += $plainCount
            $totalKvRefs += $kvCount
            continue
        }

        # Pass 1: Import plain values via temp JSON file
        if ($plainCount -gt 0) {
            $tempFile = Join-Path $tempDir "label-$($lbl -replace '[^a-zA-Z0-9_.-]', '_').json"
            $plainEntries | ConvertTo-Json -Depth 5 | Set-Content -Path $tempFile -Encoding UTF8

            $importResult = az appconfig kv import `
                @storeArgs `
                --source file `
                --path $tempFile `
                --format json `
                --label $lbl `
                --yes `
                --only-show-errors 2>&1

            if ($LASTEXITCODE -ne 0) {
                Write-Host "    [ERROR] Import failed for label $lbl : $importResult" -ForegroundColor Red
                $totalErrors += $plainCount
            }
            else {
                Write-Host "    Imported $plainCount plain values" -ForegroundColor DarkGray
                $totalPlain += $plainCount
            }
        }

        # Pass 2: Apply KV references individually
        foreach ($kvEntry in $kvRefEntries) {
            $key = $kvEntry["key"]
            $value = $kvEntry["value"]

            try {
                $kvJson = $value | ConvertFrom-Json
                $secretUri = $kvJson.uri

                $setResult = az appconfig kv set-keyvault `
                    @storeArgs `
                    --key $key `
                    --label $lbl `
                    --secret-identifier $secretUri `
                    --yes `
                    --only-show-errors 2>&1

                if ($LASTEXITCODE -ne 0) {
                    Write-Host "    [ERROR] $key (KV ref): $setResult" -ForegroundColor Red
                    $totalErrors++
                }
                else {
                    $totalKvRefs++
                }
            }
            catch {
                Write-Host "    [ERROR] $key (KV ref): $_" -ForegroundColor Red
                $totalErrors++
            }
        }
    }
}
finally {
    # Cleanup temp files
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "[$mode] Complete:" -ForegroundColor $(if ($totalErrors -gt 0) { "Yellow" } else { "Green" })
Write-Host "  Plain values: $totalPlain"
Write-Host "  KV references: $totalKvRefs"
Write-Host "  Errors: $totalErrors"
