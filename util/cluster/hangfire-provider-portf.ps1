#!/usr/bin/env pwsh
# Port forward to Hangfire dashboard on Provider pod

Write-Host "Finding Provider pod..." -ForegroundColor Cyan

# Get the Provider pod name
$podName = kubectl get pods -n default -o json | 
    ConvertFrom-Json | 
    Select-Object -ExpandProperty items | 
    Where-Object { $_.metadata.name -like "provider-football-ncaa-*" } | 
    Select-Object -First 1 -ExpandProperty metadata | 
    Select-Object -ExpandProperty name

if (-not $podName) {
    Write-Host "ERROR: No Provider pod found in default namespace" -ForegroundColor Red
    exit 1
}

Write-Host "Found pod: $podName" -ForegroundColor Green
Write-Host "Waiting for pod to be ready..." -ForegroundColor Cyan

# Wait for pod to be ready
$maxWaitSeconds = 120
$waitedSeconds = 0
while ($waitedSeconds -lt $maxWaitSeconds) {
    $podStatus = kubectl get pod -n default $podName -o jsonpath='{.status.phase}'
    $containerReady = kubectl get pod -n default $podName -o jsonpath='{.status.containerStatuses[0].ready}'
    
    if ($podStatus -eq "Running" -and $containerReady -eq "true") {
        Write-Host "Pod is ready!" -ForegroundColor Green
        break
    }
    
    Write-Host "  Pod status: $podStatus, Container ready: $containerReady (waiting...)" -ForegroundColor Gray
    Start-Sleep -Seconds 5
    $waitedSeconds += 5
}

if ($waitedSeconds -ge $maxWaitSeconds) {
    Write-Host "ERROR: Pod did not become ready within $maxWaitSeconds seconds" -ForegroundColor Red
    exit 1
}

Write-Host "Starting port forward to 8080..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Hangfire dashboard will be available at: http://localhost:8080/dashboard" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop port forwarding" -ForegroundColor Gray
Write-Host ""

# Start port forwarding
kubectl port-forward -n default pod/$podName 8080:8080
