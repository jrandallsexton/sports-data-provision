# Requires Az.Accounts, Az.Resources

# Ensure you're authenticated before continuing
try {
    Get-AzContext | Out-Null
} catch {
    Write-Host "Logging in..." -ForegroundColor Yellow
    Connect-AzAccount | Out-Null
}

$subscriptions = Get-AzSubscription

foreach ($sub in $subscriptions) {
    Write-Host ""
    Write-Host "===== [$($sub.Name)] =====" -ForegroundColor Cyan

    try {
        Set-AzContext -SubscriptionId $sub.Id -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "Failed to switch to subscription: $($sub.Name)" -ForegroundColor Red
        continue
    }

    $resources = Get-AzResource

    if (-not $resources) {
        Write-Host "No resources found." -ForegroundColor Yellow
        continue
    }

    $grouped = $resources | Group-Object ResourceType | Sort-Object Count -Descending

    foreach ($g in $grouped) {
        Write-Host ("{0,3} x {1}" -f $g.Count, $g.Name)
    }

    Start-Sleep -Milliseconds 250  # Prevents flicker or UI corruption on some terminals
}
