
# ══════════════════════════════════════════════════════════════════
# 🔍 ADVISOR IMPACT ANALYSIS — rg-srelab-eastus2
# ══════════════════════════════════════════════════════════════════

## Ambiente Atual
- **AKS Cluster**: aks-srelab (K8s 1.32)
- **Node Pools**: system (1x Standard_D2s_v3, Managed OS disk), workload (0 nodes, autoscale)
- **Availability Zones**: Não configuradas
- **ACR**: acrsrelabtlwgvg (Basic tier, acesso público habilitado)
- **Key Vault**: kv-srelab-tlwgvg
- **Total de Recomendações**: 22

---

## 📊 Resumo por Risco Operacional

| # | Categoria | Recomendação | Recurso | Impacto Advisor | Risco Operacional | Downtime | Quick Win? |
|---|-----------|-------------|---------|-----------------|-------------------|----------|------------|
| 1 | Security | Diagnostic logs em AKS | aks-srelab | Low | 🟢 Safe | Nenhum | ✅ Sim |
| 2 | Security | Diagnostic logs em Key Vault | kv-srelab-tlwgvg | Low | 🟢 Safe | Nenhum | ✅ Sim |
| 3 | Security | Habilitar proteção contra exclusão (KV) | kv-srelab-tlwgvg | Medium | 🟢 Safe | Nenhum | ✅ Sim |
| 4 | Cost | Usar AKS Cost Analysis | aks-srelab | Medium | 🟢 Safe | Nenhum | ✅ Sim |
| 5 | Cost | Ajustar perfil do cluster autoscaler | aks-srelab | Medium | 🟢 Safe | Nenhum | ✅ Sim |
| 6 | Cost | Habilitar VPA em modo recomendação | aks-srelab | Medium | 🟢 Safe | Nenhum | ✅ Sim |
| 7 | HighAvailability | Usar AKS Backup para volumes persistentes | aks-srelab | Medium | 🟢 Safe | Nenhum | ✅ Sim |
| 8 | HighAvailability | ACR Premium tier | acrsrelabtlwgvg | High | 🟢 Safe | Nenhum | ⚠️ Custo |
| 9 | HighAvailability | Mínimo 2 nodes no system pool | aks-srelab | High | 🟡 Low | Nenhum (adição) | ⚠️ Custo |
| 10 | Cost | Considerar Spot nodes | aks-srelab | Medium | 🟡 Low | Nenhum (adição) | ⚠️ Custo |
| 11 | Security | Containers rodando como root | aks-srelab | High | 🟡 Low | ~30s/pod | Não |
| 12 | Security | Read-only root filesystem | aks-srelab | Medium | 🟡 Low | ~30s/pod | Não |
| 13 | Security | Imagens de registros confiáveis | aks-srelab | High | 🟡 Low | Rolling ~1min | Não |
| 14 | Security | Desabilitar automount de credenciais API | aks-srelab | High | 🟡 Low | Restart pods | Não |
| 15 | HighAvailability | ACR Geo-replicação | acrsrelabtlwgvg | High | 🟠 Medium | Nenhum | Não (requer Premium) |
| 16 | HighAvailability | Usar NAT gateway | vnet-srelab | Medium | 🟠 Medium | ~1-5 min outbound | Não |
| 17 | Security | API server com acesso restrito | aks-srelab | High | 🟠 Medium | Risco de autenticação | Não |
| 18 | Security | Key Vault via private link | kv-srelab-tlwgvg | Medium | 🟠 Medium | Risco de conectividade | Não |
| 19 | Security | ACR via private link | acrsrelabtlwgvg | Medium | 🟠 Medium | Risco de conectividade | Não |
| 20 | Security | ACR restringir acesso de rede | acrsrelabtlwgvg | Medium | 🟠 Medium | Risco de conectividade | Não |
| 21 | OpEx | Usar VM series Ddv5 | aks-srelab | Low | 🟠 Medium | Rolling ~5-10 min | Não |
| 22 | OpEx | Usar Ephemeral OS disk | aks-srelab | Low | 🔴 High | ~15-20 min | Não |

---

## 🟢 QUICK WINS — Execução Imediata (7 itens, zero downtime)

Estes podem ser executados a qualquer momento, sem janela de manutenção:

### 1. Diagnostic logs em AKS
- **Risco**: 🟢 Safe | **Downtime**: Nenhum | **Rollback**: ✅ Remover configuração
- **Comando**: `az monitor diagnostic-settings create` para enviar logs ao Log Analytics
- **Impacto**: Nenhum serviço afetado — apenas habilita coleta de logs

### 2. Diagnostic logs em Key Vault
- **Risco**: 🟢 Safe | **Downtime**: Nenhum | **Rollback**: ✅ Remover configuração
- **Comando**: `az monitor diagnostic-settings create` para kv-srelab-tlwgvg
- **Impacto**: Nenhum — apenas telemetria adicional

