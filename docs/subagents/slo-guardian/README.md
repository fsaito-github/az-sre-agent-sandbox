# 🛡️ SLO Guardian — Sub-agent for Azure SRE Agent

> **Automated Service Level Objective tracking, error-budget management, and deploy-readiness decisions for the AKS Pet Store demo.**

---

## Why SLO Guardian?

The native Azure SRE Agent is excellent at reactive troubleshooting — finding the root cause of an alert, diagnosing a pod crash, or suggesting a fix. However, it does **not** natively:

| Capability | Native SRE Agent | SLO Guardian |
|---|---|---|
| Track SLOs over rolling windows | ❌ | ✅ |
| Calculate error budgets from live SLIs | ❌ | ✅ |
| Compute multi-window burn rates (1 h / 6 h / 24 h) | ❌ | ✅ |
| Make deploy-or-freeze recommendations based on budget | ❌ | ✅ |
| Produce a standardized SLO status report on demand | ❌ | ✅ |

The SLO Guardian **complements** the SRE Agent by adding a **proactive, SLO-driven layer** that answers: _"Can we safely deploy right now?"_ and _"How much reliability margin do we have left?"_

---

## SLOs Defined for the Pet Store

| Service | SLI | Target | Window |
|---|---|---|---|
| store-front | HTTP success rate (non-5xx / total) | 99.5 % | 30 days |
| order-service | HTTP success rate **AND** p99 latency < 500 ms | 99.9 % | 30 days |
| product-service | HTTP success rate | 99.5 % | 30 days |
| makeline-service | HTTP success rate | 99.5 % | 30 days |
| MongoDB | Pod uptime (Running / total time) | 99.9 % | 30 days |
| RabbitMQ | Availability + queue depth < 1 000 msgs | 99.5 % | 30 days |

---

## Installation

1. Open the **Azure SRE Agent** portal.
2. Navigate to **Settings → Subagent Builder**.
3. Click **+ New Sub-agent**.
4. Paste the entire contents of [`subagent.yaml`](./subagent.yaml) into the configuration editor.
5. Click **Save & Activate**.

The SLO Guardian now appears as an available sub-agent in the Agent Playground and will be automatically invoked when the SRE Agent determines that an SLO-related question has been asked.

---

## Test Prompts for the Playground

Copy-paste these into the Azure SRE Agent Playground to exercise the SLO Guardian:

### Basic SLO Report

```
Show me the current SLO status for all Pet Store services.
```

### Single-Service Deep Dive

```
What is the error budget status for order-service? Include burn rates.
```

### Deployment Readiness

```
Is it safe to deploy a new version of store-front right now?
```

### Latency-Specific Check

```
What is the p99 latency for order-service over the last 24 hours?
Is it within SLO?
```

### Error Budget Projection

```
At the current burn rate, when will order-service exhaust its error budget?
```

### Compare Services

```
Which Pet Store services are closest to breaching their SLOs?
Rank them by error budget remaining.
```

### Post-Incident Budget Impact

```
order-service was OOM-killed for the last 10 minutes.
How much error budget did we burn?
```

---

## Example KQL Queries Used Internally

These are the queries the SLO Guardian runs behind the scenes. You do not need to type them — they are documented here for transparency and troubleshooting.

### HTTP Success Rate (Availability SLI)

```kql
AppRequests
| where TimeGenerated > ago(30d)
| where AppRoleName == "order-service"
| summarize
    TotalRequests   = count(),
    SuccessRequests = countif(ResultCode !startswith "5")
| extend SLI_Pct = round(todouble(SuccessRequests) / TotalRequests * 100, 4)
```

### p99 Latency

```kql
AppRequests
| where TimeGenerated > ago(30d)
| where AppRoleName == "order-service"
| summarize P99_ms = percentile(DurationMs, 99)
```

### Pod Uptime (for MongoDB / RabbitMQ)

```kql
KubePodInventory
| where TimeGenerated > ago(30d)
| where Namespace == "pets"
| where Name startswith "mongodb"
| summarize
    TotalRecords   = count(),
    RunningRecords = countif(PodStatus == "Running")
| extend UptimePct = round(todouble(RunningRecords) / TotalRecords * 100, 4)
```

### RabbitMQ Queue Depth

```kql
InsightsMetrics
| where TimeGenerated > ago(1h)
| where Namespace == "prometheus"
| where Name == "rabbitmq_queue_messages"
| summarize MaxDepth = max(Val)
```

### Multi-Window Burn Rate (1 h example)

```kql
let slo_target = 0.999;
AppRequests
| where TimeGenerated > ago(1h)
| where AppRoleName == "order-service"
| summarize
    Total = count(),
    Bad   = countif(ResultCode startswith "5")
| extend
    ErrorRate = todouble(Bad) / Total,
    BurnRate  = (todouble(Bad) / Total) / (1 - slo_target)
```

> **Interpretation:** A burn rate of **1.0** means the budget is being consumed exactly on pace. A burn rate of **14.4** means the budget will be exhausted in ~2 hours — this is page-worthy.

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                Azure SRE Agent                       │
│                                                      │
│   User prompt ──► Orchestrator ──► SLO Guardian      │
│                        │              │               │
│                        │         ┌────┴────┐          │
│                        │         │  Tools  │          │
│                        │         ├─────────┤          │
│                        │         │ KQL     │──► Log Analytics
│                        │         │ kubectl │──► AKS cluster
│                        │         │ az cli  │──► Azure APIs
│                        │         │ Python  │──► calculations
│                        │         └─────────┘          │
│                        │                              │
│                        ▼                              │
│                  Response to user                     │
└──────────────────────────────────────────────────────┘
```

---

## Troubleshooting

| Problem | Likely Cause | Fix |
|---|---|---|
| "No data returned" for AppRequests | Application Insights not wired to the service | Verify the app instrumentation key in the deployment YAML |
| Pod uptime shows 0 % | Wrong pod name prefix in the query | Check `kubectl get pods -n pets` for actual names |
| Queue depth query fails | Prometheus metrics not scraped | Ensure the RabbitMQ Prometheus plugin is enabled and Azure Monitor scrape config includes it |
| Burn rate shows `NaN` | Zero requests in the window | The service may not be receiving traffic — check virtual-customer is running |

---

## References

- [Google SRE Workbook — SLOs](https://sre.google/workbook/implementing-slos/)
- [Google SRE Book — Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
- [Azure Monitor KQL Reference](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
- [Azure SRE Agent Documentation](https://learn.microsoft.com/en-us/azure/sre-agent/)
