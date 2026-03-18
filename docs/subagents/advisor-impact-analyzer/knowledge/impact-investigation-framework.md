# Impact Investigation Framework

Este documento ensina o agente a INVESTIGAR impacto, não dá respostas prontas.
Funciona para QUALQUER ambiente, não apenas o pet store.

Upload para: SRE Agent → Builder → Knowledge Base → Add file

---

## Princípio Central

NUNCA assuma o que vai quebrar. SEMPRE descubra executando comandos.
O ambiente do cliente pode ter configurações que mudam completamente o impacto.

---

## Passo 1: Descobrir o ambiente (OBRIGATÓRIO antes de qualquer análise)

```bash
# Listar TODOS os namespaces com workloads
kubectl get pods --all-namespaces --no-headers | awk '{print $1}' | sort -u

# Para cada namespace com workloads, descobrir:
# 1. Pods e replicas
kubectl get pods -n <ns> -o wide

# 2. Services e tipo de exposição (ClusterIP vs LoadBalancer vs NodePort)
kubectl get svc -n <ns>

# 3. Dependências de storage
kubectl get pvc -n <ns>

# 4. Configurações de segurança atuais
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    name = pod['metadata']['name']
    for c in pod['spec'].get('containers', []):
        sc = c.get('securityContext', {})
        img = c.get('image', 'unknown')
        res = c.get('resources', {})
        print(f'{name}/{c[\"name\"]}: image={img} runAsNonRoot={sc.get(\"runAsNonRoot\",\"NOT SET\")} readOnlyRootFs={sc.get(\"readOnlyRootFilesystem\",\"NOT SET\")} limits={res.get(\"limits\",\"NOT SET\")}')
"

# 5. Network policies existentes
kubectl get networkpolicy -n <ns>

# 6. PodDisruptionBudgets
kubectl get pdb -n <ns>

# 7. Nodes e capacity
kubectl get nodes -o wide
kubectl top nodes 2>/dev/null
```

---

## Passo 2: Descobrir dependências entre serviços

O agente NÃO deve usar um mapa estático. Deve DESCOBRIR as dependências.

### Método 1: Via variáveis de ambiente (mais confiável)
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    name = pod['metadata'].get('labels', {}).get('app', pod['metadata']['name'])
    for c in pod['spec'].get('containers', []):
        for env in c.get('env', []):
            val = env.get('value', '')
            # Detectar referências a outros serviços
            if any(x in val.lower() for x in ['http://', 'amqp://', 'mongodb://', 'redis://', 'postgres://', 'mysql://', ':5432', ':3306', ':6379', ':27017', ':5672']):
                print(f'{name} → {val}')
"
```

### Método 2: Via Service endpoints
```bash
kubectl get endpoints -n <ns> -o wide
```

### Método 3: Via logs de conexão (se disponível)
```bash
# Verificar logs recentes para conexões
kubectl logs -n <ns> deploy/<service> --tail=20 2>/dev/null | grep -i "connect\|error\|refused"
```

### Como interpretar as dependências:
- Se serviço A tem env var apontando para serviço B → A depende de B
- Se B cair, A pode falhar (verificar se A tem retry/circuit breaker)
- Dependências de dados (MongoDB, SQL, Redis) são as mais críticas
- Dependências de fila (RabbitMQ, Kafka) geralmente permitem buffer

---

## Passo 3: Framework de análise por tipo de recomendação

### Recomendações de SECURITY em containers

#### "Running as root" / "Read-only rootfs" / "Capabilities"

**Investigação (rodar para cada pod):**
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    for c in pod['spec'].get('containers', []):
        img = c.get('image', '')
        sc = c.get('securityContext', {})
        
        # Verificar se JÁ roda como non-root
        if sc.get('runAsNonRoot'):
            risk = 'SAFE — já roda non-root'
        elif any(x in img.lower() for x in ['mongo', 'postgres', 'mysql', 'redis', 'rabbitmq', 'kafka', 'elasticsearch', 'nginx']):
            risk = 'ALTO RISCO — imagem oficial de infra, provavelmente requer root'
        elif 'bitnami' in img.lower():
            risk = 'SAFE — imagens Bitnami são designed para non-root'
        else:
            risk = 'MÉDIO — testar antes de aplicar'
        
        print(f'{pod[\"metadata\"][\"name\"]}/{c[\"name\"]}: {img} → {risk}')
"
```

