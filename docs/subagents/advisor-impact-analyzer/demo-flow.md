# 🎬 Demo Flow — Advisor Impact Analyzer

## Objective

Show how the sub-agent transforms "stuck" Azure Advisor recommendations into
actionable execution plans, resolving the gap that prevents teams from acting.

The agent works with **any environment**. This demo flow uses the AKS Pet Store
lab as a concrete example, but every prompt and technique applies to any Azure
resource group with Advisor recommendations.

**Duration:** ~15-20 minutes
**Target audience:** Teams with unacted Advisor recommendations

---

## Preparation (before the demo)

```bash
# Verify that Advisor recommendations are available
az advisor recommendation list --resource-group <your-rg> -o table

# If no recommendations are visible, Advisor may take up to 24h
# to generate recommendations after deployment. In that case, use
# hypothetical prompts — the agent will still perform dependency analysis.
```

> **Note:** For performance/cost recommendations, resources need to run
> for at least 24-48h with load. For the AKS Pet Store lab specifically,
> running `high-cpu` scenario for 30-60 minutes can generate right-sizing
> recommendations.

---

## Act 1: The Problem (2 min)

**Narrative for the audience:**

> "How many pending Azure Advisor recommendations do you have in your
> environment? 10? 50? 200? The problem isn't that Advisor is wrong — it's
> that nobody can assess whether it's safe to execute the change. Let's fix that."

### Prompt 1 — Show pending recommendations

```
What are all the Azure Advisor recommendations for my resource group?
Show in table format with category, impact, and affected resource.
```

**What the audience sees:**
Table with real Advisor recommendations (reliability, cost, security, etc.)

**Key point:** The agent discovers the environment — it doesn't need to know
what runs there beforehand.

---

## Act 2: Quick Wins (3 min)

**Narrative:**

> "First, let's identify what we can do RIGHT NOW, with zero risk."

### Prompt 2 — Identify safe actions

```
Which of these recommendations are "quick wins" — I can execute them now,
without causing downtime and without risk? Classify each one by risk level.
```

**What the audience sees:**
- Table with 🟢🟡🟠🔴 classification for each recommendation
- Quick wins highlighted (e.g., enable diagnostic settings, soft delete)
- Clear message: "These N can be executed now with zero impact"

**Talking point:**
> "See — X recommendations can be resolved right now, no risk at all.
> These are the ones that sit idle because nobody separated safe from risky."

---

## Act 3: Cost Impact (3 min)

**Narrative:**

> "Before we deep-dive into risky changes, let's understand the financial
> picture. Which recommendations save money? Which ones cost more?"

### Prompt 3 — Cost analysis

```
For each Advisor recommendation, show me the cost impact: will it
increase or decrease my monthly Azure spend? Use real pricing data
and show the total monthly delta if I implement everything.
```

**What the audience sees:**
- Each recommendation tagged with 💰 cost delta (+$X or -$X or $0)
- Source of pricing data (Azure Retail Prices API, Advisor savings, estimate)
- Financial summary: total additional cost vs total savings
- ROI assessment for expensive recommendations

**Talking point:**
> "Now the team knows not just the risk, but the cost. Some recommendations
> save money — those are easy wins. Others cost more — but now you can
> evaluate whether the reliability improvement is worth the investment."

---

## Act 4: Deep Dive on a Risky Recommendation (5 min)

**Narrative:**

> "Now let's take a recommendation that scares people — a redundancy change
> or resize that nobody wants to execute without knowing the impact."

### Prompt 4 — Detailed impact analysis

```
Analyze in depth the impact of executing the [choose a reliability or
performance recommendation]. I want to know: estimated downtime, affected
workloads, whether there's rollback, and the complete execution plan.
```

**Alternative if no reliability recommendations exist:**
```
Analyze the impact of upgrading the AKS node pool to the next
Kubernetes version. Give me the complete plan with pre-checks,
execution, post-checks, and rollback.
```

**What the audience sees:**
- Risk Level with emoji (🟠 Medium Risk)
- Estimated downtime in minutes
- Table of affected workloads with end-user impact flag
- **Complete execution plan:**
  - ☐ Pre-checks (snapshot, verify queues, stop load)
  - Specific az cli / kubectl commands
  - ☐ Post-checks (validate pods, test flows)
  - Rollback plan with commands

**Talking point:**
> "THIS is what was missing. It's not the recommendation itself — it's the
> execution plan with risk analysis. Now the team can make an informed decision."

