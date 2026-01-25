# Stop RabbitMQ container

Write-Host "Stopping RabbitMQ..." -ForegroundColor Cyan

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rmqPath = Join-Path $scriptPath "rabbitmq"

Push-Location $rmqPath

try {
    docker-compose down
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "RabbitMQ stopped successfully!" -ForegroundColor Green
    } else {
        Write-Host "Failed to stop RabbitMQ" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}
