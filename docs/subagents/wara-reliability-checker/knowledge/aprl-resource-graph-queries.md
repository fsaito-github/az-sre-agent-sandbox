# APRL Resource Graph Queries

Azure Resource Graph queries from the Azure Proactive Resiliency Library (APRL).
Each query returns resources that are NOT compliant with reliability best practices.
Empty result = compliant (pass).

Source: https://github.com/Azure/Azure-Proactive-Resiliency-Library-v2

---

## How to run ARG queries

```bash
az graph query -q "<QUERY>" --subscriptions <sub-id> -o json
```

If `az graph` is not available, use the REST API:
```bash
az rest --method post \
  --url "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01" \
  --body '{"subscriptions":["<sub-id>"],"query":"<QUERY>"}'
```

---

## Virtual Machines

### VMs without Availability Zone
```kql
resources
| where type =~ "microsoft.compute/virtualmachines"
| where isnull(zones) or array_length(zones) == 0
| project recommendationId="vm-no-az", name, id, resourceGroup, location
```

### VMs without managed disks
```kql
resources
| where type =~ "microsoft.compute/virtualmachines"
| where properties.storageProfile.osDisk.managedDisk == ""
| project recommendationId="vm-unmanaged-disk", name, id, resourceGroup
```

### VMs without backup configured
```kql
resources
| where type =~ "microsoft.compute/virtualmachines"
| where isnull(properties.storageProfile.osDisk.managedDisk.id) == false
| join kind=leftouter (
    recoveryservicesresources
    | where type =~ "microsoft.recoveryservices/vaults/backupfabrics/protectioncontainers/protecteditems"
    | extend vmId = tolower(properties.sourceResourceId)
    | project vmId
) on $left.id == $right.vmId
| where isempty(vmId)
| project recommendationId="vm-no-backup", name, id, resourceGroup
```

---

## AKS (Azure Kubernetes Service)

### AKS cluster without availability zones
```kql
resources
| where type =~ "microsoft.containerservice/managedclusters"
| mv-expand agentPool = properties.agentPoolProfiles
| where isnull(agentPool.availabilityZones) or array_length(agentPool.availabilityZones) == 0
| project recommendationId="aks-no-az", name, id, resourceGroup, poolName=agentPool.name
```

### AKS cluster with single node pool
```kql
resources
| where type =~ "microsoft.containerservice/managedclusters"
| mv-expand agentPool = properties.agentPoolProfiles
| where agentPool['count'] < 2
| project recommendationId="aks-single-node", name, id, resourceGroup, poolName=agentPool.name, count=agentPool['count']
```

### AKS without auto-upgrade
```kql
resources
| where type =~ "microsoft.containerservice/managedclusters"
| where isnull(properties.autoUpgradeProfile.upgradeChannel) or properties.autoUpgradeProfile.upgradeChannel == "none"
| project recommendationId="aks-no-autoupgrade", name, id, resourceGroup
```

---

## SQL Databases

### SQL without geo-replication
```kql
resources
| where type =~ "microsoft.sql/servers/databases"
| where name != "master"
| where isnull(properties.secondaryType)
| project recommendationId="sql-no-georep", name, id, resourceGroup
```

### SQL without zone redundancy
```kql
resources
| where type =~ "microsoft.sql/servers/databases"
| where name != "master"
| where properties.zoneRedundant == false
| project recommendationId="sql-no-zr", name, id, resourceGroup
```

### SQL without auditing
```kql
resources
| where type =~ "microsoft.sql/servers"
| join kind=leftouter (
    resources
    | where type =~ "microsoft.sql/servers/auditingsettings"
    | where properties.state =~ "Enabled"
    | project serverId = tostring(split(id, "/auditingSettings")[0])
) on $left.id == $right.serverId
| where isempty(serverId)
| project recommendationId="sql-no-audit", name, id, resourceGroup
```

---

## Storage Accounts

### Storage without zone redundancy (LRS)
```kql
resources
| where type =~ "microsoft.storage/storageaccounts"
| where sku.name in ("Standard_LRS", "Premium_LRS")
| project recommendationId="storage-lrs", name, id, resourceGroup, sku=sku.name
```

