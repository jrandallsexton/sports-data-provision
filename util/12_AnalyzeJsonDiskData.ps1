$path = "D:\Dropbox\Code\sports-data\data\"

# Define size buckets (in bytes)
$buckets = @(
    @{ Label = "<10KB";         Min = 0;            Max = 10 * 1KB },
    @{ Label = "10-50KB";       Min = 10 * 1KB;     Max = 50 * 1KB },
    @{ Label = "50-100KB";      Min = 50 * 1KB;     Max = 100 * 1KB },
    @{ Label = "101-150KB";     Min = 101 * 1KB;    Max = 150 * 1KB },
    @{ Label = "151-200KB";     Min = 151 * 1KB;    Max = 200 * 1KB },
    @{ Label = "201-255KB";     Min = 201 * 1KB;    Max = 255 * 1KB },
    @{ Label = "256KB-1MB";     Min = 256 * 1KB;    Max = 1MB },
    @{ Label = ">1MB";          Min = 1MB;          Max = [int]::MaxValue }
)

# Collect JSON file info
$jsonFiles = Get-ChildItem -Path $path -Recurse -Filter *.json | Select-Object FullName, Length

# Track largest file
$largest = $jsonFiles | Sort-Object Length -Descending | Select-Object -First 1

# Summarize by bucket
$summary = foreach ($bucket in $buckets) {
    $matched = $jsonFiles | Where-Object { $_.Length -ge $bucket.Min -and $_.Length -lt $bucket.Max }
    [PSCustomObject]@{
        Bucket        = $bucket.Label
        FileCount     = $matched.Count
        TotalSizeKB   = [math]::Round(($matched | Measure-Object Length -Sum).Sum / 1KB, 2)
        AvgSizeKB     = if ($matched.Count -gt 0) { [math]::Round(($matched | Measure-Object Length -Average).Average / 1KB, 2) } else { 0 }
    }
}

# Output results
$summary | Format-Table -AutoSize
Write-Host "`nLargest file:`n$($largest.FullName) - $([math]::Round($largest.Length / 1KB, 2)) KB"
