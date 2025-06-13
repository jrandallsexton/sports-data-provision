# Requires Az.Accounts, Az.Consumption

param (
    [int]$LastNDays = 10
)

# Ensure you're authenticated before continuing
try {
    Get-AzContext | Out-Null
} catch {
    Write-Host "Logging in..." -ForegroundColor Yellow
    Connect-AzAccount | Out-Null
}

$subscriptions = Get-AzSubscription

$endDate = (Get-Date).ToString("yyyy-MM-dd")
$startDate = (Get-Date).AddDays(-$LastNDays).ToString("yyyy-MM-dd")

foreach ($sub in $subscriptions) {
    Write-Host ""
    Write-Host "===== [$($sub.Name)] =====" -ForegroundColor Cyan

    try {
        Set-AzContext -SubscriptionId $sub.Id -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Failed to switch to subscription: $($sub.Name)" -ForegroundColor Red
        continue
    }

    try {
        $usage = Get-AzConsumptionUsageDetail `
            -StartDate $startDate `
            -EndDate $endDate `
            -ErrorAction Stop

        if (-not $usage) {
            Write-Host "No usage data found for last $LastNDays days." -ForegroundColor Yellow
            continue
        }

        $grouped = $usage | Group-Object MeterCategory | Sort-Object Count -Descending

        foreach ($group in $grouped) {
            $sum = ($group.Group | Measure-Object -Property PretaxCost -Sum).Sum
            $formatted = "{0,-40} {1,10:C2}" -f $group.Name, $sum
            Write-Host $formatted
        }

        $total = ($usage | Measure-Object -Property PretaxCost -Sum).Sum
        Write-Host ("`nTotal: {0:C2}" -f $total) -ForegroundColor Green

    } catch {
        Write-Warning "No cost data for $($sub.Name): $_"
    }

    Start-Sleep -Milliseconds 250
}
