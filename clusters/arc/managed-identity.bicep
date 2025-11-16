// Managed Identity for Workload Identity Federation
@description('Name of the managed identity')
param managedIdentityName string = 'id-sportdeets-workload'

@description('Location for the managed identity')
param location string = resourceGroup().location

@description('Tags to apply to the managed identity')
param tags object = {
  environment: 'production'
  managedBy: 'bicep'
  purpose: 'workload-identity'
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
  tags: tags
}

output managedIdentityName string = managedIdentity.name
output managedIdentityClientId string = managedIdentity.properties.clientId
output managedIdentityPrincipalId string = managedIdentity.properties.principalId
output managedIdentityId string = managedIdentity.id
