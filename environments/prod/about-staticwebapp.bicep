@description('Name of the static web app')
param name string = 'about-sportdeets'

@description('Location for the static web app')
param location string = 'eastus2'

@description('SKU for the static web app')
@allowed([
  'Free'
  'Standard'
])
param sku string = 'Free'

@description('Environment tag')
param environment string = 'prod'

@description('Repository URL')
param repositoryUrl string = 'https://github.com/jrandallsexton/sports-data'

@description('Branch to deploy from')
param branch string = 'main'

resource staticWebApp 'Microsoft.Web/staticSites@2023-12-01' = {
  name: name
  location: location
  tags: {
    environment: environment
  }
  sku: {
    name: sku
    tier: sku
  }
  properties: {
    repositoryUrl: repositoryUrl
    branch: branch
    buildProperties: {
      appLocation: '/src/about'
      apiLocation: ''
      outputLocation: 'build'
    }
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
    provider: 'GitHub'
  }
}

@description('The default hostname of the static web app')
output defaultHostname string = staticWebApp.properties.defaultHostname

@description('The resource ID of the static web app')
output staticWebAppId string = staticWebApp.id

@description('The deployment token for GitHub Actions')
@secure()
output deploymentToken string = staticWebApp.listSecrets().properties.apiKey
