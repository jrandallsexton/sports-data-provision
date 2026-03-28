#Requires -Version 7.0
# Clone-Label.ps1
# Clones all entries from one label to a new label in manifest.json.
# This is the primary workflow for adding a new sport — clone an existing
# label's config and adjust values as needed.
#
# Usage:
#   .\Clone-Label.ps1 -Source "Local.FootballNcaa" -Target "Local.FootballNfl"
#   .\Clone-Label.ps1 -Source "Prod.FootballNcaa" -Target "Prod.FootballNfl"

param(
    [Parameter(Mandatory)]
    [string]$Source,

    [Parameter(Mandatory)]
    [string]$Target,

    [string]$ManifestPath = ""
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

if (-not $manifest.ContainsKey($Source)) {
    Write-Error "Source label '$Source' not found in manifest. Available labels: $($manifest.Keys -join ', ')"
    exit 1
}

if ($manifest.ContainsKey($Target)) {
    Write-Host "Target label '$Target' already exists with $($manifest[$Target].Count) entries." -ForegroundColor Yellow
    $confirm = Read-Host "Overwrite? (y/N)"
    if ($confirm -ne "y") {
        Write-Host "Aborted." -ForegroundColor Yellow
        exit 0
    }
}

# Deep clone the source entries
$sourceJson = $manifest[$Source] | ConvertTo-Json -Depth 10
$cloned = $sourceJson | ConvertFrom-Json -AsHashtable

# Ensure it's always an array
if ($cloned -isnot [System.Collections.IList]) {
    $cloned = @($cloned)
}

$manifest[$Target] = $cloned

# Write back sorted by label
$sorted = [ordered]@{}
foreach ($key in $manifest.Keys | Sort-Object) {
    $sorted[$key] = $manifest[$key]
}

$sorted | ConvertTo-Json -Depth 10 | Set-Content -Path $ManifestPath -Encoding UTF8

Write-Host ""
Write-Host "Cloned '$Source' -> '$Target' ($($cloned.Count) entries)" -ForegroundColor Green
Write-Host "Review and edit $ManifestPath to adjust sport-specific values."
Write-Host "Then run: .\Apply-AppConfig.ps1 -Label '$Target'" -ForegroundColor Cyan