**Key point for generic environments:** The agent built the workload impact
table from what it discovered — not from a predefined list.

---

## Act 5: Batch Execution Plan (3 min)

**Narrative:**

> "What if I want to resolve ALL recommendations? What's the best order?"

### Prompt 5 — Complete ordered plan

```
Create an execution plan for ALL pending recommendations, ordered
from lowest to highest risk. Identify which can be done in parallel
and estimate total time.
```

**What the audience sees:**
- Optimized execution order
- Grouping: first 🟢, then 🟡, then 🟠, then 🔴
- Which can be parallelized
- Total estimated time
- Clear guidance: "The first N can be done in 1 hour without a maintenance window"

**Talking point:**
> "Instead of isolated recommendations nobody acts on, we have a complete
> operational plan. The team can schedule a window and resolve everything."

---

## Act 6: Execution and Validation (2 min, optional)

**If time permits and there's a 🟢 Safe recommendation:**

### Prompt 6 — Execute a quick win

```
Execute recommendation [chosen quick win] and validate that everything
continues working after the change.
```

**What the audience sees:**
- Agent executes pre-checks
- Applies the change
- Runs post-checks
- Confirms: "✅ Recommendation applied successfully. All workloads operational."

---

## Closing

**Final narrative:**

> "Azure Advisor knows WHAT to do. SRE Agent knows how to diagnose problems.
> The Advisor Impact Analyzer is the bridge: it analyzes WHETHER it's safe
> and HOW to do it. That's what turns stale recommendations into executed actions."

---

## Alternative Prompts

Adapt to your demo environment:

```
# Cost focus
Which Advisor recommendations will generate savings? For each one,
compare the estimated saving with the operational risk of executing.

# Cost focus — total investment
What's the total monthly cost if I implement ALL Advisor recommendations?
Break it down by: savings, additional costs, and net impact.

# Security focus
Analyze the security recommendations from Advisor. Which are most
urgent and which can I apply without causing disruption?

# Specific scenario (any environment)
I need to upgrade Kubernetes on AKS from 1.31 to 1.32.
Analyze the complete impact and give me the execution plan.

# Disk scenario (any environment with managed disks)
Advisor recommends changing managed disk redundancy from LRS to ZRS.
This disk is used by a database pod. Analyze the impact.

# PaaS scenario (App Service environment)
Advisor recommends upgrading my App Service plan from S1 to P1v3.
Analyze the impact on my web apps and slot swaps.

# PaaS scenario — database
Advisor recommends changing my SQL Database from Basic DTU to
Standard vCore. Analyze downtime, data risk, and cost impact.

# PaaS scenario — Redis
Advisor recommends upgrading Redis from Basic to Standard for
replication. What data loss risk is there during migration?

# PaaS scenario — full analysis
Analyze all Advisor recommendations for my resource group.
Note: this environment has no Kubernetes — only App Service,
SQL Database, Redis, and Storage.
```

---

## Demo with the AKS Pet Store Lab

If using the AKS lab from this repository:

```bash
# Ensure the lab is deployed and healthy
kubectl get pods -n pets

# Useful resource group name
# rg-srelab-eastus2 (default)

# To generate more Advisor recommendations, run high-cpu scenario:
kubectl apply -f k8s/scenarios/high-cpu.yaml
# Wait 30-60 minutes, then check Advisor
```

## Demo with a PaaS-only Environment

If using the PaaS test environment:

```bash
# Deploy the PaaS test environment (~5-10 min)
az deployment group create \
  --resource-group <rg> \
  --template-file infra/bicep/paas-test/main.bicep \
  --parameters location=eastus2

# Wait 24h for Advisor to generate recommendations, then use prompts
# from the "Alternative Prompts — PaaS scenario" section above.
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Advisor shows no recommendations | Resources need to run 24-48h for Advisor to generate recommendations. Use hypothetical scenarios in the demo. |
| Recommendations are only "generic" | Run workloads with load for 30-60 min to generate right-sizing recommendations. |
| Agent cannot list recommendations | Verify that the SRE Agent has Reader role on the subscription. |
| Agent assumes wrong workloads | Verify the agent ran discovery commands. If it used old data, ask it to "re-discover the environment first". |
| Agent output differs from Playground | Expected behavior — the main SRE Agent may summarize or truncate the sub-agent's response. Ask for "full detailed report" to get more complete output. |
| Cost data shows "estimate" instead of real prices | The Azure Retail Prices API may be unreachable from the SRE Agent environment. Verify internet access or use the static reference table as fallback. |
