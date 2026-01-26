#!/usr/bin/env pwsh
# Setup Hangfire connection string secrets for KEDA PostgreSQL scalers

param(
    [Parameter(Mandatory=$false)]
    [string]$SecretsPath = $env:SPORTDEETS_SECRETS_PATH
)

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "Hangfire Secrets Setup for KEDA" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Load secrets from _common-variables.ps1
if (-not $SecretsPath) {
    Write-Host "❌ SPORTDEETS_SECRETS_PATH environment variable not set" -ForegroundColor Red
    Write-Host "   Please set it to your secrets directory (e.g., D:\Dropbox\Code\sports-data-provision\_secrets)" -ForegroundColor Yellow
    exit 1
}

$commonVarsPath = Join-Path $SecretsPath "_common-variables.ps1"
if (-not (Test-Path $commonVarsPath)) {
    Write-Host "❌ Cannot find _common-variables.ps1 at: $commonVarsPath" -ForegroundColor Red
    exit 1
}

Write-Host "[INFO] Loading configuration from: $commonVarsPath" -ForegroundColor Yellow
. $commonVarsPath

# Validate required variables
if (-not $script:pgHostProd) {
    Write-Host "❌ Missing `$pgHostProd in _common-variables.ps1" -ForegroundColor Red
    Write-Host "   Add: `$pgHostProd = 'your-postgresql-host'" -ForegroundColor Yellow
    exit 1
}

if (-not $script:pgUserProd) {
    Write-Host "❌ Missing `$pgUserProd in _common-variables.ps1" -ForegroundColor Red
    Write-Host "   Add: `$pgUserProd = 'your-postgresql-username'" -ForegroundColor Yellow
    exit 1
}

if (-not $script:pgPasswordProd) {
    Write-Host "❌ Missing `$pgPasswordProd in _common-variables.ps1" -ForegroundColor Red
    Write-Host "   Add: `$pgPasswordProd = 'your-postgresql-password'" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Configuration:" -ForegroundColor White
Write-Host "  PostgreSQL Host: $($script:pgHostProd)" -ForegroundColor Gray
Write-Host "  PostgreSQL User: $($script:pgUserProd)" -ForegroundColor Gray
Write-Host "  PostgreSQL Password: ********" -ForegroundColor Gray
Write-Host ""

# Switch to cluster context
kubectl config use-context nuc | Out-Null
Write-Host "[INFO] Using cluster context: nuc" -ForegroundColor Yellow
Write-Host ""

# Build base connection string
$baseConnStr = "Host=$script:pgHostProd;Port=5432;Username=$script:pgUserProd;Password=$script:pgPasswordProd;SSL Mode=Prefer"

# Producer Football NCAA
Write-Host "[STEP 1/3] Creating connection string secret: producer-football-ncaa-hangfire..." -ForegroundColor Cyan
$producerFootballNcaaConnStr = "$baseConnStr;Database=sdProducer.FootballNcaa.Hangfire"
kubectl create secret generic producer-football-ncaa-hangfire -n default `
    --from-literal=connectionstring="$producerFootballNcaaConnStr" `
    --dry-run=client -o yaml | kubectl apply -f - | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✓ producer-football-ncaa-hangfire created/updated" -ForegroundColor Green
} else {
    Write-Host "    ✗ Failed to create producer-football-ncaa-hangfire" -ForegroundColor Red
    exit 1
}

# Producer KEDA PostgreSQL parameters (separate values for KEDA scaler)
Write-Host "[STEP 2/3] Creating KEDA PostgreSQL parameters: producer-hangfire-pg-params..." -ForegroundColor Cyan
kubectl create secret generic producer-hangfire-pg-params -n default `
    --from-literal=host="$script:pgHostProd" `
    --from-literal=port="5432" `
    --from-literal=username="$script:pgUserProd" `
    --from-literal=password="$script:pgPasswordProd" `
    --from-literal=database="sdProducer.FootballNcaa.Hangfire" `
    --from-literal=sslmode="prefer" `
    --dry-run=client -o yaml | kubectl apply -f - | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✓ producer-hangfire-pg-params created/updated" -ForegroundColor Green
} else {
    Write-Host "    ✗ Failed to create producer-hangfire-pg-params" -ForegroundColor Red
    exit 1
}

# Provider Football NCAA
Write-Host "[STEP 3/3] Creating connection string secret: provider-football-ncaa-hangfire..." -ForegroundColor Cyan
$providerFootballNcaaConnStr = "$baseConnStr;Database=sdProvider.FootballNcaa.Hangfire"
kubectl create secret generic provider-football-ncaa-hangfire -n default `
    --from-literal=connectionstring="$providerFootballNcaaConnStr" `
    --dry-run=client -o yaml | kubectl apply -f - | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "    ✓ provider-football-ncaa-hangfire created/updated" -ForegroundColor Green
} else {
    Write-Host "    ✗ Failed to create provider-football-ncaa-hangfire" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host "✓ Hangfire Secrets Setup Complete" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""
Write-Host "Created secrets:" -ForegroundColor White
Write-Host "  • producer-football-ncaa-hangfire (connection string for app)" -ForegroundColor Gray
Write-Host "  • producer-hangfire-pg-params (PostgreSQL parameters for KEDA)" -ForegroundColor Gray
Write-Host "  • provider-football-ncaa-hangfire (connection string for app)" -ForegroundColor Gray
Write-Host ""
Write-Host "These secrets are used by KEDA ScaledObjects to query Hangfire job queue depth." -ForegroundColor Yellow
