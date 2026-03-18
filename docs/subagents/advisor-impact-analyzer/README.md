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
| **Dependency mapping** | Partial | ✅ Dynamic (K8s + Azure) |
| **Execution plan with rollback** | ❌ | ✅ Structured |
| **Risk classification** | ❌ | ✅ 4 levels |
| **Batch analysis and prioritization** | ❌ | ✅ With execution order |

The SRE Agent knows that Advisor recommends something, but it doesn't analyze
whether it's **safe to execute now** nor produce an operational plan.

## Installation

### 1. Create the Sub-Agent

1. Open the SRE Agent in the [Azure Portal](https://aka.ms/sreagent/portal)
2. Go to **Builder** → **Subagent Builder**
3. Click **+ Create subagent**
4. Paste the contents of [`subagent.yaml`](subagent.yaml)
5. Save and test in the **Playground**

### 2. Upload the Knowledge File

The knowledge file teaches the agent to **investigate** impact dynamically.
It works in ANY environment.

1. In the SRE Agent portal, go to **Builder** → **Knowledge Base**
2. Click **Add file** and upload:

| File | Contents |
|------|----------|
| [`impact-investigation-framework.md`](knowledge/impact-investigation-framework.md) | Investigation framework: how to detect environment profiles, discover dependencies, assess risk by recommendation type, and build impact tables using real data |

3. Wait for indexing (usually < 1 minute)

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
    │       └── env vars/connection strings → dependencies
    ├── 3. CLASSIFIES workloads by role (customer-facing, data store, etc.)
    ├── 4. Consults Knowledge Base (impact-investigation-framework.md)
    │       → Framework teaches HOW to investigate, not pre-built answers
    ├── 5. REASONS about impact using discovered data
    ├── 6. Generates impact table PER WORKLOAD with real data
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
```
