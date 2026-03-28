#!/usr/bin/env pwsh
# ESPN Rate Limit Concurrent Test
# Simulates multiple Provider pods hitting ESPN simultaneously

param(
    [int]$ConcurrentWorkers = 10,  # Simulate 10 concurrent workers
    [int]$RequestsPerWorker = 100, # Each worker makes 100 requests
    [int]$DurationSeconds = 0,     # 0 = run until RequestsPerWorker complete, >0 = run for duration
    [string]$OutputFolder = ".\rate-limit-tests"
)

$url = "http://sports.core.api.espn.com/v2/sports/football/leagues/college-football/venues?lang=en&limit=999"

Write-Host "ESPN Concurrent Load Test" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "URL: $url"
Write-Host "Concurrent Workers: $ConcurrentWorkers"
Write-Host "Requests per Worker: $RequestsPerWorker"
Write-Host "Total Target Requests: $($ConcurrentWorkers * $RequestsPerWorker)"
if ($DurationSeconds -gt 0) {
    Write-Host "Duration: ${DurationSeconds}s"
}
Write-Host ""
Write-Host "IMPORTANT: Use VPN to protect your production IP!" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Press ENTER to start concurrent test or Ctrl+C to cancel"

# Create output folder
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

Write-Host "Starting concurrent load test..." -ForegroundColor Green
Write-Host ""

# Script block for each worker
$workerScript = {
    param($WorkerId, $Url, $RequestCount, $DurationSeconds)
    
    $results = @()
    $startTime = Get-Date
    $requestNumber = 0
    
    while ($true) {
        $requestNumber++
        
        # Check stop conditions
        if ($DurationSeconds -gt 0) {
            if (((Get-Date) - $startTime).TotalSeconds -ge $DurationSeconds) {
                break
            }
        }
        else {
            if ($requestNumber -gt $RequestCount) {
                break
            }
        }
        
        $requestStart = Get-Date
        
        try {
            $response = Invoke-WebRequest -Uri $Url -Method Get -ErrorAction Stop
            
            $result = [PSCustomObject]@{
                WorkerId = $WorkerId
                RequestNumber = $requestNumber
                StatusCode = $response.StatusCode
                ResponseTimeMs = [math]::Round(((Get-Date) - $requestStart).TotalMilliseconds, 2)
                ContentLength = $response.Content.Length
                RetryAfter = $response.Headers['Retry-After']
                XRateLimitLimit = $response.Headers['X-RateLimit-Limit']
                XRateLimitRemaining = $response.Headers['X-RateLimit-Remaining']
                XRateLimitReset = $response.Headers['X-RateLimit-Reset']
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                Error = $null
            }
        }
        catch {
            $statusCode = $_.Exception.Response.StatusCode.value__
            
            $result = [PSCustomObject]@{
                WorkerId = $WorkerId
                RequestNumber = $requestNumber
                StatusCode = $statusCode
                ResponseTimeMs = [math]::Round(((Get-Date) - $requestStart).TotalMilliseconds, 2)
                ContentLength = $null
                RetryAfter = $_.Exception.Response.Headers['Retry-After']
                XRateLimitLimit = $_.Exception.Response.Headers['X-RateLimit-Limit']
                XRateLimitRemaining = $_.Exception.Response.Headers['X-RateLimit-Remaining']
                XRateLimitReset = $_.Exception.Response.Headers['X-RateLimit-Reset']
                Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
                Error = $_.Exception.Message
            }
        }
        
        $results += $result
    }
    
    return $results
}

# Start all workers
$jobs = @()
$testStartTime = Get-Date

for ($i = 1; $i -le $ConcurrentWorkers; $i++) {
    Write-Host "Starting Worker $i..." -ForegroundColor Cyan
    $job = Start-Job -ScriptBlock $workerScript -ArgumentList $i, $url, $RequestsPerWorker, $DurationSeconds
    $jobs += $job
}

Write-Host ""
Write-Host "All workers started. Waiting for completion..." -ForegroundColor Yellow
Write-Host ""

# Monitor progress
$lastUpdate = Get-Date
while ($jobs | Where-Object { $_.State -eq 'Running' }) {
    $completedJobs = ($jobs | Where-Object { $_.State -eq 'Completed' }).Count
    $runningJobs = ($jobs | Where-Object { $_.State -eq 'Running' }).Count
    
    if (((Get-Date) - $lastUpdate).TotalSeconds -ge 2) {
        $elapsed = ((Get-Date) - $testStartTime).TotalSeconds
        Write-Host "[${elapsed}s] Workers: $runningJobs running, $completedJobs completed" -ForegroundColor Gray
        $lastUpdate = Get-Date
    }
    
    Start-Sleep -Milliseconds 500
}

$testEndTime = Get-Date
$totalDuration = ($testEndTime - $testStartTime).TotalSeconds

Write-Host ""
Write-Host "Collecting results..." -ForegroundColor Cyan

# Collect all results
$allResults = @()
foreach ($job in $jobs) {
    $jobResults = Receive-Job -Job $job
    $allResults += $jobResults
    Remove-Job -Job $job
}

