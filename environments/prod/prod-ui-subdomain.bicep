@description('The name of the Azure Front Door profile')
param profileName string = 'fd-sportdeets'

@description('The name of the endpoint to associate with this custom domain')
param endpointName string = 'default'

@description('The origin host for the production UI (Static Web App)')
param originHost string = 'calm-grass-079c5ae0f.3.azurestaticapps.net'

@description('The origin group name')
param originGroupName string = 'prod-ui-origin-group'

// Reference the existing Front Door profile
resource frontDoorProfile 'Microsoft.Cdn/profiles@2024-02-01' existing = {
  name: profileName
}

// Reference the existing endpoint
resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' existing = {
  parent: frontDoorProfile
  name: endpointName
}

// Create origin group for production UI
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
      probePath: '/'
      probeRequestType: 'GET'
      probeProtocol: 'Https'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

// Create origin for the production UI
resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: originGroup
  name: 'prod-ui-origin'
  properties: {
    hostName: originHost
    httpPort: 80
    httpsPort: 443
    originHostHeader: originHost
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
  }
}

// Reference existing custom domains
resource customDomainWww 'Microsoft.Cdn/profiles/customDomains@2024-02-01' existing = {
  parent: frontDoorProfile
  name: 'www-sportdeets-com-a381'
}

resource customDomainRoot 'Microsoft.Cdn/profiles/customDomains@2024-02-01' existing = {
  parent: frontDoorProfile
  name: 'sportdeets-com-eb4e'
}

// Update the default route to point to production UI
resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: endpoint
  name: 'default'
  dependsOn: [
    origin
  ]
  properties: {
    customDomains: [
      {
        id: customDomainWww.id
      }
      {
        id: customDomainRoot.id
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
    linkToDefaultDomain: 'Enabled'
    httpsRedirect: 'Enabled'
    enabledState: 'Enabled'
  }
}

@description('The resource ID of the origin group')
output originGroupId string = originGroup.id

@description('The resource ID of the route')
output routeId string = route.id

@description('The production UI origin hostname')
output originHostname string = originHost
