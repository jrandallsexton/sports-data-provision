// Cosmos DB for SQL (Core API) in production
param location string = resourceGroup().location
param cosmosAccountName string
param databaseName string
param enableFreeTier bool = true // Free tier is sufficient for production

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    capabilities: [] // No special APIs like MongoDB or Cassandra
    enableFreeTier: enableFreeTier
  }
}

resource sqlDb 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

resource venueContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: sqlDb
  name: 'Venue'
  properties: {
    resource: {
      id: 'Venue'
      partitionKey: {
        paths: ['/partitionKey']
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
    }
    options: {
      throughput: 400
    }
  }
}

resource franchiseContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: sqlDb
  name: 'Franchise'
  properties: {
    resource: {
      id: 'Franchise'
      partitionKey: {
        paths: ['/partitionKey']
        kind: 'Hash'
      }
    }
    options: {
      autoscaleSettings: {
        maxThroughput: 1000
      }
    }
  }
}

output cosmosAccountName string = cosmosAccount.name
output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output databaseName string = sqlDb.name
