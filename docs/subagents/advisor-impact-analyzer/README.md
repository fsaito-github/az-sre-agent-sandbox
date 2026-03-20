# 🔍 Advisor Impact Analyzer

## The Problem

Azure Advisor generates valuable recommendations (reliability, cost, security,
performance), but most remain **unacted for months** because teams cannot answer:

- Will it cause downtime? How long?
- Which workloads will be affected?
- Can I roll back if something goes wrong?
- Do I need a maintenance window?
- Is it safe to do it now?

These questions apply regardless of what runs in the environment — whether it's
a microservices application on AKS, a set of App Services, VMs, or a hybrid
topology.

## The Solution

The **Advisor Impact Analyzer** transforms a vague Advisor recommendation into
a **complete execution plan with risk analysis**, including:

- Dynamic discovery of workloads and their dependencies
- Downtime estimation based on real environment state
- Blast radius mapping (affected workloads and end users)
- Risk classification (🟢 Safe → 🔴 High Risk)
- **💰 Cost impact analysis** with real-time pricing from Azure Retail Prices API
- Step-by-step plan with pre-checks, execution, post-checks, and rollback
- Timing recommendation (maintenance window or immediate execution)

## Key Design Principle: Discover, Don't Assume

The agent does NOT contain a static map of services. It **discovers** what
exists in the environment at analysis time:

```
Static approach (fragile):          Dynamic approach (this agent):
"MongoDB: ❌ CrashLoop"              kubectl get pods → discovers real workloads
                                     → discovers dependencies from env vars
                                     → checks security posture per container
                                     → CONCLUDES what will break in THIS environment
```

This means the agent works in any environment — e-commerce, banking,
SaaS platform, IoT backend — without rewriting its configuration.

## Why isn't this redundant with the native SRE Agent?

| Capability | Native SRE Agent | Advisor Impact Analyzer |
|-----------|-----------------|------------------------|
| Read Advisor recommendations | ✅ Can query | ✅ Queries and analyzes |
| Incident diagnosis | ✅ Core feature | ❌ Not its function |
| **Operational impact analysis** | ❌ | ✅ Specialized |
| **Dependency mapping** | Partial | ✅ Dynamic — App Insights KQL (runtime) + K8s/Azure discovery |
| **Execution plan with rollback** | ❌ | ✅ Structured |
| **Risk classification** | ❌ | ✅ 4 levels |
| **💰 Cost impact analysis** | ❌ | ✅ Real-time pricing (3 sources) |
| **Batch analysis and prioritization** | ❌ | ✅ With execution order |

The SRE Agent knows that Advisor recommends something, but it doesn't analyze
whether it's **safe to execute now** nor produce an operational plan.

## Installation

### 1. Create the Sub-Agent