# Export results
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csvPath = Join-Path $OutputFolder "espn-concurrent-test-$timestamp.csv"
$allResults | Export-Csv -Path $csvPath -NoTypeInformation

# Analysis
$totalRequests = $allResults.Count
$successCount = ($allResults | Where-Object StatusCode -eq 200).Count
$rateLimitCount = ($allResults | Where-Object StatusCode -eq 429).Count
$errorCount = $totalRequests - $successCount - $rateLimitCount

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Concurrent Test Complete!" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test Configuration:" -ForegroundColor White
Write-Host "  Concurrent Workers:  $ConcurrentWorkers"
Write-Host "  Total Requests:      $totalRequests"
Write-Host "  Total Duration:      $([math]::Round($totalDuration, 2))s"
Write-Host "  Aggregate Req/Sec:   $([math]::Round($totalRequests / $totalDuration, 2))" -ForegroundColor Yellow
Write-Host ""
Write-Host "Status Breakdown:" -ForegroundColor White
Write-Host "  Successful (200):    $successCount" -ForegroundColor Green
Write-Host "  Rate Limited (429):  $rateLimitCount" -ForegroundColor $(if ($rateLimitCount -gt 0) { "Red" } else { "Green" })
Write-Host "  Other Errors:        $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($successCount -gt 0) {
    $avgResponseTime = ($allResults | Where-Object StatusCode -eq 200 | Measure-Object ResponseTimeMs -Average).Average
    $minResponseTime = ($allResults | Where-Object StatusCode -eq 200 | Measure-Object ResponseTimeMs -Minimum).Minimum
    $maxResponseTime = ($allResults | Where-Object StatusCode -eq 200 | Measure-Object ResponseTimeMs -Maximum).Maximum
    
    Write-Host "Response Times (successful requests):" -ForegroundColor White
    Write-Host "  Average: $([math]::Round($avgResponseTime, 2))ms"
    Write-Host "  Minimum: $([math]::Round($minResponseTime, 2))ms"
    Write-Host "  Maximum: $([math]::Round($maxResponseTime, 2))ms"
    Write-Host ""
}

# Per-worker breakdown
Write-Host "Per-Worker Statistics:" -ForegroundColor White
for ($i = 1; $i -le $ConcurrentWorkers; $i++) {
    $workerResults = $allResults | Where-Object WorkerId -eq $i
    $workerSuccess = ($workerResults | Where-Object StatusCode -eq 200).Count
    $workerRateLimit = ($workerResults | Where-Object StatusCode -eq 429).Count
    $workerTotal = $workerResults.Count
    
    $status = if ($workerRateLimit -gt 0) { "⚠ RATE LIMITED" } else { "✓" }
    $color = if ($workerRateLimit -gt 0) { "Red" } else { "Green" }
    
    Write-Host "  Worker $i : $workerTotal requests ($workerSuccess success, $workerRateLimit limited) $status" -ForegroundColor $color
}
Write-Host ""

# Rate limit analysis
if ($rateLimitCount -gt 0) {
    $firstRateLimit = $allResults | Where-Object StatusCode -eq 429 | Sort-Object Timestamp | Select-Object -First 1
    Write-Host "Rate Limit Analysis:" -ForegroundColor Yellow
    Write-Host "  First 429 from Worker $($firstRateLimit.WorkerId) at $($firstRateLimit.Timestamp)"
    Write-Host "  Total requests before limit: $(($allResults | Where-Object { ([datetime]$_.Timestamp) -lt ([datetime]$firstRateLimit.Timestamp) }).Count)"
    
    $retryAfter = $firstRateLimit.RetryAfter
    if ($retryAfter) {
        Write-Host "  Retry-After header: $retryAfter"
    }
    
    # Calculate rate when limit hit
    $limitTime = [datetime]$firstRateLimit.Timestamp
    $requestsBeforeLimit = ($allResults | Where-Object { ([datetime]$_.Timestamp) -lt $limitTime }).Count
    $timeToLimit = ($limitTime - $testStartTime).TotalSeconds
    $rateWhenLimited = [math]::Round($requestsBeforeLimit / $timeToLimit, 2)
    
    Write-Host "  Estimated limit: ~$requestsBeforeLimit requests in $([math]::Round($timeToLimit, 2))s (~$rateWhenLimited req/sec)" -ForegroundColor Yellow
}
else {
    Write-Host "No rate limiting detected!" -ForegroundColor Green
    Write-Host "  ESPN handled $totalRequests concurrent requests in $([math]::Round($totalDuration, 2))s" -ForegroundColor Green
    Write-Host "  Aggregate throughput: ~$([math]::Round($totalRequests / $totalDuration, 2)) req/sec" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  ESPN either has no limits or they're higher than this test level." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Detailed results exported to:" -ForegroundColor Cyan
Write-Host "  $csvPath"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Try -ConcurrentWorkers 20 to simulate more Provider pods"
Write-Host "  2. Try -RequestsPerWorker 200 for longer sustained load"
Write-Host "  3. Try -DurationSeconds 60 for time-based test"
Write-Host "  4. Review CSV for per-worker patterns"
