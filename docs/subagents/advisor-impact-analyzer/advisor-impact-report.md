
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

| # | Category | Recommendation | Resource | Operational Risk | Downtime | 💰 Cost Delta | Quick Win? |
|---|----------|---------------|----------|------------------|----------|--------------|------------|
| 1 | Security | Diagnostic logs on AKS | aks-srelab | 🟢 Safe | None | +~$5/mo _(log volume)_ | ✅ Yes |
| 2 | Security | Diagnostic logs on Key Vault | kv-srelab-tlwgvg | 🟢 Safe | None | +~$2/mo _(log volume)_ | ✅ Yes |
| 3 | Security | Enable purge protection (KV) | kv-srelab-tlwgvg | 🟢 Safe | None | $0 | ✅ Yes |
| 4 | Cost | Enable AKS Cost Analysis | aks-srelab | 🟢 Safe | None | $0 | ✅ Yes |
| 5 | Cost | Tune cluster autoscaler profile | aks-srelab | 🟢 Safe | None | 💰 Saves 10-30% | ✅ Yes |
| 6 | Cost | Enable VPA in recommendation mode | aks-srelab | 🟢 Safe | None | $0 | ✅ Yes |
| 7 | HighAvailability | Enable AKS Backup for PVs | aks-srelab | 🟢 Safe | None | +~$10/mo | ✅ Yes |
| 8 | HighAvailability | ACR Premium tier | acrsrelabtlwgvg | 🟢 Safe | None | +$145/mo | ⚠️ Cost |
| 9 | HighAvailability | Min 2 nodes in system pool | aks-srelab | 🟡 Low | None (additive) | +$73/mo | ⚠️ Cost |
| 10 | Cost | Consider Spot nodes | aks-srelab | 🟡 Low | None (additive) | 💰 Saves 60-80% | ⚠️ Cost |
| 11 | Security | Containers running as root | aks-srelab | 🟡 Low | ~30s/pod | $0 | No |
| 12 | Security | Read-only root filesystem | aks-srelab | 🟡 Low | ~30s/pod | $0 | No |
| 13 | Security | Images from trusted registries | aks-srelab | 🟡 Low | Rolling ~1min | $0 | No |
| 14 | Security | Disable API credential automount | aks-srelab | 🟡 Low | Pod restart | $0 | No |
| 15 | HighAvailability | ACR Geo-replication | acrsrelabtlwgvg | 🟠 Medium | None | +$50/mo per region | No |
| 16 | HighAvailability | Use NAT gateway | vnet-srelab | 🟠 Medium | ~1-5 min | +$35/mo | No |
| 17 | Security | Restrict API server access | aks-srelab | 🟠 Medium | Auth risk | $0 | No |
| 18 | Security | Key Vault via private link | kv-srelab-tlwgvg | 🟠 Medium | Connectivity risk | +$7/mo | No |
| 19 | Security | ACR via private link | acrsrelabtlwgvg | 🟠 Medium | Connectivity risk | +$7/mo | No |
| 20 | Security | ACR restrict network access | acrsrelabtlwgvg | 🟠 Medium | Connectivity risk | $0 | No |
| 21 | OpEx | Use Ddv5 VM series | aks-srelab | 🟠 Medium | Rolling ~5-10 min | -5% _(newer gen)_ | No |
| 22 | OpEx | Use Ephemeral OS disk | aks-srelab | 🔴 High | ~15-20 min | -$5/mo _(no managed OS disk)_ | No |

_💰 Cost data source: Azure Retail Prices API (eastus2 region, pay-as-you-go). Actual costs may vary with EA/CSP agreements and reserved instances._

---

## 🟢 QUICK WINS — Immediate Execution (7 items, zero downtime)

These can be executed at any time, no maintenance window needed:

### 1. Diagnostic logs on AKS
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Remove config
- **Command**: `az monitor diagnostic-settings create` to send logs to Log Analytics
- **Impact**: No workload affected — only enables log collection
- **💰 Cost**: +~$5/month _(Log Analytics ingestion, depends on volume)_ — Source: estimate

### 2. Diagnostic logs on Key Vault
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Remove config
- **Impact**: None — additional telemetry only
- **💰 Cost**: +~$2/month _(low volume)_ — Source: estimate

### 3. Purge protection on Key Vault
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ⚠️ Irreversible (by design)
- **Command**: `az keyvault update --enable-purge-protection true`
- **💰 Cost**: $0

### 4. AKS Cost Analysis
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Disable
- **💰 Cost**: $0

### 5. Tune cluster autoscaler
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Revert profile
- **💰 Cost**: 💰 Potential savings of 10-30% on compute

### 6. Enable VPA (recommendation mode)
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Remove
- **💰 Cost**: $0

### 7. AKS Backup
- **Risk**: 🟢 Safe | **Downtime**: None | **Rollback**: ✅ Remove
- **💰 Cost**: +~$10/month _(backup storage for PVCs)_ — Source: estimate

---

## 🟡 LOW RISK — Execute during low traffic (6 items)

