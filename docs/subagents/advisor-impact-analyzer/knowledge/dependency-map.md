# Pet Store Application — Dependency Map

This document is a knowledge file for the Advisor Impact Analyzer sub-agent.
Upload it to the Azure SRE Agent Knowledge Base (Builder → Knowledge Base → Add file)
so the agent can determine blast radius when analyzing Advisor recommendations.

---

## Azure Resources → Kubernetes Services → Business Impact

### AKS Cluster: aks-srelab

**Resource Group:** rg-srelab-eastus2
**Node Pools:**
- `system` — system node pool (system components, CoreDNS, kube-proxy)
- `user` — application workloads (all pet store pods use `nodeSelector: nodepool-type: user`)

**If AKS cluster is disrupted:**
- ALL services offline
- ALL customer-facing features unavailable
- Blast radius: 🔴 Critical — complete outage

---

### Container Registry: acrsrelabtlwgvg

**Used by:** All application deployments (image pull source)

**Dependency chain:**
```
ACR → image pull → ALL pods in namespace "pets"
```

**If ACR is disrupted:**
- Existing running pods: ✅ Unaffected (images already pulled)
- New pod creation / restarts: ❌ ImagePullBackOff
- Scaling events: ❌ Cannot pull images for new pods
- Blast radius: 🟡 Low (only affects new pod creation, not running workloads)

**Impact on Advisor recommendations:**
- SKU upgrade (Basic→Premium): No impact on running pods
- Geo-replication: No impact on running pods
- Trusted registries policy: Requires migrating image references

---

### Virtual Network: vnet-srelab

**Subnets:**
- `snet-aks` — AKS node subnet
- `snet-services` — Service subnet

**Dependency chain:**
```
VNet → AKS node networking → ALL pod communication
VNet → NAT gateway / Load Balancer → outbound connectivity
VNet → NSGs → network policy enforcement
```

**If VNet/subnet is disrupted:**
- Pod-to-pod communication: ❌ Broken
- External access (LoadBalancer): ❌ Broken
- Blast radius: 🔴 Critical — all network connectivity lost

**Impact on Advisor recommendations:**
- NAT gateway addition: Brief outbound disruption during cutover (~1-5 min)
- NSG changes: May break pod connectivity if rules are too restrictive

---

### Key Vault: kv-srelab-tlwgvg

**Used by:** AKS for secrets management (CSI driver integration)

**Dependency chain:**
```
Key Vault → CSI Secret Store Driver → pods mounting secrets
```

**If Key Vault is disrupted:**
- Existing pods with cached secrets: ✅ Continue running
- Pod restarts / new pods: ❌ Cannot mount secrets
- Blast radius: 🟡 Low (only affects pod startup, not running workloads)

**Impact on Advisor recommendations:**
- Soft delete / purge protection: No impact (setting change only)
- Diagnostic logs: No impact (additive monitoring)

---

### Log Analytics Workspace: log-srelab

**Used by:** AKS diagnostics, Container Insights, alerts

**Dependency chain:**
```
Log Analytics → Container Insights → monitoring dashboards
Log Analytics → Alert rules → incident detection
Log Analytics → SRE Agent → diagnostic queries (KQL)
```

**If Log Analytics is disrupted:**
- Application: ✅ Unaffected (monitoring only)
- Monitoring/Alerts: ❌ Blind — no alerting or diagnostics
- SRE Agent: ⚠️ Degraded — cannot run KQL queries
- Blast radius: 🟡 Low (no app impact, but loses observability)

---

### Application Insights: appi-srelab

**Used by:** Application-level telemetry

**If disrupted:**
- Application: ✅ Unaffected
- Telemetry: ❌ Lost during disruption
- Blast radius: 🟡 Low

---

### Managed Grafana: grafana-srelab-tlwgvg

**Used by:** Dashboards and visualization

**If disrupted:**
- Application: ✅ Unaffected
- Dashboards: ❌ Unavailable
- Blast radius: 🟡 Low

---

### Azure Monitor Workspace (Prometheus): prometheus-srelab

**Used by:** Prometheus metrics collection

**If disrupted:**
- Application: ✅ Unaffected
- Metrics: ❌ Gap in metric collection
- Grafana dashboards: ⚠️ Stale data
- Blast radius: 🟡 Low

---

## Kubernetes Services → Business Functions

### Namespace: pets

