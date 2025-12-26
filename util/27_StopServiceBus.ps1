# Stop Azure Service Bus Emulator

Write-Host "Stopping Service Bus Emulator..." -ForegroundColor Cyan

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$servicebusPath = Join-Path $scriptPath "servicebus"

Push-Location $servicebusPath

try {
    docker-compose down
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Service Bus Emulator stopped successfully!" -ForegroundColor Green
    } else {
        Write-Host "Failed to stop Service Bus Emulator" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}
