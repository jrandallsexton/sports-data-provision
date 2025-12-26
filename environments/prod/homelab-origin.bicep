// Front Door Origin Group for homelab k3s cluster
// This defines the origin that points to your home k3s cluster

param frontDoorProfileName string = 'fd-sportdeets'
param originGroupName string = 'homelab-cluster'
param originName string = 'homelab'
param homelabIp string = '67.7.88.82'
param originHostHeader string = 'api-int.sportdeets.com'

// Reference existing Front Door profile
resource frontDoorProfile 'Microsoft.Cdn/profiles@2024-02-01' existing = {
  name: frontDoorProfileName
}

// Create origin group for homelab k3s cluster
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
      probePath: '/health'
      probeRequestType: 'GET'
      probeProtocol: 'Http'
      probeIntervalInSeconds: 100
    }
    sessionAffinityState: 'Disabled'
  }
}

// Create origin pointing to homelab public IP
resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: originGroup
  name: originName
  properties: {
    hostName: homelabIp
    httpPort: 80
    httpsPort: 443
    originHostHeader: originHostHeader
    priority: 1
    weight: 1000
    enabledState: 'Enabled'
    enforceCertificateNameCheck: false  // IP address, not hostname
  }
}

output originGroupId string = originGroup.id
output originGroupName string = originGroup.name
output originId string = origin.id
output originHostName string = origin.properties.hostName
output originHostHeader string = origin.properties.originHostHeader
