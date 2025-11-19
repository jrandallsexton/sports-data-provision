// Azure API Management - Consumption Tier
// Provisions APIM to sit behind Azure Front Door
// APIM proxies requests to internal K3s API (api-int.sportdeets.com)

param location string = 'eastus2'
param apimName string = 'sportdeets-apim'
param publisherEmail string = 'admin@sportdeets.com'
param publisherName string = 'SportDeets'
param backendApiUrl string = 'https://api-int.sportdeets.com'

resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: 'Consumption'
    capacity: 0
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// Backend configuration for internal API
resource backend 'Microsoft.ApiManagement/service/backends@2024-06-01-preview' = {
  parent: apim
  name: 'sportdeets-internal-api'
  properties: {
    description: 'Internal K3s API via Traefik'
    url: backendApiUrl
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

// API definition - Import from OpenAPI/Swagger
resource api 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apim
  name: 'sportdeets-api'
  properties: {
    displayName: 'SportDeets API'
    description: 'SportDeets production API proxied through APIM'
    path: ''  // No path prefix - API root at /
    protocols: [
      'https'
    ]
    subscriptionRequired: false
    serviceUrl: backendApiUrl
    type: 'http'
    format: 'openapi+json-link'
    value: '${backendApiUrl}/swagger/v1/swagger.json'
  }
}

// SignalR negotiate endpoint
resource signalrNegotiateOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: api
  name: 'signalr-negotiate'
  properties: {
    displayName: 'SignalR Negotiate'
    method: 'POST'
    urlTemplate: '/hubs/notifications/negotiate'
    description: 'SignalR connection negotiation endpoint'
  }
}

// SignalR hub endpoint - catch all methods
resource signalrHubOperation 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: api
  name: 'signalr-hub'
  properties: {
    displayName: 'SignalR Hub Communication'
    method: '*'
    urlTemplate: '/hubs/notifications'
    description: 'SignalR hub communication endpoint'
  }
}

// API policy: Set backend, CORS, rate limiting
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-06-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    value: '''
      <policies>
        <inbound>
          <base />
          <set-backend-service backend-id="sportdeets-internal-api" />
          <cors allow-credentials="true">
            <allowed-origins>
              <origin>https://sportdeets.com</origin>
              <origin>https://www.sportdeets.com</origin>
            </allowed-origins>
            <allowed-methods>
              <method>GET</method>
              <method>POST</method>
              <method>PUT</method>
              <method>DELETE</method>
              <method>OPTIONS</method>
            </allowed-methods>
            <allowed-headers>
              <header>*</header>
            </allowed-headers>
            <expose-headers>
              <header>*</header>
            </expose-headers>
          </cors>
          <rate-limit calls="1000" renewal-period="60" />
        </inbound>
        <backend>
          <base />
        </backend>
        <outbound>
          <base />
        </outbound>
        <on-error>
          <base />
        </on-error>
      </policies>
    '''
    format: 'xml'
  }
}

// Product: Unlimited (for production use)
resource unlimitedProduct 'Microsoft.ApiManagement/service/products@2024-06-01-preview' = {
  parent: apim
  name: 'unlimited'
  properties: {
    displayName: 'Unlimited'
    description: 'Unlimited access to SportDeets API'
    subscriptionRequired: true
    approvalRequired: false
    state: 'published'
  }
}

// Link API to product
resource productApi 'Microsoft.ApiManagement/service/products/apis@2024-06-01-preview' = {
  parent: unlimitedProduct
  name: api.name
}

// Subscription for production UI
resource uiSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' = {
  parent: apim
  name: 'sportdeets-ui-subscription'
  properties: {
    displayName: 'SportDeets UI Subscription'
    scope: '/products/${unlimitedProduct.id}'
    state: 'active'
  }
}

output apimHostname string = apim.properties.gatewayUrl
output apimResourceId string = apim.id
output apimName string = apim.name
#disable-next-line outputs-should-not-contain-secrets
output subscriptionKey string = uiSubscription.listSecrets().primaryKey
output subscriptionId string = uiSubscription.id
output backendUrl string = backend.properties.url
