# 🛡️ WARA Reliability Checker

## The Problem

Azure has excellent reliability guidance (Well-Architected Framework, APRL,
Advisor), but teams struggle to act on it because:

- **WARA PowerShell module has bugs** — filters break, false negatives, scripts not Microsoft-signed
- **Validation is manual and heavy** — hundreds of recommendations requiring portal review
- **No trend analysis** — each assessment is a snapshot with no comparison to previous state
- **Recommendations lack context** — "enable zone redundancy" without cost, blast radius, or rollback info
- **Guest account/access issues** — customers refuse to run external scripts in their tenant

## The Solution

The **WARA Reliability Checker** runs APRL reliability checks directly via
Azure Resource Graph queries — no PowerShell module, no guest accounts, no
scripts to install. It runs inside the Azure SRE Agent using managed identity.

Key capabilities:

- **27+ automated reliability checks** from APRL across VMs, AKS, SQL, Storage, App Service, Key Vault, LB, App Gateway, Firewall, Cosmos DB, Redis
- **Reliability Score** — % compliance mapped to WAF pillars (RE:01-RE:10)
- **Severity + blast radius classification** per finding
- **💰 Remediation cost** via Azure Retail Prices API
- **Rollback assessment** (✅ Reversible / ⚠️ Complex / ❌ Irreversible)
- **Scheduled execution** — weekly checks via SRE Agent Scheduled Tasks
- **Advisor HA integration** — combines APRL + Advisor for complete coverage

## Installation

### 1. Create the Sub-Agent

1. Open your SRE Agent in the [Azure Portal](https://aka.ms/sreagent/portal)
2. Go to the **Subagent builder** tab
3. Click **Create** → select **Subagent**
4. Fill in the fields:

   | Portal Field | What to configure |
   |-------------|------------------|
   | **Name** | `WARA Reliability Checker` |
   | **Instructions** | Copy the `system_prompt` from subagent.yaml |
   | **Tools** | Select: Azure CLI (read), Log Analytics/Kusto query, Python code execution |
   | **Skills** | Leave empty |
   | **Hooks** | Leave empty |

5. Enable **Knowledge base** (see step 2)
6. Click **Save**
7. Test in the **Test playground**

### 2. Upload Knowledge Files

1. Go to **Settings** → **Knowledge Base** → **Files**
2. Upload all files from the `knowledge/` folder:

| File | Purpose |
|------|---------|
| [`aprl-resource-graph-queries.md`](knowledge/aprl-resource-graph-queries.md) | 27+ ARG queries by resource type |
| [`reliability-scoring.md`](knowledge/reliability-scoring.md) | Compliance score calculation and severity levels |
| [`waf-reliability-checklist.md`](knowledge/waf-reliability-checklist.md) | RE:01-RE:10 mapped to automated checks |
| [`remediation-priorities.md`](knowledge/remediation-priorities.md) | Priority formula, quick wins, blast radius |

3. Enable Knowledge base on the subagent

### 3. Configure Scheduled Task (optional)

For recurring weekly checks:

1. Go to **Scheduled tasks** tab
2. Click **Create scheduled task**
3. Configure:

   | Setting | Value |
   |---------|-------|
   | **Name** | Weekly WARA Reliability Check |
   | **Description** | Run APRL reliability checks against all resources |
   | **When** | Every Monday at 8:00 AM |
   | **How often** | Weekly |
   | **Agent instructions** | Run the WARA Reliability Checker against subscription `<sub-id>`. Report reliability score, top findings by severity, and quick wins. |
   | **Max executions** | 52 |

## Test Prompts

### Quick Scan
```
Run a reliability assessment on my Azure environment.
Show the compliance score and top findings.
```

### Specific Resource Group
```
Check the reliability posture of resource group rg-production-eastus2.
Which resources are not zone-redundant?
```

### Quick Wins
```
What reliability improvements can I make right now with zero cost
and no downtime?
```

### Zone Redundancy Focus
```
Which resources in my environment are NOT zone-redundant?
Show the blast radius if an availability zone goes down.
```

### Executive Summary
```
Generate an executive reliability summary for my subscription.
Include the score, trend if available, and top 5 actions with cost.
```

### Comparison with Advisor
```
Compare the APRL reliability findings with Azure Advisor HighAvailability
recommendations. Are there any gaps that one catches but the other misses?
```

## Risk Classification

| Severity | Criteria |
|----------|----------|
| 🔴 **Critical** | Data loss risk, no redundancy on customer-facing, retirement imminent |
| 🟠 **High** | Single point of failure, no zone redundancy on critical resources |
| 🟡 **Medium** | Missing best practice, recoverable but suboptimal |
| 🟢 **Low** | Observability gap, minor configuration |

## Limitations

- Uses Azure Resource Graph queries — coverage depends on APRL library updates
- Some checks (DR testing, application-level patterns) require manual review
- Drift detection requires previous baseline stored in agent memory
- Cost estimates are pay-as-you-go; EA/CSP agreements may differ
- Services not yet in APRL (OpenAI, Synapse, AI Search) are not covered

## References

- [Azure Proactive Resiliency Library v2](https://azure.github.io/Azure-Proactive-Resiliency-Library-v2/)
- [WARA PowerShell Module](https://github.com/Azure/Well-Architected-Reliability-Assessment)
- [WAF Reliability Pillar](https://learn.microsoft.com/en-us/azure/well-architected/reliability/)
- [SRE Agent Scheduled Tasks](https://learn.microsoft.com/en-us/azure/sre-agent/scheduled-tasks)
