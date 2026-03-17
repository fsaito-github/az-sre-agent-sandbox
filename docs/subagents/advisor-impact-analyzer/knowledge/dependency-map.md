# Impact Matrix — Recurso Azure × Serviço K8s

Upload para: SRE Agent → Builder → Knowledge Base → Add file

## Como usar esta matriz

Quando o agente analisa uma recomendação do Advisor:
1. Identifique qual recurso Azure é afetado
2. Cruze com a tabela abaixo para saber o impacto em cada serviço
3. Use a coluna "Auto-recupera?" para informar o cliente

---

## Matriz: Recurso Afetado → Impacto por Serviço

### AKS Node Pool (scale, drain, recreate)

| Serviço | Impacto durante drain | Auto-recupera? | Tempo | Cliente afetado? |
|---------|----------------------|----------------|-------|-----------------|
| store-front | ❌ Offline até reschedule | ✅ Sim (reschedule) | ~2-5 min | Sim — loja inacessível |
| order-service | ❌ Offline até reschedule | ✅ Sim | ~2-5 min | Sim — checkout falha |
| product-service | ❌ Offline até reschedule | ✅ Sim | ~2-5 min | Sim — catálogo vazio |
| makeline-service | ❌ Offline até reschedule | ✅ Sim | ~2-5 min | Não (backend) |
| MongoDB | ❌ Offline + PV remount | ✅ Sim (StatefulSet) | ~5-10 min | Indireto — fulfillment para |
| RabbitMQ | ❌ Offline + possível perda msgs in-flight | ⚠️ Manual (verificar fila) | ~3-5 min | Indireto — pedidos podem perder |
| store-admin | ❌ Offline até reschedule | ✅ Sim | ~2-5 min | Não (interno) |
| virtual-customer | ❌ Offline até reschedule | ✅ Sim | ~2-5 min | Não (sintético) |

**Cascata:** Node drain → TODOS os pods evicted → PVs remontados → pods rescheduled.
MongoDB (StatefulSet) é o mais lento a recuperar por causa do PV remount.

---

### AKS Node Pool (add nodes — operação aditiva)

| Serviço | Impacto | Auto-recupera? | Cliente afetado? |
|---------|---------|----------------|-----------------|
| TODOS | ✅ Sem impacto | N/A | Não |

Adicionar nodes é sempre seguro. Pods existentes não são movidos.

---

### AKS Config (autoscaler, VPA, cost analysis, backup)

| Serviço | Impacto | Auto-recupera? | Cliente afetado? |
|---------|---------|----------------|-----------------|
| TODOS | ✅ Sem impacto | N/A | Não |

Mudanças de configuração do cluster não afetam pods rodando.

---

### AKS Security (non-root, read-only rootfs, automount)

| Serviço | Impacto ao aplicar securityContext | Auto-recupera? | Cliente afetado? |
|---------|------------------------------------|----------------|-----------------|
| store-front | ⚠️ Rolling restart ~30s | ✅ Sim | Breve (~30s) se 1 replica |
| order-service | ⚠️ Rolling restart ~30s | ✅ Sim | Pedidos falham ~30s |
| product-service | ⚠️ Rolling restart ~30s | ✅ Sim | Catálogo indisponível ~30s |
| makeline-service | ⚠️ Rolling restart ~30s | ✅ Sim | Não (backend) |
| MongoDB | ❌ PODE FALHAR — imagem mongo:4.4 requer root | ❌ NÃO | Sim — pipeline de pedidos PARA |
| RabbitMQ | ⚠️ Restart ~30s (UID 999 compatível com non-root) | ✅ Sim | Não |
| store-admin | ⚠️ Rolling restart ~30s | ✅ Sim | Não (interno) |
| virtual-customer | ⚠️ Restart ~30s | ✅ Sim | Não (sintético) |

**⚠️ ALERTA CRÍTICO:** MongoDB (mongo:4.4) NÃO funciona com runAsNonRoot sem
configuração especial (runAsUser: 999, fsGroup: 999, ou imagem Bitnami).
SEMPRE excluir MongoDB da primeira fase de hardening ou testar antes.

**Cascata se MongoDB falhar (non-root):**
```
securityContext.runAsNonRoot aplicado ao MongoDB
  → Container não inicia (permissão negada)
  → Pod entra em CrashLoopBackOff
  → makeline-service perde conexão com DB → health check falha
  → Pedidos acumulam no RabbitMQ (NÃO são perdidos)
  → store-admin não exibe dados de pedidos
  → PEDIDOS CONTINUAM SENDO ACEITOS (order-service → RabbitMQ OK)
  → MAS NÃO SÃO PROCESSADOS até MongoDB voltar
  → AÇÃO MANUAL: reverter securityContext do MongoDB
```

