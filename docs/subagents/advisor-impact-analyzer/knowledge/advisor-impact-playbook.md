# Advisor Impact Playbook

This document is a knowledge file for the Advisor Impact Analyzer sub-agent.
Upload it to the Azure SRE Agent Knowledge Base (Builder → Knowledge Base → Add file)
so the agent can consult it during impact analysis.

---

## How to Use This Playbook

When analyzing an Azure Advisor recommendation, the agent should:
1. Match the recommendation to a section in this playbook
2. Use the pre-analyzed impact data as a starting point
3. Verify against the actual environment (resource config, dependencies)
4. Adjust risk rating based on environment-specific factors

---

## AKS — Azure Kubernetes Service

### Scaling Node Pools

**Recommendation:** "Have at least 2 nodes in your system node pool"

| Aspect | Analysis |
|--------|----------|
| Operation | Add nodes to existing pool (scale up) |
| Downtime | None — new nodes join without disrupting existing pods |
| Data Risk | None |
| Cost Impact | +$2-5/day per additional Standard_D2s_v3 node |
| Rollback | Scale down (but check PodDisruptionBudgets first) |
| Dependencies | None — additive operation |

**Execution:**
```bash
# Check current state
az aks nodepool show -g <rg> --cluster-name <aks> -n <pool> --query nodeCount

# Scale up
az aks nodepool scale -g <rg> --cluster-name <aks> -n <pool> --node-count 2

# Verify
kubectl get nodes
```

**When NOT safe:** If subnet has insufficient IP addresses, the operation will fail
(not break anything, but fail). Check available IPs first.

---

### Container Security — Running as Root

**Recommendation:** "Running containers as root user should be avoided"

| Aspect | Analysis |
|--------|----------|
| Operation | Modify deployment securityContext |
| Downtime | Pod restart (~30s per pod, rolling update) |
| Data Risk | None (stateless containers) |
| Cost Impact | None |
| Rollback | Remove securityContext from deployment |

**Known issues in this lab (Pet Store):**
- **MongoDB 4.4**: Official image runs as root by default. To run as non-root:
  - Use `runAsUser: 999` (mongodb user) in securityContext
  - May need to adjust volume permissions with `fsGroup: 999`
  - Alternative: use Bitnami MongoDB image (designed for non-root)
- **RabbitMQ 3.11**: Official image runs as `rabbitmq` user (UID 999).
  - Generally compatible with `runAsNonRoot: true`
  - Set `runAsUser: 999`
- **Application containers** (store-front, order-service, etc.):
  - Typically work fine with `runAsNonRoot: true`
  - May fail if they write to paths outside mounted volumes

**Recommended approach:**
1. Test each container individually in a dev namespace
2. Apply one deployment at a time, verify health
3. Start with application containers (lower risk)
4. Tackle data stores last (MongoDB, RabbitMQ)

---

### Container Security — Trusted Registries

**Recommendation:** "Container images should be deployed from trusted registries only"

| Aspect | Analysis |
|--------|----------|
| Operation | Import images to ACR, update deployment manifests |
| Downtime | Rolling update ~1 min per service |
| Data Risk | None |
| Cost Impact | Minor ACR storage increase |
| Rollback | Revert image references in manifests |

**Current state in this lab:**
- All images from `ghcr.io/azure-samples/aks-store-demo/`
- MongoDB from Docker Hub: `mongo:4.4`
- RabbitMQ from Docker Hub: `rabbitmq:3.11-management-alpine`

**Migration steps:**
```bash
# Import to ACR (one-time operation)
az acr import --name <acr> --source ghcr.io/azure-samples/aks-store-demo/store-front:latest --image store-front:latest
az acr import --name <acr> --source ghcr.io/azure-samples/aks-store-demo/order-service:latest --image order-service:latest
# ... repeat for all images

# Update k8s/base/application.yaml with ACR paths
# image: <acr>.azurecr.io/store-front:latest
```

---

### Container Security — Immutable Root Filesystem

**Recommendation:** "Immutable (read-only) root filesystem should be enforced"

| Aspect | Analysis |
|--------|----------|
| Operation | Add `readOnlyRootFilesystem: true` + emptyDir volumes |
| Downtime | Pod restart (~30s per pod) |
| Data Risk | None |
| Rollback | Remove readOnlyRootFilesystem setting |

**Common writable paths needed:**
| Container | Writable Paths | Solution |
|-----------|---------------|----------|
| Node.js apps | /tmp, /home/node | emptyDir volume mounts |
| Go apps | /tmp | emptyDir volume mount |
| Vue.js (nginx) | /tmp, /var/cache/nginx, /var/run | emptyDir volume mounts |
| MongoDB | /data/db (already on PVC), /tmp | Already on PVC + emptyDir for /tmp |
| RabbitMQ | /var/lib/rabbitmq, /tmp | emptyDir volume mounts |

---

### AKS Backup

**Recommendation:** "Use AKS Backup for clusters with persistent volumes"

| Aspect | Analysis |
|--------|----------|
| Operation | Install Backup Extension + configure Backup Vault |
| Downtime | None — purely additive |
| Data Risk | None — backup doesn't modify workloads |
| Cost Impact | ~$0.15/instance/month + storage costs |
| Rollback | Remove backup extension |

This is a **quick win** — zero risk, immediate compliance improvement.

---

### Cost — Spot Nodes

