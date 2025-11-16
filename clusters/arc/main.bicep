// Main deployment for Arc-enabled Kubernetes infrastructure
targetScope = 'subscription'

@description('Name of the resource group for Arc resources')
param resourceGroupName string = 'rg-sportDeets-prod'

@description('Name of the managed identity for workload identity')
param managedIdentityName string = 'id-sportdeets-workload'

@description('Location for all resources')
param location string = 'eastus'

@description('Tags to apply to all resources')
param tags object = {
  environment: 'production'
  managedBy: 'bicep'
  project: 'sportdeets'
}

// Deploy resource group
module resourceGroup 'resource-group.bicep' = {
  name: 'deploy-rg-${uniqueString(deployment().name)}'
  params: {
    resourceGroupName: resourceGroupName
    location: location
    tags: tags
  }
}

// Deploy managed identity
module managedIdentity 'managed-identity.bicep' = {
  name: 'deploy-identity-${uniqueString(deployment().name)}'
  scope: az.resourceGroup(resourceGroupName)
  params: {
    managedIdentityName: managedIdentityName
    location: location
    tags: tags
  }
  dependsOn: [
    resourceGroup
  ]
}

output resourceGroupName string = resourceGroup.outputs.resourceGroupName
output managedIdentityName string = managedIdentity.outputs.managedIdentityName
output managedIdentityClientId string = managedIdentity.outputs.managedIdentityClientId
output managedIdentityPrincipalId string = managedIdentity.outputs.managedIdentityPrincipalId
output managedIdentityId string = managedIdentity.outputs.managedIdentityId