---

### ACR (SKU upgrade, geo-rep)

| Serviço | Impacto | Auto-recupera? | Cliente afetado? |
|---------|---------|----------------|-----------------|
| TODOS (rodando) | ✅ Sem impacto | N/A | Não |
| Novos pods/restarts | ⚠️ Se ACR offline → ImagePullBackOff | ✅ Sim (quando ACR volta) | Só se pod crashar durante |

ACR upgrade e geo-rep são operações online. Pods já rodando NÃO são afetados.
Risco apenas se um pod crashar durante a operação e tentar pull de imagem.

---

### ACR Private Link / Network Restrictions

| Serviço | Impacto se mal configurado | Auto-recupera? | Cliente afetado? |
|---------|--------------------------|----------------|-----------------|
| TODOS (rodando) | ✅ Sem impacto imediato | N/A | Não |
| Qualquer pod que restartar | ❌ ImagePullBackOff (não consegue pull) | ❌ NÃO até corrigir rede | Sim — se pod afetado for customer-facing |

**Cascata se rede bloquear ACR:**
```
Private endpoint configurado sem rota correta
  → Pods rodando: OK (imagem já em cache)
  → Pod crashar ou escalar: ImagePullBackOff
  → Se order-service crashar: checkout para
  → Se MongoDB crashar: fulfillment para
  → AÇÃO MANUAL: corrigir DNS/rede do private endpoint
```

---

### VNet / NAT Gateway

| Serviço | Impacto durante cutover (~1-5 min) | Auto-recupera? | Cliente afetado? |
|---------|------------------------------------|----------------|-----------------|
| store-front | ⚠️ Recursos externos falham | ✅ Sim | Sim — assets externos |
| order-service | ⚠️ Outbound calls falham | ✅ Sim | Sim — pedidos podem falhar |
| product-service | ⚠️ ai-service inacessível | ✅ Sim | Parcial — sem AI recs |
| makeline-service | ✅ Sem impacto (interno) | N/A | Não |
| MongoDB | ✅ Sem impacto (interno) | N/A | Não |
| RabbitMQ | ✅ Sem impacto (interno) | N/A | Não |
| store-admin | ⚠️ Recursos externos falham | ✅ Sim | Não (interno) |
| virtual-customer | ⚠️ Pedidos falham | ✅ Sim | Não (sintético) |

Serviços que fazem APENAS comunicação interna (MongoDB, RabbitMQ, makeline) NÃO são afetados.

---

### Key Vault (settings, private link)

| Mudança | Impacto | Serviços afetados |
|---------|---------|------------------|
| Soft delete / purge protection | ✅ Nenhum | Nenhum |
| Diagnostic logs | ✅ Nenhum | Nenhum |
| Private link | ⚠️ Se pods usam CSI driver: falha ao montar secrets em restart | Pods com volume mounts do KV |

---

### Log Analytics / App Insights / Grafana / Prometheus

| Mudança | Impacto em serviços | Cliente afetado? |
|---------|-------------------|-----------------|
| Qualquer mudança | ✅ NENHUM impacto em serviços | Não |

Estes são recursos de observabilidade. Mudanças neles afetam apenas monitoramento,
nunca a aplicação em si.

---

## Auto-Recuperação por Serviço

| Serviço | Replicas | readinessProbe | livenessProbe | Auto-recupera após restart? |
|---------|----------|---------------|---------------|---------------------------|
| store-front | 2 | ✅ /health | ✅ /health | ✅ Sim — 2 replicas, rolling |
| order-service | 2 | ✅ /health | ✅ /health | ✅ Sim — 2 replicas, rolling |
| product-service | 2 | ✅ /health | ✅ /health | ✅ Sim — 2 replicas, rolling |
| makeline-service | 2 | ✅ /health | ✅ /health | ✅ Sim — 2 replicas, rolling |
| MongoDB | 1 | ✅ port check | ✅ port check | ⚠️ Lento — PV remount + data load |
| RabbitMQ | 1 | ✅ diagnostics | ✅ diagnostics | ⚠️ Msgs in-flight podem perder |
| store-admin | 1 | ✅ /health | ✅ /health | ⚠️ 1 replica — breve indisponibilidade |
| virtual-customer | 1 | Nenhum | Nenhum | ✅ Sim — stateless |

**Serviços com 1 replica (MongoDB, RabbitMQ, store-admin, virtual-customer):**
NÃO têm redundância. Qualquer restart = downtime completo daquele serviço até voltar.

**Serviços com 2 replicas (store-front, order-service, product-service, makeline-service):**
Rolling update possível sem downtime SE usando Deployment strategy RollingUpdate.
