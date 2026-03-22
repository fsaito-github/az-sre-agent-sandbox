# WAF Reliability Checklist (RE:01 — RE:10)

Maps the Well-Architected Framework Reliability pillar recommendations
to automated checks the subagent can perform.

Source: https://azure.github.io/Azure-Proactive-Resiliency-Library-v2/azure-waf/reliability/

---

## RE:01 — Align with business objectives

**Automated checks**: Limited — mostly architectural/design review.
**What the agent CAN check**:
- Are resources tagged with criticality/workload identifiers?
```kql
resources
| where isnull(tags) or tags == "{}"
| summarize count() by type
| order by count_ desc
```

---

## RE:04 — Define reliability targets

**Automated checks**:
- Are production resources on SLA-backed SKUs (not Basic/Free)?
- See: `pip-basic-sku`, `appsvc-single-instance` queries

---

## RE:05 — Design for redundancy

**Automated checks** (highest coverage):
- VMs without Availability Zones → `vm-no-az`
- AKS without AZ → `aks-no-az`
- AKS single node → `aks-single-node`
- SQL without zone redundancy → `sql-no-zr`
- SQL without geo-replication → `sql-no-georep`
- Storage using LRS → `storage-lrs`
- App Service without ZR → `appsvc-no-zr`
- App Service single instance → `appsvc-single-instance`
- LB without zone redundancy → `lb-no-zr`
- Public IP Basic SKU → `pip-basic-sku`
- App Gateway without AZ → `appgw-no-zr`
- Firewall without AZ → `fw-no-az`
- Cosmos DB single region → `cosmos-single-region`
- Redis without AZ → `redis-no-zr`

---

## RE:06 — Design for reliable scaling

**Automated checks**:
- App Service Plan with capacity < 2 → `appsvc-single-instance`
- AKS node pool with count < 2 → `aks-single-node`

**Manual checks** (note in report):
- HPA/VPA configured for AKS workloads
- App Service autoscale rules defined
- Cosmos DB auto-scale throughput

---

## RE:07 — Self-preservation and self-healing

**Automated checks**:
- App Service without health check → `appsvc-no-healthcheck`
- AKS without auto-upgrade → `aks-no-autoupgrade`

**Manual checks** (note in report):
- VMSS auto-repair enabled (check via az vmss show)
- Liveness/readiness probes in K8s deployments
- Circuit breaker patterns in application code

---

## RE:09 — Business continuity and DR

**Automated checks**:
- VMs without backup → `vm-no-backup`
- SQL without geo-replication → `sql-no-georep`
- Storage without soft delete → `storage-no-softdelete`
- Key Vault without soft delete → `kv-no-softdelete`
- Key Vault without purge protection → `kv-no-purge`

**Manual checks** (note in report):
- Recovery plan tested in last 12 months
- RPO/RTO documented and validated
- Cross-region DR procedures documented

---

## RE:10 — Monitoring and alerting

**Automated checks**:
- No Service Health alerts → `no-servicehealth-alert`

**Manual checks** (note in report):
- Diagnostic settings enabled on all critical resources
- Azure Monitor alerts for key metrics
- Grafana/dashboards for operational visibility

---

## Pillar Coverage Summary

| Pillar | Automated Checks | Manual Checks | Total |
|--------|-----------------|---------------|-------|
| RE:01 Align | 1 (tagging) | Design review | 1+ |
| RE:04 Targets | 2 (SKU checks) | SLA review | 2+ |
| RE:05 Redundancy | 14 | Multi-region review | 14+ |
| RE:06 Scaling | 2 | Autoscale config | 2+ |
| RE:07 Self-healing | 2 | Probes, patterns | 2+ |
| RE:09 BCDR | 5 | DR plan review | 5+ |
| RE:10 Monitoring | 1 | Alert config | 1+ |
| **Total** | **27** | **~10+** | **37+** |
