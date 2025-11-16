# This script creates an Azure Arc resource to connect a Kubernetes cluster to Azure

# Set subscription
az account set --subscription "b6a19542-6917-4cd8-94ad-1db493ec3bc4"

# Register required resource providers (only needs to be done once per subscription)
Write-Host "Registering Azure resource providers..." -ForegroundColor Yellow
az provider register --namespace Microsoft.Kubernetes
az provider register --namespace Microsoft.KubernetesConfiguration  
az provider register --namespace Microsoft.ExtendedLocation

Write-Host "Waiting for provider registration to complete (this may take a few minutes)..." -ForegroundColor Yellow
az provider show --namespace Microsoft.Kubernetes --query "registrationState" -o tsv
az provider show --namespace Microsoft.KubernetesConfiguration --query "registrationState" -o tsv
az provider show --namespace Microsoft.ExtendedLocation --query "registrationState" -o tsv

# Connect cluster to Arc
Write-Host "Connecting cluster to Azure Arc..." -ForegroundColor Cyan
az connectedk8s connect --name "sportdeets-k3s-prod" --resource-group "rg-sportDeets-prod" --location "eastus" --correlation-id "c18ab9d0-685e-48e7-ab55-12588447b0ed" --tags "environment=production env=prod"