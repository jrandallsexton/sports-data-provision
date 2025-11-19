// Azure Data Factory for Cosmos DB migration
// This template creates an ADF instance with linked services for dev and prod Cosmos DB
// and a pipeline to copy data from dev to prod

param location string = 'eastus2'
param adfName string = 'adf-sportdeets-migration'
param keyVaultName string = 'sportsdatakv'

// Create Azure Data Factory
resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: adfName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}

// Linked Service for Dev Cosmos DB
resource linkedServiceDevCosmos 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: 'LS_CosmosDB_Dev'
  parent: dataFactory
  properties: {
    type: 'CosmosDb'
    typeProperties: {
      connectionString: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: 'LS_KeyVault'
          type: 'LinkedServiceReference'
        }
        secretName: 'Provider-CosmosConnString-DEV'
      }
    }
  }
  dependsOn: [
    linkedServiceKeyVault
  ]
}

// Linked Service for Prod Cosmos DB
resource linkedServiceProdCosmos 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: 'LS_CosmosDB_Prod'
  parent: dataFactory
  properties: {
    type: 'CosmosDb'
    typeProperties: {
      connectionString: {
        type: 'AzureKeyVaultSecret'
        store: {
          referenceName: 'LS_KeyVault'
          type: 'LinkedServiceReference'
        }
        secretName: 'Provider-CosmosConnString-PROD'
      }
    }
  }
  dependsOn: [
    linkedServiceKeyVault
  ]
}

// Linked Service for Key Vault
resource linkedServiceKeyVault 'Microsoft.DataFactory/factories/linkedServices@2018-06-01' = {
  name: 'LS_KeyVault'
  parent: dataFactory
  properties: {
    type: 'AzureKeyVault'
    typeProperties: {
      baseUrl: 'https://${keyVaultName}${environment().suffixes.keyvaultDns}/'
    }
  }
}

// Dataset for Dev FootballNcaa Container
resource datasetDevFootballNcaa 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'DS_DevFootballNcaa'
  parent: dataFactory
  properties: {
    type: 'CosmosDbSqlApiCollection'
    linkedServiceName: {
      referenceName: linkedServiceDevCosmos.name
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      collectionName: 'FootballNcaa'
    }
  }
}

// Dataset for Prod FootballNcaa Container
resource datasetProdFootballNcaa 'Microsoft.DataFactory/factories/datasets@2018-06-01' = {
  name: 'DS_ProdFootballNcaa'
  parent: dataFactory
  properties: {
    type: 'CosmosDbSqlApiCollection'
    linkedServiceName: {
      referenceName: linkedServiceProdCosmos.name
      type: 'LinkedServiceReference'
    }
    typeProperties: {
      collectionName: 'FootballNcaa'
    }
  }
}

// Pipeline to copy FootballNcaa data
resource pipelineCosmosMigration 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  name: 'PL_CosmosDB_DevToProd_Migration'
  parent: dataFactory
  properties: {
    activities: [
      {
        name: 'Copy_FootballNcaa_Data'
        type: 'Copy'
        typeProperties: {
          source: {
            type: 'CosmosDbSqlApiSource'
            preferredRegions: []
          }
          sink: {
            type: 'CosmosDbSqlApiSink'
            writeBehavior: 'insert'
          }
          enableStaging: false
        }
        inputs: [
          {
            referenceName: datasetDevFootballNcaa.name
            type: 'DatasetReference'
          }
        ]
        outputs: [
          {
            referenceName: datasetProdFootballNcaa.name
            type: 'DatasetReference'
          }
        ]
      }
    ]
  }
}

output dataFactoryName string = dataFactory.name
output dataFactoryId string = dataFactory.id
output dataFactoryPrincipalId string = dataFactory.identity.principalId
output pipelineName string = pipelineCosmosMigration.name
