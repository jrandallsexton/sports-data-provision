// Azure API Management - Consumption Tier
// Updates existing APIM configuration
// APIM proxies requests to internal K3s API (api-int.sportdeets.com)
// NOTE: Deploy this to rg-sportDeets resource group

param apimName string = 'sportdeets-apim'
param backendApiUrl string = 'https://api-int.sportdeets.com'

// Reference existing APIM service
resource apim 'Microsoft.ApiManagement/service@2024-06-01-preview' existing = {
  name: apimName
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
          <!-- Global rate limit: 5000 calls per minute (Consumption SKU only supports basic rate-limit) -->
          <rate-limit calls="5000" renewal-period="60" />
        </inbound>
        <backend>
          <base />
        </backend>
        <outbound>
          <base />
          <set-header name="X-RateLimit-Limit" exists-action="override">
            <value>5000</value>
          </set-header>
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

// SignalR negotiate operation (not in Swagger)
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
