# Reliability Scoring

How to calculate the reliability compliance score for the environment.

---

## Overall Score

```
Reliability Score = (Passed Checks / Total Applicable Checks) × 100%
```

- **Passed check**: ARG query returns EMPTY (all resources compliant)
- **Failed check**: ARG query returns resources (non-compliant resources found)
- **Not applicable**: Resource type doesn't exist in the environment (skip)

## Severity Classification

Classify each finding (failed check) by severity:

| Severity | Criteria | Example |
|----------|----------|---------|
| **🔴 Critical** | Data loss risk, no redundancy on customer-facing services, retirement imminent | No backup on production DB, Basic Public IP on production LB |
| **🟠 High** | Single point of failure, no zone redundancy on critical resources | AKS with 1 node, SQL without zone redundancy |
| **🟡 Medium** | Missing best practice, recoverable but suboptimal | No health check on App Service, no auto-upgrade on AKS |
| **🟢 Low** | Observability gap, minor configuration | No diagnostic logs, no Service Health alert |

## Severity Amplifiers (increase by one level)

- Resource is customer-facing (LoadBalancer, public endpoint)
- Resource has no backup or DR configuration
- Resource is a data store (SQL, Cosmos, Storage) without redundancy
- Multiple resources affected by the same finding (blast radius > 5)

## WAF Category Mapping

Map each finding to a WAF Reliability pillar:

| Pillar | Description | Example Findings |
|--------|-------------|-----------------|
| **RE:05 Redundancy** | Zone/region/instance redundancy | No AZ, single instance, no geo-rep |
| **RE:07 Self-healing** | Auto-repair, auto-scale, health probes | No health check, no auto-repair, no HPA |
| **RE:09 BCDR** | Backup, DR, recovery targets | No backup, no geo-replication, no PITR |
| **RE:10 Monitoring** | Alerts, diagnostics, observability | No diagnostic logs, no Service Health alerts |
| **RE:04 Targets** | SLA, SKU alignment | Basic SKU in production, no SLA tier |

## Score Presentation

```
## 🛡️ RELIABILITY SCORE: 72% (18/25 checks passed)

| WAF Pillar | Checks | Passed | Score | Status |
|-----------|--------|--------|-------|--------|
| RE:05 Redundancy | 10 | 6 | 60% | 🟠 |
| RE:07 Self-healing | 5 | 4 | 80% | 🟡 |
| RE:09 BCDR | 4 | 3 | 75% | 🟡 |
| RE:10 Monitoring | 4 | 3 | 75% | 🟡 |
| RE:04 Targets | 2 | 2 | 100% | 🟢 |
```

## Status Thresholds

| Score | Status | Meaning |
|-------|--------|---------|
| ≥ 90% | 🟢 Healthy | Minor improvements only |
| 70-89% | 🟡 Needs attention | Important gaps to address |
| 50-69% | 🟠 At risk | Significant reliability concerns |
| < 50% | 🔴 Critical | Immediate action required |
