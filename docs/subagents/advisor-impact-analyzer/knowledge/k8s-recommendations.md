# Kubernetes Recommendations Analysis

How to investigate and assess impact of Advisor recommendations
for Kubernetes (AKS) resources: container security, network, and node pools.

---

## SECURITY — Container hardening

### "Running as root" / "Read-only rootfs" / "Capabilities"

**Investigation:**
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    for c in pod['spec'].get('containers', []):
        img = c.get('image', '')
        sc = c.get('securityContext', {})
        if sc.get('runAsNonRoot'):
            risk = 'SAFE — already runs non-root'
        elif any(x in img.lower() for x in ['mongo', 'postgres', 'mysql', 'redis', 'rabbitmq', 'kafka', 'elasticsearch', 'nginx', 'memcached', 'cassandra', 'couchdb']):
            risk = 'HIGH RISK — official infra image, likely requires root'
        elif 'bitnami' in img.lower():
            risk = 'SAFE — Bitnami images designed for non-root'
        else:
            risk = 'MEDIUM — test before applying'
        print(f'{pod[\"metadata\"][\"name\"]}/{c[\"name\"]}: {img} -> {risk}')
"
```

**Decision rules:**
- Image has `USER` in Dockerfile (bitnami, distroless) → 🟢 Safe
- Official DB/middleware (mongo, postgres, redis, rabbitmq, nginx) → 🔴 Verify docs
- Custom app container → 🟡 Test in staging
- Already `runAsNonRoot: true` → ✅ Skip

**Read-only rootfs — discover write paths:**
```bash
kubectl exec -n <ns> deploy/<service> -- find / -writable -type d 2>/dev/null | head -20
```

---

### "Trusted registries" / "Image pull from trusted sources"

**Investigation:**
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
registries = {}
for pod in pods:
    for c in pod['spec'].get('containers', []):
        img = c.get('image', '')
        registry = img.split('/')[0] if '/' in img else 'docker.io'
        registries.setdefault(registry, []).append(img)
for reg, imgs in registries.items():
    trusted = any(x in reg for x in ['.azurecr.io', '.gcr.io', '.ecr.'])
    print(f'{\"✅\" if trusted else \"⚠️\"} {reg}: {len(imgs)} images {\"(trusted)\" if trusted else \"(EXTERNAL)\"}')
    for img in set(imgs):
        print(f'   {img}')
"
```

**Decision rules:**
- In customer's ACR → ✅ No action
- docker.io / ghcr.io / quay.io → needs `az acr import`
- Migration: rolling update per workload, ~1 min each
- ACR unavailable after migration: running pods OK, restarts → ImagePullBackOff

---

### "Disable API credential automount"

**Investigation:**
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    sa = pod['spec'].get('serviceAccountName', 'default')
    automount = pod['spec'].get('automountServiceAccountToken', True)
    name = pod['metadata']['name']
    if automount:
        print(f'⚠️ {name}: SA={sa}, automount=true — verify K8s API usage')
    else:
        print(f'✅ {name}: automount already disabled')
"
```

**Verify K8s API usage:**
```bash
kubectl exec -n <ns> <pod> -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>/dev/null
```
- Exists AND app needs it (leader election, discovery) → do NOT disable
- Exists but not needed → safe to disable

---

## NETWORK

### "NAT Gateway" / "Private Link" / "Restrict API server"

**Investigation — external calls:**
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    for c in pod['spec'].get('containers', []):
        for env in c.get('env', []):
            val = env.get('value', '')
            if val.startswith('http') and not any(x in val for x in ['localhost', '127.0.0.1', '.svc.cluster']):
                print(f'{pod[\"metadata\"][\"name\"]}: external call -> {val}')
"
```

**Decision rules:**
- Internal-only calls (ClusterIP, private endpoint) → ✅ No impact
- External API calls → ⚠️ Affected during cutover
- LoadBalancer/public endpoints → check if IPs change (client allowlists)
- API server restriction → list ALL IPs for kubectl/CI-CD BEFORE restricting

---

## NODE POOL / COMPUTE

### "Add nodes" / "Ephemeral OS disk" / "VM series upgrade" / "Spot nodes"

**Investigation:**
```bash
kubectl get pdb -n <ns>
kubectl get statefulsets -n <ns>
kubectl get pvc -n <ns>

kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    affinity = pod['spec'].get('affinity', {})
    if affinity:
        print(f'{pod[\"metadata\"][\"name\"]}: has affinity rules')
    owner = pod['metadata'].get('ownerReferences', [{}])[0].get('kind', '')
    print(f'{pod[\"metadata\"][\"name\"]}: controlled by {owner}')
"
```

**Decision rules:**
- Adding nodes → ✅ Always safe (additive)
- Node pool drain:
  - Pods with PVC → slow (PV detach + reattach)
  - StatefulSets → order matters (scale down one at a time)
  - Pods without PDB → all drained at once (availability risk)
  - Pods with PDB → respect minAvailable/maxUnavailable
- Spot nodes → NEVER for StatefulSets or persistent data
- VM resize → depends on deallocation requirement
