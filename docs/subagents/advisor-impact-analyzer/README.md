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

### 1. Criar o Sub-Agent

1. Acesse o SRE Agent no [Azure Portal](https://aka.ms/sreagent/portal)
2. Vá em **Builder** → **Subagent Builder**
3. Clique **+ Create subagent**
4. Cole o conteúdo de [`subagent.yaml`](subagent.yaml)
5. Salve e teste no **Playground**

### 2. Upload do Knowledge File

O knowledge file ensina o agente a **investigar** impacto dinamicamente,
não dá respostas prontas. Funciona em QUALQUER ambiente.

1. No SRE Agent portal, vá em **Builder** → **Knowledge Base**
2. Clique **Add file** e faça upload:

| Arquivo | O que contém |
|---------|-------------|
| [`impact-investigation-framework.md`](knowledge/impact-investigation-framework.md) | Framework de investigação: como descobrir dependências, avaliar risco por tipo de recomendação, e construir tabelas de impacto usando dados reais do ambiente |

3. Aguarde a indexação (geralmente < 1 minuto)

### Filosofia: Investigação, não Lookup

O knowledge file **NÃO** contém respostas prontas como "MongoDB quebra com non-root".
Ele ensina o agente a **descobrir** se um container vai quebrar:

```
Antes (lookup estático):     Agora (investigação dinâmica):
"MongoDB: ❌ CrashLoop"       kubectl get pods → descobre imagens reais
                              → verifica se já tem securityContext
                              → identifica se é imagem oficial (requer root)
                              → CONCLUI se vai quebrar naquele ambiente
```

Isso significa que o agente funciona em qualquer ambiente — pet store,
e-commerce real, microserviços bancários — sem precisar reescrever os
knowledge files.

### Como Funciona a Integração

```
Usuário: "Analise as recomendações do Advisor"
    │
    ↓
SRE Agent (principal)
    │
    ├── handoff_description match → invoca Advisor Impact Analyzer
    │
    ↓
Advisor Impact Analyzer (sub-agent)
    │
    ├── 1. Coleta recomendações via `az advisor recommendation list`
    ├── 2. DESCOBRE estado real do ambiente:
    │       ├── kubectl get pods → replicas, imagens, securityContext
    │       ├── kubectl get svc → exposição (LB vs ClusterIP)
    │       └── env vars dos pods → dependências entre serviços
    ├── 3. Consulta Knowledge Base (impact-investigation-framework.md)
    │       → Framework ensina COMO investigar, não dá respostas prontas
    ├── 4. RACIOCINA sobre impacto usando dados reais
    ├── 5. Gera tabela de impacto POR SERVIÇO com dados descobertos
    │
    ↓
Retorna análise ao chat
    │
    ├── Usuário pode pedir deep-dive em uma recomendação
    ├── Usuário pode pedir para executar (handoff ao SRE Agent principal)
    └── Usuário pode pedir análise de outro sub-agent:
        ├── Security Auditor → aprofundar recomendações de segurança
        ├── SLO Guardian → checar se error budget permite janela de manutenção
        └── E-Commerce Expert → impacto de negócio durante downtime
```

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
