# Impact Investigation Framework

This document teaches the agent HOW TO INVESTIGATE impact — it does NOT
provide pre-built answers. It works for ANY environment, not just a specific
demo or lab.

Upload to: SRE Agent → Builder → Knowledge Base → Add file

---

## Core Principle

NEVER assume what will break. ALWAYS discover by running commands.
The customer's environment may have configurations that completely change
the impact of any given recommendation.

---

## Step 1: Detect the environment profile

Before running any discovery commands, determine which profile applies:

| Profile | How to detect | Discovery tools |
|---------|--------------|-----------------|
| **A — Kubernetes + Azure** | AKS resource exists, `kubectl` works | kubectl, az cli, KQL |
| **B — Azure PaaS (no K8s)** | No AKS, resources are App Service/VMs/Functions/DBs | az cli, KQL |
| **C — Hybrid** | AKS exists AND PaaS resources exist alongside it | kubectl + az cli + KQL |
| **D — Partially observable** | Some commands fail or return empty | Use what works, note gaps |

**Detection commands:**
```bash
# Check if kubectl is available and connected
kubectl cluster-info 2>/dev/null && echo "KUBERNETES: YES" || echo "KUBERNETES: NO"

# List all resource types in the resource group
az resource list --resource-group <rg> --query "[].type" -o tsv | sort -u
```

If kubectl fails → use Profile B.
If kubectl works AND there are non-AKS resources → use Profile C.
If both fail partially → use Profile D and explicitly note what you could not verify.

---

## Step 2: Discover the environment (MANDATORY before any analysis)

### For Kubernetes workloads (Profiles A and C)

```bash
# 1. Discover ALL namespaces with workloads (do NOT assume a namespace)
kubectl get pods --all-namespaces --no-headers | awk '{print $1}' | sort -u

# 2. For EACH namespace with application workloads:
kubectl get pods -n <ns> -o wide
kubectl get svc -n <ns>
kubectl get pvc -n <ns>
kubectl get pdb -n <ns> 2>/dev/null
kubectl get statefulsets -n <ns> 2>/dev/null
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

### For Azure PaaS workloads (Profiles B and C)

```bash
# List all resources in the resource group
az resource list --resource-group <rg> -o table

# Discover specific resource types
az webapp list --resource-group <rg> -o table 2>/dev/null
az functionapp list --resource-group <rg> -o table 2>/dev/null
az vm list --resource-group <rg> -o table 2>/dev/null
az sql server list --resource-group <rg> -o table 2>/dev/null
az cosmosdb list --resource-group <rg> -o table 2>/dev/null
az redis list --resource-group <rg> -o table 2>/dev/null
az servicebus namespace list --resource-group <rg> -o table 2>/dev/null
az eventhubs namespace list --resource-group <rg> -o table 2>/dev/null
az storage account list --resource-group <rg> -o table 2>/dev/null
```

### For partially observable environments (Profile D)

Run all commands from Profiles A and B. For each command that fails or
returns empty results, record:
- What you tried
- What failed
- What this means for your analysis confidence

Add a **⚠️ CONFIDENCE NOTE** to your report listing what you could not verify.

---

## Step 3: Discover dependencies between workloads

The agent MUST NOT use a static dependency map. It MUST DISCOVER dependencies.

### For Kubernetes workloads

#### Method 1: Environment variables (most reliable)
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    name = pod['metadata'].get('labels', {}).get('app', pod['metadata']['name'])
    for c in pod['spec'].get('containers', []):
        for env in c.get('env', []):
            val = env.get('value', '')
            if any(x in val.lower() for x in ['http://', 'https://', 'amqp://', 'mongodb://', 'redis://', 'postgres://', 'mysql://', 'sqlserver://', 'sb://', ':5432', ':3306', ':6379', ':27017', ':5672', ':9092', ':1433', ':443']):
                print(f'{name} -> {val}')
"
```

#### Method 2: Service endpoints
```bash
kubectl get endpoints -n <ns> -o wide
```

