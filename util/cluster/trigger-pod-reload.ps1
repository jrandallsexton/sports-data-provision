# Trigger pod restarts after updating Azure App Configuration
# This updates the reload-trigger ConfigMap, which causes Reloader to restart all pods

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

Write-Host "Triggering pod reload at $timestamp..." -ForegroundColor Cyan

# Create temp patch file
$patchFile = [System.IO.Path]::GetTempFileName()
@"
{"data":{"last-reload":"$timestamp"}}
"@ | Out-File -FilePath $patchFile -Encoding ASCII -NoNewline

kubectl patch configmap reload-trigger -n default --type merge --patch-file $patchFile

Remove-Item $patchFile

if ($LASTEXITCODE -eq 0) {
    Write-Host "Reload triggered successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Watching for pod restarts (Ctrl+C to stop)..." -ForegroundColor Yellow
    Write-Host ""
    
    # Watch pods restart
    kubectl get pods -n default -w
} else {
    Write-Host "Failed to trigger reload" -ForegroundColor Red
    exit 1
}
