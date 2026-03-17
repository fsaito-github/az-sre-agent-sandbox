# SKILL: Advisor Impact Analysis

This is a SKILL.md file for the Azure SRE Agent. Upload it to the
Knowledge Base so the agent can follow this procedure automatically
when analyzing Azure Advisor recommendations.

---

## Skill: advisor-impact-analysis

### Description
Systematic procedure for analyzing the operational impact of Azure Advisor
recommendations before execution. Transforms vague recommendations into
risk-rated execution plans.

### When to Use
- User asks about Azure Advisor recommendations
- User wants to know if a change is safe to execute
- User needs a maintenance plan for infrastructure changes
- User asks "what Advisor recommendations do I have?"
- User asks "is it safe to apply recommendation X?"
- User asks "what are the quick wins?"

### Procedure

#### Step 1: Collect Recommendations

```bash
# Get all recommendations for the resource group
az advisor recommendation list \
  --resource-group <resource-group> \
  -o json

# Or filter by category
az advisor recommendation list \
  --resource-group <resource-group> \
  --category <Reliability|Cost|Security|Performance|OperationalExcellence> \
  -o json
```

Extract for each recommendation:
- `category` — which Advisor pillar
- `impact` — Advisor's own rating (High/Medium/Low)
- `shortDescription.problem` — what the issue is
- `shortDescription.solution` — what Advisor suggests
- `impactedValue` — which resource
- `impactedField` — resource type

#### Step 2: Classify Risk

For each recommendation, determine the operational risk level:

| Check | 🟢 Safe | 🟡 Low | 🟠 Medium | 🔴 High |
|-------|---------|--------|-----------|---------|
| Causes downtime? | No | <1 min | 1-15 min | >15 min |
| Data risk? | None | None | None | Possible |
| Reversible? | Easily | Yes | Yes | Hard/No |
| Affects running pods? | No | Restart only | Drain/reschedule | Recreation |
| Customer-facing impact? | None | None | Indirect | Direct |

**Decision tree:**
1. No downtime + no data risk + easily reversible → 🟢 Safe
2. Brief pod restart + no data risk + reversible → 🟡 Low Risk
3. Node drain or network change + no data loss + reversible → 🟠 Medium Risk
4. Resource recreation or hard to rollback or data risk → 🔴 High Risk

#### Step 3: Map Dependencies

For each affected resource, determine blast radius:

```bash
# For AKS resources — check what pods run on the cluster
kubectl get pods -n pets -o wide

# For storage/disk — check PVC bindings
kubectl get pvc -n pets

# For networking — check services and endpoints
kubectl get svc -n pets
kubectl get endpoints -n pets

# For ACR — check which images pods use
kubectl get pods -n pets -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.image}{"\n"}{end}{end}'
```

Consult the `dependency-map.md` knowledge file for the full dependency graph.

#### Step 4: Generate Impact Report

For each recommendation, produce:

```markdown
### [Recommendation Title]

**Category:** <category> | **Advisor Impact:** <impact>
**Resource:** <impactedValue> (<impactedField>)

| Aspect | Assessment |
|--------|-----------|
| Risk Level | 🟢/🟡/🟠/🔴 <level> |
| Downtime | <estimate> |
| Blast Radius | <services affected> |
| Data Risk | <None/Low/Medium/High> |
| Rollback | ✅/⚠️/❌ <details> |
| Maintenance Window | Required/Not required |
| Cost Delta | <+$X/month or None> |
| Quick Win? | ✅ Yes / No |
```

#### Step 5: Prioritize Execution Order

Group recommendations into 4 phases:

**Phase 1 — Quick Wins (🟢 Safe)**
Execute immediately. No risk. Immediate compliance improvement.
Can be batched together in a single session.

**Phase 2 — Low Traffic Window (🟡 Low Risk)**
Execute during off-peak hours. Brief disruptions possible.
Apply one at a time, verify health between each.

**Phase 3 — Scheduled Maintenance (🟠 Medium Risk)**
Requires maintenance window communicated to stakeholders.
Execute sequentially with validation between each step.
Have rollback plan ready and tested.

**Phase 4 — Planned Change (🔴 High Risk)**
Requires change advisory board approval.
Execute in dedicated maintenance window.
Have tested rollback plan.
Consider staging environment test first.

#### Step 6: Generate Execution Plan (if requested)

For each recommendation the user wants to execute:

```markdown
#### Pre-Checks
□ <check 1>
□ <check 2>

#### Execution
1. <command or action>
2. <command or action>

#### Post-Checks
□ <verification 1>
□ <verification 2>

#### Rollback (if issues detected)
1. <rollback step>
2. <rollback step>
```

### Templates

#### Standard Pre-Checks for AKS Changes
```
□ kubectl get pods -n pets — all Running and Ready
□ kubectl get nodes — all Ready
□ No active alerts in Azure Monitor
□ RabbitMQ queue depth is manageable
□ Scale virtual-customer to 0 (stop synthetic load)
□ Note current state for comparison after change
```

#### Standard Post-Checks for AKS Changes
```
□ kubectl get pods -n pets — all Running and Ready
□ kubectl get nodes — all Ready
□ kubectl get events -n pets --sort-by='.lastTimestamp' — no errors
□ Test store-front: curl http://<store-front-ip>/
□ Test store-admin: curl http://<store-admin-ip>/
□ Scale virtual-customer back to 1
□ Monitor for 15 minutes for any anomalies
□ Verify no increase in error rate in Application Insights
```

#### Standard Pre-Checks for Network Changes
```
□ Document current outbound IP (for allowlisting)
□ Test outbound connectivity: kubectl exec -n pets <pod> -- wget -qO- https://mcr.microsoft.com
□ Note current NSG rules
□ Scale virtual-customer to 0
```

### Cross-References

- For business impact analysis of downtime → handoff to **E-Commerce Domain Expert**
- For security recommendation deep-dive → handoff to **Security Posture Auditor**
- For checking if error budget allows maintenance → handoff to **SLO Guardian**
- For post-change incident documentation → handoff to **PIR Generator**
