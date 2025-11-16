@description('Name of the Service Bus namespace')
param namespaceName string = 'sb-prod-sportdeets'

@description('Location for the Service Bus namespace')
param location string = 'eastus2'

@description('Service Bus SKU')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param sku string = 'Standard'

@description('Enable zone redundancy')
param zoneRedundant bool = true

@description('Environment tag')
param environment string = 'prod'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: namespaceName
  location: location
  tags: {
    environment: environment
  }
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    zoneRedundant: zoneRedundant
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

@description('Service Bus namespace ID')
output namespaceId string = serviceBusNamespace.id

@description('Service Bus namespace name')
output namespaceName string = serviceBusNamespace.name

@description('Service Bus endpoint')
output serviceBusEndpoint string = serviceBusNamespace.properties.serviceBusEndpoint

@description('Primary connection string')
@secure()
output primaryConnectionString string = listKeys('${serviceBusNamespace.id}/AuthorizationRules/RootManageSharedAccessKey', serviceBusNamespace.apiVersion).primaryConnectionString
