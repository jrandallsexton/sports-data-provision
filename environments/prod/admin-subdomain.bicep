@description('Front Door resource name')
param frontDoorName string = 'fd-sportdeets'

@description('Custom domain hostname')
param customDomainName string = 'admin.sportdeets.com'

@description('Endpoint name')
param endpointName string = 'default'

@description('Origin group name')
param originGroupName string = 'homelab-cluster'

resource frontDoor 'Microsoft.Cdn/profiles@2024-02-01' existing = {
  name: frontDoorName
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' existing = {
  parent: frontDoor
  name: endpointName
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' existing = {
  parent: frontDoor
  name: originGroupName
}

resource customDomain 'Microsoft.Cdn/profiles/customDomains@2024-02-01' = {
  parent: frontDoor
  name: replace(customDomainName, '.', '-')
  properties: {
    hostName: customDomainName
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      secret: {
        id: resourceId('Microsoft.Cdn/profiles/secrets', frontDoorName, 'sportsdataweb-sportdeetssslissued-latest')
      }
    }
  }
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: endpoint
  name: 'admin-route'
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
  }
}

output customDomainId string = customDomain.id
output validationToken string = customDomain.properties.validationProperties.validationToken
output customDomainHostname string = customDomain.properties.hostName
