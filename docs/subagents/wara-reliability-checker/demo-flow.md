# 🎬 Demo Flow — WARA Reliability Checker

## Objective

Show how the subagent replaces manual WARA script execution with automated,
contextualized reliability checks that produce executive-ready output.

**Duration:** ~15-20 minutes
**Target audience:** CSAs, CSAMs, SRE/platform teams

---

## Preparation

```bash
# Verify you have resources to scan
az resource list --subscription <sub-id> --query "length(@)"

# Verify Advisor has HA recommendations
az advisor recommendation list --category HighAvailability -o table
```

---

## Act 1: The Problem (2 min)

**Narrative:**

> "How many of you have run a WARA assessment? How long did it take?
> The module says 32 hours, but with validation and report writing,
> it's often 40+. And 3 months later, nobody knows if the findings
> were fixed or if new ones appeared."

### Prompt 1 — Quick reliability scan

```
Run a reliability assessment on my Azure environment.
Show the compliance score and top findings.
```

**What the audience sees:**
- Reliability Score: X% (N/M checks passed)
- Score by WAF pillar (RE:05 Redundancy, RE:09 BCDR, etc.)
- Top findings table with severity and resources

---

## Act 2: Quick Wins (3 min)

**Narrative:**

> "Before we tackle the hard stuff, what can we fix RIGHT NOW?"

### Prompt 2 — Zero-cost fixes

```
Which reliability findings can I fix right now with zero cost,
no downtime, and no risk? List the quick wins.
```

**What the audience sees:**
- List of 🟢 findings with $0 cost
- Each with the exact az command to remediate
- "You can resolve X findings in the next 30 minutes"

---

## Act 3: Zone Redundancy Deep Dive (5 min)

**Narrative:**

> "Zone redundancy is the #1 reliability gap we see across accounts.
> Let's see exactly where we stand."

### Prompt 3 — Zone redundancy focus

```
Which resources are NOT zone-redundant? For each one, show what happens
if an availability zone goes down and what it costs to fix.
```

**What the audience sees:**
- Non-ZR resources listed by type
- Blast radius per resource ("if AZ1 fails, these 3 services go offline")
- Remediation cost from Retail Prices API
- Rollback assessment

---

## Act 4: Executive Summary (3 min)

**Narrative:**

> "Now let's put this in a format your leadership can act on."

### Prompt 4 — Executive report

```
Generate an executive reliability summary. Include the score, top 5
actions prioritized by severity and blast radius, and total remediation cost.
```

**What the audience sees:**
- Score card with trend (if baseline exists)
- Priority matrix: P0/P1/P2/P3
- Total cost: quick wins ($0) vs investments (+$X/mo)
- Recommended execution phases

---

## Act 5: Scheduled Monitoring (2 min, optional)

**Narrative:**

> "What if this ran automatically every week and you got notified
> when something degrades?"

Show the Scheduled Tasks configuration in the portal:
- Weekly schedule, Monday 8 AM
- Agent instructions referencing the subagent
- History of past runs with score trend

---

## Closing

**Narrative:**

> "Instead of a 40-hour manual WARA that runs once and gets forgotten,
> you now have a reliability monitor that runs weekly, catches new issues,
> tracks your score, and tells you exactly what to fix and what it costs.
> No scripts to install, no guest accounts, no manual validation."

---

## Alternative Prompts

```
# APRL vs Advisor comparison
Compare APRL findings with Advisor HighAvailability recommendations.
What does each catch that the other misses?

# Specific resource type focus
Check the reliability of all SQL databases in my subscription.
Are they zone-redundant, geo-replicated, and backed up?

# Remediation plan
For all Critical and High findings, create a phased remediation plan
with cost estimates and rollback procedures.

# Compliance check
How does my environment score against each WAF reliability pillar
(RE:01 through RE:10)?
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| ARG queries return errors | Verify subscription ID and `az graph` extension installed |
| All checks show as passed | Verify the correct subscription/RG is being queried |
| No Advisor recommendations | Resources need 24-48h for Advisor to generate recs |
| Agent runs out of turns | Ask for "score only" first, then deep-dive specific findings |