**Recommendation:** "Consider Spot nodes for interruptible workloads"

| Aspect | Analysis |
|--------|----------|
| Operation | Add Spot node pool alongside existing pool |
| Downtime | None for existing workloads |
| Data Risk | Spot nodes can be evicted anytime — only for fault-tolerant workloads |
| Cost Impact | Up to 90% savings on Spot node compute |
| Rollback | Delete Spot pool; workloads fall back to regular pool |

**Good candidates in this lab:**
- `virtual-customer` — synthetic load generator, OK to be interrupted
- `store-admin` — internal dashboard, brief interruption acceptable

**Bad candidates:**
- `MongoDB` — data store, must not be evicted
- `order-service` — customer-facing, must be available

---

### Cost — Cluster Autoscaler Tuning

**Recommendation:** "Fine-tune the cluster autoscaler profile for rapid scale down"

Zero-risk change. Only affects future scaling decisions.

```bash
az aks update -g <rg> -n <aks> \
  --cluster-autoscaler-profile \
    scale-down-delay-after-add=5m \
    scale-down-unneeded-time=5m \
    scan-interval=10s
```

---

### Cost — VPA Recommendation Mode

**Recommendation:** "Enable Vertical Pod Autoscaler recommendation mode"

Zero-risk change. Recommendation mode is **read-only** — only observes and suggests,
never auto-resizes containers.

```bash
az aks update -g <rg> -n <aks> --enable-vpa
```

---

### OperationalExcellence — Ephemeral OS Disk

**Recommendation:** "Use Ephemeral OS disk"

**HIGH RISK** — requires node pool recreation.

| Aspect | Analysis |
|--------|----------|
| Operation | Create new node pool + drain old + delete old |
| Downtime | Full pod reschedule: 10-20 min |
| Data Risk | emptyDir data lost during drain (expected) |
| Cost Impact | Slight reduction (no managed OS disk cost) |
| Rollback | Create new pool without ephemeral, drain back |

**Benefits:** Faster node boot, lower latency I/O, reduced cost.
**Risk:** Major disruption. Only do during planned maintenance.

---

### OperationalExcellence — Latest VM Series

**Recommendation:** "Use latest generation VM series such as Ddv5"

⚠️ **In this lab:** Standard_D2s_v5 is NOT available due to subscription
restrictions. This recommendation is **not actionable** in the current environment.
Flag as "Acknowledged — not actionable in current subscription" and suppress.

---

## Container Registry (ACR)

### Geo-Replication

**Recommendation:** "Ensure Geo-replication is enabled for resilience"

| Aspect | Analysis |
|--------|----------|
| Operation | Add replication to second region |
| Downtime | None — purely additive |
| Prerequisite | Requires Premium SKU |
| Cost Impact | Premium: ~$50/month + replication storage |
| Rollback | Remove replication region |

**Dependency:** Must upgrade to Premium SKU first (see below).

### Premium SKU

**Recommendation:** "Use Premium tier for critical production workloads"

| Aspect | Analysis |
|--------|----------|
| Operation | In-place SKU upgrade |
| Downtime | None — online operation |
| Cost Impact | Basic (~$5/month) → Premium (~$50/month) = +$45/month |
| Rollback | Downgrade SKU (loses Premium features) |

---

## Networking

### NAT Gateway

**Recommendation:** "Use NAT gateway for outbound connectivity"

| Aspect | Analysis |
|--------|----------|
| Operation | Create NAT GW + associate with AKS subnet |
| Downtime | Brief outbound connectivity disruption (1-5 min) |
| Data Risk | None |
| Cost Impact | ~$32/month (NAT GW) + data processing |
| Rollback | Disassociate NAT GW from subnet |

**Why it matters:** Without NAT GW, AKS uses load balancer SNAT ports which
can be exhausted under high outbound connection load.

---

## Key Vault

### Soft Delete + Purge Protection

**Recommendation:** "Key vaults should have deletion protection enabled"

| Aspect | Analysis |
|--------|----------|
| Operation | Enable soft-delete and purge protection |
| Downtime | None |
| Data Risk | None — protective measure |
| Rollback | ⚠️ **Cannot be disabled** once enabled |
| Cost Impact | None |

**IMPORTANT:** This is a one-way change. Once enabled:
- Deleted secrets are retained for 90 days
- Cannot be permanently deleted during retention period
- This is by design for security compliance

### Diagnostic Logs

**Recommendation:** "Diagnostic logs in Key Vault should be enabled"

Zero-risk change. Enables audit logging of Key Vault operations.

```bash
az monitor diagnostic-settings create \
  --name kv-diagnostics \
  --resource <kv-resource-id> \
  --workspace <log-analytics-id> \
  --logs '[{"category":"AuditEvent","enabled":true}]'
```

---

## Quick Reference — Risk by Recommendation

| Risk | Recommendations | Count |
|------|----------------|-------|
| 🟢 Safe | AKS Backup, Cost Analysis, VPA recommendation mode, Autoscaler tuning, ACR Premium, ACR Geo-rep, Diagnostic logs (KV), Diagnostic logs (K8s), Soft delete KV | 9 |
| 🟡 Low | Running as root, Read-only rootfs, Spot nodes, Trusted registries | 4 |
| 🟠 Medium | 2+ system nodes, NAT gateway, Latest VM series | 3 |
| 🔴 High | Ephemeral OS disk | 1 |
