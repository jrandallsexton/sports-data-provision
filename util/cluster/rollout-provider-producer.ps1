# Force a rolling restart of Provider and Producer deployments
# Usage:
#   .\rollout-provider-producer.ps1                           # All sports
#   .\rollout-provider-producer.ps1 -Mode football-nfl        # NFL only
#   .\rollout-provider-producer.ps1 -Mode football-ncaa       # NCAA only

param(
    [string]$Mode = "",
    [string]$Context = "nuc",
    [string]$Namespace = "default"
)

# Discover deployments matching the mode filter
$filter = if ($Mode) { "provider-$Mode|producer-$Mode" } else { "provider-football|producer-football" }

$deployments = kubectl get deployments -n $Namespace --context=$Context -o name 2>&1 |
    Where-Object { $_ -match $filter } |
    ForEach-Object { $_ -replace "deployment.apps/", "" } |
    Sort-Object

if ($deployments.Count -eq 0) {
    Write-Host "No deployments found matching filter: $filter" -ForegroundColor Yellow
    exit 0
}

$modeDisplay = if ($Mode) { $Mode } else { "all sports" }
Write-Host "Forcing rollout restart for $($deployments.Count) deployments ($modeDisplay)..." -ForegroundColor Cyan
Write-Host ""

$allSucceeded = $true

foreach ($deployment in $deployments) {
    Write-Host "  Restarting $deployment..." -ForegroundColor Yellow
    kubectl rollout restart deployment/$deployment -n $Namespace --context=$Context 2>&1 | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "    Failed" -ForegroundColor Red
        $allSucceeded = $false
    } else {
        Write-Host "    Triggered" -ForegroundColor Green
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
