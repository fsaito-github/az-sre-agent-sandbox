# PaaS Recommendations Analysis

How to investigate and assess impact of Advisor recommendations
for Azure PaaS resources (App Service, SQL, Redis, Storage, Functions).

---

## App Service Plan resize (scale up: S1 → P1v3, etc.)

**Investigation:**
```bash
az appservice plan show --name <plan> --resource-group <rg> \
  --query "{sku:sku.name, tier:sku.tier, capacity:sku.capacity, kind:kind}" -o json

# Apps on this plan (all affected)
az webapp list --resource-group <rg> \
  --query "[?appServicePlanId.contains(@, '<plan>')].{name:name, state:state}" -o table

# Deployment slots (zero-downtime alternative)
az webapp deployment slot list --name <app> --resource-group <rg> -o table 2>/dev/null
```

**Decision rules:**
- Scale up (SKU change): brief restart ~30s per instance, auto-recovers
- Scale out (add instances): always safe, no restart
- If app has deployment slots: use slot swap for zero-downtime
- Multiple apps on same plan: ALL affected by SKU change
- Downgrading may disable always-on (cold starts)

---

## SQL Database tier change (DTU → vCore, Basic → Standard)

**Investigation:**
```bash
az sql db show --name <db> --server <server> --resource-group <rg> \
  --query "{sku:currentSku.name, tier:currentSku.tier, maxSize:maxSizeBytes, zoneRedundant:zoneRedundant, status:status}" -o json
```

**Decision rules:**
- DTU ↔ vCore: brief connectivity interruption ~30s, data safe
- Tier upgrade (Basic → Standard): usually online, brief pause possible
- Tier downgrade: verify current data size fits target maxSize
- Zone-redundant → non-zone-redundant: availability degradation
- All apps with connection strings to this DB affected during transition

---

## Redis Cache SKU change (Basic → Standard → Premium)

**Investigation:**
```bash
az redis show --name <redis> --resource-group <rg> \
  --query "{sku:sku.name, capacity:sku.capacity, port:port, sslPort:sslPort, replicasPerPrimary:replicasPerPrimary, enableNonSslPort:enableNonSslPort}" -o json
```

**Decision rules:**
- Basic → Standard/Premium: requires NEW instance + data migration
- 🟠 Medium Risk: cache data LOST during migration (unless export/import)
- Standard → Premium (same family): can be done online
- All connecting apps affected during DNS cutover
- If used for sessions/state: data loss = user sessions lost

---

## Storage Account redundancy (LRS → ZRS/GRS)

**Investigation:**
```bash
az storage account show --name <sa> --resource-group <rg> \
  --query "{sku:sku.name, kind:kind, accessTier:accessTier}" -o json
```

**Decision rules:**
- LRS → ZRS: live migration available for most types (no downtime)
- LRS → GRS/RA-GRS: online operation, no downtime
- ZRS → LRS: requires manual data copy (downtime)
- Check what uses this storage: blobs, file shares, table storage
- Blob containers mounted by apps: may see brief latency during transition

---

## Function App plan change (Consumption → Premium / Dedicated)

**Investigation:**
```bash
az functionapp show --name <func> --resource-group <rg> \
  --query "{state:state, kind:kind, planId:appServicePlanId}" -o json
az functionapp function list --name <func> --resource-group <rg> -o table 2>/dev/null
```

**Decision rules:**
- Consumption → Premium: brief cold start, then warm instances
- Premium → Consumption: lose VNet integration, always-ready, large payload
- Dedicated → Consumption: lose long-running execution (>10 min), VNet
- Timer triggers: may miss one execution during transition
- Service Bus/Event Hub triggers: messages buffer, no loss

---

## Supporting resources (ACR, Key Vault, Monitoring)

**Investigation:**
```bash
az acr show --name <acr> --query "{sku:sku.name, adminEnabled:adminUserEnabled}" -o json 2>/dev/null
az keyvault show --name <kv> --query "{softDelete:properties.enableSoftDelete, purgeProtection:properties.enablePurgeProtection}" -o json 2>/dev/null
az storage account show --name <sa> --query "{sku:sku.name, kind:kind, accessTier:accessTier}" -o json 2>/dev/null
```

**General rule:** Changes to supporting resources (ACR SKU, KV settings,
monitoring, storage tier) almost NEVER affect running workloads. Impact is:
- Cost (SKU upgrade = more expensive)
- Future operations (soft delete, purge protection)
- Workloads that restart during operation (rare)
- If resource becomes unreachable (private link misconfiguration) → cascading failure
