// Resource Group for Azure Arc-enabled Kubernetes cluster
targetScope = 'subscription'

@description('Name of the resource group for Arc resources')
param resourceGroupName string = 'rg-sportDeets-prod'

@description('Location for the resource group')
param location string = 'eastus'

@description('Tags to apply to the resource group')
param tags object = {
  environment: 'production'
  managedBy: 'bicep'
  purpose: 'arc-kubernetes'
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

output resourceGroupName string = resourceGroup.name
output resourceGroupId string = resourceGroup.id
output location string = resourceGroup.location
