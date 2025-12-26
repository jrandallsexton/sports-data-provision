# Start Azure Service Bus Emulator for local development

Write-Host "Starting Azure Service Bus Emulator..." -ForegroundColor Cyan

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$servicebusPath = Join-Path $scriptPath "servicebus"

Push-Location $servicebusPath

try {
    # Check if container is already running
    $running = docker ps --filter "name=servicebus-emulator" --format "{{.Names}}"
    
    if ($running -eq "servicebus-emulator") {
        Write-Host "Service Bus Emulator is already running" -ForegroundColor Yellow
        Write-Host "`nConnection String:" -ForegroundColor Green
        Write-Host "Endpoint=sb://localhost;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=<any-key>;UseDevelopmentEmulator=true;"
        Write-Host "`nNote: SharedAccessKey can be any value - not validated by emulator" -ForegroundColor Gray
    } else {
        # Start container
        docker-compose up -d
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nService Bus Emulator started successfully!" -ForegroundColor Green
            Write-Host "`nEndpoint:" -ForegroundColor Cyan
            Write-Host "  AMQP: sb://localhost:5672" -ForegroundColor White
            Write-Host "`nConnection String:" -ForegroundColor Green
            Write-Host "Endpoint=sb://localhost;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=<any-key>;UseDevelopmentEmulator=true;"
            Write-Host "`nNote: SharedAccessKey can be any value - not validated by emulator" -ForegroundColor Gray
        } else {
            Write-Host "Failed to start Service Bus Emulator" -ForegroundColor Red
            exit 1
        }
    }
} finally {
    Pop-Location
}