#### Method 3: Logs (if available)
```bash
kubectl logs -n <ns> deploy/<service> --tail=20 2>/dev/null | grep -i "connect\|error\|refused"
```

### For Azure PaaS workloads

```bash
# App Service connection strings and app settings
az webapp config connection-string list --name <app> --resource-group <rg> -o json 2>/dev/null
az webapp config appsettings list --name <app> --resource-group <rg> -o json 2>/dev/null

# Function App settings
az functionapp config appsettings list --name <func> --resource-group <rg> -o json 2>/dev/null

# Private endpoints (indicate network-level dependencies)
az network private-endpoint list --resource-group <rg> -o table 2>/dev/null
```

### How to interpret dependencies

- Service A has env/connection string pointing to B → A depends on B
- Data stores (SQL, MongoDB, Redis, Cosmos DB, PostgreSQL) = most critical
- Message queues (RabbitMQ, Kafka, Service Bus) = usually allow buffering
- If B goes down, A may fail — look for retry/circuit breaker config
- External dependencies (outside the resource group) = note but don't analyze deeply

---

## Step 4: Classify workloads by role

For every discovered workload, assign one of these roles:

| Role | How to detect | Impact priority |
|------|--------------|-----------------|
| **Customer-facing** | LoadBalancer, Ingress, public App Service, public IP | 🔴 Highest |
| **Internal API** | ClusterIP service, private App Service, internal LB | 🟠 High |
| **Data store** | StatefulSet, PVC, managed DB (SQL/Cosmos/Redis), storage account | 🔴 Highest (data risk) |
| **Message broker** | Image contains rabbitmq/kafka/servicebus, queue-related env vars | 🟠 High (data loss risk) |
| **Batch/Job** | CronJob, Job, Function App with timer trigger | 🟡 Medium |
| **Observability** | Prometheus, Grafana, log collectors, Application Insights agent | 🟢 Low |
| **Load generator** | Synthetic traffic, test workloads | 🟢 Lowest |

**Detection shortcuts for Kubernetes:**
- `kubectl get svc -n <ns>` → type LoadBalancer/NodePort = likely customer-facing
- StatefulSet or PVC attached = data store
- Image name contains db/cache/queue keywords = infrastructure component
- No Service object = batch/job or sidecar

**Detection shortcuts for PaaS:**
- App Service with custom domain or public endpoint = customer-facing
- Azure SQL / Cosmos DB / Redis Cache = data store
- Service Bus / Event Hub = message broker
- Function App with timer trigger = batch

---

## Step 5: Analysis framework by recommendation type

### SECURITY recommendations — container hardening

#### "Running as root" / "Read-only rootfs" / "Capabilities"

**Investigation (run for each pod):**
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    for c in pod['spec'].get('containers', []):
        img = c.get('image', '')
        sc = c.get('securityContext', {})
        if sc.get('runAsNonRoot'):
            risk = 'SAFE — already runs non-root'
        elif any(x in img.lower() for x in ['mongo', 'postgres', 'mysql', 'redis', 'rabbitmq', 'kafka', 'elasticsearch', 'nginx', 'memcached', 'cassandra', 'couchdb']):
            risk = 'HIGH RISK — official infra image, likely requires root'
        elif 'bitnami' in img.lower():
            risk = 'SAFE — Bitnami images are designed for non-root'
        else:
            risk = 'MEDIUM — test before applying'
        print(f'{pod[\"metadata\"][\"name\"]}/{c[\"name\"]}: {img} -> {risk}')
