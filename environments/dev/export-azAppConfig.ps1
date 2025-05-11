$labels = @(
  "Development",
  "Development.BaseballMlb",
  "Development.BasketballNba",
  "Development.FootballNcaa",
  "Development.FootballNfl",
  "Development.Golf",
  "Development.GolfPga",
  "Local",
  "Local.FootballNcaa",
  "Local.FootballNfl",
  "Local.GolfPga",
  "LocalDev"
)

$storeName = "sportsdataappconfig"

foreach ($label in $labels) {
    $safeLabel = $label -replace '\.', '_'
    $path = "sportsdataappconfig-$safeLabel.json"

    Write-Host "Exporting $label → $path"
    az appconfig kv export `
        --name $storeName `
        --destination file `
        --path $path `
        --format json `
        --label $label `
        --yes
}
