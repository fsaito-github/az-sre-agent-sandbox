# 🤖 Custom Sub-Agents for Azure SRE Agent

This directory contains custom sub-agent definitions designed to **extend** the Azure SRE Agent with capabilities it doesn't provide natively.

## Why Sub-Agents?

The Azure SRE Agent already excels at incident diagnosis, automated remediation, monitoring, and capacity planning. These sub-agents fill the gaps:

| Sub-Agent | What It Adds | Native SRE Agent Gap |
|-----------|-------------|---------------------|
| [📊 SLO Guardian](slo-guardian/) | SLO framework with error budgets, burn rate analysis, deploy/freeze decisions | No built-in SLO/error budget framework |
| [🛒 E-Commerce Domain Expert](ecommerce-expert/) | Business-aware diagnosis — translates infra failures to order/revenue impact | Knows K8s but not app business logic |
| [📋 PIR Generator](pir-generator/) | Structured Post-Incident Review documents (timeline, RCA, action items) | Diagnoses incidents but doesn't generate formal post-mortems |
| [🔐 Security Posture Auditor](security-auditor/) | Proactive K8s security audit (CIS benchmark, secrets, RBAC, network policies) | Diagnoses incidents, doesn't audit compliance |
| [🔍 Advisor Impact Analyzer](advisor-impact-analyzer/) | Dynamically discovers workloads and dependencies in any Azure environment, then analyzes operational impact of Advisor recommendations with execution plans and rollback | Doesn't bridge Advisor recommendations to safe execution |

## Quick Start

1. Open your SRE Agent in the [Azure Portal](https://aka.ms/sreagent/portal)
2. Go to the **Subagent builder** tab
3. Click **Create** → select **Subagent**
4. Fill in the portal fields (Name, Instructions, Handoff Description, Tools, Agent Type) using the values from the `subagent.yaml` file in the desired sub-agent folder
5. If the sub-agent has a `knowledge/` folder, upload the files via **Settings** → **Knowledge Base** → **Files** and enable Knowledge base on the subagent
6. Click **Save** and test in the **Test playground** (view toggle in the Subagent builder)
7. To invoke in chat, type `/agent` and select your sub-agent

## Demo Recommendations

| Audience | Recommended Sub-Agents | Demo Time |
|----------|----------------------|-----------|
| **SRE/DevOps Teams** | SLO Guardian + PIR Generator | ~20 min |
| **Engineering Leadership** | E-Commerce Expert + SLO Guardian | ~15 min |
| **Security/Compliance** | Security Auditor + PIR Generator | ~15 min |
| **Operations/Change Mgmt** | Advisor Impact Analyzer + SLO Guardian | ~20 min |
| **Full Demo** | All 5 (in order below) | ~50 min |

### Suggested Full Demo Order

1. **Advisor Impact Analyzer** — Show pending Advisor recommendations and safe execution plans
2. **Security Auditor** — Start with a clean audit (sets the stage)
3. **SLO Guardian** — Show healthy SLO baseline
4. Break a scenario (e.g., `kubectl apply -f k8s/scenarios/oom-killed.yaml`)
5. **E-Commerce Expert** — Analyze business impact
6. Fix with SRE Agent (native capability)
7. **PIR Generator** — Generate post-mortem
8. **SLO Guardian** — Show error budget impact and deploy readiness

## File Structure

```
docs/subagents/
├── README.md                    # This file
├── advisor-impact-analyzer/
│   ├── subagent.yaml           # Field values for Subagent builder
│   ├── README.md               # Documentation & test prompts
│   ├── demo-flow.md            # Step-by-step demo script
│   ├── advisor-impact-report.md # Example report
│   └── knowledge/              # Upload ALL to Knowledge Base
│       ├── discovery-procedures.md
│       ├── dependency-mapping.md
│       ├── risk-classification.md
│       ├── cost-analysis.md
│       ├── k8s-recommendations.md
│       ├── paas-recommendations.md
│       └── impact-table-guide.md
├── slo-guardian/
│   ├── subagent.yaml           # Field values for Subagent builder
│   ├── README.md               # Documentation & test prompts
│   └── demo-flow.md            # Step-by-step demo script
├── ecommerce-expert/
│   ├── subagent.yaml
│   ├── README.md
│   └── demo-flow.md
├── pir-generator/
│   ├── subagent.yaml
│   ├── README.md
│   └── demo-flow.md
└── security-auditor/
    ├── subagent.yaml
    ├── README.md
    └── demo-flow.md
```