### 3. Proteção contra exclusão do Key Vault
- **Risco**: 🟢 Safe | **Downtime**: Nenhum | **Rollback**: ⚠️ Purge Protection é irreversível (por design)
- **Comando**: `az keyvault update --enable-purge-protection true`
- **Nota**: Soft delete + purge protection. Uma vez habilitado, purge protection não pode ser desabilitado.

### 4. AKS Cost Analysis
- **Risco**: 🟢 Safe | **Downtime**: Nenhum | **Rollback**: ✅ Desabilitar
- **Ação**: Habilitar add-on de análise de custos no cluster
- **Impacto**: Apenas adiciona visibilidade de custos

### 5. Ajustar perfil do cluster autoscaler
- **Risco**: 🟢 Safe | **Downtime**: Nenhum | **Rollback**: ✅ Reverter perfil
- **Ação**: Configurar parâmetros como `scale-down-delay-after-add`, `scale-down-unneeded-time`
- **Impacto**: Otimiza escalabilidade — sem reinício de pods

### 6. Habilitar VPA (modo recomendação)
- **Risco**: 🟢 Safe | **Downtime**: Nenhum | **Rollback**: ✅ Remover
- **Ação**: Habilitar Vertical Pod Autoscaler em modo "Off" (apenas recomendações)
- **Impacto**: Apenas gera sugestões de requests/limits — sem alteração automática

### 7. AKS Backup
- **Risco**: 🟢 Safe | **Downtime**: Nenhum | **Rollback**: ✅ Remover
- **Ação**: Configurar Azure Backup para proteger PVCs (MongoDB, RabbitMQ)
- **Impacto**: Crítico para DR — MongoDB StatefulSet tem dados persistentes

---

## 🟡 BAIXO RISCO — Executar em horário de menor tráfego (6 itens)

