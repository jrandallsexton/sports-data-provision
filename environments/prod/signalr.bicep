@description('Name of the SignalR service')
param signalRName string = 'sportdeets-prod'

@description('Location for the SignalR service')
param location string = 'eastus'

@description('SignalR SKU')
@allowed([
  'Free_F1'
  'Standard_S1'
  'Premium_P1'
])
param skuName string = 'Free_F1'

@description('SignalR capacity (units)')
param capacity int = 1

@description('Service mode for SignalR')
@allowed([
  'Default'
  'Serverless'
  'Classic'
])
param serviceMode string = 'Default'

@description('Environment tag')
param environment string = 'prod'

resource signalR 'Microsoft.SignalRService/signalR@2024-03-01' = {
  name: signalRName
  location: location
  tags: {
    environment: environment
  }
  sku: {
    name: skuName
    capacity: capacity
  }
  kind: 'SignalR'
  properties: {
    features: [
      {
        flag: 'ServiceMode'
        value: serviceMode
      }
    ]
    cors: {
      allowedOrigins: [
        '*'
      ]
    }
    publicNetworkAccess: 'Enabled'
    tls: {
      clientCertEnabled: false
    }
  }
}

@description('SignalR service ID')
output signalRId string = signalR.id

@description('SignalR service name')
output signalRName string = signalR.name

@description('SignalR hostname')
output hostname string = signalR.properties.hostName

@description('Primary connection string')
@secure()
output primaryConnectionString string = signalR.listKeys().primaryConnectionString
