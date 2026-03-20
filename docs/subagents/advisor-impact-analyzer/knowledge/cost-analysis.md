# Cost Analysis

How to assess the cost impact of Azure Advisor recommendations.
Use the FIRST source that returns data; fall back to the next.

---

## Source 1: Azure Retail Prices API (PREFERRED — real-time, no auth)

Public REST API. Returns actual per-hour pricing by SKU, region, and meter.

### Important: Use broad-first queries
Some serviceName/meterName filters don't match exactly. Start BROAD
(serviceName only), then refine. If a specific query returns empty,
try without meterName filter.

```bash
# BROAD query first — discover available meters for a service
az rest --method get \
  --url "https://prices.azure.com/api/retail/prices?\$filter=serviceName eq 'Virtual Machines' and armSkuName eq 'Standard_D2s_v3' and armRegionName eq 'eastus2' and priceType eq 'Consumption'" \
  --query "Items[?contains(productName, 'Windows') == \`false\` && contains(meterName, 'Spot') == \`false\` && contains(meterName, 'Low Priority') == \`false\`].{sku:armSkuName, price:retailPrice, unit:unitOfMeasure}" -o table 2>/dev/null

# ACR pricing — broad query by service
az rest --method get \
  --url "https://prices.azure.com/api/retail/prices?\$filter=serviceName eq 'Container Registry' and armRegionName eq '<REGION>' and priceType eq 'Consumption'" \
  --query "Items[].{sku:skuName, meter:meterName, price:retailPrice, unit:unitOfMeasure}" -o table 2>/dev/null

# NAT Gateway — use 'Virtual Network' service (NOT 'NAT Gateway')
az rest --method get \
  --url "https://prices.azure.com/api/retail/prices?\$filter=serviceName eq 'Virtual Network' and armRegionName eq '<REGION>' and priceType eq 'Consumption'" \
  --query "Items[?contains(meterName, 'NAT')].{meter:meterName, price:retailPrice, unit:unitOfMeasure}" -o table 2>/dev/null

# Private Link — broad query
az rest --method get \
  --url "https://prices.azure.com/api/retail/prices?\$filter=serviceName eq 'Azure Private Link' and armRegionName eq '<REGION>' and priceType eq 'Consumption'" \
  --query "Items[].{meter:meterName, price:retailPrice, unit:unitOfMeasure}" -o table 2>/dev/null

# App Service — use 'Azure App Service' with Linux/Windows distinction
az rest --method get \
  --url "https://prices.azure.com/api/retail/prices?\$filter=serviceName eq 'Azure App Service' and armRegionName eq '<REGION>' and priceType eq 'Consumption'" \
  --query "Items[?contains(productName, 'Linux')].{sku:armSkuName, meter:meterName, price:retailPrice, unit:unitOfMeasure}" -o table 2>/dev/null
```

### Troubleshooting empty results
If a query returns empty:
1. Remove meterName filter — query by serviceName + region only
2. Try without armRegionName — some meters are global
3. Check serviceName spelling — use `az rest --url "https://prices.azure.com/api/retail/prices?\$filter=armRegionName eq '<REGION>'" --query "Items[].serviceName" -o tsv | sort -u | grep -i "<keyword>"` to find the exact name
4. If still empty → use static estimate and mark as "💰 ⚠️ Price not verified via API — using estimate"

**Monthly cost from hourly price:** `hourly_price × 730`

Use Python for complex calculations:
```python
current_hourly = <price for current SKU>
new_hourly = <price for recommended SKU>
node_count = <from az aks nodepool list>
monthly_delta = (new_hourly - current_hourly) * 730 * node_count
print(f"Monthly delta: ${monthly_delta:+.2f}/month")
```

---

## Source 2: Advisor savings data

Some recommendations (especially Cost category) include pre-calculated savings.

```bash
az advisor recommendation list --resource-group <rg> -o json \
  | python3 -c "
import json, sys
recs = json.load(sys.stdin)
for r in recs:
    ext = r.get('extendedProperties', {})
    savings = ext.get('savingsAmount', ext.get('annualSavingsAmount', ''))
    currency = ext.get('savingsCurrency', 'USD')
    name = r.get('shortDescription', {}).get('problem', 'unknown')
    cat = r.get('category', '')
    if savings:
        print(f'💰 [{cat}] {name}: saves {currency} {savings}')
    else:
        print(f'   [{cat}] {name}: no savings data from Advisor')
"
```

---

## Source 3: Azure Cost Management (actual spend)

```bash
az costmanagement query \
  --type ActualCost \
  --scope "subscriptions/<sub-id>/resourceGroups/<rg>" \
  --timeframe MonthToDate \
  --dataset-grouping name=ResourceId type=Dimension \
  -o json 2>/dev/null
```

If this fails (permissions), fall back to Source 1.

---

## Discover current pricing tiers

Before calculating deltas, know the current state:

```bash
# AKS node pools
az aks nodepool list --resource-group <rg> --cluster-name <aks> \
  --query "[].{name:name, vmSize:vmSize, count:count}" -o table

# ACR SKU
az acr show --name <acr> --query "sku.name" -o tsv 2>/dev/null

# App Service Plan
az appservice plan list --resource-group <rg> \
  --query "[].{name:name, sku:sku.name, tier:sku.tier, workers:sku.capacity}" -o table 2>/dev/null

# SQL Database tier
az sql db list --resource-group <rg> --server <server> \
  --query "[].{name:name, sku:currentSku.name, tier:currentSku.tier}" -o table 2>/dev/null

# Redis SKU
az redis show --name <redis> --resource-group <rg> \
  --query "{sku:sku.name, capacity:sku.capacity}" -o json 2>/dev/null
```

---

## Fallback: Static estimates

Use ONLY when Sources 1-3 unavailable. Approximate USD pay-as-you-go.

| Change | Monthly delta |
|--------|--------------|
| +1x Standard_D2s_v3 node | +$70-90 |
| +1x Standard_D4s_v3 node | +$140-180 |
| ACR Basic → Premium | +$140-160 |
| ACR Geo-replication (per region) | +$50-80 |
| NAT Gateway | +$32-45 |
| Private endpoint (each) | +$7-10 |
| Azure Backup for AKS (per PV) | +$5-15 |
| Diagnostic logs (Log Analytics) | +$2-10 |
| Spot nodes vs regular | -60 to -80% |
| Newer VM series (D→Dv5) | ±0 to -10% |

---

## Rules

- ALWAYS show cost delta per recommendation
- Savings → "💰 Saves ~$X/month"
- Cost increase → "💰 Adds ~$X/month"
- Significant increase (>$100/mo) → "⚠️ Evaluate ROI"
- ALWAYS state source: "Azure Retail Prices API", "Advisor data", or "estimate"
