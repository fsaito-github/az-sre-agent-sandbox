# Discovery Procedures

How to discover and inventory workloads in any Azure environment.
Run these procedures BEFORE analyzing any Advisor recommendation.

---

## Step 1: Detect the environment profile

| Profile | How to detect | Discovery tools |
|---------|--------------|-----------------|
| **A — Kubernetes + Azure** | AKS resource exists, `kubectl` works | kubectl, az cli, KQL |
| **B — Azure PaaS (no K8s)** | No AKS, resources are App Service/VMs/Functions/DBs | az cli, KQL |
| **C — Hybrid** | AKS exists AND PaaS resources exist alongside it | kubectl + az cli + KQL |
| **D — Partially observable** | Some commands fail or return empty | Use what works, note gaps |

**Detection commands:**
```bash
kubectl cluster-info 2>/dev/null && echo "KUBERNETES: YES" || echo "KUBERNETES: NO"
az resource list --resource-group <rg> --query "[].type" -o tsv | sort -u
```

If kubectl fails → Profile B.
If kubectl works AND non-AKS resources exist → Profile C.
If both fail partially → Profile D (note what you could not verify).

---

## Profile A — Kubernetes (AKS)

```bash
# 1. Discover ALL namespaces with workloads (do NOT assume a namespace)
kubectl get pods --all-namespaces --no-headers | awk '{print $1}' | sort -u

# 2. For EACH namespace with application workloads:
kubectl get pods -n <ns> -o wide
kubectl get svc -n <ns>
kubectl get pvc -n <ns>
kubectl get pdb -n <ns> 2>/dev/null
kubectl get statefulsets -n <ns> 2>/dev/null
kubectl get daemonsets -n <ns> 2>/dev/null
kubectl get hpa -n <ns> 2>/dev/null
kubectl get ingress -n <ns> 2>/dev/null
kubectl get networkpolicy -n <ns> 2>/dev/null

# 3. Security posture per container
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    name = pod['metadata']['name']
    for c in pod['spec'].get('containers', []):
        sc = c.get('securityContext', {})
        img = c.get('image', 'unknown')
        res = c.get('resources', {})
        print(f'{name}/{c[\"name\"]}: image={img} runAsNonRoot={sc.get(\"runAsNonRoot\",\"NOT SET\")} readOnlyRootFs={sc.get(\"readOnlyRootFilesystem\",\"NOT SET\")} limits={res.get(\"limits\",\"NOT SET\")}')
"

# 4. Cluster-level
kubectl get nodes -o wide
kubectl top nodes 2>/dev/null
```

---

## Profile B — Azure PaaS

```bash
# List all resources in the resource group
az resource list --resource-group <rg> -o table

# App Services — details with SKU, state, health, deployment slots
az webapp list --resource-group <rg> \
  --query "[].{name:name, state:state, kind:kind, defaultHostName:defaultHostName}" -o table 2>/dev/null
az webapp show --name <app> --resource-group <rg> \
  --query "{state:state, alwaysOn:siteConfig.alwaysOn, healthCheck:siteConfig.healthCheckPath, httpsOnly:httpsOnly, vnetIntegration:virtualNetworkSubnetId}" -o json 2>/dev/null
az webapp deployment slot list --name <app> --resource-group <rg> -o table 2>/dev/null

# App Service Plans — SKU, scaling
az appservice plan list --resource-group <rg> \
  --query "[].{name:name, sku:sku.name, tier:sku.tier, workers:sku.capacity, maxWorkers:maximumElasticWorkerCount}" -o table 2>/dev/null

# Function Apps
az functionapp list --resource-group <rg> \
  --query "[].{name:name, state:state, kind:kind}" -o table 2>/dev/null

# VMs
az vm list --resource-group <rg> \
  --query "[].{name:name, size:hardwareProfile.vmSize, os:storageProfile.osDisk.osType}" -o table 2>/dev/null

# SQL Databases
az sql server list --resource-group <rg> \
  --query "[].{name:name, fqdn:fullyQualifiedDomainName}" -o table 2>/dev/null
# For each server:
# az sql db list --server <server> --resource-group <rg> \
#   --query "[].{name:name, sku:currentSku.name, tier:currentSku.tier, maxSize:maxSizeBytes, zoneRedundant:zoneRedundant}" -o table

# Cosmos DB
az cosmosdb list --resource-group <rg> \
  --query "[].{name:name, kind:kind, locations:locations[0].locationName}" -o table 2>/dev/null

# Redis Cache
az redis list --resource-group <rg> \
  --query "[].{name:name, sku:sku.name, capacity:sku.capacity}" -o table 2>/dev/null

# Storage Accounts
az storage account list --resource-group <rg> \
  --query "[].{name:name, sku:sku.name, kind:kind, accessTier:accessTier}" -o table 2>/dev/null

# Service Bus / Event Hubs
az servicebus namespace list --resource-group <rg> \
  --query "[].{name:name, sku:sku.name}" -o table 2>/dev/null
az eventhubs namespace list --resource-group <rg> \
  --query "[].{name:name, sku:sku.name}" -o table 2>/dev/null

# Networking
az network private-endpoint list --resource-group <rg> -o table 2>/dev/null
```

---

## Profile C — Hybrid

Run BOTH Profile A and Profile B commands.

---

## Profile D — Partially observable

Run all commands from Profiles A and B. For each command that fails, record:
- What you tried
- What failed
- What this means for your analysis confidence

Add a **⚠️ CONFIDENCE NOTE** to your report listing what you could not verify.

---

## Workload Classification

After discovery, classify every workload:

| Role | How to detect | Impact priority |
|------|--------------|-----------------|
| **Customer-facing** | LoadBalancer, Ingress, public App Service, public IP | 🔴 Highest |
| **Internal API** | ClusterIP service, private App Service, internal LB | 🟠 High |
| **Data store** | StatefulSet, PVC, managed DB (SQL/Cosmos/Redis), storage account | 🔴 Highest (data risk) |
| **Message broker** | Image contains rabbitmq/kafka/servicebus, queue-related env vars | 🟠 High (data loss risk) |
| **Batch/Job** | CronJob, Job, Function App with timer trigger | 🟡 Medium |
| **Observability** | Prometheus, Grafana, log collectors, Application Insights agent | 🟢 Low |
| **Load generator** | Synthetic traffic, test workloads | 🟢 Lowest |

**K8s shortcuts:**
- `kubectl get svc` → LoadBalancer/NodePort = customer-facing
- `kubectl get ingress` → Ingress = customer-facing
- StatefulSet or PVC = data store
- DaemonSet = observability/networking agent

**PaaS shortcuts:**
- App Service with custom domain/public endpoint = customer-facing
- Azure SQL / Cosmos DB / Redis Cache = data store
- Service Bus / Event Hub = message broker
- Function App with timer trigger = batch
