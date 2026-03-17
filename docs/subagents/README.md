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

## Quick Start

1. Open your SRE Agent in the [Azure Portal](https://aka.ms/sreagent/portal)
2. Go to **Builder** → **Subagent Builder**
3. Click **+ Create subagent**
4. Copy the contents of the `subagent.yaml` file from the desired sub-agent folder
5. Paste into the builder and save
6. Test in the **Playground** using the prompts from the sub-agent's README

## Demo Recommendations

| Audience | Recommended Sub-Agents | Demo Time |
|----------|----------------------|-----------|
| **SRE/DevOps Teams** | SLO Guardian + PIR Generator | ~20 min |
| **Engineering Leadership** | E-Commerce Expert + SLO Guardian | ~15 min |
| **Security/Compliance** | Security Auditor + PIR Generator | ~15 min |
| **Full Demo** | All 4 (in order below) | ~40 min |

### Suggested Full Demo Order

1. **Security Auditor** — Start with a clean audit (sets the stage)
2. **SLO Guardian** — Show healthy SLO baseline
3. Break a scenario (e.g., `kubectl apply -f k8s/scenarios/oom-killed.yaml`)
4. **E-Commerce Expert** — Analyze business impact
5. Fix with SRE Agent (native capability)
6. **PIR Generator** — Generate post-mortem
7. **SLO Guardian** — Show error budget impact and deploy readiness

## File Structure

```
docs/subagents/
├── README.md                    # This file
├── slo-guardian/
│   ├── subagent.yaml           # Paste into Subagent Builder
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
