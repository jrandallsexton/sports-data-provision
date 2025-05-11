param environment string = 'dev'
param location string = 'East US 2'

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'ASP-rgsportDeets${environment}-b389'
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
    size: 'S1'
    family: 'S'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: true
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
} 