**Regras de decisão:**
- Se a imagem já tem `USER` no Dockerfile (bitnami, distroless) → 🟢 Safe
- Se é imagem oficial de DB/middleware (mongo, postgres, redis, rabbitmq) → 🔴 Verificar docs da imagem
- Se é app container custom → 🟡 Testar em staging
- Se já tem `runAsNonRoot: true` → ✅ Já implementado, pular

**Para read-only rootfs — descobrir paths de escrita:**
```bash
# Executar dentro do container para ver o que escreve
kubectl exec -n <ns> deploy/<service> -- find / -writable -type d 2>/dev/null | head -20
```

---

#### "Trusted registries" / "Image pull from trusted sources"

**Investigação:**
```bash
# Listar todas as imagens e seus registries
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
    acr = '.azurecr.io' in reg
    print(f'{\"✅\" if acr else \"⚠️\"} {reg}: {len(imgs)} images {\"(ACR)\" if acr else \"(EXTERNAL)\"}')
    for img in set(imgs):
        print(f'   {img}')
"
```

**Regras de decisão:**
- Imagens já no ACR do cliente → ✅ Sem ação
- Imagens em docker.io / ghcr.io / quay.io → precisa `az acr import`
- Impacto da migração: rolling update por serviço, ~1 min cada
- Se ACR ficar indisponível após migração: pods rodando OK, mas restarts → ImagePullBackOff

---

#### "Disable API credential automount"

**Investigação:**
```bash
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    sa = pod['spec'].get('serviceAccountName', 'default')
    automount = pod['spec'].get('automountServiceAccountToken', True)
    # Verificar se o container REALMENTE usa a API K8s
    # (containers que fazem leader election, service discovery, etc.)
    name = pod['metadata']['name']
    if automount:
        print(f'⚠️ {name}: SA={sa}, automount=true — verificar se usa K8s API')
    else:
        print(f'✅ {name}: automount já desabilitado')
"
```

**Como verificar se o pod usa K8s API:**
```bash
# Verificar se o processo acessa o token
kubectl exec -n <ns> <pod> -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>/dev/null
# Se existir E o app precisar (ex: leader election, config discovery) → NÃO desabilitar
# Se existir e o app NÃO precisar → seguro desabilitar
```

---

### Recomendações de REDE

#### "NAT Gateway" / "Private Link" / "Restrict API server"

**Investigação — quem faz chamadas externas:**
```bash
# Descobrir pods que fazem outbound connections
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    for c in pod['spec'].get('containers', []):
        for env in c.get('env', []):
            val = env.get('value', '')
            if val.startswith('http') and not any(x in val for x in ['localhost', '127.0.0.1', '.svc.cluster']):
                if not any(svc in val for x in ['ClusterIP']):
                    print(f'{pod[\"metadata\"][\"name\"]}: external call → {val}')
"
```

**Regras de decisão:**
- Serviços que fazem APENAS chamadas internas (ClusterIP) → ✅ Sem impacto em mudança de rede
- Serviços que chamam APIs externas → ⚠️ Afetados durante cutover
- LoadBalancer services → verificar se IPs mudam (clientes com allowlist)
- API server restriction → listar TODOS os IPs que fazem kubectl/CI-CD ANTES de restringir

---

### Recomendações de NODE POOL

#### "Add nodes" / "Ephemeral OS disk" / "VM series upgrade" / "Spot nodes"

