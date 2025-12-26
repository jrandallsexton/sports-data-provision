param(
    [string]$App = "SportsData.Api",
    [int]$Lines = 50,
    [string]$Filter = "*"
)

# Path relative to: c:\Projects\sports-data-provision\util\
# Target: c:\Projects\sports-data\logs\
$logDir = Join-Path $PSScriptRoot "..\..\sports-data\logs"
$logDir = [System.IO.Path]::GetFullPath($logDir)

if (-not (Test-Path $logDir)) {
    Write-Warning "Log directory not found: $logDir"
    return
}

# Matches both:
# - SportsData.Api-20251226.log (Windows/Dev)
# - SportsData.Api-podname-20251226.log (Docker/Cluster)
$filePattern = "$App-*.log"

$latestLog = Get-ChildItem $logDir -Filter $filePattern | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $latestLog) {
    Write-Warning "No log files found matching '$filePattern' in $logDir"
    return
}

Write-Host "Reading log file: $($latestLog.Name)" -ForegroundColor Cyan
Write-Host "Path: $($latestLog.FullName)" -ForegroundColor DarkGray

Get-Content $latestLog.FullName -Tail $Lines | Where-Object { $_ -like $Filter }
