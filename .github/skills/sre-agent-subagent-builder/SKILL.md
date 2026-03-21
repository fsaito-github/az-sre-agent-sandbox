---
name: sre-agent-subagent-builder
description: 'Create custom subagents for Azure SRE Agent. Use when asked to "create a subagent", "build an SRE agent", "scaffold a sub-agent", "make a new analyzer", or when designing specialized AI agents for Azure operations, incident response, or infrastructure analysis. Generates subagent.yaml with system_prompt, knowledge files, README, and demo-flow following proven patterns and Azure SRE Agent best practices.'
---

# SRE Agent Subagent Builder

Create production-ready custom subagents for Azure SRE Agent following proven
patterns and official best practices from Microsoft Learn documentation.

## When to Use This Skill

- User asks to "create a subagent", "build an SRE agent", or "design an analyzer"
- User wants to add a new specialist capability to their Azure SRE Agent
- User needs to scaffold a subagent with knowledge files, README, and demo flow
- User wants to follow the patterns used by the Advisor Impact Analyzer

## Prerequisites

- Azure SRE Agent instance in the [Azure Portal](https://aka.ms/sreagent/portal)
- Clear definition of what the subagent should analyze or do
- Understanding of which Azure resources the subagent will interact with

## Step 1: Define the Subagent Purpose

Before writing any files, answer these questions:

| Question | Why it matters |
|----------|---------------|
| What problem does this subagent solve? | Defines the core value proposition |
| What can't the native SRE Agent do that this subagent adds? | Avoids redundancy |
| Which Azure resources will it analyze? | Determines tools needed |
| What output should it produce? | Shapes the system_prompt |
| What pattern fits? (Domain Expert / Task Specialist / Workflow Executor) | Guides architecture |

### Subagent Patterns

| Pattern | When to use | Examples |
|---------|-------------|---------|
| **Domain Expert** | Deep expertise in one technology | AKS Expert, Network Expert, Database Expert |
| **Task Specialist** | Focused on a specific task | Cost Optimizer, Security Scanner, Log Analyzer |
| **Workflow Executor** | Multi-step procedures | Incident Triage, Deployment Validator, Backup Verifier |

## Step 2: Create the File Structure

```
docs/subagents/<subagent-name>/
├── subagent.yaml              # System prompt + config (field values for portal)
├── README.md                  # Documentation, installation, test prompts
├── demo-flow.md               # Step-by-step demo script
└── knowledge/                 # Knowledge files (upload to portal Knowledge Base)
    ├── <topic-1>.md           # Focused by topic for better RAG retrieval
    ├── <topic-2>.md
    └── <topic-N>.md
```

## Step 3: Write the subagent.yaml

### Template

```yaml
name: <Subagent Name>

agent_type: Review    # ReadOnly | Review | Autonomous

enable_skills: true

# TOOLS — Select in the Subagent builder UI:
#   Built-in tools: Azure CLI (read + write), Log Analytics / Kusto query,
#   Python code execution.
#   kubectl is available natively when AKS is connected as a resource.
tools:
  - RunAzCliReadCommands
  - RunAzCliWriteCommands
  - execute_kusto_query
  - ExecutePythonCode

handoff_agents: []

handoff_description: >
  <1-3 sentences explaining WHEN to invoke this subagent and WHAT it does.
  This text helps the orchestrator decide when to delegate.>

system_prompt: |
  You are the **<Subagent Name>**. Your job is to <core mission in one line>.

  ## WORKFLOW (follow this order)
  1. **<STEP 1>** — <what to do, reference knowledge file by name>
  2. **<STEP 2>** — <next step>
  ...

  ## OUTPUT FORMAT
  <define the structure of the response>

  ## KEY RULES
  1. <most important behavioral rule>
  2. <second rule>
  ...
```

### System Prompt Best Practices (from real-world testing)

| Practice | Why |
|----------|-----|
| **Keep under 5K chars** | Larger prompts consume context and cause maxTurnsReached |
| **Reference knowledge files by name** | "See `discovery-procedures.md`" — the agent will RAG-retrieve them |
| **Workflow steps, not scripts** | Put az/kubectl commands in knowledge files, not the prompt |
| **Show raw data first** | Never conclude without showing the actual command output |
| **Respect cancellation** | Add rule: "If user cancels, STOP and ask before retrying" |
| **Budget turns** | Produce summary first, deep analysis on demand |
| **Validate runtime state** | Never assert "Running" without evidence from tools |
| **Respond in user's language** | Always match the language of the user's prompt |

### Agent Type Selection

| Type | Use when | Risk level |
|------|----------|-----------|
| **ReadOnly** | Only queries and analyzes, no changes | Safest — log analysis, audits |
| **Review** | Proposes actions, waits for approval | Recommended default — recommendations, plans |
| **Autonomous** | Acts without human approval | Only for well-tested, trusted operations |

## Step 4: Create Knowledge Files

### Why Multiple Files?

The SRE Agent uses semantic search (RAG) to find relevant knowledge. Focused
files per topic yield better retrieval than one large monolithic file.

### Naming Convention

Use descriptive, lowercase, hyphenated names:
- ✅ `discovery-procedures.md`, `risk-classification.md`, `cost-analysis.md`
- ❌ `doc1.md`, `knowledge.md`, `notes.txt`

### Knowledge File Template

```markdown
# <Topic Title>

<Brief description of what this file teaches the agent to do.>

---

## <Procedure 1>

**Investigation commands:**
```bash
<az/kubectl commands with query filters>
```

**Decision rules:**
- If <condition> → <action>
- If <other condition> → <other action>

---

## <Procedure 2>
...
```

### Knowledge File Guidelines

| Guideline | Why |
|-----------|-----|
| **Teach HOW to investigate, not WHAT the answer is** | Works in any environment |
| **Include fallback commands** | Tools may be unavailable (e.g., kubectl) |
| **Add troubleshooting for empty results** | Queries may return ZERO_ROWS |
| **Use `2>/dev/null` on optional commands** | Prevents error noise |
| **Max 50 MB per file** | Platform limit |
| **Supported formats: .md and .txt only** | Platform constraint |

## Step 5: Write the README.md

### Template

```markdown
# <Emoji> <Subagent Name>

## The Problem
<What gap this subagent fills — 3-5 lines>

## The Solution
<What the subagent does — bullet list of capabilities>

## Installation

### 1. Create the Sub-Agent
1. Open your SRE Agent in the [Azure Portal](https://aka.ms/sreagent/portal)
2. Go to the **Subagent builder** tab
3. Click **Create** → select **Subagent**
4. Fill in the fields:
   | Portal Field | What to configure |
   |-------------|------------------|
   | **Name** | `<subagent name>` |
   | **Instructions** | Copy the `system_prompt` from subagent.yaml |
   | **Tools** | Select: <list tools> |
   | **Skills** | Leave empty |
   | **Hooks** | Leave empty |
5. Enable **Knowledge base**
6. Click **Save**
7. Test in the **Test playground**
8. Run **Evaluate** (aim for Overall > 80)

### 2. Upload Knowledge Files
1. Go to **Settings** → **Knowledge Base** → **Files**
2. Upload all files from the `knowledge/` folder
3. Enable Knowledge base on the subagent

## Test Prompts
<3-5 prompts the user can try>

## Limitations
<What the subagent cannot do>
```

## Step 6: Write the demo-flow.md

Structure demos as numbered Acts (15-20 min total):

```markdown
# Demo Flow — <Subagent Name>

## Act 1: The Problem (2 min)
<Narrative + prompt>

## Act 2: Quick Analysis (3 min)
<Show fast value>

## Act 3: Deep Dive (5 min)
<Detailed analysis on one item>

## Act 4: Action Plan (3 min)
<Prioritized execution order>

## Troubleshooting
| Problem | Solution |
```

## Step 7: Register in the Portal

1. Open Azure SRE Agent → **Subagent builder** tab
2. Click **Create** → **Subagent**
3. Fill in **Name**, **Instructions** (from system_prompt), **Tools**
4. Upload knowledge files via **Settings** → **Knowledge Base** → **Files**
5. Enable Knowledge base on the subagent
6. Test in **Test playground**
7. Run **Evaluate** — check scores and use "Refine with AI" if needed
8. Invoke via `/agent <name>` in chat

## Validation Checklist

- [ ] system_prompt is under 5K chars
- [ ] Knowledge files are focused by topic (not monolithic)
- [ ] Knowledge file names are descriptive and lowercase-hyphenated
- [ ] Commands in knowledge files have fallbacks for unavailable tools
- [ ] README has correct portal fields (Name, Instructions, Tools, Skills, Hooks)
- [ ] Demo flow has 4-6 acts, ~15-20 min total
- [ ] Test prompts produce useful output in Test playground
- [ ] AI Evaluation score > 80

## References

- [Azure SRE Agent — Subagents](https://learn.microsoft.com/en-us/azure/sre-agent/sub-agents)
- [Azure SRE Agent — Skills](https://learn.microsoft.com/en-us/azure/sre-agent/skills)
- [Azure SRE Agent — Tools](https://learn.microsoft.com/en-us/azure/sre-agent/tools)
- [Azure SRE Agent — Memory & Knowledge](https://learn.microsoft.com/en-us/azure/sre-agent/memory)
- [Azure SRE Agent — Playground](https://learn.microsoft.com/en-us/azure/sre-agent/agent-playground)
- Example subagent: [Advisor Impact Analyzer](../../docs/subagents/advisor-impact-analyzer/)
