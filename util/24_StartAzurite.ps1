# Start Azurite container for local development
# This provides blob, queue, and table storage emulation

Write-Host "Starting Azurite (Azure Storage Emulator)..." -ForegroundColor Cyan

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$azuritePath = Join-Path $scriptPath "azurite"

Push-Location $azuritePath

try {
    # Check if container is already running
    $running = docker ps --filter "name=azurite-local" --format "{{.Names}}"
    
    if ($running -eq "azurite-local") {
        Write-Host "Azurite is already running" -ForegroundColor Yellow
        Write-Host "`nConnection String:" -ForegroundColor Green
        Write-Host "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;"
    } else {
        # Start container
        docker-compose up -d
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`nAzurite started successfully!" -ForegroundColor Green
            Write-Host "`nEndpoints:" -ForegroundColor Cyan
            Write-Host "  Blob:  http://127.0.0.1:10000" -ForegroundColor White
            Write-Host "  Queue: http://127.0.0.1:10001" -ForegroundColor White
            Write-Host "  Table: http://127.0.0.1:10002" -ForegroundColor White
            Write-Host "`nConnection String:" -ForegroundColor Green
            Write-Host "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://127.0.0.1:10000/devstoreaccount1;QueueEndpoint=http://127.0.0.1:10001/devstoreaccount1;TableEndpoint=http://127.0.0.1:10002/devstoreaccount1;"
        } else {
            Write-Host "Failed to start Azurite" -ForegroundColor Red
            exit 1
        }
    }
} finally {
    Pop-Location
}
