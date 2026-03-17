# Advisor Impact Playbook — "O Que Quebra"

Upload para: SRE Agent → Builder → Knowledge Base → Add file

Para CADA tipo de recomendação do Advisor, este playbook responde:
**"Se eu aplicar essa correção, o que quebra no meu ambiente?"**

---

## 🟢 SAFE — Nada quebra

### Diagnostic Logs (AKS, Key Vault, qualquer recurso)
**O que quebra:** NADA. Apenas adiciona coleta de logs.
**Todos os serviços:** ✅ Sem impacto.
**Validação:** Verificar que logs aparecem no Log Analytics após ~5 min.

### Soft Delete / Purge Protection (Key Vault)
**O que quebra:** NADA. Apenas protege contra exclusão acidental.
**Todos os serviços:** ✅ Sem impacto.
**⚠️ IRREVERSÍVEL:** Purge protection não pode ser desabilitada uma vez ativa.

### AKS Cost Analysis / VPA Recommendation / Autoscaler Tuning
**O que quebra:** NADA. Apenas monitoramento e otimização.
**Todos os serviços:** ✅ Sem impacto.

### AKS Backup
**O que quebra:** NADA. Apenas adiciona proteção de dados.
**Todos os serviços:** ✅ Sem impacto.

### ACR Premium Upgrade
**O que quebra:** NADA. Upgrade de SKU é online.
**Todos os serviços:** ✅ Sem impacto.
**Custo:** +~$45/mês.

### ACR Geo-Replicação
**O que quebra:** NADA. Replicação é aditiva.
**Todos os serviços:** ✅ Sem impacto.
**Requisito:** Premium SKU (aplicar upgrade primeiro).

---

## 🟡 LOW RISK — Restarts breves, atenção especial com data stores

### Non-Root Containers ("Running containers as root should be avoided")

**O que quebra POR SERVIÇO:**

| Serviço | Quebra? | Por quê? | Auto-recupera? |
|---------|---------|----------|----------------|
| store-front | Não — restart 30s | App containers funcionam non-root | ✅ Sim |
| order-service | Não — restart 30s | Node.js funciona non-root | ✅ Sim |
| product-service | Não — restart 30s | Rust funciona non-root | ✅ Sim |
| makeline-service | Não — restart 30s | Go funciona non-root | ✅ Sim |
| **MongoDB** | **SIM — CrashLoop** | **mongo:4.4 requer root por padrão** | **❌ NÃO** |
| RabbitMQ | Não — UID 999 OK | rabbitmq user já é non-root | ✅ Sim |
| store-admin | Não — restart 30s | Vue.js funciona non-root | ✅ Sim |
| virtual-customer | Não — restart 30s | Stateless, funciona non-root | ✅ Sim |

**Cascata se aplicar no MongoDB:**
```
runAsNonRoot no MongoDB → Container falha ao iniciar
  → CrashLoopBackOff
  → makeline-service: "connection refused" ao MongoDB
  → makeline-service health check falha → restart loop
  → Pedidos acumulam no RabbitMQ (queue depth cresce)
  → store-admin: "no order data"
  → Pedidos novos CONTINUAM sendo aceitos (order→RabbitMQ OK)
  → Mas NÃO são processados (makeline down)
  → AÇÃO MANUAL: kubectl rollout undo deploy/mongodb -n pets
```

**RECOMENDAÇÃO:** Aplicar non-root em: store-front, order-service, product-service,
makeline-service, store-admin, virtual-customer. **EXCLUIR MongoDB e RabbitMQ.**

**Validação pós-execução:**
```
□ kubectl get pods -n pets — todos Running
□ curl http://<store-front-ip>/ — página carrega
□ kubectl exec -n pets deploy/rabbitmq -- rabbitmqctl list_queues — fila OK
□ kubectl logs -n pets deploy/mongodb --tail=5 — sem erros
```

---

### Read-Only Root Filesystem ("Immutable root filesystem should be enforced")

**O que quebra POR SERVIÇO:**

| Serviço | Quebra sem emptyDir? | Paths que precisam de escrita |
|---------|---------------------|------------------------------|
| store-front (nginx) | SIM | /tmp, /var/cache/nginx, /var/run |
| order-service (Node.js) | SIM | /tmp, /home/node |
| product-service (Rust) | Talvez | /tmp |
| makeline-service (Go) | Talvez | /tmp |
| MongoDB | NÃO (PVC já montado) | /data/db (PVC), /tmp (emptyDir) |
| RabbitMQ | SIM | /var/lib/rabbitmq, /tmp |
| store-admin (nginx) | SIM | /tmp, /var/cache/nginx |
| virtual-customer | Talvez | /tmp |

**REGRA:** Para CADA serviço, adicionar emptyDir para TODOS os paths de escrita
ANTES de habilitar readOnlyRootFilesystem. Se esquecer um path, o container CRASHA.

---

### Trusted Registries ("Container images from trusted registries only")

**O que quebra:** NADA se feito corretamente (import → update manifests → rolling update).
**Risco:** Se esquecer de importar uma imagem para o ACR, o pod faz ImagePullBackOff.

