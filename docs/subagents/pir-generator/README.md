# PIR Generator — Azure SRE Agent Sub-agent

## What is this?

The **Post-Incident Review (PIR) Generator** is a custom sub-agent for the Azure SRE Agent that produces formal, publication-ready post-mortem documents following Google SRE and Microsoft ICM standards.

### Why isn't this redundant with the SRE Agent?

The built-in SRE Agent is designed to **diagnose and remediate** — it finds the broken pod, explains the root cause, and suggests or applies a fix. What it does *not* do is produce a **structured post-incident document** suitable for stakeholder review, compliance, or process improvement.

The PIR Generator fills that gap:

| Capability | SRE Agent | PIR Generator |
|---|---|---|
| Diagnose root cause | ✅ | ❌ (relies on SRE Agent) |
| Suggest / apply fix | ✅ | ❌ |
| Produce formal PIR document | ❌ | ✅ |
| Calculate TTD / TTM / TTR metrics | ❌ | ✅ |
| Classify severity (SEV1–4) | ❌ | ✅ |
| Generate prioritized action items | ❌ | ✅ |
| Blameless post-mortem tone | — | ✅ |

The intended workflow is: **Diagnose → Fix → PIR**.

---

## Installation

1. Open your SRE Agent in the [Azure Portal](https://aka.ms/sreagent/portal)
2. Go to the **Subagent builder** tab
3. Click **Create** → select **Subagent**
4. Fill in the portal fields (Name, Instructions, Handoff Description, Tools, Agent Type) using the values from [`subagent.yaml`](./subagent.yaml)
5. Click **Save**
6. Test in the **Test playground** (view toggle in the Subagent builder)
7. To invoke in chat, type `/agent` and select **PIR Generator**

> **Prerequisites:** The SRE Agent must already have access to the AKS cluster and its Log Analytics workspace.

---

## Test Prompts

Use these prompts after breaking a scenario and letting the SRE Agent diagnose/fix it.

### General-purpose

```
Generate a Post-Incident Review for the incident that just occurred in the pets namespace.
```

### Scenario-specific

| Scenario | Prompt |
|---|---|
| **oom-killed** | `Generate a PIR for the OOMKilled incident affecting order-service in the pets namespace. Look back 1 hour.` |
| **crash-loop** | `Create a post-mortem for the CrashLoopBackOff on product-service. Include container restart counts.` |
| **image-pull-backoff** | `Write a PIR for the ImagePullBackOff failure. Focus on the deployment pipeline gap that allowed a bad image tag.` |
| **high-cpu** | `Generate a PIR for the high-CPU incident. Include Perf counter data and correlate with request latency.` |
| **pending-pods** | `Create a post-incident review for pods stuck in Pending state. Check node resource pressure.` |
| **probe-failure** | `Write a PIR for the readiness/liveness probe failures on store-front.` |
| **network-block** | `Generate a PIR for the network connectivity issue between services. Check NetworkPolicy events.` |
| **missing-config** | `Create a post-mortem for the missing ConfigMap/Secret that prevented pod startup.` |
| **mongodb-down** | `Write a PIR for the MongoDB outage. Include impact on order-service and makeline-service.` |
| **service-mismatch** | `Generate a PIR for the service selector mismatch. Focus on why traffic was not reaching the pods.` |

### With custom time range

```
Generate a PIR for incidents in the pets namespace between 2025-01-15T14:00:00Z and 2025-01-15T15:30:00Z.
```

---

## Example PIR Output Structure

Below is the skeleton of a generated PIR. Actual content is populated from live KQL and kubectl data.

```markdown
# Post-Incident Review — OOMKilled: order-service

**Date:** 2025-01-15  
**Severity:** SEV2  
**Duration:** 47 minutes  
**Author:** PIR Generator (Azure SRE Agent)

---

## 1. Incident Summary

The order-service pod in the `pets` namespace was repeatedly OOMKilled starting
at 14:02 UTC due to a memory limit of 128 Mi being insufficient for peak load.
The store-front returned HTTP 502 errors for all order-related operations for
approximately 47 minutes until the memory limit was increased to 512 Mi.

## 2. Timeline

| Time (UTC) | Event | Source |
|---|---|---|
| 14:02:13 | Pod order-service-7b8f4c killed (OOMKilled) | KubeEvents |
| 14:02:45 | Pod restarted (attempt 1) | KubeEvents |
| 14:05:22 | Pod killed again (OOMKilled, restart 2) | KubeEvents |
| 14:12:00 | Alert fired: pod restart count > 3 | Azure Monitor |
| 14:18:30 | SRE Agent diagnosed OOMKilled root cause | Agent log |
| 14:35:00 | Memory limit patched to 512 Mi | kubectl |
| 14:49:00 | Pod stable, zero restarts for 10 min | KubePodInventory |

## 3. Root Cause Analysis

**Trigger:** Increased order volume during a promotional event caused
order-service heap usage to exceed the 128 Mi container memory limit.

**Underlying cause:** The memory limit was set to a default value during
initial deployment and was never load-tested or tuned for production traffic
patterns.

## 4. Impact Assessment

- **Services affected:** order-service (direct), store-front (indirect — 502s)
- **Customer impact:** Customers could not place orders for ~47 minutes
- **Data impact:** No data loss — orders failed at the API layer before write
- **Blast radius:** Single service (order-service), single pod

## 5. Detection & Response Metrics

| Metric | Value |
|---|---|
| Time to Detect (TTD) | 10 min |
| Time to Mobilize (TTM) | 6 min |
| Time to Resolve (TTR) | 31 min |
| Total Incident Duration | 47 min |

## 6. What Went Well

- SRE Agent correctly identified the OOMKilled reason within seconds of engagement
- kubectl access was available and functional
- Container logs clearly showed the memory pressure pattern

## 7. What Could Be Improved

- No proactive memory utilization alert — detection relied on pod restart count
- Memory limits were never validated against realistic load profiles
- No Horizontal Pod Autoscaler (HPA) configured for order-service

## 8. Action Items

| Priority | Action | Owner | Due Date |
|---|---|---|---|
| P0 | Validate memory limits for all services against load test data | TBD | +7 days |
| P1 | Configure HPA for order-service with memory-based scaling | TBD | +14 days |
| P1 | Add memory utilization alert at 80% of limit | TBD | +14 days |
| P2 | Establish quarterly load-testing cadence | TBD | +30 days |
```

---

## Integration with Incident Workflow

The PIR Generator is designed to be the **final step** in a three-phase incident lifecycle:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────────┐
│  1. DETECT   │────▶│  2. RESPOND  │────▶│  3. REVIEW (PIR) │
│  & DIAGNOSE  │     │  & MITIGATE  │     │  & IMPROVE       │
│              │     │              │     │                  │
│  SRE Agent   │     │  SRE Agent   │     │  PIR Generator   │
│  identifies  │     │  applies fix │     │  queries data,   │
│  root cause  │     │  or suggests │     │  writes formal   │
│              │     │  remediation │     │  post-mortem     │
└─────────────┘     └─────────────┘     └─────────────────┘
```

1. **Break** a scenario (e.g., `break oom-killed`).
2. **Ask the SRE Agent** to diagnose and fix the issue.
3. **Wait** for the fix to stabilize (~2–5 minutes).
4. **Ask the SRE Agent** to hand off to the PIR Generator, or invoke it directly:
   > "Generate a Post-Incident Review for the incident that just occurred."
5. The PIR Generator runs KQL queries and kubectl commands, then outputs a complete markdown PIR.
6. **Copy** the PIR into your incident management system, wiki, or ADO work item.

---

## Tips

- **Run the PIR soon after the incident** — KQL data retention means older events may age out of the default query window.
- **Specify a time range** if the incident happened more than 2 hours ago.
- **Review the Action Items table** with your team — the PIR Generator suggests actions but owners and dates must be confirmed by humans.
- The PIR is **blameless by design** — it focuses on systems and processes, not individuals.