### Storage without soft delete for blobs
```kql
resources
| where type =~ "microsoft.storage/storageaccounts"
| where isnull(properties.deleteRetentionPolicy) or properties.deleteRetentionPolicy.enabled == false
| project recommendationId="storage-no-softdelete", name, id, resourceGroup
```

---

## App Service

### App Service without minimum 2 instances
```kql
resources
| where type =~ "microsoft.web/serverfarms"
| where sku.capacity < 2
| project recommendationId="appsvc-single-instance", name, id, resourceGroup, sku=sku.name, instances=sku.capacity
```

### App Service without zone redundancy
```kql
resources
| where type =~ "microsoft.web/serverfarms"
| where properties.zoneRedundant == false or isnull(properties.zoneRedundant)
| project recommendationId="appsvc-no-zr", name, id, resourceGroup, sku=sku.name
```

### App Service without health check
```kql
resources
| where type =~ "microsoft.web/sites"
| where isnull(properties.siteConfig.healthCheckPath) or properties.siteConfig.healthCheckPath == ""
| project recommendationId="appsvc-no-healthcheck", name, id, resourceGroup
```

---

## Key Vault

### Key Vault without soft delete
```kql
resources
| where type =~ "microsoft.keyvault/vaults"
| where properties.enableSoftDelete == false or isnull(properties.enableSoftDelete)
| project recommendationId="kv-no-softdelete", name, id, resourceGroup
```

### Key Vault without purge protection
```kql
resources
| where type =~ "microsoft.keyvault/vaults"
| where properties.enablePurgeProtection == false or isnull(properties.enablePurgeProtection)
| project recommendationId="kv-no-purge", name, id, resourceGroup
```

---

## Load Balancer

### Standard LB without zone redundancy
```kql
resources
| where type =~ "microsoft.network/loadbalancers"
| where sku.name =~ "Standard"
| mv-expand fip = properties.frontendIPConfigurations
| where isnull(fip.zones) or array_length(fip.zones) < 3
| project recommendationId="lb-no-zr", name, id, resourceGroup
```

---

## Public IP

### Public IP using Basic SKU
```kql
resources
| where type =~ "microsoft.network/publicipaddresses"
| where sku.name =~ "Basic"
| project recommendationId="pip-basic-sku", name, id, resourceGroup
```

---

## Application Gateway

### App Gateway without zone redundancy
```kql
resources
| where type =~ "microsoft.network/applicationgateways"
| where isnull(zones) or array_length(zones) < 2
| project recommendationId="appgw-no-zr", name, id, resourceGroup
```

---

## Azure Firewall

### Firewall without availability zones
```kql
resources
| where type =~ "microsoft.network/azurefirewalls"
| where isnull(zones) or array_length(zones) < 2
| project recommendationId="fw-no-az", name, id, resourceGroup
```

---

## Cosmos DB

### Cosmos DB without multi-region
```kql
resources
| where type =~ "microsoft.documentdb/databaseaccounts"
| where array_length(properties.locations) < 2
| project recommendationId="cosmos-single-region", name, id, resourceGroup
```

---

## Redis Cache

### Redis without zone redundancy
```kql
resources
| where type =~ "microsoft.cache/redis"
| where isnull(zones) or array_length(zones) == 0
| project recommendationId="redis-no-zr", name, id, resourceGroup, sku=properties.sku.name
```

---

## Service Health Alerts

### No Service Health alert configured
```kql
resources
| where type =~ "microsoft.insights/activitylogalerts"
| where properties.condition.allOf has "ServiceHealth"
| project id
| summarize alertCount = count()
| where alertCount == 0
| project recommendationId="no-servicehealth-alert", note="No Service Health alerts configured in this subscription"
```

---

## Notes

- Empty query result = resource is COMPLIANT (pass)
- Non-empty result = resources that need remediation (finding)
- Combine multiple queries in a single `az graph query` call when possible
- For large environments, use pagination: `--first 1000 --skip N`
- APRL source: https://azure.github.io/Azure-Proactive-Resiliency-Library-v2/
