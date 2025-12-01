// Azure Storage Account for Production
param location string = 'eastus2'
param storageAccountName string = 'sportdeetssa'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Blob Service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
}

// Container: prompts (anonymous blob access)
resource promptsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'prompts'
  properties: {
    publicAccess: 'Blob'
  }
}

// Container: football-ncaa-athlete-image (private)
resource athleteImageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'football-ncaa-athlete-image'
  properties: {
    publicAccess: 'None'
  }
}

// Container: football-ncaa-athlete-image-2025 (private)
resource athleteImage2025Container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'football-ncaa-athlete-image-2025'
  properties: {
    publicAccess: 'None'
  }
}

// Container: football-ncaa-franchise-logo (private)
resource franchiseLogoContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'football-ncaa-franchise-logo'
  properties: {
    publicAccess: 'None'
  }
}

// Container: football-ncaa-franchise-logo-2025 (private)
resource franchiseLogo2025Container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'football-ncaa-franchise-logo-2025'
  properties: {
    publicAccess: 'None'
  }
}

// Container: football-ncaa-team-by-season-logo-2025 (private)
resource teamBySeasonLogoContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'football-ncaa-team-by-season-logo-2025'
  properties: {
    publicAccess: 'None'
  }
}

// Container: football-ncaa-venue-image (private)
resource venueImageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'football-ncaa-venue-image'
  properties: {
    publicAccess: 'None'
  }
}

// Container: pg-migration (private)
resource pgMigrationContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  parent: blobService
  name: 'pg-migration'
  properties: {
    publicAccess: 'None'
  }
}

output storageAccountName string = storageAccount.name
output storageAccountId string = storageAccount.id
output primaryEndpoints object = storageAccount.properties.primaryEndpoints
