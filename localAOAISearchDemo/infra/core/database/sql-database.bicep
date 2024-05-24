param sqlAdminLogin string = 'azureuser'
param sqlServerName string

@secure()
param sqlAdminPassword string = newGuid()

param sqlDatabaseName string
param databaseCollation string = 'SQL_Latin1_General_CP1_CI_AS'
param databaseMaxSizeBytes int = 34359738368 // 32 GB
param location string
param tags object = {}

@description('Key Vault ID')
param keyVaultName string = ''

@description('Key Vault ID')
param addKeysToVault bool = false

param principal_id string
param tenant_id string
param principal_name string

resource sqlServer 'Microsoft.Sql/servers@2022-08-01-preview' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: principal_name
      principalType: 'Application'
      sid: principal_id
      tenantId: tenant_id
    }
    version: '12.0'
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-08-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  properties: {
    collation: databaseCollation
    maxSizeBytes: databaseMaxSizeBytes
  }
}

module sqlConnectionStringSecret '../keyvault/keyvault-secret.bicep' = if(addKeysToVault) {
  name: 'sql-secret-connection-string'
  params: {
    keyVaultName: keyVaultName
    secretName: 'SQL-CONNECTION-STRING'
    secretValue: concat('Driver={ODBC Driver 18 for SQL Server};',
     'Server=tcp:',
     sqlServer.properties.fullyQualifiedDomainName, 
     ',1433;Database=', sqlDatabaseName, 
     ';Encrypt=yes;Connection Timeout=30;Authentication=ActiveDirectoryIntegrated')
  }
}

resource sqlAllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2022-05-01-preview' = {
  name: 'AllowAllWindowsAzureIps'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

output sqlServerName string = sqlServer.name
output sqlServerFqdn string = '${sqlServerName}.database.windows.net'
output databaseName string = sqlDatabase.name