"
```

**Decision rules:**
- Image already has `USER` in Dockerfile (bitnami, distroless) → 🟢 Safe
- Official DB/middleware image (mongo, postgres, redis, rabbitmq, nginx) → 🔴 Verify docs
- Custom app container → 🟡 Test in staging
- Already has `runAsNonRoot: true` → ✅ Already compliant, skip

**For read-only rootfs — discover write paths:**
```bash
kubectl exec -n <ns> deploy/<service> -- find / -writable -type d 2>/dev/null | head -20
```

---

#### "Trusted registries" / "Image pull from trusted sources"

**Investigation:**
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
registries = {}
for pod in pods:
    for c in pod['spec'].get('containers', []):
        img = c.get('image', '')
        registry = img.split('/')[0] if '/' in img else 'docker.io'
        registries.setdefault(registry, []).append(img)
for reg, imgs in registries.items():
    trusted = any(x in reg for x in ['.azurecr.io', '.gcr.io', '.ecr.'])
    print(f'{\"✅\" if trusted else \"⚠️\"} {reg}: {len(imgs)} images {\"(trusted)\" if trusted else \"(EXTERNAL)\"}')
    for img in set(imgs):
        print(f'   {img}')
"
```

**Decision rules:**
- Images in customer's ACR → ✅ No action
- Images in docker.io / ghcr.io / quay.io → needs `az acr import`
- Migration impact: rolling update per workload, ~1 min each
- If ACR becomes unavailable after migration: running pods OK, but restarts → ImagePullBackOff

---

#### "Disable API credential automount"

**Investigation:**
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    sa = pod['spec'].get('serviceAccountName', 'default')
    automount = pod['spec'].get('automountServiceAccountToken', True)
    name = pod['metadata']['name']
    if automount:
        print(f'⚠️ {name}: SA={sa}, automount=true — verify if it uses K8s API')
    else:
        print(f'✅ {name}: automount already disabled')
"
```

**Verify if pod uses K8s API:**
```bash
kubectl exec -n <ns> <pod> -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>/dev/null
# If exists AND app needs it (leader election, config discovery) → do NOT disable
# If exists but app does NOT need it → safe to disable
```

---

### NETWORK recommendations

#### "NAT Gateway" / "Private Link" / "Restrict API server"

**Investigation — who makes external calls:**
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    for c in pod['spec'].get('containers', []):
        for env in c.get('env', []):
            val = env.get('value', '')
            if val.startswith('http') and not any(x in val for x in ['localhost', '127.0.0.1', '.svc.cluster']):
                print(f'{pod[\"metadata\"][\"name\"]}: external call -> {val}')
"
```

**For PaaS workloads:**
```bash
# Check VNet integration
az webapp vnet-integration list --name <app> --resource-group <rg> -o table 2>/dev/null

# Check private endpoints
az network private-endpoint list --resource-group <rg> -o table 2>/dev/null
```

**Decision rules:**
- Workloads making ONLY internal calls (ClusterIP, private endpoint) → ✅ No impact from network changes
- Workloads calling external APIs → ⚠️ Affected during cutover
- LoadBalancer / public endpoint services → check if IPs change (clients with allowlists)
- API server restriction → list ALL IPs that run kubectl/CI-CD BEFORE restricting

---

### NODE POOL / COMPUTE recommendations

#### "Add nodes" / "Ephemeral OS disk" / "VM series upgrade" / "Spot nodes"

**Investigation:**
```bash
# PDBs (protect during drain)
kubectl get pdb -n <ns>

# Anti-affinity rules
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    affinity = pod['spec'].get('affinity', {})
    if affinity:
        print(f'{pod[\"metadata\"][\"name\"]}: has affinity rules')
    replicas_owner = pod['metadata'].get('ownerReferences', [{}])[0].get('kind', '')
    print(f'{pod[\"metadata\"][\"name\"]}: controlled by {replicas_owner}')
"

# StatefulSets (more complex to move)
kubectl get statefulsets -n <ns>

# PVCs (persistent data that must be remounted)
kubectl get pvc -n <ns>
```

**For VM-based workloads:**
```bash
az vm list --resource-group <rg> -o table
az vm show --name <vm> --resource-group <rg> --query "{size:hardwareProfile.vmSize, disks:storageProfile.dataDisks[].name}" -o json
```

