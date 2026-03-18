
# ══════════════════════════════════════════════════════════════════
# 🔍 ADVISOR IMPACT ANALYSIS — Example Report
# ══════════════════════════════════════════════════════════════════
#
# This is an EXAMPLE report generated from the AKS Pet Store demo lab.
# Your report will reflect the workloads, dependencies, and resources
# that the agent discovers in YOUR environment.
#
# The agent dynamically builds the impact table based on what it finds.
# The workload names, counts, and dependencies below are specific to
# this lab — they are NOT hardcoded into the agent.
# ══════════════════════════════════════════════════════════════════

## Discovered Environment
- **Environment Profile**: A — Kubernetes + Azure
- **AKS Cluster**: aks-srelab (K8s 1.32)
- **Node Pools**: system (1x Standard_D2s_v3), workload (0 nodes, autoscale)
- **Namespaces with workloads**: pets
- **Discovered workloads**: 8 (store-front, order-service, product-service, makeline-service, mongodb, rabbitmq, store-admin, virtual-customer)
- **Supporting resources**: ACR (Basic), Key Vault, VNet, Log Analytics, App Insights
- **Total Advisor Recommendations**: 22

### Discovered Dependency Graph
```
store-front → order-service → rabbitmq
store-front → product-service
makeline-service → rabbitmq (consumer)
makeline-service → mongodb
store-admin → product-service
store-admin → makeline-service
virtual-customer → order-service
```
_(This graph was built from environment variable inspection, not preconfigured.)_

---

## 📊 Summary by Operational Risk

| # | Category | Recommendation | Resource | Advisor Impact | Operational Risk | Downtime | Quick Win? |
|---|----------|---------------|----------|----------------|------------------|----------|------------|
| 1 | Security | Diagnostic logs on AKS | aks-srelab | Low | 🟢 Safe | None | ✅ Yes |
| 2 | Security | Diagnostic logs on Key Vault | kv-srelab-tlwgvg | Low | 🟢 Safe | None | ✅ Yes |
| 3 | Security | Enable purge protection (KV) | kv-srelab-tlwgvg | Medium | 🟢 Safe | None | ✅ Yes |
| 4 | Cost | Enable AKS Cost Analysis | aks-srelab | Medium | 🟢 Safe | None | ✅ Yes |
| 5 | Cost | Tune cluster autoscaler profile | aks-srelab | Medium | 🟢 Safe | None | ✅ Yes |
| 6 | Cost | Enable VPA in recommendation mode | aks-srelab | Medium | 🟢 Safe | None | ✅ Yes |
| 7 | HighAvailability | Enable AKS Backup for PVs | aks-srelab | Medium | 🟢 Safe | None | ✅ Yes |
| 8 | HighAvailability | ACR Premium tier | acrsrelabtlwgvg | High | 🟢 Safe | None | ⚠️ Cost |
| 9 | HighAvailability | Min 2 nodes in system pool | aks-srelab | High | 🟡 Low | None (additive) | ⚠️ Cost |
| 10 | Cost | Consider Spot nodes | aks-srelab | Medium | 🟡 Low | None (additive) | ⚠️ Cost |
| 11 | Security | Containers running as root | aks-srelab | High | 🟡 Low | ~30s/pod | No |
| 12 | Security | Read-only root filesystem | aks-srelab | Medium | 🟡 Low | ~30s/pod | No |
| 13 | Security | Images from trusted registries | aks-srelab | High | 🟡 Low | Rolling ~1min | No |
| 14 | Security | Disable API credential automount | aks-srelab | High | 🟡 Low | Pod restart | No |
| 15 | HighAvailability | ACR Geo-replication | acrsrelabtlwgvg | High | 🟠 Medium | None | No (requires Premium) |
| 16 | HighAvailability | Use NAT gateway | vnet-srelab | Medium | 🟠 Medium | ~1-5 min outbound | No |
| 17 | Security | Restrict API server access | aks-srelab | High | 🟠 Medium | Auth risk | No |
| 18 | Security | Key Vault via private link | kv-srelab-tlwgvg | Medium | 🟠 Medium | Connectivity risk | No |
| 19 | Security | ACR via private link | acrsrelabtlwgvg | Medium | 🟠 Medium | Connectivity risk | No |
| 20 | Security | ACR restrict network access | acrsrelabtlwgvg | Medium | 🟠 Medium | Connectivity risk | No |
| 21 | OpEx | Use Ddv5 VM series | aks-srelab | Low | 🟠 Medium | Rolling ~5-10 min | No |
| 22 | OpEx | Use Ephemeral OS disk | aks-srelab | Low | 🔴 High | ~15-20 min | No |

---

## 🟢 QUICK WINS — Immediate Execution (7 items, zero downtime)

These can be executed at any time, no maintenance window needed:

### 1. Diagnostic logs on AKS
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Remove config
- **Command**: `az monitor diagnostic-settings create` to send logs to Log Analytics
- **Impact**: No workload affected — only enables log collection

