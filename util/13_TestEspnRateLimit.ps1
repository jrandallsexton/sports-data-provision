#!/usr/bin/env pwsh
# ESPN Rate Limit Burst Test
# Tests ESPN API to discover rate limiting behavior

param(
    [int]$TotalRequests = 200,
    [int]$DelayMs = 0,  # 0 = burst test, >0 = controlled rate
    [string]$OutputFolder = ".\rate-limit-tests"
)

$url = "http://sports.core.api.espn.com/v2/sports/football/leagues/college-football/venues?lang=en&limit=999"

Write-Host "ESPN Rate Limit Burst Test" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "URL: $url"
Write-Host "Total Requests: $TotalRequests"
Write-Host "Delay: ${DelayMs}ms"
Write-Host ""
Write-Host "IMPORTANT: Consider using VPN to protect your production IP!" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Press ENTER to start test or Ctrl+C to cancel"

# Create output folder
if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

$results = @()
$startTime = Get-Date
$successCount = 0
$rateLimitCount = 0
$errorCount = 0

Write-Host "Starting burst test..." -ForegroundColor Green
Write-Host ""

for ($i = 1; $i -le $TotalRequests; $i++) {
    $requestStart = Get-Date
    
    try {
        $response = Invoke-WebRequest -Uri $url -Method Get -ErrorAction Stop
        
        $result = [PSCustomObject]@{
            RequestNumber = $i
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
        
        $successCount++
        Write-Host "[$i] ✓ ${($result.StatusCode)} - ${($result.ResponseTimeMs)}ms" -ForegroundColor Green
        
        # Highlight if rate limit headers present
        if ($result.XRateLimitRemaining) {
            Write-Host "    Rate Limit Remaining: $($result.XRateLimitRemaining)" -ForegroundColor Yellow
        }
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        
        $result = [PSCustomObject]@{
            RequestNumber = $i
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
        
        if ($statusCode -eq 429) {
            $rateLimitCount++
            Write-Host "[$i] ⚠ RATE LIMITED (429)" -ForegroundColor Red
            if ($result.RetryAfter) {
                Write-Host "    Retry-After: $($result.RetryAfter)" -ForegroundColor Yellow
            }
        }
        else {
            $errorCount++
            Write-Host "[$i] ✗ ERROR ($statusCode) - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    $results += $result
    
    # Add delay if specified
    if ($DelayMs -gt 0) {
        Start-Sleep -Milliseconds $DelayMs
    }
}

$endTime = Get-Date
$totalDuration = ($endTime - $startTime).TotalSeconds

# Export results
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$csvPath = Join-Path $OutputFolder "espn-rate-limit-test-$timestamp.csv"
$results | Export-Csv -Path $csvPath -NoTypeInformation

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Test Complete!" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Results Summary:" -ForegroundColor White
Write-Host "  Total Requests:     $TotalRequests"
Write-Host "  Total Duration:     $([math]::Round($totalDuration, 2))s"
Write-Host "  Requests/Second:    $([math]::Round($TotalRequests / $totalDuration, 2))"
Write-Host ""
Write-Host "Status Breakdown:" -ForegroundColor White
Write-Host "  Successful (200):   $successCount" -ForegroundColor Green
Write-Host "  Rate Limited (429): $rateLimitCount" -ForegroundColor $(if ($rateLimitCount -gt 0) { "Red" } else { "Green" })
Write-Host "  Other Errors:       $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($successCount -gt 0) {
    $avgResponseTime = ($results | Where-Object StatusCode -eq 200 | Measure-Object ResponseTimeMs -Average).Average
    $minResponseTime = ($results | Where-Object StatusCode -eq 200 | Measure-Object ResponseTimeMs -Minimum).Minimum
    $maxResponseTime = ($results | Where-Object StatusCode -eq 200 | Measure-Object ResponseTimeMs -Maximum).Maximum
    
    Write-Host "Response Times (successful requests):" -ForegroundColor White
    Write-Host "  Average: $([math]::Round($avgResponseTime, 2))ms"
    Write-Host "  Minimum: $([math]::Round($minResponseTime, 2))ms"
    Write-Host "  Maximum: $([math]::Round($maxResponseTime, 2))ms"
    Write-Host ""
}

# Rate limit analysis
if ($rateLimitCount -gt 0) {
    $firstRateLimitRequest = ($results | Where-Object StatusCode -eq 429 | Select-Object -First 1).RequestNumber
    Write-Host "Rate Limit Analysis:" -ForegroundColor Yellow
    Write-Host "  First 429 at request #$firstRateLimitRequest"
    Write-Host "  Estimated limit: ~$($firstRateLimitRequest - 1) requests in $([math]::Round(($results[$firstRateLimitRequest - 2].Timestamp -as [datetime] - $startTime).TotalSeconds, 2))s"
    
    # Check for Retry-After header
    $retryAfter = ($results | Where-Object StatusCode -eq 429 | Select-Object -First 1).RetryAfter
    if ($retryAfter) {
        Write-Host "  Retry-After header: $retryAfter"
    }
}
else {
    Write-Host "No rate limiting detected!" -ForegroundColor Green
    Write-Host "  ESPN may not have rate limits, or limit is > $TotalRequests requests in $([math]::Round($totalDuration, 2))s"
}

Write-Host ""
Write-Host "Detailed results exported to:" -ForegroundColor Cyan
Write-Host "  $csvPath"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Review CSV for patterns (response times, error distribution)"
Write-Host "  2. Run again with -TotalRequests 500 to find higher limits"
Write-Host "  3. Run with -DelayMs 100 to test sustained rate (10 req/sec)"
Write-Host "  4. Check for X-RateLimit-* headers in CSV"
