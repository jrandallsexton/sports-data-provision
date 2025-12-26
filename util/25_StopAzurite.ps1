# Stop Azurite container

Write-Host "Stopping Azurite..." -ForegroundColor Cyan

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$azuritePath = Join-Path $scriptPath "azurite"

Push-Location $azuritePath

try {
    docker-compose down
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Azurite stopped successfully!" -ForegroundColor Green
    } else {
        Write-Host "Failed to stop Azurite" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}
