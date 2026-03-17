# 🎬 SLO Guardian — Live Demo Script

> **Audience:** Developers, SREs, platform engineers seeing the Azure SRE Agent for the first time.
>
> **Duration:** ~15 minutes
>
> **Prerequisites:**
> - AKS cluster running the Pet Store app (namespace: `pets`)
> - Virtual-customer load generator active (~100 orders/hour)
> - Azure SRE Agent with SLO Guardian sub-agent installed
> - Azure SRE Agent Playground open in a browser

---

## Act 1 — Healthy State Baseline 🟢

**Goal:** Show the audience what a healthy SLO report looks like.

### Step 1.1 — Open the Playground

Open the Azure SRE Agent Playground in your browser. Make sure the SLO Guardian sub-agent is listed under the active sub-agents.

### Step 1.2 — Request the SLO Report

Type this prompt in the Playground:

```
Show me the current SLO status for all Pet Store services in the pets namespace.
```

**What the audience sees:**

The SLO Guardian queries live metrics and returns a table like this:

```
🛡️ SLO Guardian — Status Report
Reporting window: 30 days ending 2025-07-15T14:30:00Z

| Service          | SLI (actual) | SLO Target | Status | Budget Used | Burn 1h | Burn 6h | Burn 24h |
|------------------|-------------|------------|--------|-------------|---------|---------|----------|
| store-front      | 99.82 %     | 99.5 %     | 🟢     |   8 %       | 0.2     | 0.3     | 0.3      |
| order-service    | 99.97 %     | 99.9 %     | 🟢     |  12 %       | 0.4     | 0.5     | 0.4      |
| product-service  | 99.91 %     | 99.5 %     | 🟢     |   5 %       | 0.1     | 0.2     | 0.2      |
| makeline-service | 99.88 %     | 99.5 %     | 🟢     |   6 %       | 0.2     | 0.2     | 0.3      |
| MongoDB          | 100.00 %    | 99.9 %     | 🟢     |   0 %       | 0.0     | 0.0     | 0.0      |
| RabbitMQ         | 99.95 %     | 99.5 %     | 🟢     |   3 %       | 0.1     | 0.1     | 0.1      |

📋 Deployment Recommendation
All services: ✅ Safe to deploy — error budgets healthy.
```

**Talking points:**

- _"Every service is green. Our error budgets are barely touched."_
- _"Burn rates are well below 1.0, meaning we're consuming budget slower than our pace allows."_
- _"This is the kind of report you'd check before every deployment."_

---

## Act 2 — Inject the Failure 💥

**Goal:** Break order-service with an OOM kill to simulate a real incident.

### Step 2.1 — Trigger OOM on order-service

Open a terminal and run:

```bash
kubectl set resources deployment/order-service \
  -n pets \
  --limits=memory=32Mi \
  --requests=memory=32Mi
```

> **What this does:** Sets the memory limit for order-service to 32 Mi, which is far too low. The container will be OOM-killed repeatedly by the kubelet.

**What the audience sees (optional — show the terminal):**

```bash
kubectl get pods -n pets -w
```

Within 30–60 seconds the order-service pod will start crash-looping:

```
order-service-7b4d9f6c8-x2k1p   0/1   OOMKilled   1   45s
order-service-7b4d9f6c8-x2k1p   0/1   CrashLoopBackOff   2   78s
```

**Talking point:**

- _"We just simulated what happens when a bad config change or memory leak hits production. The service is now crash-looping."_

### Step 2.2 — Wait for Impact

**Wait 3–5 minutes** to let the failure accumulate errors. The virtual-customer is still sending ~100 orders/hour, so requests to order-service are now failing with 5xx errors.

> 💡 **Tip:** Use this time to talk about error budgets conceptually:
> _"Every second that order-service is down, it's burning through our error budget. With a 99.9 % SLO over 30 days, we only have about 43 minutes of allowed downtime for the entire month."_

---

## Act 3 — Show the SLO Impact 🔴

**Goal:** Demonstrate how the SLO Guardian detects and quantifies the impact.

### Step 3.1 — Request the SLO Report Again

Go back to the Playground and type:

```
Show me the current SLO status for all Pet Store services.
```

**What the audience sees:**

```
🛡️ SLO Guardian — Status Report
Reporting window: 30 days ending 2025-07-15T14:45:00Z

| Service          | SLI (actual) | SLO Target | Status | Budget Used | Burn 1h | Burn 6h | Burn 24h |
|------------------|-------------|------------|--------|-------------|---------|---------|----------|
| store-front      | 99.82 %     | 99.5 %     | 🟢     |   8 %       | 0.2     | 0.3     | 0.3      |
| order-service    | 98.50 %     | 99.9 %     | 🔴     |  92 %       | 36.0    | 8.2     | 2.1      |
| product-service  | 99.91 %     | 99.5 %     | 🟢     |   5 %       | 0.1     | 0.2     | 0.2      |
| makeline-service | 99.70 %     | 99.5 %     | 🟡     |  28 %       | 1.8     | 0.6     | 0.4      |
| MongoDB          | 100.00 %    | 99.9 %     | 🟢     |   0 %       | 0.0     | 0.0     | 0.0      |
| RabbitMQ         | 99.80 %     | 99.5 %     | 🟢     |  10 %       | 0.8     | 0.3     | 0.2      |

⚠️  ALERT: order-service is BREACHING its SLO.
    1-hour burn rate: 36.0 — budget will be fully exhausted in ~5 minutes.

📋 Deployment Recommendation
- order-service:    🚫 FREEZE all deploys — error budget nearly exhausted.
- makeline-service: ⚠️ Deploy with caution — budget consumption elevated.
- All others:       ✅ Safe to deploy.
```