```
┌─────────────────────────────────────────────────────────┐
│                    CUSTOMER-FACING                        │
│                                                           │
│  store-front (Vue.js)          store-admin (Vue.js)       │
│  Port: 8080, LB: 80           Port: 8081, LB: 80         │
│  2 replicas                    1 replica                  │
│  External IP: 4.153.127.195   External IP: 128.85.216.177│
│       │                              │                    │
│       ├──→ order-service             ├──→ product-service │
│       └──→ product-service           └──→ makeline-service│
│                                                           │
├───────────────────────────────────────────────────────────┤
│                    PROCESSING LAYER                        │
│                                                           │
│  order-service (Node.js)       product-service (Rust)     │
│  Port: 3000, ClusterIP        Port: 3002, ClusterIP      │
│  2 replicas                    2 replicas                 │
│       │                                                   │
│       └──→ RabbitMQ (queue: "orders")                     │
│                 │                                         │
│                 ↓                                         │
│  makeline-service (Go)                                    │
│  Port: 3001, ClusterIP                                    │
│  2 replicas                                               │
│       │                                                   │
│       └──→ MongoDB (db: "orderdb", collection: "orders")  │
│                                                           │
├───────────────────────────────────────────────────────────┤
│                    DATA LAYER                              │
│                                                           │
│  MongoDB 4.4           RabbitMQ 3.11                      │
│  Port: 27017           Port: 5672 (AMQP)                  │
│  1 replica             Port: 15672 (Management)           │
│  PVC: 8Gi              1 replica                          │
│  Creds: none           Creds: guest/guest                 │
│                                                           │
├───────────────────────────────────────────────────────────┤
│                    LOAD GENERATION                         │
│                                                           │
│  virtual-customer                                         │
│  1 replica                                                │
│  Rate: ~100 orders/hour                                   │
│  Target: order-service                                    │
└─────────────────────────────────────────────────────────┘
```

---

## Cascading Failure Chains

### Chain 1: MongoDB failure
```
MongoDB down
  → makeline-service health check fails → pod restarts
  → Orders accumulate in RabbitMQ queue (queue depth grows)
  → store-admin shows no order data
  → Customer orders accepted but never fulfilled
  Impact: Order fulfillment stopped. No data loss if RabbitMQ is healthy.
  Recovery priority: 1 (restore MongoDB first)
```

### Chain 2: RabbitMQ failure
```
RabbitMQ down
  → order-service cannot publish orders → returns errors to store-front
  → makeline-service loses message source → idle
  → Customer orders LOST (not queued anywhere)
  Impact: DATA LOSS RISK. Orders submitted during outage are lost.
  Recovery priority: 1 (restore RabbitMQ first)
```

### Chain 3: order-service failure
```
order-service down
  → store-front checkout broken → customers cannot place orders
  → virtual-customer generates errors
  → RabbitMQ and downstream unaffected (no new messages)
  Impact: Customer-facing. No orders can be placed.
  Recovery priority: 2
```

### Chain 4: product-service failure
```
product-service down
  → store-front shows no products → customers cannot browse
  → store-admin cannot manage products
  → Order flow technically works but no new orders (no catalog)
  Impact: Customer-facing. Store appears empty.
  Recovery priority: 3
```

### Chain 5: store-front failure
```
store-front down
  → Customers cannot access the store
  → Backend services unaffected
  → virtual-customer still generates orders via order-service directly
  Impact: Customer-facing but no backend cascade.
  Recovery priority: 4
```

### Chain 6: store-admin failure
```
store-admin down
  → Admins cannot view/manage orders or products
  → ALL customer-facing functionality unaffected
  Impact: Internal only. Zero customer impact.
  Recovery priority: 5
```

---

## Impact Matrix for Advisor Recommendation Execution

Use this matrix to determine which services need monitoring when executing
an Advisor recommendation that causes downtime:

| Resource Changed | Monitor These Services | Pre-Action |
|------------------|----------------------|-----------|
| AKS node pool | ALL pods | `kubectl get pods -n pets -w` |
| AKS cluster config | ALL pods | `kubectl get pods -n pets -w` |
| ACR | Pod restarts only | `kubectl get events -n pets -w` |
| VNet / subnet | ALL network connectivity | `kubectl exec -n pets <pod> -- wget -qO- http://order-service:3000/health` |
| Key Vault | Pod mounts | `kubectl describe pods -n pets \| grep -A5 "Volumes"` |
| Managed disk | MongoDB (PVC) | `kubectl get pods -n pets -l app=mongodb -w` |
| Log Analytics | None (monitoring only) | N/A |
| Grafana | None (dashboards only) | N/A |

**Standard pre-action for any disruptive change:**
1. Scale virtual-customer to 0: `kubectl scale deploy virtual-customer -n pets --replicas=0`
2. Wait for RabbitMQ queue to drain: `kubectl exec -n pets deploy/rabbitmq -- rabbitmqctl list_queues`
3. Take note of current pod status: `kubectl get pods -n pets -o wide`
