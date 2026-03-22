# Remediation Priorities

How to prioritize reliability findings for action.

---

## Priority Formula

```
Priority Score = Severity × Blast Radius × (1 + Cost Factor)
```

| Factor | Values |
|--------|--------|
| **Severity** | Critical=4, High=3, Medium=2, Low=1 |
| **Blast Radius** | # of dependent workloads affected (1-10+) |
| **Cost Factor** | 0 if $0, 0.5 if <$50/mo, 1 if $50-200/mo, 2 if >$200/mo |

Higher score = fix first.

---

## Priority Tiers

| Tier | Score Range | Action | SLA |
|------|-----------|--------|-----|
| **P0 — Immediate** | ≥ 20 | Fix now, no approval needed | This week |
| **P1 — Urgent** | 10-19 | Schedule maintenance window | This sprint |
| **P2 — Planned** | 5-9 | Add to backlog, plan for next cycle | This quarter |
| **P3 — Advisory** | 1-4 | Awareness, fix if convenient | When possible |

---

## Quick Win Identification

A finding is a **Quick Win** if ALL of these are true:
- Severity ≤ Medium
- Remediation cost = $0
- Rollback = ✅ Reversible
- No downtime required
- Can be done via single az command

Examples:
- Enable diagnostic logs
- Enable Key Vault soft delete
- Create Service Health alert
- Enable AKS auto-upgrade

---

## Blast Radius Assessment

Determine how many workloads are affected if a resource fails:

```bash
# For AKS: how many pods/services depend on this?
az aks show --name <aks> --resource-group <rg> --query "agentPoolProfiles[].count"

# For SQL: which apps connect?
# Check App Insights dependencies or connection strings

# For Storage: who mounts this?
# Check blob container references in app settings
```

Use App Insights KQL when available:
```kql
dependencies
| where timestamp > ago(7d)
| where target contains "<resource-name>"
| distinct cloud_RoleName
| count
```

---

## Integration with Azure Advisor

Combine APRL findings with Advisor HighAvailability recommendations:

```bash
az advisor recommendation list --category HighAvailability -o json
```

**Deduplication**: If both APRL and Advisor flag the same resource,
use the APRL finding (more specific) and note Advisor confirmation.

**Advisor-only findings**: Include recommendations that APRL doesn't
cover (e.g., VMSS auto-repair, specific SKU recommendations).

---

## Remediation Cost Estimation

For each finding that requires a SKU change or new resource:

1. Query Azure Retail Prices API (see cost-analysis knowledge file
   from the Advisor Impact Analyzer)
2. Calculate monthly delta
3. Flag findings where fix cost > $100/mo: "⚠️ Evaluate ROI"

---

## Executive Presentation Tips

Based on field feedback, executives respond best to:

1. **Score trend**: "Last month 72%, this month 68% — we're getting worse"
2. **Business risk framing**: "If Zone 1 in eastus2 goes down, these 5 services
   go offline for ~2 hours"
3. **Quick wins count**: "7 findings can be fixed today at $0 cost"
4. **Cost of inaction**: "One AZ outage affecting these resources would cost
   approximately X hours of downtime"

Avoid:
- ❌ Listing 50 findings without prioritization
- ❌ Technical jargon without business context
- ❌ Presenting all findings as equally urgent
