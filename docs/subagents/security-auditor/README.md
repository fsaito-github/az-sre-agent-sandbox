# 🛡️ Security Posture Auditor — Sub-Agent for Azure SRE Agent

## What It Does

The Security Posture Auditor proactively scans your Kubernetes cluster for security misconfigurations, compliance gaps, and hardcoded secrets. It produces a structured report with severity ratings, CIS Benchmark references, and actionable remediation steps.

### Why isn't this redundant with the SRE Agent?

| | Azure SRE Agent (native) | Security Posture Auditor (this sub-agent) |
|---|---|---|
| **Trigger** | Reactive — fires on incidents, alerts, user questions | Proactive — runs on demand as a security review |
| **Focus** | Diagnose root cause, mitigate outage | Find misconfigurations before they cause outages |
| **Scope** | Single resource or incident | Entire namespace or cluster |
| **Output** | Diagnosis + mitigation steps | Structured audit report + risk score |

The core SRE Agent is excellent at answering "why is this pod crashing?" but it won't tell you "your RabbitMQ password is hardcoded in plaintext." This sub-agent fills that gap.

## Audit Categories

| # | Category | What It Checks |
|---|---|---|
| 1 | **Container Security** | `runAsNonRoot`, `readOnlyRootFilesystem`, privileged mode, capabilities |
| 2 | **Image Security** | `:latest` tags, untrusted registries, `imagePullPolicy` |
| 3 | **Resource Governance** | Missing requests/limits, no LimitRange, no PDB |
| 4 | **Secrets Management** | Hardcoded passwords in env vars, secrets not in K8s Secrets or Key Vault |
| 5 | **Network Security** | Missing NetworkPolicy, no default deny, exposed services |
| 6 | **RBAC & Access Control** | Overly permissive ClusterRoleBindings, default service account usage |

## Installation

1. Open your SRE Agent in the [Azure Portal](https://aka.ms/sreagent/portal)
2. Go to the **Subagent builder** tab
3. Click **Create** → select **Subagent**
4. Fill in the portal fields (Name, Instructions, Handoff Description, Tools, Agent Type) using the values from [`subagent.yaml`](subagent.yaml)
5. For **Built-in Tools**, select: Azure CLI, Log Analytics/Kusto query, Python code execution
6. Click **Save**
7. Test in the **Test playground** (view toggle in the Subagent builder)
8. To invoke in chat, type `/agent` and select **Security Posture Auditor**

No additional permissions are required beyond what the SRE Agent already has.

## Test Prompts

### Full Namespace Audit

```
Run a full security posture audit on the pets namespace.
```

This triggers all six audit categories and produces the complete report with risk score. Ideal for the first demo.

### Secrets-Only Audit

```
Check the pets namespace for any hardcoded credentials or secrets management issues.
```

Focuses on Category 4. Will find the RabbitMQ `guest/guest` credentials in plaintext env vars.

### Container Security Audit

```
Audit container security settings in the pets namespace. Check for containers running
as root, missing securityContext, and privileged containers.
```

Focuses on Category 1. Will surface missing `runAsNonRoot` and `readOnlyRootFilesystem`.

### Network Policy Audit

```
Check if the pets namespace has proper NetworkPolicy coverage, including a default deny policy.
```

Focuses on Category 5. Will find no NetworkPolicies exist.

### Image Security Audit

```
Review all container images in the pets namespace for version pinning and registry trust.
```

Focuses on Category 2. Will find all images using `:latest` tags.

### Resource Governance Audit

```
Check the pets namespace for resource requests, limits, LimitRanges, and PodDisruptionBudgets.
```

Focuses on Category 3. Will find missing PDBs and potentially missing resource limits.

### Remediation Request

```
Generate remediation YAML for the critical findings in the pets namespace.
```

Use after a full audit. The agent will produce ready-to-apply YAML patches.

### Before/After Comparison

```
I just applied a default-deny NetworkPolicy to the pets namespace. Re-audit network
security and show me the improvement.
```

Great for showing risk score improvement in a demo.

## Known Findings in the Pet Store Lab

This lab environment has intentional security issues that make the auditor very
demonstrable. Here's what the auditor will find:

### 🔴 Critical Findings

| Finding | Service | Details |
|---|---|---|
| Hardcoded RabbitMQ credentials | order-service, makeline-service, rabbitmq | `RABBITMQ_DEFAULT_USER=guest`, `RABBITMQ_DEFAULT_PASS=guest` in plaintext env vars |

### 🟠 High Findings

| Finding | Services | Details |
|---|---|---|
| Containers not running as non-root | All services | No `securityContext.runAsNonRoot: true` configured |
| No `readOnlyRootFilesystem` | All services | Containers have writable root filesystem |
| MongoDB has no authentication | mongodb | No auth flags or credentials configured |

### 🟡 Medium Findings

| Finding | Services | Details |
|---|---|---|
| All images use `:latest` tag | All services | No version pinning — builds are not reproducible |
| No default-deny NetworkPolicy | pets namespace | Any pod can talk to any other pod in the cluster |
| No PodDisruptionBudgets | All services | Voluntary disruptions may cause downtime |

### 🔵 Low Findings

| Finding | Services | Details |
|---|---|---|
| Default service account usage | Various | Pods use the `default` SA instead of dedicated ones |
| SA tokens auto-mounted | Various | `automountServiceAccountToken` not set to false |

### Expected Risk Score

With all findings present, expect a risk score in the range of **15–35 out of 100**
(High Risk). This dramatically demonstrates the value of proactive security auditing.

## Customization

You can tailor the auditor by editing the `system_prompt` in `subagent.yaml`:

- **Add company-specific policies** — add checks for required labels, annotations, or naming conventions.
- **Adjust severity weights** — change the risk score deductions to match your org's risk tolerance.
- **Add Azure-specific checks** — query AKS configuration (managed identity, Azure Policy, Defender for Containers) using the `azure_cli` tool.
- **Integrate with Log Analytics** — use `execute_kusto_query` to check for historical security events.
