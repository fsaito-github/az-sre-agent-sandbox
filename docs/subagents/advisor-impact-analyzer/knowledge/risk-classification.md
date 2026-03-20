# Risk Classification

How to classify operational risk for Azure Advisor recommendations.

---

## Risk levels

| Level | Criteria | Action |
|-------|----------|--------|
| 🟢 **Safe** | No downtime, no data risk, reversible, no restart | Execute anytime |
| 🟡 **Low Risk** | Brief disruption (<1 min), reversible, rolling restart | Execute during low traffic |
| 🟠 **Medium Risk** | Downtime 1-15 min, no data loss, requires validation | Schedule maintenance window |
| 🔴 **High Risk** | Downtime >15 min, data risk, hard to reverse | Approval + window + tested rollback |

## Risk amplifiers (increase by one level)

- Workload has replicas=1 (no redundancy during restart)
- StatefulSet with persistent data and no backup
- No PodDisruptionBudget protecting the workload
- Customer-facing workload with no health probe configured

---

## Risk reference by recommendation type

Use as a STARTING POINT, then adjust based on discovered environment.

### Kubernetes / Infrastructure

| Recommendation | Baseline | Notes |
|---------------|----------|-------|
| Enable diagnostic logs | 🟢 | Always safe |
| Enable soft delete / purge protection | 🟢 | Safe, but purge protection is ❌ irreversible |
| Enable cost analysis / VPA / autoscaler tuning | 🟢 | Observability only |
| Enable backup | 🟢 | Additive. 💰 Adds backup storage cost |
| SKU upgrade (ACR, DB, etc.) | 🟢 | 💰 Higher tier = higher cost |
| Add nodes / scale up | 🟡 | Additive, check quota. 💰 +$X/month per node |
| Spot nodes | 🟡 | Check if stateful workloads on spot. 💰 60-80% savings |
| Security hardening (non-root, rootfs) | 🟡 | ⚠️ Official DB images may FAIL. 💰 $0 |
| Trusted registries / image source | 🟡 | Rolling update per workload |
| Disable API credential automount | 🟡 | Check if workload uses K8s API |
| NAT gateway | 🟠 | Outbound calls affected. 💰 ~$32/mo + egress |
| Restrict API server access | 🟠 | kubectl/CI-CD may be LOST. 💰 $0 |
| Private link (ACR, KV, DB) | 🟠 | May FAIL if DNS misconfigured. 💰 ~$7-10/mo per endpoint |
| VM series upgrade / node pool change | 🟠 | Rolling drain. 💰 Varies |
| Ephemeral OS disk | 🔴 | Full recreation. 💰 $0 or savings |
| Geo-replication | 🟢-🟠 | Depends on resource. 💰 +$50-200/mo per region |

### AKS Managed RG (MC_*) — VMSS, Load Balancer, Disks

| Recommendation | Baseline | Notes |
|---------------|----------|-------|
| VMSS enable automatic repair policy | 🟡 | No downtime, additive. Requires health probe. 💰 $0 |
| VMSS zone-balanced configuration | 🟠 | Requires node pool recreation with `--zones`. All pods rescheduled. 💰 $0 |
| VMSS enable health monitoring | 🟢 | Additive, no downtime. 💰 $0 |
| VMSS encryption at host | 🟠 | Requires node pool recreation with `--enable-encryption-at-host`. 💰 $0 |
| LB backend pool ≥2 instances | 🟡 | Scale node pool to 2+. 💰 +$X/mo per node |
| Unattached managed disk (orphaned PVC) | 🟢 | Verify PVC is orphaned, then delete. 💰 Saves ~$1-4/mo per disk |

### PaaS

| Recommendation | Baseline | Notes |
|---------------|----------|-------|
| App Service Plan resize (scale up) | 🟢-🟡 | Brief restart ~30s. 💰 Varies by tier |
| App Service scale out (add instances) | 🟢 | Additive. 💰 +$X per instance |
| App Service slot swap | 🟢 | Zero-downtime. 💰 $0 |
| SQL DTU → vCore migration | 🟠 | Brief interruption ~30s. Data safe. 💰 Varies |
| SQL tier change (Basic → Standard) | 🟡 | Brief pause. 💰 Higher cost |
| Redis SKU change (Basic → Standard) | 🟠 | New instance + migration. 💰 Higher tier |
| Storage redundancy (LRS → ZRS/GRS) | 🟢-🟡 | Usually online. 💰 ZRS ~2x |
| Function Consumption → Premium | 🟡 | Brief cold start. 💰 Fixed + usage |
