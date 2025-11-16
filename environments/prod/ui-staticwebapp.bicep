@description('The name of the Static Web App')
param staticWebAppName string = 'sportdeets'

@description('Location for the Static Web App')
param location string = 'eastus2'

@description('SKU for the Static Web App')
@allowed([
  'Free'
  'Standard'
])
param sku string = 'Free'

resource staticWebApp 'Microsoft.Web/staticSites@2023-01-01' = {
  name: staticWebAppName
  location: location
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    repositoryUrl: 'https://github.com/jrandallsexton/sports-data'
    branch: 'main'
    buildProperties: {
      appLocation: '/src/UI/sd-ui'
      apiLocation: ''
      outputLocation: 'dist'
    }
  }
}

@description('The default hostname of the Static Web App')
output defaultHostname string = staticWebApp.properties.defaultHostname

@description('The deployment token for GitHub Actions')
#disable-next-line outputs-should-not-contain-secrets
output deploymentToken string = staticWebApp.listSecrets().properties.apiKey

@description('The resource ID of the Static Web App')
output staticWebAppId string = staticWebApp.id

@description('The name of the Static Web App')
output staticWebAppName string = staticWebApp.name
