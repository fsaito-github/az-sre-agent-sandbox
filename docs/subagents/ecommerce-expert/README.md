# E-Commerce Domain Expert — Azure SRE Agent Subagent

## Why This Exists

The native Azure SRE Agent is excellent at Kubernetes infrastructure — it can
read pod status, parse logs, and execute kubectl commands. But it has **no idea
what the application does**.

Ask the SRE Agent _"Is MongoDB being down a big deal?"_ and it will tell you the
pod is in CrashLoopBackOff. It won't tell you that **every order in the pipeline
is now blocked and customers can't complete checkout**.

The E-Commerce Domain Expert fills that gap:

| Capability | SRE Agent | E-Commerce Expert |
|---|---|---|
| Pod status, logs, restarts | ✅ | ✅ (via tools) |
| Kubernetes resource diagnosis | ✅ | — |
| Service dependency graph | — | ✅ |
| Business impact analysis | — | ✅ |
| Recovery priority by business criticality | — | ✅ |
| Order-flow lifecycle knowledge | — | ✅ |
| End-to-end validation after fix | — | ✅ |
| Revenue / customer impact quantification | — | ✅ |

They are **complementary**: the SRE Agent fixes infrastructure; the E-Commerce
Expert tells you _what to fix first_ and _why it matters_.

---

## Architecture at a Glance

```
[Customer Browser] → store-front (Vue.js :8080)
    ├──→ order-service (Node.js :3000) → RabbitMQ (:5672, queue "orders")
    └──→ product-service (Rust :3002)                    ↓
                                          makeline-service (Go :3001) → MongoDB (:27017, db "orderdb")

[Admin Browser] → store-admin (Vue.js :8081)
    ├──→ product-service
    └──→ makeline-service

[virtual-customer] → order-service (~100 orders/hour)
```

Namespace: `pets` · RabbitMQ creds: `guest/guest` · MongoDB: no auth

---

## Installation

1. Open your SRE Agent in the [Azure Portal](https://aka.ms/sreagent/portal)
2. Go to the **Subagent builder** tab
3. Click **Create** → select **Subagent**
4. Fill in the portal fields (Name, Instructions, Handoff Description, Tools, Agent Type) using the values from [`subagent.yaml`](subagent.yaml)
5. Click **Save**
6. Test in the **Test playground** (view toggle in the Subagent builder)
7. To invoke in chat, type `/agent` and select **E-Commerce Domain Expert**

No additional infrastructure or secrets are required — the agent uses the same
tools (Azure CLI, kubectl, Kusto, Python) already available to the SRE Agent.

---

## Test Prompts by Scenario

### 🔴 MongoDB Down

> _"MongoDB is down in the pets namespace. What is the business impact and what
> should I fix first?"_

Expected behavior: The agent explains that order fulfillment is completely
blocked, makeline-service cannot persist orders, quantifies ~100 orders/hour
affected, and recommends restoring MongoDB before restarting any dependent
services.

> _"Can customers still place orders if MongoDB is down?"_

Expected: Yes — orders can still be submitted via order-service and queued in
RabbitMQ, but they will **not be fulfilled** until MongoDB recovers.

### 🔴 RabbitMQ Down

> _"RabbitMQ is unreachable. What happens to orders?"_

Expected: Orders are **lost** — order-service cannot queue them. This is a
data-loss scenario. The agent should flag this as highest priority and recommend
checking RabbitMQ pod health and persistent volume status.

### 🔴 order-service CrashLoopBackOff

> _"order-service keeps crashing. How does this affect the store?"_

Expected: Checkout is broken. No new orders can be placed. The agent should
check logs for the crash reason, note that ~100 orders/hour from
virtual-customer are also failing, and recommend examining the dependency on
RabbitMQ connectivity.

### 🟡 makeline-service Down

> _"makeline-service is down but everything else is green. Is this urgent?"_

Expected: Moderate urgency. Orders are still being placed and queued in
RabbitMQ (no data loss), but fulfillment is stalled. The queue will grow.
store-admin will show stale data. The agent should recommend fixing it soon but
note it's less critical than a data-store outage.

### 🟡 product-service Down

> _"product-service is returning 503. What breaks?"_

Expected: Catalog is unavailable. Customers cannot browse products or place
orders (store-front). Admins cannot manage products (store-admin). Existing
orders in the pipeline are unaffected.

### 🟢 store-admin Down

> _"store-admin is not accessible. How bad is this?"_

Expected: Internal-only impact. Admins cannot view orders or manage products,
but **no customer impact**. The order pipeline continues to function normally.

### 🔵 Multi-Component Failure

> _"Multiple pods are down: mongodb, makeline-service, and order-service. What
> is the recovery order?"_

Expected: The agent identifies MongoDB as the root dependency, recommends
restoring it first, then makeline-service (to drain the queue), and finally
order-service (to resume accepting orders). Explains the cascading dependency.

### ✅ Post-Recovery Validation

> _"I just fixed the MongoDB outage. How do I verify everything is working
> end to end?"_

Expected: Step-by-step validation — check all pods, verify MongoDB accepts
connections, confirm makeline-service is consuming from the RabbitMQ queue,
submit a test order, trace it through the pipeline, verify it appears in
store-admin.

---

## How It Complements the Native SRE Agent

The handoff works like this:

1. **SRE Agent** detects an alert or the user reports an issue.
2. SRE Agent investigates infrastructure (pods, nodes, networking).
3. When the investigation requires **business context** — impact analysis,
   recovery prioritization, order-flow tracing — the SRE Agent hands off to
   the **E-Commerce Domain Expert**.
4. The E-Commerce Expert analyzes the failure through the lens of the service
   dependency graph and order lifecycle.
5. It returns a business-impact assessment and prioritized recovery plan.
6. The **SRE Agent** executes the recovery steps.

This separation keeps the SRE Agent focused on infrastructure while the
E-Commerce Expert provides the domain knowledge needed to make smart decisions
about _what matters most_.

---

## Files in This Directory

| File | Purpose |
|---|---|
| `subagent.yaml` | Field values for the Subagent builder portal |
| `README.md` | This documentation |
| `demo-flow.md` | Step-by-step demo script for live walkthroughs |
