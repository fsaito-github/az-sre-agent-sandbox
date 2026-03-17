# 🎬 Security Posture Auditor — Demo Flow

A step-by-step script for demonstrating the Security Posture Auditor sub-agent
using the pet store e-commerce lab (AKS, namespace: `pets`).

**Total demo time:** 10–15 minutes

---

## Pre-Demo Checklist

- [ ] AKS cluster is running and the `pets` namespace has all services deployed
- [ ] The Security Posture Auditor sub-agent is installed via Subagent Builder
- [ ] You have the Azure SRE Agent chat open in the portal
- [ ] Verify services are running: `kubectl get pods -n pets` shows all pods in Running state

**Services expected:**
store-front, store-admin, order-service, product-service, makeline-service,
virtual-customer, mongodb, rabbitmq

---

## Step 1 — Set the Stage (1 minute)

**What to say to the audience:**

> "The Azure SRE Agent is great at diagnosing incidents — 'why is my pod crashing?',
> 'what caused this alert?' But what about finding security issues *before* they
> become incidents? That's where sub-agents come in. I've built a Security Posture
> Auditor that proactively scans our cluster for misconfigurations."

---

## Step 2 — Run the Full Audit (3–4 minutes)

**Prompt to type:**

```
Run a full security posture audit on the pets namespace.
```

**What the agent will do:**
1. Query all pods in the `pets` namespace
2. Inspect container security contexts
3. Check image tags and registries
4. Scan environment variables for hardcoded credentials
5. Look for NetworkPolicies and PodDisruptionBudgets
6. Review RBAC and service account configuration

**What the audience will see:**

The agent will produce a structured report that includes:

- **Risk Score:** Approximately 15–35/100 (High Risk) — this is the attention-grabber
- **Critical findings:** Hardcoded RabbitMQ `guest/guest` credentials in plaintext
- **High findings:** Containers running as root, no `readOnlyRootFilesystem`, unauthenticated MongoDB
- **Medium findings:** All images on `:latest`, no NetworkPolicy, no PDBs
- **Low findings:** Default service account usage, auto-mounted SA tokens

**Demo tip:** Let the report render fully. The risk score and the red "Critical"
findings are the most impactful visual moments.

**What to say:**

> "Look at that risk score — we're at about 25 out of 100. And we have a critical
> finding: RabbitMQ credentials are hardcoded in plaintext as environment variables.
> Let's dig into that."

---

## Step 3 — Deep Dive on a Critical Finding (2–3 minutes)

**Prompt to type:**

```
Show me the details of the hardcoded credentials finding. Which deployments are
affected and what are the actual values?
```

**What the audience will see:**

The agent will show:
- The specific pods/deployments with the hardcoded `RABBITMQ_DEFAULT_USER=guest`
  and `RABBITMQ_DEFAULT_PASS=guest` environment variables
- Which services are affected (order-service, makeline-service, rabbitmq)
- The CIS Benchmark reference (5.4.1)
- Why this is critical: if an attacker gains access to any pod, they can read
  these credentials from the environment and pivot to RabbitMQ

**What to say:**

> "These are real credentials, visible in the pod spec. Anyone with kubectl access
> can see them. And the password is 'guest' — the RabbitMQ default. In a real
> environment, this is how lateral movement happens."

---

## Step 4 — Request Remediation (2–3 minutes)

**Prompt to type:**

```
Generate a remediation plan for the critical and high severity findings. Include
YAML I can apply.
```

**What the audience will see:**

The agent will produce remediation steps with ready-to-apply YAML, including:

1. **Kubernetes Secret for RabbitMQ credentials:**
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: rabbitmq-credentials
     namespace: pets
   type: Opaque
   stringData:
     username: rabbitmq-admin
     password: <generated-strong-password>
   ```

2. **Updated deployment snippet using secretKeyRef:**
   ```yaml
   env:
     - name: RABBITMQ_DEFAULT_USER
       valueFrom:
         secretKeyRef:
           name: rabbitmq-credentials
           key: username
     - name: RABBITMQ_DEFAULT_PASS
       valueFrom:
         secretKeyRef:
           name: rabbitmq-credentials
           key: password
   ```

3. **SecurityContext patch for containers:**
   ```yaml
   securityContext:
     runAsNonRoot: true
     readOnlyRootFilesystem: true
     allowPrivilegeEscalation: false
     capabilities:
       drop:
         - ALL
   ```

4. **Default-deny NetworkPolicy:**
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: NetworkPolicy
   metadata:
     name: default-deny-all
     namespace: pets
   spec:
     podSelector: {}
     policyTypes:
       - Ingress
       - Egress
   ```

**What to say:**

> "The agent doesn't just find problems — it gives us the fix. These are
> ready-to-apply YAML snippets. Let's apply one and see the score improve."

---

## Step 5 — Apply a Fix and Re-Audit (2–3 minutes)

> **Note:** This step is optional. Only do it if you're comfortable making
> changes to the lab cluster during the demo.

**Prompt to type:**

```
Apply a default-deny NetworkPolicy to the pets namespace, then re-audit just
the network security category to show the improvement.
```

**What the agent will do:**
1. Create and apply the default-deny NetworkPolicy
2. Re-run the network security audit
3. Show the finding is now resolved

**What the audience will see:**

- The NetworkPolicy finding changes from 🟡 Medium to ✅ No issues found
- The risk score improves (goes up by ~5 points)

**⚠️ Important:** Applying a default-deny policy without corresponding allow
rules will break pod-to-pod communication. The agent should warn about this.
In a demo, you can acknowledge the warning and proceed — the lab can be reset.

**What to say:**

> "We just improved our security posture by 5 points with one command. Imagine
> running this audit weekly or as part of your CI/CD pipeline — you'd catch
> these issues before they ship."

---

## Step 6 — Wrap Up (1 minute)

**What to say:**

> "To recap: the Azure SRE Agent handles incident response. But with the
> Subagent Builder, we extended it with a Security Posture Auditor that
> proactively finds misconfigurations. It checked six categories, found
> real issues — including hardcoded passwords — and gave us ready-to-apply
> fixes. And you can build your own sub-agents for cost optimization,
> compliance checking, or anything else your team needs."

---

## Bonus Prompts (if time allows)

### Compare to CIS Benchmark

```
How does the pets namespace compare against the CIS Kubernetes Benchmark v1.8?
Which controls are passing and which are failing?
```

### Scope to a Single Service

```
Run a focused security audit on just the order-service deployment in the pets namespace.
```

### Cost of Remediation

```
Estimate the effort to remediate all findings — which fixes are quick wins
and which require architectural changes?
```

### Azure-Level Security

```
Check AKS-level security configuration for this cluster — is managed identity
enabled? Is Azure Policy configured? Is Defender for Containers active?
```

---

## Troubleshooting

| Issue | Resolution |
|---|---|
| Agent doesn't find any pods | Verify `kubectl get pods -n pets` returns results; check AKS connection |
| Agent skips a category | Explicitly ask: "Also check [category]" — or run the full audit prompt |
| Risk score seems wrong | The score is calculated as 100 minus deductions; verify finding counts match |
| Agent refuses to apply changes | This is by design — it warns before modifying. Confirm you want to proceed |
| NetworkPolicy breaks connectivity | Expected with default-deny. Reset the lab or apply allow rules |
