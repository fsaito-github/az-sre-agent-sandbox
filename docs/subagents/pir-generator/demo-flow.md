# PIR Generator — Demo Flow

> **Estimated total time:** 15–20 minutes  
> **Scenario used:** `oom-killed` (order-service)  
> **Prerequisites:** AKS cluster running, Pet Store deployed, SRE Agent configured with PIR Generator sub-agent installed.

---

## Step 0 — Verify Baseline (1 minute)

Confirm the Pet Store is healthy before breaking anything.

**Prompt to SRE Agent:**

```
Check the health of all pods in the pets namespace.
```

**Expected output:** All pods Running, zero restarts, no warnings.

> 💡 If anything is already broken, fix it first or reset the environment before proceeding.

---

## Step 1 — Break the Scenario (30 seconds)

Trigger the OOMKilled scenario. Run this in your terminal (or use the lab's break command):

```bash
break oom-killed
```

This patches the `order-service` deployment to set an artificially low memory limit (e.g., 64 Mi), causing the container to be killed by the kernel OOM killer under normal load.

> ⏳ **Wait 2–3 minutes** for the pod to cycle through a few OOMKilled restarts so there is enough event data for the PIR.

---

## Step 2 — Diagnose with the SRE Agent (3–5 minutes)

Ask the SRE Agent to investigate. This is the standard diagnostic flow — the PIR Generator is **not** involved yet.

**Prompt:**

```
There seems to be an issue with the pets namespace. Can you diagnose what's wrong?
```

**What to expect:**
- The SRE Agent queries pod status and events.
- It identifies `order-service` in `CrashLoopBackOff` with reason `OOMKilled`.
- It explains the root cause: memory limit too low.

**Follow-up prompt to fix:**

```
Can you fix the OOMKilled issue on order-service? Set the memory limit to 512Mi.
```

**What to expect:**
- The SRE Agent patches the deployment or suggests a kubectl command.
- The pod restarts with the new memory limit and stabilizes.

> ⏳ **Wait 2–3 minutes** for the fix to take effect and the pod to show zero recent restarts.

---

## Step 3 — Verify the Fix (1 minute)

Confirm the incident is resolved before generating the PIR.

**Prompt:**

```
Is order-service healthy now? Show me current pod status and restart counts.
```

**Expected output:** order-service Running, 0 recent restarts, all other pods healthy.

---

## Step 4 — Generate the PIR (3–5 minutes)

Now invoke the PIR Generator. You can either ask the SRE Agent to hand off, or prompt directly.

**Option A — Handoff (recommended for demo):**

```
Now that the incident is resolved, generate a Post-Incident Review for the OOMKilled 
incident that just occurred on order-service. Look back 30 minutes.
```

**Option B — Direct and detailed:**

```
Generate a formal Post-Incident Review for the OOMKilled incident in the pets namespace.
Query KubeEvents, ContainerLog, and KubePodInventory for the last 30 minutes.
Include severity classification, TTD/TTM/TTR metrics, and action items.
```

**What to expect (this is the key demo moment):**

1. The PIR Generator runs 4–5 KQL queries against Log Analytics.
2. It runs `kubectl get events -n pets` for additional context.
3. It produces a complete markdown PIR document with all 8 sections:
   - Incident Summary
   - Timeline (table with real timestamps from KQL)
   - Root Cause Analysis
   - Impact Assessment
   - Detection & Response Metrics (TTD / TTM / TTR)
   - What Went Well
   - What Could Be Improved
   - Action Items (table with priorities)

> 💡 **Demo talking point:** "Notice that every timestamp in the timeline comes from actual cluster data — KubeEvents and ContainerLog. The PIR Generator doesn't guess; it queries."

---

## Step 5 — Walk Through the Document (3–5 minutes)

Use the generated PIR to drive a discussion. Highlight these sections:

### 5a — Timeline Table

> **Talking point:** "The timeline is built from KubeEvents. You can see the exact second the first OOMKill happened, when restarts began, when we engaged, and when the fix landed. This is the kind of detail that's tedious to compile manually but critical for a good post-mortem."

### 5b — Detection & Response Metrics

> **Talking point:** "TTD, TTM, and TTR are calculated from the event data. In a real incident, these metrics help you track whether your detection and response are improving over time."

### 5c — Severity Classification

> **Talking point:** "The PIR Generator classified this as SEV2 because order-service was down — customers couldn't place orders. It's not SEV1 because the storefront was still reachable and no data was lost."

### 5d — Action Items

> **Talking point:** "These are actionable next steps: validate memory limits, add HPA, set up proactive alerts. In a real team, you'd assign owners and due dates in this table and track them in your sprint."

---

## Summary — What the Audience Saw

| Phase | Actor | Duration |
|---|---|---|
| Break scenario | Operator (terminal) | 30 sec |
| Wait for events to accumulate | — | 2–3 min |
| Diagnose root cause | SRE Agent | 2–3 min |
| Apply fix | SRE Agent | 1 min |
| Wait for stabilization | — | 2–3 min |
| Generate PIR | PIR Generator sub-agent | 3–5 min |
| Review & discuss | Presenter | 3–5 min |
| **Total** | | **~15–20 min** |

---

## Alternate Scenarios

You can repeat this flow with any of the 10 breakable scenarios. Good alternatives for demos:

| Scenario | Why it demos well |
|---|---|
| `mongodb-down` | Shows cross-service impact (order-service and makeline-service both affected), higher severity |
| `crash-loop` | Rapid restart events create a rich timeline |
| `network-block` | Demonstrates the PIR capturing NetworkPolicy events and inter-service communication failures |
| `high-cpu` | Includes Perf counter data in the PIR, good for showing resource metrics |

**Prompt template for any scenario:**

```
Generate a Post-Incident Review for the [SCENARIO] incident in the pets namespace.
Look back [TIME RANGE]. Include all KQL data and action items.
```

---

## Troubleshooting

| Issue | Solution |
|---|---|
| PIR has "Insufficient data" in sections | Wait longer after breaking the scenario (≥2 min) so events are ingested into Log Analytics |
| KQL queries return empty results | Verify the Log Analytics workspace is connected to the AKS cluster; check `ContainerInsights` solution is enabled |
| PIR Generator not available as handoff | Re-check that `subagent.yaml` was pasted correctly in the Subagent Builder and saved |
| Timeline timestamps look wrong | Ensure your KQL time range covers the incident window; use explicit time range in the prompt |
