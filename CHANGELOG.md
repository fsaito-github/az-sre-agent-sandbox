# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- **Advisor Impact Analyzer**: Application Insights KQL as primary dependency
  discovery source, aligned with native SRE Agent behavior (`0727603`)
- **Advisor Impact Analyzer**: Mandatory 💰 Cost Impact section per recommendation
  with 3-source pipeline: Azure Retail Prices API, Advisor savings data, and
  Azure Cost Management (`8fc05ee`, `43476fd`)
- **Advisor Impact Analyzer**: Cost analysis documentation across README,
  demo-flow, and example report (`b30a29c`)
- **Advisor Impact Analyzer**: Limitations and Prerequisites section in README
- **Advisor Impact Analyzer**: DaemonSets, HPA, and Ingress resource discovery
- **Advisor Impact Analyzer**: Resource group discovery step in workflow
- **Advisor Impact Analyzer**: Expanded troubleshooting (Playground vs SRE Agent
  output differences, Retail Prices API issues)
- Issue templates: bug report, feature request, subagent improvement
- PR template with testing checklist
- CONTRIBUTING.md with contributor guidelines
- GitHub Actions CI workflow for YAML and Markdown linting
- GitHub Labels taxonomy (type, component, priority, status)
- GitHub Milestones (v1.0 GA Ready, v1.1 Cost, v1.2 Multi-env, backlog)

### Changed
- **Advisor Impact Analyzer**: Generalized for any Azure environment — removed
  all hardcoded references to AKS Pet Store demo lab (`14c846f`)
- **Advisor Impact Analyzer**: Dynamic workload discovery across 4 environment
  profiles (K8s, PaaS, Hybrid, Partially observable)
- **Advisor Impact Analyzer**: Workload classification by role (customer-facing,
  data store, message broker, batch, observability, load generator)
- **Advisor Impact Analyzer**: Knowledge file renumbered to clean Step 1-9 sequence
- **Advisor Impact Analyzer**: Demo flow renumbered to Acts 1-6 (duration updated
  to 15-20 min)
- **Advisor Impact Analyzer**: Example report completed with all 22 items detailed
  and cost data per recommendation with source attribution

### Fixed
- **Advisor Impact Analyzer**: Restored missing `az advisor recommendation list`
  step in workflow (`7569d0d`)
- **Advisor Impact Analyzer**: Aligned cost table columns (Source) across all files