**Talking points:**

- _"order-service went from green to red. Its SLI dropped to 98.5 %, well below the 99.9 % target."_
- _"The 1-hour burn rate is 36 — that's 36× the sustainable pace. At this rate, we'd burn the entire monthly budget in minutes."_
- _"Notice makeline-service turned yellow too — it depends on order-service, so cascading failures are showing up in the data."_
- _"The Guardian automatically recommends freezing deploys for order-service."_

### Step 3.2 — Drill into the Details

Type this prompt:

```
What caused the error budget burn on order-service?
Show me the timeline of failures in the last 15 minutes.
```

**What the audience sees:**

The SLO Guardian queries pod events and AppRequests to show a timeline of OOM kills, CrashLoopBackOff events, and the corresponding spike in 5xx errors.

**Talking point:**

- _"The agent correlates the SLO breach back to the root cause — OOMKilled pods — without us having to dig through logs manually."_

---

## Act 4 — Fix the Issue ✅

**Goal:** Restore order-service and show the SLO recovering.

### Step 4.1 — Remove the Memory Constraint

In your terminal:

```bash
kubectl set resources deployment/order-service \
  -n pets \
  --limits=memory=256Mi \
  --requests=memory=128Mi
```

### Step 4.2 — Verify Recovery

```bash
kubectl get pods -n pets -l app=order-service -w
```

Wait until the pod shows `Running` and `1/1 READY`.

**Talking point:**

- _"We've restored the memory limits. The pod should stabilize in a few seconds."_

---

## Act 5 — Show Recovery & Deploy Readiness 📊

**Goal:** Show that the SLO Guardian reflects the recovery and updates its recommendation.

### Step 5.1 — Wait 2–3 Minutes

Let the virtual-customer send some successful requests so the short-window burn rates drop.

### Step 5.2 — Request the Report One More Time

```
Show me the current SLO status for all Pet Store services.
Is it safe to deploy order-service now?
```

**What the audience sees:**

```
🛡️ SLO Guardian — Status Report
Reporting window: 30 days ending 2025-07-15T15:00:00Z

| Service          | SLI (actual) | SLO Target | Status | Budget Used | Burn 1h | Burn 6h | Burn 24h |
|------------------|-------------|------------|--------|-------------|---------|---------|----------|
| store-front      | 99.82 %     | 99.5 %     | 🟢     |   8 %       | 0.2     | 0.3     | 0.3      |
| order-service    | 98.65 %     | 99.9 %     | 🔴     |  88 %       | 0.5     | 6.8     | 2.0      |
| product-service  | 99.91 %     | 99.5 %     | 🟢     |   5 %       | 0.1     | 0.2     | 0.2      |
| makeline-service | 99.72 %     | 99.5 %     | 🟡     |  24 %       | 0.3     | 0.5     | 0.4      |
| MongoDB          | 100.00 %    | 99.9 %     | 🟢     |   0 %       | 0.0     | 0.0     | 0.0      |
| RabbitMQ         | 99.82 %     | 99.5 %     | 🟢     |   8 %       | 0.4     | 0.3     | 0.2      |

📋 Deployment Recommendation
- order-service: 🛑 Hold non-critical deploys.
  The 1-hour burn rate has dropped to 0.5 (recovering), but 88% of the monthly
  budget has been consumed. Only 5.2 minutes of downtime remain before SLO breach
  for the rest of the month.
  Recommendation: Wait for the next budget window or request an SLO exception.
```

**Talking points:**

- _"The 1-hour burn rate dropped from 36 back to 0.5 — the service is healthy again."_
- _"But look at the budget: 88 % consumed. Even though we fixed the incident, we've used almost all our reliability margin for the month."_
- _"The Guardian says: hold deploys. Any new deployment that introduces even a small regression could push us over the edge."_
- _"This is the power of SLO-based thinking — it's not just 'is it up right now?' but 'how much room do we have for future risk?'"_

---

## Key Takeaways (for the audience)

Summarize with these points:

1. **SLOs quantify reliability** — not just "is it up?" but "how reliable has it been?"
2. **Error budgets create shared language** — product and engineering teams can agree on when to push features vs. invest in reliability.
3. **Burn rates enable early detection** — a high 1-hour burn rate tells you about a problem long before the 30-day SLI drops noticeably.
4. **Deploy decisions become data-driven** — no more guessing whether it's safe to ship.
5. **The SLO Guardian automates all of this** — it queries live data and gives you an answer in seconds.

---

## Cleanup

After the demo, reset the environment:

```bash
# Restore order-service to its original resource spec
kubectl rollout undo deployment/order-service -n pets

# Verify all pods are healthy
kubectl get pods -n pets
```

---

## Troubleshooting the Demo

| Issue | Fix |
|---|---|
| SLO report shows "No data" | Verify virtual-customer is running: `kubectl get pods -n pets -l app=virtual-customer` |
| OOM kill doesn't trigger | Lower the memory limit further to `16Mi` |
| Burn rate doesn't spike | Wait longer (3–5 min) — the virtual-customer needs time to generate failed requests |
| makeline-service stays green | This is normal if makeline-service doesn't directly call order-service in your deployment topology |
