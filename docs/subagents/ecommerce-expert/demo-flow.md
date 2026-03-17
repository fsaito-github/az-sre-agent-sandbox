# E-Commerce Domain Expert — Demo Flow

A step-by-step script for demonstrating the E-Commerce Domain Expert subagent
in a live walkthrough. Total demo time: ~10 minutes.

---

## Prerequisites

- AKS cluster running with the pet-store app deployed in the `pets` namespace.
- All services healthy (`kubectl get pods -n pets` — all Running/Ready).
- The E-Commerce Domain Expert subagent installed in the Azure SRE Agent
  (see [README.md](README.md) for installation steps).
- Access to the Azure SRE Agent chat interface.

---

## Act 1 — Establish Baseline (1 min)

### Step 1: Verify the application is healthy

Run in your terminal:

```bash
kubectl get pods -n pets
```

**Expected:** All pods (store-front, store-admin, order-service,
product-service, makeline-service, rabbitmq, mongodb, virtual-customer) show
`Running` with ready containers.

### Step 2: Confirm order flow is working

```bash
# Check RabbitMQ queue — should show "orders" queue with 0 or low message count
kubectl exec -n pets deployment/rabbitmq -- rabbitmqctl list_queues

# Check MongoDB has recent orders
kubectl exec -n pets deployment/mongodb -- mongosh orderdb --eval "db.orders.countDocuments()"
```

**Expected:** The "orders" queue exists with a small or zero message backlog.
MongoDB shows a growing order count.

> **Talking point:** _"Everything is green. Orders are flowing from
> virtual-customer through the pipeline to MongoDB. Let's break something."_

---

## Act 2 — Break MongoDB (1 min)

### Step 3: Simulate a MongoDB outage

```bash
kubectl scale deployment mongodb -n pets --replicas=0
```

**Expected:** The mongodb pod terminates. After 10-20 seconds, makeline-service
starts logging connection errors.

> **Talking point:** _"We've just lost our database. Let's see what the
> E-Commerce Domain Expert thinks about this."_

---

## Act 3 — Business Impact Analysis (3 min)

### Step 4: Ask for business impact

In the Azure SRE Agent chat, type:

> **Prompt:** _"MongoDB appears to be down in the pets namespace. What is the
> business impact of this outage?"_

**Expected response from the agent:**

The E-Commerce Domain Expert should:

1. **Confirm the outage** — verify that the mongodb deployment has 0 replicas
   or the pod is missing.
2. **Explain the business impact in plain terms:**
   - Order fulfillment is completely blocked.
   - makeline-service cannot persist orders to the database.
   - Orders are still being accepted by order-service and queued in RabbitMQ,
     so **no orders are lost yet** — but they are piling up.
   - The RabbitMQ queue depth is growing (~1-2 messages/minute from
     virtual-customer).
   - store-admin will show stale order data.
   - **Customers can still browse** (product-service is unaffected) **and
     submit orders** (order-service is up), but those orders will not be
     fulfilled.
3. **Quantify the impact:** ~100 orders/hour are being queued but not
   fulfilled. The longer the outage, the larger the backlog.

> **Talking point:** _"Notice how the agent doesn't just say 'pod is down' —
> it explains what that means for the business. It knows the dependency chain."_

### Step 5: Ask about cascading effects

> **Prompt:** _"Which other services are affected by the MongoDB outage? Is
> there any risk of data loss?"_

**Expected response:**

- **makeline-service** is directly affected — it depends on MongoDB to write
  orders.
- **store-admin** is indirectly affected — it reads from makeline-service.
- **No data loss** as long as RabbitMQ remains healthy — orders are buffered
  in the queue.
- **Risk escalation:** If RabbitMQ's queue fills up or RabbitMQ itself goes
  down while MongoDB is offline, **then** orders will be lost.

> **Talking point:** _"The agent traces the full dependency chain and
> identifies where the real risk is — it's not MongoDB alone, it's what happens
> if RabbitMQ overflows while we're down."_

---

## Act 4 — Recovery Priority (2 min)

### Step 6: Ask for a recovery plan

> **Prompt:** _"Multiple things look unhealthy now. What should I fix first
> and in what order?"_

**Expected response:**

The agent should provide a prioritized recovery plan:

1. **First: Restore MongoDB** — it is the root dependency. Without it,
   restarting other services just generates more errors.
2. **Second: Verify makeline-service recovers** — once MongoDB is back, it
   should automatically reconnect and start draining the RabbitMQ queue.
3. **Third: Monitor the queue** — confirm the backlog of orders is being
   processed and the queue depth is decreasing.
4. **No action needed** for order-service, product-service, store-front —
   they were never directly broken.

The agent should also provide the specific commands or recommend the SRE Agent
execute the fix.

> **Talking point:** _"The agent recommends fixing the data store first, not
> the thing that's throwing the most errors. That's business-aware
> prioritization."_

---

## Act 5 — Fix and Recover (1 min)

### Step 7: Restore MongoDB

```bash
kubectl scale deployment mongodb -n pets --replicas=1
```

**Expected:** The mongodb pod starts and reaches Running/Ready state within
30-60 seconds.

### Step 8: Wait for automatic recovery

Wait 30-60 seconds for makeline-service to reconnect to MongoDB and start
draining the RabbitMQ queue.

> **Talking point:** _"Now let's ask the agent to validate the full pipeline."_

---

## Act 6 — End-to-End Validation (2 min)

### Step 9: Ask for post-recovery validation

> **Prompt:** _"I've restored MongoDB. Can you validate that the entire order
> flow is working end to end?"_

**Expected response:**

The agent should perform (or instruct you to perform) these validation steps:

1. ✅ **All pods Running** — `kubectl get pods -n pets` shows everything
   healthy.
2. ✅ **MongoDB accepting connections** — can connect to port 27017, database
   "orderdb" is accessible.
3. ✅ **RabbitMQ queue draining** — the "orders" queue message count is
   decreasing or at 0 (backlog from the outage is being processed).
4. ✅ **makeline-service consuming** — logs show successful order processing,
   no connection errors.
5. ✅ **New orders flowing** — order count in MongoDB is increasing, matching
   the virtual-customer rate (~100/hour).
6. ✅ **store-admin showing current data** — makeline-service is returning
   fresh order data.

> **Talking point:** _"The agent doesn't just check if pods are green — it
> validates the full business flow from order submission to fulfillment. That's
> the difference between infrastructure monitoring and business-aware SRE."_

---

## Closing Summary

| Demo Phase | What It Shows |
|---|---|
| Baseline | The agent understands the healthy order flow |
| Break | Simple fault injection for the demo |
| Impact Analysis | Translates infrastructure failure → business impact |
| Cascading Effects | Traces the full dependency graph, identifies risk |
| Recovery Priority | Recommends fix order based on business criticality |
| Fix & Validate | End-to-end validation beyond "pods are green" |

### Key Takeaways for the Audience

1. **The SRE Agent knows Kubernetes. The E-Commerce Expert knows the
   business.** Together, they provide complete incident response.
2. **Business impact in seconds** — no need to page a developer who knows the
   app architecture.
3. **Smart recovery ordering** — fix the root dependency first, not the
   loudest alert.
4. **End-to-end validation** — confirm the business flow works, not just the
   infrastructure.
