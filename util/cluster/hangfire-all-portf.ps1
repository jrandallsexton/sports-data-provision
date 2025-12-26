#!/usr/bin/env pwsh
# Port forward to Hangfire dashboards on all services (Provider, Producer, API)

kubectl config use-context nuc | Out-Null
Write-Host "Using cluster context: nuc (NUC cluster)" -ForegroundColor Yellow

Write-Host "Finding pods..." -ForegroundColor Cyan

# Get all pod names
$pods = kubectl get pods -n default -o json | ConvertFrom-Json | Select-Object -ExpandProperty items

$providerPod = $pods | Where-Object { $_.metadata.name -like "provider-football-ncaa-*" } | Select-Object -First 1 -ExpandProperty metadata | Select-Object -ExpandProperty name
$producerPod = $pods | Where-Object { $_.metadata.name -like "producer-football-ncaa-*" } | Select-Object -First 1 -ExpandProperty metadata | Select-Object -ExpandProperty name
$apiPod = $pods | Where-Object { $_.metadata.name -like "api-all-*" } | Select-Object -First 1 -ExpandProperty metadata | Select-Object -ExpandProperty name

# Check if all pods were found
$missingPods = @()
if (-not $providerPod) { $missingPods += "Provider" }
if (-not $producerPod) { $missingPods += "Producer" }
if (-not $apiPod) { $missingPods += "API" }

if ($missingPods.Count -gt 0) {
    Write-Host "ERROR: Could not find pods for: $($missingPods -join ', ')" -ForegroundColor Red
    exit 1
}

Write-Host "Found pods:" -ForegroundColor Green
Write-Host "  Provider: $providerPod" -ForegroundColor Gray
Write-Host "  Producer: $producerPod" -ForegroundColor Gray
Write-Host "  API: $apiPod" -ForegroundColor Gray
Write-Host ""

# Wait for all pods to be ready
Write-Host "Waiting for all pods to be ready..." -ForegroundColor Cyan
$maxWaitSeconds = 120
$waitedSeconds = 0

while ($waitedSeconds -lt $maxWaitSeconds) {
    $providerReady = kubectl get pod -n default $providerPod -o jsonpath='{.status.containerStatuses[0].ready}'
    $producerReady = kubectl get pod -n default $producerPod -o jsonpath='{.status.containerStatuses[0].ready}'
    $apiReady = kubectl get pod -n default $apiPod -o jsonpath='{.status.containerStatuses[0].ready}'
    
    if ($providerReady -eq "true" -and $producerReady -eq "true" -and $apiReady -eq "true") {
        Write-Host "All pods are ready!" -ForegroundColor Green
        break
    }
    
    Write-Host "  Provider: $providerReady, Producer: $producerReady, API: $apiReady (waiting...)" -ForegroundColor Gray
    Start-Sleep -Seconds 5
    $waitedSeconds += 5
}

if ($waitedSeconds -ge $maxWaitSeconds) {
    Write-Host "ERROR: Not all pods became ready within $maxWaitSeconds seconds" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Starting port forwards..." -ForegroundColor Cyan
Write-Host "  Provider: http://localhost:8081/dashboard" -ForegroundColor Yellow
Write-Host "  Producer: http://localhost:8082/dashboard" -ForegroundColor Yellow
Write-Host "  API:      http://localhost:8083/dashboard" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop all port forwarding" -ForegroundColor Gray
Write-Host ""

try {
    # Start all three port forwards as background jobs
    $providerJob = Start-Job -ScriptBlock {
        param($pod)
        kubectl port-forward -n default pod/$pod 8081:8080
    } -ArgumentList $providerPod

    $producerJob = Start-Job -ScriptBlock {
        param($pod)
        kubectl port-forward -n default pod/$pod 8082:8080
    } -ArgumentList $producerPod

    $apiJob = Start-Job -ScriptBlock {
        param($pod)
        kubectl port-forward -n default pod/$pod 8083:8080
    } -ArgumentList $apiPod

    # Wait a moment for port forwards to establish
    Start-Sleep -Seconds 2

    # Open all three dashboards in browser
    Write-Host "Opening dashboards in browser..." -ForegroundColor Cyan
    Start-Process "http://localhost:8081/dashboard"
    Start-Sleep -Milliseconds 500
    Start-Process "http://localhost:8082/dashboard"
    Start-Sleep -Milliseconds 500
    Start-Process "http://localhost:8083/dashboard"

    Write-Host ""
    Write-Host "All dashboards running. Press Ctrl+C to stop." -ForegroundColor Green
    Write-Host ""

    # Wait for all jobs (keeps script running)
    Wait-Job $providerJob, $producerJob, $apiJob
}
finally {
    Write-Host ""
    Write-Host "Cleaning up all port forwards..." -ForegroundColor Yellow
    
    # Stop all background jobs
    Get-Job | Stop-Job -ErrorAction SilentlyContinue
    Get-Job | Remove-Job -ErrorAction SilentlyContinue
    
    # Kill any remaining kubectl port-forward processes
    Get-Process -Name kubectl -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*port-forward*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    Write-Host "Cleanup complete." -ForegroundColor Green
}
