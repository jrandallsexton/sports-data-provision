# Force a rolling restart of Provider and Producer deployments
# Usage: .\rollout-provider-producer.ps1 [-Mode FootballNcaa] [-Context nuc]

param(
    [string]$Mode = "football-ncaa",
    [string]$Context = "nuc",
    [string]$Namespace = "default"
)

$deployments = @(
    "provider-$Mode",
    "producer-$Mode"
)

Write-Host "Forcing rollout restart for Provider and Producer (mode: $Mode)..." -ForegroundColor Cyan
Write-Host ""

$allSucceeded = $true

foreach ($deployment in $deployments) {
    Write-Host "Restarting $deployment..." -ForegroundColor Yellow
    kubectl rollout restart deployment/$deployment -n $Namespace --context=$Context

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Failed to restart $deployment" -ForegroundColor Red
        $allSucceeded = $false
    } else {
        Write-Host "  Restart triggered for $deployment" -ForegroundColor Green
    }
}

if (-not $allSucceeded) {
    Write-Host ""
    Write-Host "One or more restarts failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Watching rollout status (Ctrl+C to stop)..." -ForegroundColor Yellow
Write-Host ""

$jobs = $deployments | ForEach-Object {
    $dep = $_
    Start-Job -ScriptBlock {
        kubectl rollout status deployment/$using:dep -n $using:Namespace --context=$using:Context --timeout=120s 2>&1
    }
}

$jobs | ForEach-Object {
    $result = Receive-Job -Job $_ -Wait
    Write-Host $result
}

$jobs | Remove-Job
