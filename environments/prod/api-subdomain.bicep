@description('The name of the Azure Front Door profile')
param profileName string = 'fd-sportdeets'

@description('The hostname for the API custom domain')
param hostname string = 'api.sportdeets.com'

@description('The name of the endpoint to associate with this custom domain')
param endpointName string = 'default'

@description('The APIM hostname')
param apimHostname string = 'sportdeets-apim.azure-api.net'

@description('The origin group name')
param originGroupName string = 'apim-origin-group'

// Reference the existing Front Door profile
resource frontDoorProfile 'Microsoft.Cdn/profiles@2024-02-01' existing = {
  name: profileName
}

// Reference the existing endpoint
resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' existing = {
  parent: frontDoorProfile
  name: endpointName
}

// Create origin group for APIM
resource originGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = {
  parent: frontDoorProfile
  name: originGroupName
  properties: {
    loadBalancingSettings: {
      sampleSize: 4
      successfulSamplesRequired: 3
      additionalLatencyInMilliseconds: 50
    }
    healthProbeSettings: {
      probePath: '/swagger/index.html'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

// Create origin for APIM
resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: originGroup
  name: 'apim-origin'
  properties: {
    hostName: apimHostname
    httpPort: 80
    httpsPort: 443
    originHostHeader: apimHostname
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}

// Create custom domain for api.sportdeets.com
resource customDomain 'Microsoft.Cdn/profiles/customDomains@2024-02-01' = {
  parent: frontDoorProfile
  name: replace(hostname, '.', '-')
  properties: {
    hostName: hostname
    tlsSettings: {
      certificateType: 'ManagedCertificate'
      minimumTlsVersion: 'TLS12'
    }
    azureDnsZone: null
  }
}

// Create route to connect endpoint -> custom domain -> APIM origin group
resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: endpoint
  name: 'api-route'
  dependsOn: [
    origin
  ]
  properties: {
    customDomains: [
      {
        id: customDomain.id
      }
    ]
    originGroup: {
      id: originGroup.id
    }
    supportedProtocols: [
      'Http'
      'Https'
    ]
    patternsToMatch: [
      '/*'
    ]
    forwardingProtocol: 'HttpsOnly'
    linkToDefaultDomain: 'Disabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

@description('The resource ID of the custom domain')
output customDomainId string = customDomain.id

@description('The hostname of the custom domain')
output customDomainHostname string = customDomain.properties.hostName

@description('The validation token for DNS verification')
output validationToken string = customDomain.properties.validationProperties.validationToken

@description('The resource ID of the origin group')
output originGroupId string = originGroup.id

@description('The resource ID of the route')
output routeId string = route.id