**Investigação:**
```bash
# Verificar PDBs existentes (protegem durante drain)
kubectl get pdb -n <ns>

# Verificar anti-affinity (pods que NÃO podem rodar no mesmo node)
kubectl get pods -n <ns> -o json | python3 -c "
import json, sys
pods = json.load(sys.stdin)['items']
for pod in pods:
    affinity = pod['spec'].get('affinity', {})
    if affinity:
        print(f'{pod[\"metadata\"][\"name\"]}: tem affinity rules')
    replicas_owner = pod['metadata'].get('ownerReferences', [{}])[0].get('kind', '')
    print(f'{pod[\"metadata\"][\"name\"]}: controlado por {replicas_owner}')
"

# Verificar StatefulSets (mais complexos de mover)
kubectl get statefulsets -n <ns>

# Verificar PVCs (dados persistentes que precisam ser remontados)
kubectl get pvc -n <ns>
```

**Regras de decisão:**
- Adicionar nodes → ✅ Sempre safe (aditivo)
- Drain de node pool:
  - Pods com PVC → lento (PV detach + reattach)
  - StatefulSets → ordem importa (escala down 1 por vez)
  - Pods sem PDB → todos drenados de uma vez (risco de indisponibilidade)
  - Pods com PDB → respeitam minAvailable/maxUnavailable
- Spot nodes → NUNCA para StatefulSets ou dados persistentes

---

### Recomendações de ACR / Key Vault / Monitoring

#### "Premium tier" / "Geo-replication" / "Diagnostic logs" / "Soft delete"

**Investigação rápida:**
```bash
# Verificar SKU atual do ACR
az acr show --name <acr> --query "{sku:sku.name, adminEnabled:adminUserEnabled}" -o json

# Verificar KV settings
az keyvault show --name <kv> --query "{softDelete:properties.enableSoftDelete, purgeProtection:properties.enablePurgeProtection}" -o json
```

**Regra geral:** Mudanças em recursos de suporte (ACR SKU, KV settings, monitoring)
NUNCA afetam pods rodando. O impacto é apenas em:
- Custo (SKU upgrade = mais caro)
- Futuras operações (ex: soft delete afeta como secrets são deletados)
- Pods que RESTARTAREM durante a operação (raro)

---

## Passo 4: Construir a tabela de impacto

Após coletar dados reais (passos 1-3), montar a tabela:

```markdown
| Serviço | Replicas | Depende de | Durante mudança | Auto-recupera? | Cliente afetado? |
```

### Como preencher cada coluna:

**Replicas:** Dados do `kubectl get pods`. Se >1, rolling update é possível sem downtime.

**Depende de:** Descoberto no Passo 2. Se a dependência é afetada, este serviço também é.

**Durante mudança:** Usar lógica:
- Se o recurso afetado é ADIÇÃO (add node, enable feature) → "✅ Sem impacto"
- Se o recurso afetado precisa de RESTART deste pod → "⚠️ Restart Xs"
- Se o recurso afetado é DEPENDÊNCIA deste pod → "❌ Falha até dependência voltar"
- Se o recurso afetado é REDE e este pod faz outbound → "⚠️ Outbound falha"

**Auto-recupera?:**
- Sim: pod restart e volta a funcionar sozinho (deployment controller)
- Não: mudança causa estado permanente de falha (ex: imagem incompatível)
- Manual: precisa de intervenção (ex: rollback do manifest)

**Cliente afetado?:**
- Verificar se o serviço é exposto via LoadBalancer/Ingress (customer-facing)
- Se é ClusterIP apenas → impacto indireto (via cadeia de dependências)
- Quantificar: "checkout falha por ~30s" não "disruption"

---

## Passo 5: Identificar cascatas

Para cada serviço que QUEBRA (❌):
1. Quem depende deste serviço? (do Passo 2)
2. O que acontece com o dependente? (falha? degrada? enfileira?)
3. Tem dados em risco? (fila perde msgs? DB perde writes?)
4. Propagar até chegar ao cliente final

Formato:
```
<mudança aplicada>
  → <primeiro serviço afetado> — <comportamento>
  → <dependentes> — <consequência>
  → <impacto no cliente final>
  → Auto-recupera? <Sim/Não> | Ação manual? <comando específico>
```
