# 🔍 Advisor Impact Analyzer

## O Problema

O Azure Advisor gera recomendações valiosas (confiabilidade, custo, segurança, performance), mas a maioria fica **meses sem ser executada** porque as equipes não conseguem responder:

- Vai causar downtime? Quanto tempo?
- Quais serviços serão afetados?
- Tem como reverter se der errado?
- Preciso de janela de manutenção?
- É seguro fazer agora?

## A Solução

O **Advisor Impact Analyzer** transforma uma recomendação vaga do Advisor em um **plano de execução completo com análise de risco**, incluindo:

- Mapeamento de recursos e dependências afetadas
- Estimativa de downtime
- Blast radius (serviços e usuários impactados)
- Classificação de risco (🟢 Safe → 🔴 High Risk)
- Plano step-by-step com pre-checks, execução, post-checks e rollback
- Recomendação de timing (janela de manutenção ou execução imediata)

## Por que não é redundante com o SRE Agent nativo?

| Capacidade | SRE Agent Nativo | Advisor Impact Analyzer |
|-----------|-----------------|------------------------|
| Ler recomendações do Advisor | ✅ Pode consultar | ✅ Consulta e analisa |
| Diagnóstico de incidentes | ✅ Core feature | ❌ Não é sua função |
| **Análise de impacto operacional** | ❌ | ✅ Especializado |
| **Mapeamento de dependências** | Parcial | ✅ Completo (Azure + K8s) |
| **Plano de execução com rollback** | ❌ | ✅ Estruturado |
| **Classificação de risco** | ❌ | ✅ 4 níveis |
| **Batch analysis e priorização** | ❌ | ✅ Com ordem de execução |

O SRE Agent sabe que o Advisor recomenda algo, mas não analisa se é **seguro executar agora** nem produz um plano operacional.

## Instalação

1. Acesse o SRE Agent no [Azure Portal](https://aka.ms/sreagent/portal)
2. Vá em **Builder** → **Subagent Builder**
3. Clique **+ Create subagent**
4. Cole o conteúdo de [`subagent.yaml`](subagent.yaml)
5. Salve e teste no **Playground**

## Prompts de Teste

### Visão Geral
```
Quais são as recomendações do Azure Advisor para o resource group rg-srelab-eastus2?
Mostre um resumo com análise de impacto de cada uma.
```

### Análise Específica
```
Analise o impacto de executar a recomendação de [redundância/resize/upgrade]
do Advisor. Quero saber: downtime, serviços afetados, e plano de rollback.
```

### Quick Wins
```
Quais recomendações do Advisor posso executar agora com segurança,
sem causar downtime? Liste as "quick wins".
```

### Plano de Execução Completo
```
Crie um plano de execução para todas as recomendações do Advisor,
ordenado do menor para o maior risco. Inclua estimativa de tempo total.
```

### Batch Execution
```
Quais recomendações do Advisor podem ser executadas em paralelo
e quais precisam ser sequenciais? Otimize o tempo total.
```

### Análise de Custo x Risco
```
Para as recomendações de custo do Advisor, qual a economia estimada
versus o risco operacional de cada mudança?
```

### Pré-Mudança
```
Vou executar a recomendação X do Advisor. Me dê o checklist
completo de pre-checks antes de começar.
```

### Pós-Mudança
```
Acabei de executar a recomendação X do Advisor. Quais validações
devo fazer para confirmar que tudo está funcionando?
```

## Classificação de Risco

| Nível | Critério | Ação |
|-------|---------|------|
| 🟢 **Safe** | Sem downtime, sem risco de dados, reversível | Executar a qualquer momento |
| 🟡 **Low Risk** | Disrupção breve (<1 min), reversível | Executar em horário de baixo tráfego |
| 🟠 **Medium Risk** | Downtime 1-15 min, sem perda de dados | Agendar janela de manutenção |
| 🔴 **High Risk** | Downtime >15 min, risco de dados, difícil reverter | Aprovação + janela + rollback testado |

## Exemplo de Output

```
══════════════════════════════════════════════════════════════════
🔍 ADVISOR IMPACT ANALYSIS
══════════════════════════════════════════════════════════════════

📋 RECOMMENDATION
Category:       Reliability
Description:    Alterar redundância do disco managed de LRS para ZRS
Resource:       disk-mongodb-pvc-01 (rg-srelab-eastus2)
Advisor Impact: High

──────────────────────────────────────────────────────────────────
⚡ OPERATIONAL IMPACT ASSESSMENT
──────────────────────────────────────────────────────────────────
Risk Level:          🟠 Medium Risk
Estimated Downtime:  ~5-10 minutes
Blast Radius:        MongoDB → makeline-service → order fulfillment
Data Risk:           Nenhum (snapshot recomendado como precaução)
Rollback Possible:   ✅ Sim — reverter para LRS
Maintenance Window:  ⚠️ Necessária

Affected Services:
| Service          | Impact                          | Customer-Facing? |
|------------------|---------------------------------|-----------------|
| MongoDB          | Offline durante operação        | Não (backend)   |
| makeline-service | Não processa pedidos            | Indireto        |
| store-admin      | Não exibe pedidos               | Não (interno)   |
| order-service    | Pedidos enfileiram no RabbitMQ  | Indireto        |
| store-front      | Checkout funciona, fulfillment pausado | Parcial  |
```
