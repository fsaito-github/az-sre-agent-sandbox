# Lessons Learned from Building the Advisor Impact Analyzer

Real-world findings from developing, testing, and iterating the Advisor
Impact Analyzer subagent on the Azure SRE Agent platform.

## Platform Constraints

| Constraint | Impact | Workaround |
|-----------|--------|-----------|
| **maxTurnsReached** | Subagent stops mid-analysis if too many tool calls | Produce summary FIRST, deep analysis on demand only |
| **kubectl may be unavailable** | `RunKubectlReadCommand` returns "Function not available" | Fallback: `az aks command invoke` or KQL ContainerInsights |
| **`az keyvault show` unsupported** | Returns "Unsupported subcommands: keyvault" | Use `az resource show --resource-type Microsoft.KeyVault/vaults` |
| **App Insights ZERO_ROWS** | KQL queries return empty if no instrumentation | Expand timespan to 7d, verify instrumentation first, note in report |
| **Retail Prices API empty results** | Some serviceName/meterName filters don't match | Use broad-first queries, then refine; troubleshoot filter names |
| **SRE Agent summarizes subagent output** | Main agent may truncate tables/details when delegating | User can request "full detailed report" or use Test playground |

## Prompt Engineering Lessons

| Lesson | Detail |
|--------|--------|
| **Under 5K chars** | 20K char prompt caused maxTurnsReached. Condensed to 3.8K. |
| **Reference knowledge by filename** | "See `discovery-procedures.md`" triggers RAG retrieval |
| **Workflow steps, not inline scripts** | Put az/kubectl commands in knowledge files |
| **Summary-first pattern** | Users get actionable data in seconds, deep dive on demand |
| **Show raw output before concluding** | Agent said "No recommendations" without showing data. Fixed with rule. |
| **Respect cancellation explicitly** | Agent retried after user cancelled. Added explicit STOP rule. |
| **Validate runtime state** | Agent asserted "Running (2/2)" with nodepool=0. Added verification rule. |

## Knowledge File Design

| Lesson | Detail |
|--------|--------|
| **Split by topic, not monolith** | 1 file of 34K chars → 7 focused files. Better RAG retrieval. |
| **Descriptive filenames** | `cost-analysis.md` not `doc3.md` — helps both RAG and humans |
| **Include fallback commands** | kubectl unavailable → az aks → KQL. Chain of alternatives. |
| **Add troubleshooting sections** | "If query returns empty: try X, then Y, then mark as unknown" |
| **Teach investigation, not answers** | "Run this command to DISCOVER" not "MongoDB will break" |

## Cost Analysis Lessons

| Lesson | Detail |
|--------|--------|
| **Batch by resource type** | 1 API call per resource type, not 1 per recommendation |
| **Broad-first queries** | Remove meterName filter if specific query returns empty |
| **Always state source** | "(Retail Prices API)" vs "(estimate)" — credibility |
| **Flag ROI** | "+$389/mo for Redis Basic→Premium — evaluate ROI" |
| **Advisor savings data** | Check `extendedProperties.savingsAmount` for cost recs |

## Testing Workflow

1. Edit Instructions in portal (from subagent.yaml system_prompt)
2. Upload/re-upload knowledge files via Settings → Knowledge Base → Files
3. Test in Test playground (split-screen: edit left, chat right)
4. Run AI Evaluate (aim for Overall > 80, Prompt clarity > 4)
5. Use "Refine with AI" for suggestions
6. Test via `/agent <name>` in regular chat
7. Check SRE Agent evaluation feedback for improvement opportunities
