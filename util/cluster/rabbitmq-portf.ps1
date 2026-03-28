#!/usr/bin/env pwsh
# Port forward to RabbitMQ Management UI
kubectl config use-context nuc | Out-Null
Write-Host "Using cluster context: nuc (NUC cluster)" -ForegroundColor Yellow

Write-Host "Finding RabbitMQ pod..." -ForegroundColor Cyan

# Get RabbitMQ pod name
$pods = kubectl get pods -n messaging -o json | ConvertFrom-Json | Select-Object -ExpandProperty items
$rabbitmqPod = $pods | Where-Object { $_.metadata.name -like "rabbitmq-server-*" } | Select-Object -First 1 -ExpandProperty metadata | Select-Object -ExpandProperty name

if (-not $rabbitmqPod) {
    Write-Host "ERROR: Could not find RabbitMQ pod in messaging namespace" -ForegroundColor Red
    exit 1
}

Write-Host "Found pod: $rabbitmqPod" -ForegroundColor Green
Write-Host ""

# Wait for pod to be ready
Write-Host "Waiting for RabbitMQ pod to be ready..." -ForegroundColor Cyan
$maxWaitSeconds = 120
$waitedSeconds = 0

while ($waitedSeconds -lt $maxWaitSeconds) {
    $podReady = kubectl get pod -n messaging $rabbitmqPod -o jsonpath='{.status.containerStatuses[0].ready}'
    
    if ($podReady -eq "true") {
        Write-Host "RabbitMQ pod is ready!" -ForegroundColor Green
        break
    }
    
    Write-Host "  Status: $podReady (waiting...)" -ForegroundColor Gray
    Start-Sleep -Seconds 5
    $waitedSeconds += 5
}

if ($waitedSeconds -ge $maxWaitSeconds) {
    Write-Host "ERROR: RabbitMQ pod did not become ready within $maxWaitSeconds seconds" -ForegroundColor Red
    exit 1
}

# Use operator-generated credentials from rabbitmq-default-user secret
Write-Host ""
Write-Host "Retrieving RabbitMQ credentials..." -ForegroundColor Cyan
$username = kubectl get secret -n messaging rabbitmq-default-user -o jsonpath='{.data.username}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
$password = kubectl get secret -n messaging rabbitmq-default-user -o jsonpath='{.data.password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

Write-Host ""
Write-Host "Starting port forward..." -ForegroundColor Cyan
Write-Host "  Management UI: http://localhost:15673 (cluster)" -ForegroundColor Yellow
Write-Host "  AMQP Port:     localhost:5673 (cluster)" -ForegroundColor Yellow
Write-Host "  Note: Local Docker RabbitMQ on 5672/15672" -ForegroundColor Gray
Write-Host ""
Write-Host "  Username: $username" -ForegroundColor Green
Write-Host "  Password: $password" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop port forwarding" -ForegroundColor Gray
Write-Host ""

try {
    # Start port forward for management UI (15673) and AMQP (5673)
    $mgmtJob = Start-Job -ScriptBlock {
        param($pod)
        kubectl port-forward -n messaging pod/$pod 15673:15672
    } -ArgumentList $rabbitmqPod

    $amqpJob = Start-Job -ScriptBlock {
        param($pod)
        kubectl port-forward -n messaging pod/$pod 5673:5672
    } -ArgumentList $rabbitmqPod

    # Wait a moment for port forwards to establish
    Start-Sleep -Seconds 2

    # Open RabbitMQ Management UI in browser
    Write-Host "Opening RabbitMQ Management UI in browser..." -ForegroundColor Cyan
    Start-Process "http://localhost:15673"

    Write-Host ""
    Write-Host "RabbitMQ Management UI running. Press Ctrl+C to stop." -ForegroundColor Green
    Write-Host ""

    # Wait for all jobs (keeps script running)
    Wait-Job $mgmtJob, $amqpJob
}
finally {
    Write-Host ""
    Write-Host "Cleaning up port forwards..." -ForegroundColor Yellow
    
    # Stop all background jobs
    Get-Job | Stop-Job -ErrorAction SilentlyContinue
    Get-Job | Remove-Job -ErrorAction SilentlyContinue
    
    # Kill any remaining kubectl port-forward processes
    Get-Process -Name kubectl -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*port-forward*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    
    Write-Host "Cleanup complete." -ForegroundColor Green
}
