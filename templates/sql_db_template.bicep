param serverName string
param dbName string
param location string = 'centralus'
param envTag string = 'dev'
param skuName string = 'GP_S_Gen5'
param skuTier string = 'GeneralPurpose'
param skuFamily string = 'Gen5'
param skuCapacity int = 1
param maxSizeBytes int = 34359738368 // 32 GB
param autoPauseDelay int = 15 // Minimum supported
param minCapacity string = '0.5'
param maintenanceConfigId string = '/subscriptions/a11f8d2b-4f9b-4d85-ac2c-3b8e768cd8e0/providers/Microsoft.Maintenance/publicMaintenanceConfigurations/SQL_Default'
param logAnalyticsWorkspaceId string = '/subscriptions/a11f8d2b-4f9b-4d85-ac2c-3b8e768cd8e0/resourceGroups/DefaultResourceGroup-CUS/providers/Microsoft.OperationalInsights/workspaces/DefaultWorkspace-a11f8d2b-4f9b-4d85-ac2c-3b8e768cd8e0-CUS'

resource database 'Microsoft.Sql/servers/databases@2024-05-01-preview' = {
  name: '${serverName}/${dbName}'
  location: location
  tags: {
    env: envTag
  }
  sku: {
    name: skuName
    tier: skuTier
    family: skuFamily
    capacity: skuCapacity
  }
  kind: 'v12.0,user,vcore,serverless'
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: maxSizeBytes
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    zoneRedundant: false
    readScale: 'Disabled'
    autoPauseDelay: autoPauseDelay
    requestedBackupStorageRedundancy: 'Local'
    minCapacity: json(minCapacity)
    maintenanceConfigurationId: maintenanceConfigId
    isLedgerOn: false
    availabilityZone: 'NoPreference'
  }
}

resource threatProtection 'Microsoft.Sql/servers/databases/advancedThreatProtectionSettings@2024-05-01-preview' = {
  parent: database
  name: 'Default'
  properties: {
    state: 'Disabled'
  }
}

resource auditingPolicy 'Microsoft.Sql/servers/databases/auditingPolicies@2014-04-01' = {
  parent: database
  name: 'Default'
  location: location
  properties: {
    auditingState: 'Disabled'
  }
}

resource auditingSettings 'Microsoft.Sql/servers/databases/auditingSettings@2024-05-01-preview' = {
  parent: database
  name: 'default'
  properties: {
    retentionDays: 0
    isAzureMonitorTargetEnabled: false
    state: 'Disabled'
    storageAccountSubscriptionId: '00000000-0000-0000-0000-000000000000'
  }
}

resource shortTermRetention 'Microsoft.Sql/servers/databases/backupShortTermRetentionPolicies@2024-05-01-preview' = {
  parent: database
  name: 'default'
  properties: {
    retentionDays: 7
    diffBackupIntervalInHours: 12
  }
}

resource extendedAuditing 'Microsoft.Sql/servers/databases/extendedAuditingSettings@2024-05-01-preview' = {
  parent: database
  name: 'default'
  properties: {
    retentionDays: 0
    isAzureMonitorTargetEnabled: false
    state: 'Disabled'
    storageAccountSubscriptionId: '00000000-0000-0000-0000-000000000000'
  }
}

resource geoBackup 'Microsoft.Sql/servers/databases/geoBackupPolicies@2024-05-01-preview' = {
  parent: database
  name: 'Default'
  properties: {
    state: 'Disabled'
  }
}

resource securityAlerts 'Microsoft.Sql/servers/databases/securityAlertPolicies@2024-05-01-preview' = {
  parent: database
  name: 'Default'
  properties: {
    state: 'Disabled'
    disabledAlerts: [ '' ]
    emailAddresses: [ '' ]
    emailAccountAdmins: false
    retentionDays: 0
  }
}

resource vulnerabilityAssessment 'Microsoft.Sql/servers/databases/vulnerabilityAssessments@2024-05-01-preview' = {
  parent: database
  name: 'Default'
  properties: {
    recurringScans: {
      isEnabled: false
      emailSubscriptionAdmins: true
    }
  }
}

resource dbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${serverName}-${dbName}-diagnostics'
  scope: database
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLSecurityAuditEvents'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}
