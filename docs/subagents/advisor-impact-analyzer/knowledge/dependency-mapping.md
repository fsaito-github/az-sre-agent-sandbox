# Dependency Mapping

How to discover dependencies between workloads. Use the FIRST method
that returns data; fall back to the next.

---

## Method 1: Application Insights KQL (PREFERRED)

The most accurate source — shows ACTUAL runtime calls between services
with volume, latency, and failure rates. Same data that powers the
Azure Portal Application Map.

### Prerequisites check
Before running queries, verify App Insights is instrumented:
```bash
az monitor app-insights component show --resource-group <rg> \
  --query "[].{name:name, instrumentationKey:instrumentationKey, connectionString:connectionString}" -o table 2>/dev/null
```
If no components found → skip to Method 2.

### Queries (use timespan 7d for low-traffic environments)

```kql
// Full dependency map: who calls whom (last 7 days)
// Use 7d instead of 24h to catch infrequent dependencies
dependencies
| where timestamp > ago(7d)
| summarize
    CallCount=count(),
    AvgDuration=avg(duration),
    FailRate=round(100.0*countif(success == false)/count(), 1)
    by caller=cloud_RoleName, callee=target, type=dependency_Type
| order by caller asc, CallCount desc
```

```kql
// Service-to-service calls with health status (last 1h)
dependencies
| where timestamp > ago(1h)
| summarize Calls=count(), Failures=countif(success == false)
    by Source=cloud_RoleName, Target=target, Type=dependency_Type
| extend HealthPct = round(100.0*(Calls-Failures)/Calls, 1)
| order by Source asc
```

```kql
// Discover all unique service roles
union requests, dependencies, traces
| where timestamp > ago(7d)
| where isnotempty(cloud_RoleName)
| distinct cloud_RoleName
| order by cloud_RoleName asc
```

```kql
// External dependencies (outside cluster/app)
dependencies
| where timestamp > ago(7d)
| where dependency_Type !in ("InProc", "")
| summarize CallCount=count(), FailRate=round(100.0*countif(success == false)/count(), 1)
    by Target=target, Type=dependency_Type
| order by CallCount desc
```

### Troubleshooting ZERO_ROWS
If queries return empty:
1. Verify App Insights exists: `az monitor app-insights component show --resource-group <rg>`
2. Check if workloads have instrumentation configured (connection string in env vars)
3. Try broader timespan: change `ago(7d)` to `ago(30d)`
4. Try `union requests, traces | where timestamp > ago(7d) | take 5` to test basic connectivity
5. If still empty → app is not instrumented. Note: "⚠️ App Insights has no telemetry —
   dependency map is based on configuration only, not runtime data"

**Why this is better than env vars:**
- Shows ACTUAL calls, not just configured connections
- Includes call volume, latency, and failure rates
- Detects deps not visible in env vars (service discovery, hardcoded URLs)
- Shows which deps are healthy vs failing right now

**When NOT available:** Queries return empty or fail → fall back to Methods 2-4.
Note: "⚠️ App Insights not configured or no telemetry — dependency map based
on infrastructure discovery only. Runtime behavior unverified."

---

## Method 2: Environment variables (infrastructure-level)

### Kubernetes
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    name = pod['metadata'].get('labels', {}).get('app', pod['metadata']['name'])
    for c in pod['spec'].get('containers', []):
        for env in c.get('env', []):
            val = env.get('value', '')
            if any(x in val.lower() for x in ['http://', 'https://', 'amqp://', 'mongodb://', 'redis://', 'postgres://', 'mysql://', 'sqlserver://', 'sb://', ':5432', ':3306', ':6379', ':27017', ':5672', ':9092', ':1433', ':443']):
                print(f'{name} -> {val}')
"
```

### Azure PaaS
```bash
az webapp config connection-string list --name <app> --resource-group <rg> -o json 2>/dev/null
az webapp config appsettings list --name <app> --resource-group <rg> -o json 2>/dev/null
az functionapp config appsettings list --name <func> --resource-group <rg> -o json 2>/dev/null
az network private-endpoint list --resource-group <rg> -o table 2>/dev/null
```

---

## Method 3: Service endpoints (K8s only)
```bash
kubectl get endpoints -n <ns> -o wide
```

---

## Method 4: Logs (if available)
```bash
kubectl logs -n <ns> deploy/<service> --tail=20 2>/dev/null | grep -i "connect\|error\|refused"
```

---

## When to use each

| Method | Best for | Misses |
|--------|---------|--------|
| **App Insights KQL** | Real runtime calls, volumes, health | Services without App Insights SDK |
| **Env vars** | Configured connections | Unused connections, service-discovery deps |
| **Endpoints** | K8s service routing | External deps, queue consumers |
| **Logs** | Connection errors | Healthy connections (no log output) |
| **PaaS settings** | App Service/Function connections | Runtime-only deps |

**Best practice:** Use App Insights FIRST, then COMPLEMENT with env vars/endpoints.

---

## Interpretation rules

- Service A has env/connection string pointing to B → A depends on B
- Data stores (SQL, MongoDB, Redis, Cosmos DB, PostgreSQL) = most critical
- Message queues (RabbitMQ, Kafka, Service Bus) = usually allow buffering
- If B goes down, A may fail — look for retry/circuit breaker config
- External dependencies (outside the resource group) = note but don't analyze deeply
- App Insights FailRate > 0% = dependency already degraded, higher risk for changes