### 8. ACR Premium tier upgrade
- **Risco**: 🟢 Safe (upgrade de tier) | **Custo**: Aumento de ~$5/dia → ~$150/mês
- **Downtime**: Nenhum | **Rollback**: ✅ Downgrade para Basic
- **Pré-requisito para**: Geo-replicação (#15) e Private Link (#19)
- **Serviços afetados**: Nenhum — pull de imagens continua funcional

### 9. Mínimo 2 nodes no system pool
- **Risco**: 🟡 Low | **Downtime**: Nenhum (adição de node)
- **Custo**: +1x Standard_D2s_v3 (~$70/mês)
- **Comando**: `az aks nodepool update --min-count 2 --max-count 3`
- **Impacto**: ⚡ CRÍTICO para HA — atualmente 1 system node é SPOF!
- **Serviços afetados**: Nenhum (apenas adiciona capacidade)

### 10. Spot nodes para workloads tolerantes
- **Risco**: 🟡 Low | **Downtime**: Nenhum (novo pool)
- **Custo**: Redução de até 60-80% em compute
- **Nota**: Spot VMs podem ser evicted a qualquer momento — ideal para virtual-customer, não para MongoDB

### 11-14. Hardening de segurança em pods
Estas 4 recomendações requerem alterações nos manifests Kubernetes:

| Recomendação | Ação | Risco | Cuidado |
|-------------|------|-------|---------|
| Containers como root | `securityContext.runAsNonRoot: true` | 🟡 | MongoDB/RabbitMQ podem exigir root |
| Read-only rootfs | `securityContext.readOnlyRootFilesystem: true` | 🟡 | Exige tmpfs para dirs de escrita |
| Registros confiáveis | Usar apenas imagens do ACR | 🟡 | Requer import de imagens externas |
| Desabilitar automount API | `automountServiceAccountToken: false` | 🟡 | Verificar se pods usam K8s API |

**⚠️ ALERTA**: MongoDB e RabbitMQ usam imagens oficiais que podem **não funcionar** como non-root. Testar individualmente antes de aplicar em produção.

---

## 🟠 RISCO MÉDIO — Requer Janela de Manutenção (6 itens)

### 15. ACR Geo-replicação
- **Pré-requisito**: Upgrade para Premium (#8)
- **Risco**: 🟠 Medium | **Downtime**: Nenhum
- **Custo**: ~$50/mês por região adicional
- **Rollback**: ✅ Remover réplica regional

### 16. NAT Gateway
- **Risco**: 🟠 Medium | **Downtime**: ~1-5 min (tráfego outbound)
- **Blast Radius**: Todos os pods → afeta order-service (→ RabbitMQ), product-service, conectividade externa
- **Custo**: ~$32/mês + $0.045/GB
- **Rollback**: ✅ Reverter para load balancer outbound

### 17. API server com acesso restrito
- **Risco**: 🟠 Medium | **Downtime**: Potencial perda de acesso ao cluster
- **Blast Radius**: Todos os pipelines CI/CD + acesso kubectl
- **Rollback**: ⚠️ Complexo — requer acesso alternativo se configurado incorretamente
- **Pré-checks**: Listar todos os IPs que acessam o API server

### 18-20. Private Link + Network Restrictions (KV + ACR)
- **Risco**: 🟠 Medium | **Downtime**: Potencial perda de conectividade
- **Blast Radius**: Se mal configurado, pods não conseguem pull images (ACR) ou acessar secrets (KV)
- **Cadeia de dependência**:
  - ACR indisponível → nenhum pod novo pode iniciar
  - KV indisponível → pods que dependem de secrets falham
- **Rollback**: ✅ Remover private endpoint / reverter network rules

### 21. VM series Ddv5 (latest generation)
- **Risco**: 🟠 Medium | **Downtime**: Rolling ~5-10 min por node
- **Blast Radius**: Todos os pods são re-scheduled durante o upgrade
- **Cadeia**: store-front → order-service → RabbitMQ → makeline-service → MongoDB
- **Rollback**: ✅ Reverter para D2s_v3
- **Nota**: Verificar disponibilidade da VM series na subscription

---

## 🔴 ALTO RISCO — Requer Aprovação e Planejamento (1 item)

### 22. Ephemeral OS Disk
- **Risco**: 🔴 High | **Downtime**: ~15-20 min (recriação do node pool)
- **Blast Radius**: TODOS os pods do pool afetado — cascata completa
- **Node Pools afetados**: system-128GB, workload-128GB
- **Cadeia completa**:
  ```
  Node pool drain → Todos pods evicted → PVs remontados → Pods rescheduled
  MongoDB (StatefulSet) → possível perda de leader election
  RabbitMQ → possível perda de mensagens in-flight
  ```
- **Rollback**: ❌ Complexo — requer recriação do pool novamente
- **Pré-requisitos OBRIGATÓRIOS**:
  - ✅ Snapshot de todos os PVs (MongoDB, RabbitMQ)
  - ✅ Escalar virtual-customer para 0
  - ✅ Verificar se VM size suporta ephemeral disk do tamanho necessário
  - ✅ Teste completo em ambiente non-prod primeiro

---

## 📈 Ordem de Execução Recomendada

```
Fase 1 — Quick Wins (agora, ~30 min total)
├── 🟢 Diagnostic logs AKS + Key Vault
├── 🟢 Proteção contra exclusão Key Vault  
├── 🟢 AKS Cost Analysis
├── 🟢 Fine-tune autoscaler
├── 🟢 VPA modo recomendação
└── 🟢 AKS Backup

Fase 2 — Melhorias de HA (próxima janela, ~15 min)
├── 🟡 Escalar system pool para mínimo 2 nodes ⭐ PRIORIDADE
└── 🟢 ACR Premium upgrade (pré-requisito para Fase 4)

Fase 3 — Hardening de Segurança (baixo tráfego, testar 1 serviço por vez)
├── 🟡 Desabilitar automount API credentials
├── 🟡 Read-only root filesystem (exceto MongoDB/RabbitMQ)
├── 🟡 Imagens apenas de registros confiáveis
└── 🟡 Containers como non-root (exceto MongoDB/RabbitMQ)

Fase 4 — Rede e Isolamento (janela de manutenção planejada)
├── 🟠 NAT Gateway
├── 🟠 ACR Private Link + network restrictions
├── 🟠 Key Vault Private Link
├── 🟠 API server com acesso restrito
└── 🟠 ACR Geo-replicação

Fase 5 — Infraestrutura pesada (change board + teste completo)
├── 🟠 Migrar para VM series Ddv5
└── 🔴 Ephemeral OS disk (último — maior risco)
```

---

## 💰 Impacto de Custo Estimado

| Recomendação | Delta Mensal |
|-------------|-------------|
| +1 system node (D2s_v3) | +~$70/mês |
| ACR Basic → Premium | +~$145/mês |
| ACR Geo-replicação (1 região) | +~$50/mês |
| NAT Gateway | +~$32/mês + tráfego |
| VPA + Autoscaler tuning | Economia potencial de 10-30% |
| Spot nodes | Economia de 60-80% no pool |
| **Impacto líquido estimado** | **+~$250-300/mês** (antes de otimizações) |

---

## ⚠️ Alerta Crítico

**O system node pool tem apenas 1 node — isto é um Single Point of Failure.**
Se este node falhar, TODOS os serviços ficam indisponíveis. A recomendação #9 (escalar para 2 nodes) deve ser a **primeira ação** após os quick wins.