### 8. ACR Premium tier upgrade
- **Risk**: 🟢 Safe (tier upgrade) | **Downtime**: None | **Rollback**: ✅ Downgrade to Basic
- **Prerequisite for**: Geo-replication (#15) and Private Link (#19)
- **Impact**: No workload affected — image pull continues working
- **💰 Cost**: +$145/month _(Basic $5 → Premium $150)_ — Source: Azure Retail Prices API

### 9. Min 2 nodes in system pool
- **Risk**: 🟡 Low | **Downtime**: None (node addition)
- **Cost**: +$73/month _(1x Standard_D2s_v3 @ $0.10/hr × 730hrs)_ — Source: Azure Retail Prices API
- **Impact**: ⚡ CRITICAL for HA — currently 1 system node is a SPOF

### 10. Spot nodes for workloads
- **Risk**: 🟡 Low | **Downtime**: None (new pool)
- **Impact**: Spot VMs can be evicted anytime — suitable for load generators, not for data stores
- **💰 Cost**: 💰 Saves 60-80% on compute for eligible workloads — Source: Azure Retail Prices API

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

### 15. ACR Geo-replication
- **Risk**: 🟠 Medium | **Downtime**: None
- **Prerequisite**: ACR Premium (#8)
- **💰 Cost**: +$50/month per additional region — Source: Azure Retail Prices API
- **Rollback**: ✅ Remove regional replica

### 16. NAT Gateway
- **Risk**: 🟠 Medium | **Downtime**: ~1-5 min (outbound traffic)
- **Blast Radius**: All workloads making external calls
- **💰 Cost**: +$35/month _(base $32 + ~$3 processing)_ — Source: Azure Retail Prices API

### 17. Restrict API server access
- **Risk**: 🟠 Medium | **Downtime**: Potential loss of cluster access
- **Pre-checks**: List ALL IPs that access the API server
- **💰 Cost**: $0

### 18. Key Vault via private link
- **Risk**: 🟠 Medium | **Downtime**: Potential connectivity loss if misconfigured
- **Blast Radius**: Workloads that mount secrets from Key Vault
- **💰 Cost**: +$7/month _(private endpoint)_ — Source: Azure Retail Prices API
- **Rollback**: ✅ Remove private endpoint / revert network rules

### 19. ACR via private link
- **Risk**: 🟠 Medium | **Downtime**: Potential connectivity loss if misconfigured
- **Blast Radius**: All new pod starts / restarts (image pull)
- **💰 Cost**: +$7/month _(private endpoint)_ — Source: Azure Retail Prices API
- **Rollback**: ✅ Remove private endpoint / revert network rules

### 20. ACR restrict network access
- **Risk**: 🟠 Medium | **Downtime**: Potential connectivity loss if misconfigured
- **Blast Radius**: Same as #19 — image pull may fail
- **💰 Cost**: $0
- **Rollback**: ✅ Revert network rules

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
Phase 1 — Quick Wins (now, ~30 min total) 💰 +~$17/month
├── 🟢 Diagnostic logs (AKS + Key Vault)
├── 🟢 Purge protection Key Vault
├── 🟢 AKS Cost Analysis
├── 🟢 Fine-tune autoscaler
├── 🟢 VPA recommendation mode
└── 🟢 AKS Backup

Phase 2 — HA Improvements (next window, ~15 min) 💰 +~$218/month
├── 🟡 Scale system pool to min 2 nodes ⭐ PRIORITY
└── 🟢 ACR Premium upgrade (prerequisite for Phase 4)

Phase 3 — Security Hardening (low traffic, test 1 workload at a time) 💰 $0
├── 🟡 Disable API automount
├── 🟡 Read-only root filesystem (skip data store images)
├── 🟡 Trusted registries only
└── 🟡 Non-root containers (skip data store images)

Phase 4 — Network and Isolation (planned maintenance window) 💰 +~$99/month
├── 🟠 NAT Gateway
├── 🟠 ACR Private Link + network restrictions
├── 🟠 Key Vault Private Link
├── 🟠 Restrict API server access
└── 🟠 ACR Geo-replication

Phase 5 — Heavy Infrastructure (change board + full test) 💰 -~$10/month
├── 🟠 Migrate to Ddv5 VM series
└── 🔴 Ephemeral OS disk (last — highest risk)
```

---

## 💰 Financial Summary

### Cost Sources Used
- Azure Retail Prices API (eastus2, pay-as-you-go): VM sizes, ACR tiers, NAT Gateway, Private Endpoints
- Estimates: Log Analytics ingestion, Backup storage (volume-dependent)

### Additional Costs (monthly)

| Recommendation | Monthly Delta | Source |
|---------------|--------------|--------|
| +1 system node (D2s_v3) | +$73 | Retail Prices API |
| ACR Basic → Premium | +$145 | Retail Prices API |
| ACR Geo-replication (1 region) | +$50 | Retail Prices API |
| NAT Gateway | +$35 | Retail Prices API |
| Private endpoints (×3) | +$21 | Retail Prices API |
| AKS Backup | +$10 | Estimate |
| Diagnostic logs | +$7 | Estimate |
| **Subtotal additional** | **+~$341/month** | |

### Savings (monthly)

| Recommendation | Monthly Savings | Source |
|---------------|----------------|--------|
| Autoscaler tuning | -10 to -30% on compute | Estimate |
| Spot nodes (if adopted) | -60 to -80% on workload pool | Retail Prices API |
| Ddv5 VM series (newer gen) | -~5% on compute | Retail Prices API |
| Ephemeral OS disk | -$5 | Retail Prices API |
| **Subtotal savings** | **-$50 to -$300/month** _(depends on adoption)_ | |

### Net Impact
- **Without Spot nodes**: +~$290/month additional
- **With Spot nodes on workload pool**: net savings possible (-$50 to +$100/month)
- ⚠️ These are pay-as-you-go rates. EA/CSP agreements and reserved instances will reduce costs.

---

## ⚠️ Critical Alert

**The system node pool has only 1 node — this is a Single Point of Failure.**
If this node fails, ALL workloads become unavailable. Recommendation #9
(scale to 2 nodes) should be the **first action** after quick wins.
