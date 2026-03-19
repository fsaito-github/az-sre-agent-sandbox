// =============================================================================
// PaaS Test Environment — For validating Advisor Impact Analyzer Profile B
// =============================================================================
// Deploys a minimal PaaS environment to test the agent's ability to discover
// and analyze non-Kubernetes Azure workloads.
//
// Usage:
//   az deployment group create \
//     --resource-group <rg> \
//     --template-file infra/bicep/paas-test/main.bicep \
//     --parameters location=eastus2
//
// Estimated cost: ~$5-10/day (Basic tiers)
// =============================================================================

targetScope = 'resourceGroup'

@description('Azure region for deployment')
param location string = resourceGroup().location

@description('Unique suffix for resource names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Name prefix for resources')
param prefix string = 'paastest'

// =============================================================================
// APP SERVICE PLAN + WEB APP
// =============================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${prefix}-plan-${uniqueSuffix}'
  location: location
  sku: {
    name: 'S1'
    tier: 'Standard'
    capacity: 1
  }
  properties: {
    reserved: true // Linux
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: '${prefix}-web-${uniqueSuffix}'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'NODE|20-lts'
      alwaysOn: true
      healthCheckPath: '/health'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'SQL_CONNECTION_STRING'
          value: 'Server=tcp:${sqlServer.properties.fullyQualifiedDomainName},1433;Database=${sqlDatabase.name};'
        }
        {
          name: 'REDIS_HOST'
          value: '${redisCache.properties.hostName}:${redisCache.properties.sslPort}'
        }
        {
          name: 'STORAGE_ACCOUNT'
          value: storageAccount.properties.primaryEndpoints.blob
        }
      ]
    }
    httpsOnly: true
  }
}

// =============================================================================
// SQL DATABASE
// =============================================================================

resource sqlServer 'Microsoft.Sql/servers@2023-08-01-preview' = {
  name: '${prefix}-sql-${uniqueSuffix}'
  location: location
  properties: {
    administratorLogin: 'sqladmin'
    administratorLoginPassword: 'P@ssw0rd${uniqueSuffix}!'
    minimalTlsVersion: '1.2'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  parent: sqlServer
  name: '${prefix}-db'
  location: location
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
}

// Allow Azure services
resource sqlFirewall 'Microsoft.Sql/servers/firewallRules@2023-08-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// =============================================================================
// REDIS CACHE
// =============================================================================

resource redisCache 'Microsoft.Cache/redis@2024-03-01' = {
  name: '${prefix}-redis-${uniqueSuffix}'
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
  }
}

// =============================================================================
// STORAGE ACCOUNT
// =============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: '${prefix}st${uniqueSuffix}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// =============================================================================
// APPLICATION INSIGHTS + LOG ANALYTICS
// =============================================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${prefix}-logs-${uniqueSuffix}'
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${prefix}-appi-${uniqueSuffix}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// =============================================================================
// OUTPUTS
// =============================================================================

output webAppName string = webApp.name
output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output sqlServerFqdn string = sqlServer.properties.fullyQualifiedDomainName
output sqlDatabaseName string = sqlDatabase.name
output redisCacheHostName string = redisCache.properties.hostName
output storageAccountName string = storageAccount.name
output appInsightsName string = appInsights.name
output logAnalyticsId string = logAnalytics.id
