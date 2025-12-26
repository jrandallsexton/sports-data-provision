// Front Door Custom Domain for api-int.sportdeets.com
// This exposes the internal k3s API for APIM backend access

param frontDoorProfileName string = 'fd-sportdeets'
param customDomainName string = 'api-int-sportdeets-com'
param hostname string = 'api-int.sportdeets.com'
param originGroupName string = 'homelab-cluster'
param endpointName string = 'default'

// Reference existing Front Door profile
resource frontDoorProfile 'Microsoft.Cdn/profiles@2024-02-01' existing = {
  name: frontDoorProfileName
}

// Reference existing endpoint
resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' existing = {
  parent: frontDoorProfile
  name: endpointName
}

// Reference existing origin group (homelab k3s cluster)
resource originGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' existing = {
  parent: frontDoorProfile
  name: originGroupName
}

// Reference existing wildcard certificate
resource secret 'Microsoft.Cdn/profiles/secrets@2024-02-01' existing = {
  parent: frontDoorProfile
  name: 'sportsdataweb-sportdeetssslissued-latest'
}

// Create custom domain for api-int.sportdeets.com
resource customDomain 'Microsoft.Cdn/profiles/customDomains@2024-02-01' = {
  parent: frontDoorProfile
  name: customDomainName
  properties: {
    hostName: hostname
    tlsSettings: {
      certificateType: 'CustomerCertificate'
      minimumTlsVersion: 'TLS12'
      secret: {
        id: secret.id
      }
    }
  }
}

// Create route for api-int.sportdeets.com
resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: endpoint
  name: 'api-internal-route'
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
    forwardingProtocol: 'HttpOnly'
    linkToDefaultDomain: 'Disabled'  // Don't link to default domain to avoid conflict
    httpsRedirect: 'Enabled'  // APIM requires HTTPS; Front Door terminates TLS and forwards HTTP to k3s
  }
}

output customDomainId string = customDomain.id
output customDomainName string = customDomain.properties.hostName
output routeId string = route.id
output domainValidationState string = customDomain.properties.domainValidationState
