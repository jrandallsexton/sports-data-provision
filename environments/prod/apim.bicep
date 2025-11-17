// Azure API Management - Consumption Tier
// Provisions APIM to sit behind Azure Front Door
// APIM proxies requests to internal K3s API (api-int.sportdeets.com)

param location string = 'eastus2'
param apimName string = 'sportdeets-apim'
param publisherEmail string = 'admin@sportdeets.com'
param publisherName string = 'SportDeets'
param backendApiUrl string = 'https://api-int.sportdeets.com'

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
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
resource backend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
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

// API definition
resource api 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apim
  name: 'sportdeets-api'
  properties: {
    displayName: 'SportDeets API'
    description: 'SportDeets production API proxied through APIM'
    path: ''  // No path prefix - API root at /
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    serviceUrl: backendApiUrl
    type: 'http'
  }
}

// Sample operation: GET /swagger/index.html
resource swaggerOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: api
  name: 'get-swagger'
  properties: {
    displayName: 'Get Swagger UI'
    method: 'GET'
    urlTemplate: '/swagger/index.html'
    description: 'Swagger UI endpoint to verify APIM routing'
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: [
          {
            contentType: 'text/html'
          }
        ]
      }
    ]
  }
}

// API policy: Set backend, CORS, rate limiting
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
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
resource unlimitedProduct 'Microsoft.ApiManagement/service/products@2023-05-01-preview' = {
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
resource productApi 'Microsoft.ApiManagement/service/products/apis@2023-05-01-preview' = {
  parent: unlimitedProduct
  name: api.name
}

// Subscription for production UI
resource uiSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-05-01-preview' = {
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
output subscriptionKey string = uiSubscription.listSecrets().primaryKey
output subscriptionId string = uiSubscription.id
output backendUrl string = backend.properties.url