### 2. Diagnostic logs on Key Vault
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Remove config
- **Impact**: None — additional telemetry only

### 3. Purge protection on Key Vault
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ⚠️ Irreversible (by design)
- **Command**: `az keyvault update --enable-purge-protection true`

### 4. AKS Cost Analysis
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Disable

### 5. Tune cluster autoscaler
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Revert profile

### 6. Enable VPA (recommendation mode)
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Remove

### 7. AKS Backup
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Remove

---

## 🟡 LOW RISK — Execute during low traffic (6 items)

### 9. Min 2 nodes in system pool
- **Risk**: 🟡 Low | **Downtime**: None (node addition)
- **Cost**: +1x Standard_D2s_v3 (~$70/month)
- **Impact**: ⚡ CRITICAL for HA — currently 1 system node is a SPOF

### 11-14. Pod security hardening
These require Kubernetes manifest changes:

| Recommendation | Action | Risk | Watch out |
|---------------|--------|------|-----------|
| Running as root | `securityContext.runAsNonRoot: true` | 🟡 | Official DB/middleware images may require root |
| Read-only rootfs | `readOnlyRootFilesystem: true` | 🟡 | Requires tmpfs for write dirs |
| Trusted registries | Use only images from ACR | 🟡 | Requires importing external images first |
| Disable API automount | `automountServiceAccountToken: false` | 🟡 | Check if any workload uses K8s API |

**⚠️ ALERT**: Official database images (mongo, postgres, redis, rabbitmq) may
**not work** as non-root. Test individually before applying.

---

## 🟠 MEDIUM RISK — Requires Maintenance Window (6 items)

### 16. NAT Gateway
- **Risk**: 🟠 Medium | **Downtime**: ~1-5 min (outbound traffic)
- **Blast Radius**: All workloads making external calls

### 17. Restrict API server access
- **Risk**: 🟠 Medium | **Downtime**: Potential loss of cluster access
- **Pre-checks**: List ALL IPs that access the API server

### 21. Ddv5 VM series (latest generation)
- **Risk**: 🟠 Medium | **Downtime**: Rolling ~5-10 min per node
- **Blast Radius**: All pods rescheduled during upgrade

---

## 🔴 HIGH RISK — Requires Approval and Planning (1 item)

### 22. Ephemeral OS Disk
- **Risk**: 🔴 High | **Downtime**: ~15-20 min (node pool recreation)
- **Blast Radius**: ALL pods on affected pool — full cascade
- **Rollback**: ❌ Complex — requires recreating the pool
- **Mandatory pre-requisites**:
  - ✅ Snapshot all PVs (data stores)
  - ✅ Scale down load generators to 0
  - ✅ Verify VM size supports ephemeral disk of required size
  - ✅ Full test in non-prod first

---

## 📈 Recommended Execution Order

```
Phase 1 — Quick Wins (now, ~30 min total)
├── 🟢 Diagnostic logs (AKS + Key Vault)
├── 🟢 Purge protection Key Vault
├── 🟢 AKS Cost Analysis
├── 🟢 Fine-tune autoscaler
├── 🟢 VPA recommendation mode
└── 🟢 AKS Backup

Phase 2 — HA Improvements (next window, ~15 min)
├── 🟡 Scale system pool to min 2 nodes ⭐ PRIORITY
└── 🟢 ACR Premium upgrade (prerequisite for Phase 4)

Phase 3 — Security Hardening (low traffic, test 1 workload at a time)
├── 🟡 Disable API automount
├── 🟡 Read-only root filesystem (skip data store images)
├── 🟡 Trusted registries only
└── 🟡 Non-root containers (skip data store images)

Phase 4 — Network and Isolation (planned maintenance window)
├── 🟠 NAT Gateway
├── 🟠 ACR Private Link + network restrictions
├── 🟠 Key Vault Private Link
├── 🟠 Restrict API server access
└── 🟠 ACR Geo-replication

Phase 5 — Heavy Infrastructure (change board + full test)
├── 🟠 Migrate to Ddv5 VM series
└── 🔴 Ephemeral OS disk (last — highest risk)
```

---

## 💰 Estimated Cost Impact

| Recommendation | Monthly Delta |
|---------------|--------------|
| +1 system node (D2s_v3) | +~$70/month |
| ACR Basic → Premium | +~$145/month |
| ACR Geo-replication (1 region) | +~$50/month |
| NAT Gateway | +~$32/month + traffic |
| VPA + Autoscaler tuning | Potential 10-30% savings |
| Spot nodes | 60-80% savings on pool |
| **Estimated net impact** | **+~$250-300/month** (before optimizations) |

---

## ⚠️ Critical Alert

**The system node pool has only 1 node — this is a Single Point of Failure.**
If this node fails, ALL workloads become unavailable. Recommendation #9
(scale to 2 nodes) should be the **first action** after quick wins.
