#!/usr/bin/env pwsh
# Port forward to Hangfire dashboard on Producer pod

Write-Host "Finding Producer pod..." -ForegroundColor Cyan

# Get the Producer pod name
$podName = kubectl get pods -n default -o json | 
    ConvertFrom-Json | 
    Select-Object -ExpandProperty items | 
    Where-Object { $_.metadata.name -like "producer-football-ncaa-*" } | 
    Select-Object -First 1 -ExpandProperty metadata | 
    Select-Object -ExpandProperty name

if (-not $podName) {
    Write-Host "ERROR: No Producer pod found in default namespace" -ForegroundColor Red
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

Write-Host "Starting port forward to 8082..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Hangfire dashboard will be available at: http://localhost:8082/dashboard" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop port forwarding" -ForegroundColor Gray
Write-Host ""

try {
    # Start port forwarding directly (not as background job)
    Start-Job -ScriptBlock {
        Start-Sleep -Seconds 2
        Start-Process "http://localhost:8082/dashboard"
    } | Out-Null
    
    # Run port-forward in foreground
    kubectl port-forward -n default pod/$podName 8082:8080
}
finally {
    Write-Host ""
    Write-Host "Cleaning up..." -ForegroundColor Yellow
    # Kill any remaining kubectl port-forward processes
    Get-Process -Name kubectl -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*port-forward*" } | Stop-Process -Force -ErrorAction SilentlyContinue
}
