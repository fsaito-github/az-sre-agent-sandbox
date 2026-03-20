# Impact Table Guide

How to build the mandatory output for each Advisor recommendation.

---

## Per-recommendation output format

```markdown
### Rec #N: "<recommendation title>"
**Category:** <cat> | **Risk:** 🟢/🟡/🟠/🔴 | **Advisor Impact:** <High/Medium/Low>

#### 🎯 WHAT HAPPENS WHEN YOU APPLY THIS CHANGE

| Workload | Role | Current Status | During Change | After Change | Auto-recovers? | End-user affected? |
|----------|------|---------------|---------------|-------------|----------------|-------------------|
| <name> | <role> | <from discovery> | <impact> | <end state> | Yes/No/Manual | <specific action> |

**Summary:** "X workloads affected for Y minutes, Z auto-recover"

#### 💰 COST IMPACT
| Current cost | After change | Monthly delta | Source |
|-------------|-------------|--------------|--------|
| <current> | <new> | <+$X/-$X/$0> | <Retail Prices API / Advisor / Estimate> |
```

If NO cost impact: **💰 Cost impact: None**
If cost unknown: **💰 Cost impact: ⚠️ Unknown — verify pricing for <resource>**

---

## Additional sections by risk level

### For 🟡 Low Risk and above — Cascade Chain:

```markdown
#### ⚡ CASCADE CHAIN
<resource change>
  → <first workload> — <what happens>
  → <dependent workload> — <consequence>
  → <downstream effect>
  → <end-user-visible behavior>
```

### For 🟠 Medium Risk and above — Post-Execution Validation:

```markdown
#### ✅ POST-EXECUTION VALIDATION
□ <check 1: command + expected output>
□ <check 2: connectivity/health test + expected result>
□ <check 3: end-to-end flow validation>
```

---

## Rules for the Workload Impact Table

1. Include ALL workloads discovered in discovery step — do NOT omit any
2. "Current Status" MUST come from real discovery output, never guessed
3. Unaffected workloads MUST appear with "✅ No impact" (positive confirmation)
4. "Auto-recovers?" values:
   - **Yes**: restarts and works on its own
   - **No**: stays broken (permanent failure state)
   - **Manual**: needs operator action to fix
5. "End-user affected?" must specify WHICH action breaks:
   - "login fails", "API returns 503", "uploads timeout" — not just "Yes/No"
   - If you lack domain context: "⚠️ Unknown — check with application team"

---

## How to fill columns

**Replicas:** From discovery. If >1, rolling update possible without downtime.

**Depends On:** From dependency mapping. If dependency affected → this workload affected too.

**During Change logic:**
- ADDITIVE change (add node, enable feature) → "✅ No impact"
- Requires RESTART of this workload → "⚠️ Restart ~Xs"
- Affects a DEPENDENCY → "❌ Fails until dependency recovers"
- Affects NETWORK + workload makes outbound calls → "⚠️ Outbound fails"

**End-user affected logic:**
- Exposed via LoadBalancer/Ingress/public endpoint = customer-facing → direct impact
- ClusterIP/private only = indirect impact (via dependency chain)
- Quantify: "API returns 503 for ~30s" not "disruption"

---

## Cascade chain logic

For each workload that BREAKS (❌):
1. Who depends on this workload? (from dependency mapping)
2. What happens to dependents? (fails? degrades? queues?)
3. Is there data at risk? (queue loses messages? DB loses writes?)
4. Propagate until you reach the end user

---

## Executive Summary format

After all per-recommendation analyses:

```markdown
## 📊 EXECUTIVE SUMMARY

| # | Recommendation | Risk | Workloads that break | Auto-recovers? | 💰 Cost delta | Required action |
|---|---------------|------|---------------------|----------------|--------------|-----------------|
| 1 | ... | 🟢 | None | N/A | $0 | None |

### 🏆 QUICK WINS (zero impact): items ...
### ⚠️ SPECIAL ATTENTION: items ... (reason)

### 📈 RECOMMENDED EXECUTION ORDER
Phase 1 — Quick Wins (now): 🟢 items
Phase 2 — Low Risk (next window): 🟡 items
Phase 3 — Medium Risk (maintenance window): 🟠 items
Phase 4 — High Risk (change board + tested rollback): 🔴 items
```

---

## Handling incomplete information

When you CANNOT fully discover the environment:

1. **State what you know** — list confirmed workloads and dependencies
2. **State what you don't know** — list failed commands and missing data
3. **Adjust confidence**:
   - High: full discovery, all dependencies mapped
   - Medium: most workloads discovered, some dependencies inferred
   - Low: limited discovery, significant gaps
4. **Recommend next steps** for the operator to verify manually
5. **Never fill gaps with assumptions** — say "unknown" rather than guess
