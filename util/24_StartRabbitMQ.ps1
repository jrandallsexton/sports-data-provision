# Start RabbitMQ container for local development

Write-Host "Starting RabbitMQ..." -ForegroundColor Cyan

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$rmqPath = Join-Path $scriptPath "rabbitmq"

Push-Location $rmqPath

try {
    # Check if container is already running
    $running = docker ps --filter "name=rabbitmq-local" --format "{{.Names}}"
    
    if ($running -eq "rabbitmq-local") {
        Write-Host "RabbitMQ is already running" -ForegroundColor Yellow
        Write-Host "`nManagement UI: http://localhost:15672" -ForegroundColor Green
        Write-Host "Username: sportsdata / Password: local-dev-password" -ForegroundColor Cyan
    } else {
        # Start container
        docker-compose up -d
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nRabbitMQ started successfully!" -ForegroundColor Green
            Write-Host "`nEndpoints:" -ForegroundColor Cyan
            Write-Host "  AMQP:       amqp://localhost:5672" -ForegroundColor White
            Write-Host "  Management: http://localhost:15672" -ForegroundColor White
            Write-Host "`nConnection:" -ForegroundColor Green
            Write-Host "  Host: localhost" -ForegroundColor White
            Write-Host "  Username: sportsdata" -ForegroundColor White
            Write-Host "  Password: local-dev-password" -ForegroundColor White
            Write-Host "`nWaiting for RabbitMQ to be ready..." -ForegroundColor Cyan
            Start-Sleep -Seconds 10
            Write-Host "Ready!" -ForegroundColor Green
        } else {
            Write-Host "Failed to start RabbitMQ" -ForegroundColor Red
            exit 1
        }
    }
} finally {
    Pop-Location
}
