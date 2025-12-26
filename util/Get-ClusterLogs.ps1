param(
    [string]$App = "api-all", # K8s deployment/pod label name
    [string]$Namespace = "default",
    [int]$Lines = 50,
    [string]$Filter = ""
)

# Check for kubectl
if (-not (Get-Command "kubectl" -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is not installed or not in PATH."
    return
}

# Find pod
$podName = kubectl get pods -n $Namespace -l app=$App -o jsonpath="{.items[0].metadata.name}"
if (-not $podName) {
    Write-Warning "No running pods found for app label: $App in namespace: $Namespace"
    return
}

Write-Host "Fetching logs from pod: $podName" -ForegroundColor Cyan

if ($Filter) {
    kubectl logs $podName -n $Namespace --tail=$Lines | Select-String -Pattern $Filter
}
else {
    kubectl logs $podName -n $Namespace --tail=$Lines
}