| Serviço | Imagem atual | Precisa importar? |
|---------|-------------|-------------------|
| store-front | ghcr.io/azure-samples/...store-front:latest | Sim → ACR |
| order-service | ghcr.io/azure-samples/...order-service:latest | Sim → ACR |
| product-service | ghcr.io/azure-samples/...product-service:latest | Sim → ACR |
| makeline-service | ghcr.io/azure-samples/...makeline-service:latest | Sim → ACR |
| MongoDB | mongo:4.4 (Docker Hub) | Sim → ACR |
| RabbitMQ | rabbitmq:3.11-management-alpine (Docker Hub) | Sim → ACR |
| store-admin | ghcr.io/azure-samples/...store-admin:latest | Sim → ACR |
| virtual-customer | ghcr.io/azure-samples/...virtual-customer:latest | Sim → ACR |

---

### Disable API Credential Automount

**O que quebra:** Se algum pod PRECISA acessar a API do Kubernetes, ele para de funcionar.

| Serviço | Precisa de K8s API? | Seguro desabilitar? |
|---------|-------------------|-------------------|
| Todos os app containers | Não (comunicação via HTTP entre serviços) | ✅ Sim |
| Pods com CSI driver (KV) | Pode precisar | ⚠️ Verificar antes |

---

## 🟠 MEDIUM RISK — Requer janela de manutenção

### NAT Gateway

**O que quebra DURANTE o cutover (~1-5 min):**

| Serviço | Quebra? | Por quê? | Auto-recupera? |
|---------|---------|----------|----------------|
| store-front | ⚠️ Parcial | Assets externos falham | ✅ Sim |
| order-service | ⚠️ Sim | Outbound calls falham | ✅ Sim |
| product-service | ⚠️ Parcial | ai-service inacessível | ✅ Sim |
| makeline-service | Não | Comunicação interna apenas | N/A |
| MongoDB | Não | Comunicação interna apenas | N/A |
| RabbitMQ | Não | Comunicação interna apenas | N/A |

**Validação pós-execução:**
```
□ kubectl exec -n pets deploy/order-service -- wget -qO- https://mcr.microsoft.com
□ Verificar novo outbound IP: az network nat gateway show
□ kubectl get pods -n pets — todos Running
```

---

### Private Link (ACR e Key Vault)

**O que quebra SE MAL CONFIGURADO:**

```
Private endpoint ativado sem DNS correto
  → Pods rodando: ✅ OK (cache)
  → Pod que crashar/escalar: ❌ ImagePullBackOff (ACR) ou ❌ SecretMountFail (KV)
  → Se order-service crashar nesse momento: checkout PARA
  → AÇÃO MANUAL: corrigir DNS privado ou reverter private endpoint
```

**⚠️ RISCO PRINCIPAL:** A mudança não afeta pods rodando, mas SE um pod crashar
DURANTE a operação, ele não consegue restart até a rede estar correta.

---

### Restrict API Server Access

**O que quebra SE CONFIGURADO ERRADO:**
```
API server restrito a IPs específicos
  → kubectl local: ❌ Access denied (se seu IP não está na allowlist)
  → CI/CD pipelines: ❌ Deploy falha (se IP do runner não está na allowlist)
  → SRE Agent: ❌ Pode perder acesso (verificar IP do managed identity)
  → Pods rodando: ✅ OK (não acessam API server diretamente)
```

**⚠️ RISCO:** Se configurar errado, você PERDE acesso ao cluster.
Rollback é complexo porque precisa de acesso ao API server para reverter.

---

## 🔴 HIGH RISK — Aprovar formalmente + testar em non-prod

### Ephemeral OS Disk

**O que quebra:**

| Serviço | Impacto | Tempo offline | Auto-recupera? |
|---------|---------|-------------|----------------|
| TODOS | ❌ Pod evicted durante drain | ~15-20 min | ✅ Sim (reschedule) |
| MongoDB | ❌ PV remount lento | ~5-10 min extra | ✅ Sim (StatefulSet) |
| RabbitMQ | ❌ Msgs in-flight podem perder | ~3-5 min | ⚠️ Verificar fila |

**Cascata completa:**
```
Node pool recreation → kubectl drain todos os nodes
  → TODOS os pods evicted
  → PVs detached do node antigo
  → Novo node pool criado com Ephemeral OS
  → PVs re-attached aos novos nodes
  → Pods rescheduled
  → MongoDB: PV remount + data check (~5-10 min)
  → RabbitMQ: restart + verificar se msgs sobreviveram
  → App containers: restart normal (~30s cada)
  → DURANTE TUDO ISSO: loja completamente offline
```

**PRÉ-REQUISITOS OBRIGATÓRIOS:**
```
□ Snapshot de TODOS os PVs (MongoDB!)
□ kubectl scale deploy virtual-customer -n pets --replicas=0
□ Esperar RabbitMQ queue drenar: rabbitmqctl list_queues
□ Verificar que VM size suporta ephemeral disk
□ Testar em ambiente non-prod primeiro
□ Comunicar stakeholders: "loja offline por ~20 min"
```
