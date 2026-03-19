# Contributing to Azure SRE Agent Demo Lab

Thank you for your interest in contributing! This project provides custom
sub-agents for Azure SRE Agent and a demo lab environment.

## Getting Started

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed
- [VS Code](https://code.visualstudio.com/) with Dev Containers extension (recommended)
- A GitHub account with fork permissions
- For testing subagents: access to an Azure SRE Agent instance

### Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/<your-username>/az-sre-agent-sandbox.git
   cd az-sre-agent-sandbox
   ```
3. Open in VS Code with Dev Container (recommended) or install dependencies manually

### Testing Subagent Changes

Since subagents run inside the Azure SRE Agent platform, testing requires:

1. Open your SRE Agent in the [Azure Portal](https://aka.ms/sreagent/portal)
2. Go to **Builder** → **Subagent Builder**
3. Paste the updated `subagent.yaml` content
4. Test in the **Playground** with the prompts from the subagent's README
5. If updating a knowledge file, re-upload it to **Builder** → **Knowledge Base**

> **Tip:** Test in Playground first. Playground gives the sub-agent's direct
> output, while the main SRE Agent may summarize or truncate responses.

## How to Contribute

### Reporting Issues

- Use the appropriate [issue template](https://github.com/fsaito-github/az-sre-agent-sandbox/issues/new/choose)
- For bugs, include the prompt you used and the agent's output
- For feature requests, describe the problem you're solving

### Submitting Changes

1. Create a branch from `main`:
   ```bash
   git checkout -b feat/my-improvement
   ```
2. Make your changes following the conventions below
3. Commit using [Conventional Commits](https://www.conventionalcommits.org/):
   ```bash
   git commit -m "feat: add support for Cosmos DB dependency detection"
   git commit -m "fix: correct Python script variable name in network analysis"
   git commit -m "docs: update README with new cost analysis section"
   ```
4. Push and open a Pull Request against `main`
5. Fill in the PR template checklist

### Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Use for |
|--------|---------|
| `feat:` | New feature or capability |
| `fix:` | Bug fix |
| `docs:` | Documentation only |
| `refactor:` | Code change that neither fixes a bug nor adds a feature |
| `chore:` | Maintenance (CI, dependencies, etc.) |

### File Structure

```
docs/subagents/<subagent-name>/
├── subagent.yaml           # System prompt (paste into Subagent Builder)
├── README.md               # Documentation and test prompts
├── demo-flow.md            # Step-by-step demo script
├── advisor-impact-report.md # Example report (if applicable)
└── knowledge/              # Knowledge files (upload to Knowledge Base)
    └── *.md
```

### Guidelines for Subagent Changes

1. **Keep the core generic** — no hardcoded service names, namespaces, or
   application-specific logic in `subagent.yaml` or knowledge files
2. **Discover, don't assume** — always use discovery commands to detect the
   environment state
3. **Test with real prompts** — every change should be tested in Playground
4. **Update documentation** — if you change behavior, update README and demo-flow
5. **State sources** — for cost data, always indicate which source was used
6. **Handle failures gracefully** — if a command or API is unavailable, the
   agent should note what it couldn't verify

### Guidelines for Infrastructure Changes

1. Follow existing Bicep patterns in `infra/bicep/`
2. Use namespace `pets` and label with `sre-demo: breakable` for K8s manifests
3. PowerShell scripts should include error handling and support `-WhatIf`
4. New breakable scenarios go in `k8s/scenarios/` with docs in `docs/BREAKABLE-SCENARIOS.md`

## Code of Conduct

Be respectful, constructive, and inclusive. We follow the
[Contributor Covenant](https://www.contributor-covenant.org/) code of conduct.

## Questions?

Open a [question issue](https://github.com/fsaito-github/az-sre-agent-sandbox/issues/new?labels=question)
or start a discussion.
