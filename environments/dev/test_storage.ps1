# Test file
$storageAccounts = @(
    @{ name = "test1"; container = "container1" },
    @{ name = "test2"; container = "container2" }
)

foreach ($entry in $storageAccounts) {
    Write-Host "Processing $($entry.name)"
}

Write-Host "Done" -ForegroundColor Green 