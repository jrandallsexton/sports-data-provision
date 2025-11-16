# Create Federated Credential for Workload Identity
# This links the Kubernetes service account to the Azure Managed Identity

$resourceGroup = "rg-sportDeets-prod"
$clusterName = "sportdeets-k3s-prod"
$managedIdentityName = "id-sportdeets-workload"
$serviceAccountNamespace = "default"
$serviceAccountName = "sportdeets-workload-identity"
$federatedCredentialName = "sportdeets-k3s-prod-default-sa"

Write-Host "Getting OIDC issuer URL from Arc cluster..." -ForegroundColor Yellow
$oidcIssuer = az connectedk8s show `
    --name $clusterName `
    --resource-group $resourceGroup `
    --query "oidcIssuerProfile.issuerUrl" `
    -o tsv

if ([string]::IsNullOrEmpty($oidcIssuer)) {
    Write-Host "Error: OIDC issuer not found. Arc cluster may need additional configuration." -ForegroundColor Red
    Write-Host "For k3s clusters, you may need to manually configure the OIDC issuer." -ForegroundColor Yellow
    Write-Host "Using fallback approach with cluster's internal OIDC..." -ForegroundColor Yellow
    
    # For k3s, we'll use a different approach - get the service account issuer from the cluster
    $oidcIssuer = kubectl get --raw /.well-known/openid-configuration | ConvertFrom-Json | Select-Object -ExpandProperty issuer
    Write-Host "Found cluster OIDC issuer: $oidcIssuer" -ForegroundColor Cyan
}

Write-Host "OIDC Issuer: $oidcIssuer" -ForegroundColor Cyan
Write-Host ""

Write-Host "Creating federated credential..." -ForegroundColor Yellow
az identity federated-credential create `
    --name $federatedCredentialName `
    --identity-name $managedIdentityName `
    --resource-group $resourceGroup `
    --issuer $oidcIssuer `
    --subject "system:serviceaccount:${serviceAccountNamespace}:${serviceAccountName}" `
    --audience "api://AzureADTokenExchange"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Federated credential created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Details:" -ForegroundColor Cyan
    Write-Host "  Managed Identity: $managedIdentityName" -ForegroundColor Gray
    Write-Host "  Service Account: $serviceAccountNamespace/$serviceAccountName" -ForegroundColor Gray
    Write-Host "  OIDC Issuer: $oidcIssuer" -ForegroundColor Gray
} else {
    Write-Host "Failed to create federated credential." -ForegroundColor Red
}