1. Open your SRE Agent in the [Azure Portal](https://aka.ms/sreagent/portal)
2. Go to the **Subagent builder** tab
3. Click **Create** → select **Subagent**
4. Fill in the fields using the values from [`subagent.yaml`](subagent.yaml):

   | Portal Field | Value from subagent.yaml |
   |-------------|------------------------|
   | **Name** | `Advisor Impact Analyzer` |
   | **Instructions** | Copy the `system_prompt` content |
   | **Handoff Description** | Copy the `handoff_description` content |
   | **Built-in Tools** | Select: Azure CLI, Log Analytics/Kusto query, Python code execution |
   | **Agent Type** | `Review` |

5. Enable **Knowledge base** (see step 2 below)
6. Click **Save**
7. Test in the **Test playground** (view toggle in the Subagent builder)
8. Run **Evaluate** in the playground to check prompt quality (aim for Overall > 80)

> **Tip:** To invoke the subagent in chat, type `/agent`, select
> **Advisor Impact Analyzer**, and ask your question.
>
> **Tip:** Use "Refine with AI" in the playground to get AI-powered
> suggestions for improving your instructions and handoff description.

### 2. Upload Knowledge Files

The knowledge files teach the agent HOW to investigate — they don't contain
pre-built answers. Upload all files for best results.

1. In the SRE Agent portal, go to **Settings** → **Knowledge Base** → **Files**
2. Drag and drop or browse to upload all files from the `knowledge/` folder:

| File | Purpose |
|------|---------|
| [`discovery-procedures.md`](knowledge/discovery-procedures.md) | How to discover and inventory workloads (K8s, PaaS, hybrid) |
| [`dependency-mapping.md`](knowledge/dependency-mapping.md) | How to map dependencies (App Insights KQL, env vars, endpoints) |
| [`risk-classification.md`](knowledge/risk-classification.md) | Risk levels, amplifiers, and reference table by recommendation type |
| [`cost-analysis.md`](knowledge/cost-analysis.md) | 3-source cost pipeline (Retail Prices API, Advisor, Cost Management) |
| [`k8s-recommendations.md`](knowledge/k8s-recommendations.md) | K8s-specific analysis (security, network, node pools) |
| [`paas-recommendations.md`](knowledge/paas-recommendations.md) | PaaS-specific analysis (App Service, SQL, Redis, Storage, Functions) |
| [`impact-table-guide.md`](knowledge/impact-table-guide.md) | Output format, cascade chains, validation, executive summary |

3. Enable **Knowledge base** on the subagent in the Subagent builder
4. Wait for indexing (usually < 1 minute per file)

> **Why multiple files?** The SRE Agent uses semantic search (RAG) to find
> relevant knowledge. Focused files per topic yield better retrieval than
> one large monolithic file.

### How the Integration Works

```
User: "Analyze the Advisor recommendations"
    │
    ↓
SRE Agent (main)
    │
    ├── handoff_description match → invokes Advisor Impact Analyzer
    │
    ↓
Advisor Impact Analyzer (sub-agent)
    │
    ├── 1. DETECTS environment profile (K8s, PaaS, hybrid)
    ├── 2. DISCOVERS real environment state:
    │       ├── kubectl/az → workloads, replicas, security posture
    │       ├── services/endpoints → exposure (LB vs ClusterIP vs private)
    │       ├── App Insights KQL → runtime dependency map (preferred)
    │       └── env vars/connection strings → dependencies (fallback)
    ├── 3. CLASSIFIES workloads by role (customer-facing, data store, etc.)
    ├── 4. Consults Knowledge Base (impact-investigation-framework.md)
    │       → Framework teaches HOW to investigate, not pre-built answers
    ├── 5. REASONS about impact using discovered data
    ├── 6. ASSESSES cost impact using real-time pricing data
    ├── 7. Generates impact table PER WORKLOAD with real data
    │
    ↓
Returns analysis to chat
    │
    ├── User can request deep-dive on a specific recommendation
    ├── User can request execution (handoff to main SRE Agent)
    └── User can request analysis from another sub-agent:
        ├── Security Auditor → deeper security recommendation audit
        ├── SLO Guardian → check if error budget allows the maintenance window
        └── Domain Expert → business impact quantification
```

## Supported Environment Profiles

| Profile | Description | Discovery Method |
|---------|-------------|-----------------|
| **A — Kubernetes + Azure** | AKS with workloads | kubectl + az cli + KQL |
| **B — Azure PaaS** | App Service, Functions, VMs, managed DBs | az cli + KQL |
| **C — Hybrid** | AKS + PaaS resources in same resource group | kubectl + az cli + KQL |
| **D — Partially observable** | Limited tool access or empty results | Best-effort with confidence notes |

## Cost Analysis Sources

Every recommendation includes a **💰 Cost Impact** section. The agent uses
three data sources in priority order:

| Priority | Source | How it works | Auth required? |
|----------|--------|-------------|----------------|
| 1 | **Azure Retail Prices API** | Public REST API queried via `az rest` — returns real-time per-hour pricing by SKU, region, and meter | ❌ No |
| 2 | **Advisor savings data** | Some recommendations include `extendedProperties.savingsAmount` with pre-calculated savings | ✅ Reader role |
| 3 | **Azure Cost Management** | `az costmanagement query` shows actual historical spend on the resource | ✅ Cost Management Reader |

If all three fail, the agent falls back to a static reference table and marks
the estimate as approximate.

The agent always states which source it used:
- "💰 Cost from Azure Retail Prices API (real-time)"
- "💰 Cost from Advisor savings data"
- "💰 Cost estimated (approximate — verify with Azure Pricing Calculator)"

## Test Prompts

### Overview
```
What are the Azure Advisor recommendations for my resource group?
Show a summary with impact analysis for each one.
```

### Specific Analysis
```
Analyze the impact of executing the [redundancy/resize/upgrade]
recommendation. I need: downtime, affected workloads, and rollback plan.
```

### Quick Wins
```
Which Advisor recommendations can I execute right now safely,
without causing downtime? List the "quick wins".
```

### Full Execution Plan
```
Create an execution plan for all Advisor recommendations,
ordered from lowest to highest risk. Include total time estimate.
```

### Batch Execution
```
Which Advisor recommendations can be executed in parallel
and which must be sequential? Optimize total time.
```

### Cost vs Risk
```
For the cost recommendations, what's the estimated savings
versus the operational risk of each change?
```

### Pre-Change Checklist
```
I'm about to execute recommendation X. Give me the complete
pre-check checklist before starting.
```

### Post-Change Validation
```
I just executed recommendation X. What validations should I run
to confirm everything is working?
```

## Risk Classification

| Level | Criteria | Action |
|-------|----------|--------|
| 🟢 **Safe** | No downtime, no data risk, reversible | Execute anytime |
| 🟡 **Low Risk** | Brief disruption (<1 min), reversible | Execute during low traffic |
| 🟠 **Medium Risk** | Downtime 1-15 min, no data loss | Schedule maintenance window |
| 🔴 **High Risk** | Downtime >15 min, data risk, hard to reverse | Approval + window + tested rollback |

## Limitations and Prerequisites

### Prerequisites
- Azure SRE Agent with the sub-agent configured (see Installation above)
- **Reader** role on the subscription/resource group for Advisor recommendations
- **AKS credentials** configured if analyzing Kubernetes workloads
- **Cost Management Reader** role (optional — for actual spend data)

### Limitations
- The agent **analyzes** impact but does **not execute** recommendations automatically
- Cost estimates are based on Azure Retail Prices API (pay-as-you-go rates); actual costs with EA/CSP agreements or reserved instances may differ
- Subscription-level recommendations (not scoped to a resource group) are not analyzed
- The agent cannot assess business logic impact — it maps infrastructure dependencies only. For business impact, delegate to a domain-specific sub-agent
- When the SRE Agent delegates to this sub-agent, output may be summarized or truncated compared to Playground results

## Example Output

The following is an example from an AKS e-commerce lab environment. Your output
will reflect whatever workloads and dependencies the agent discovers in your
actual environment.

```
══════════════════════════════════════════════════════════════════
🔍 ADVISOR IMPACT ANALYSIS
══════════════════════════════════════════════════════════════════

📋 RECOMMENDATION
Category:       Reliability
Description:    Change managed disk redundancy from LRS to ZRS
Resource:       disk-db-pvc-01 (rg-myapp-eastus2)
Advisor Impact: High

──────────────────────────────────────────────────────────────────
⚡ OPERATIONAL IMPACT ASSESSMENT
──────────────────────────────────────────────────────────────────
Risk Level:          🟠 Medium Risk
Estimated Downtime:  ~5-10 minutes
Blast Radius:        database pod → dependent backend services
Data Risk:           None (snapshot recommended as precaution)
Rollback Possible:   ✅ Yes — revert to LRS
Maintenance Window:  ⚠️ Required

Affected Workloads:
| Workload        | Role         | Impact                          | End-user affected?   |
|-----------------|--------------|---------------------------------|---------------------|
| database        | Data store   | Offline during operation        | No (backend)        |
| backend-api     | Internal API | Cannot process requests         | Indirect            |
| admin-panel     | Internal     | Cannot display data             | No (internal)       |
| web-frontend    | Customer-facing | Partial functionality          | Partial             |

💰 COST IMPACT
| Current cost | After change | Monthly delta | Source |
|-------------|-------------|--------------|--------|
| $4.50/month (LRS 8Gi) | $9.00/month (ZRS 8Gi) | +$4.50/month | Azure Retail Prices API |

⚡ CASCADE CHAIN
Disk redundancy change (LRS → ZRS)
  → database pod — offline during disk migration (~5-10 min)
  → backend-api — cannot query database, returns 503
  → web-frontend — checkout and data display fail
  → End user: "page shows error" for ~5-10 minutes

✅ POST-EXECUTION VALIDATION
□ kubectl get pods -n <ns> — all pods Running and Ready
□ kubectl exec <db-pod> -- <db-ping-command> — database responds
□ End-to-end test: submit a request through web-frontend and verify it completes
```