**Decision rules:**
- Adding nodes → ✅ Always safe (additive)
- Node pool drain:
  - Pods with PVC → slow (PV detach + reattach)
  - StatefulSets → order matters (scale down one at a time)
  - Pods without PDB → all drained at once (availability risk)
  - Pods with PDB → respect minAvailable/maxUnavailable
- Spot nodes → NEVER for StatefulSets or persistent data workloads
- VM resize → depends on whether it requires deallocation

---

### SUPPORTING RESOURCE recommendations

#### Container Registry, Key Vault, Monitoring, Storage

**Quick investigation:**
```bash
# ACR current SKU
az acr show --name <acr> --query "{sku:sku.name, adminEnabled:adminUserEnabled}" -o json 2>/dev/null

# Key Vault settings
az keyvault show --name <kv> --query "{softDelete:properties.enableSoftDelete, purgeProtection:properties.enablePurgeProtection}" -o json 2>/dev/null

# Storage account settings
az storage account show --name <sa> --query "{sku:sku.name, kind:kind, accessTier:accessTier}" -o json 2>/dev/null
```

**General rule:** Changes to supporting resources (ACR SKU, KV settings, monitoring,
storage tier) almost NEVER affect running workloads. Impact is limited to:
- Cost (SKU upgrade = more expensive)
- Future operations (e.g., soft delete changes how secrets are purged)
- Workloads that RESTART during the operation (rare)
- If a supporting resource becomes unreachable due to network changes (private link
  misconfiguration) → cascading failure

---

## Step 6: Build the impact table

After collecting real data (Steps 1-5), build the impact table:

```markdown
| Workload | Role | Replicas | Depends On | During Change | Auto-recovers? | End-user affected? |
```

### How to fill each column:

**Replicas:** From `kubectl get pods` or PaaS scaling config. If >1, rolling
update is possible without downtime.

**Depends On:** Discovered in Step 3. If the dependency is affected, this
workload is also affected.

**During Change:** Use logic:
- Resource change is ADDITIVE (add node, enable feature) → "✅ No impact"
- Resource change requires RESTART of this workload → "⚠️ Restart ~Xs"
- Resource change affects a DEPENDENCY → "❌ Fails until dependency recovers"
- Resource change affects NETWORK and this workload makes outbound calls → "⚠️ Outbound fails"

**Auto-recovers?:**
- Yes: workload restarts and works on its own (deployment controller, App Service auto-heal)
- No: change causes permanent failure state (e.g., incompatible image, broken config)
- Manual: needs operator intervention (e.g., rollback manifest, fix connection string)

**End-user affected?:**
- Check if workload is exposed via LoadBalancer/Ingress/public endpoint (customer-facing)
- If ClusterIP/private only → indirect impact (via dependency chain)
- Quantify: "API returns 503 for ~30s", "uploads fail during migration" — not just "disruption"
- If you CANNOT determine business impact → state "⚠️ Unknown — requires domain context"

---

## Step 7: Identify cascade chains

For each workload that BREAKS (❌):
1. Who depends on this workload? (from Step 3)
2. What happens to dependents? (fails? degrades? queues?)
3. Is there data at risk? (queue loses messages? DB loses writes?)
4. Propagate until you reach the end user

Format:
```
<change applied>
  → <first workload affected> — <behavior>
  → <dependent workloads> — <consequence>
  → <end-user impact>
  → Auto-recovers? <Yes/No> | Manual action? <specific command>
```

---

## Step 8: Handle incomplete information

When you CANNOT fully discover the environment:

1. **State what you know** — list discovered workloads and confirmed dependencies
2. **State what you don't know** — list commands that failed and what data is missing
3. **Adjust confidence** — add a confidence level to your risk classification:
   - High confidence: full discovery completed, all dependencies mapped
   - Medium confidence: most workloads discovered, some dependencies inferred
   - Low confidence: limited discovery, significant gaps
4. **Recommend next steps** — suggest what the operator should verify manually
5. **Never fill gaps with assumptions** — say "unknown" rather than guess
