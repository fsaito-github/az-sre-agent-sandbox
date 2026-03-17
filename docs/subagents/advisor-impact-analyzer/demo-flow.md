# 🎬 Demo Flow — Advisor Impact Analyzer

## Objetivo

Mostrar como o sub-agent transforma recomendações "paradas" do Azure Advisor em
planos de execução acionáveis, resolvendo o gap que impede clientes de agir.

**Duração:** ~10-15 minutos
**Público-alvo:** Clientes com recomendações do Advisor não atendidas

---

## Preparação (antes do demo)

```bash
# Verificar que há recomendações do Advisor disponíveis
az advisor recommendation list --resource-group rg-srelab-eastus2 -o table

# Se não houver recomendações visíveis, o Advisor pode levar até 24h
# para gerar recomendações após o deploy. Nesse caso, use o prompt
# "analise o impacto de mudar a redundância do disco de LRS para ZRS"
# como cenário hipotético — o agente ainda fará a análise de dependências.
```

> **Nota:** Para gerar recomendações de performance/cost do Advisor, o lab
> precisa rodar por pelo menos 24-48h com carga (virtual-customer ativo).
> O cenário `high-cpu` (`kubectl apply -f k8s/scenarios/high-cpu.yaml`)
> rodando por 30-60 minutos também pode gerar recomendações de right-sizing.

---

## Act 1: O Problema (2 min)

**Narrativa para a audiência:**

> "Quantas recomendações do Azure Advisor vocês têm pendentes no ambiente?
> 10? 50? 200? O problema não é que o Advisor está errado — é que ninguém
> consegue avaliar se é seguro executar a mudança. Vamos resolver isso."

### Prompt 1 — Mostrar recomendações pendentes

```
Quais são todas as recomendações do Azure Advisor para o resource group
rg-srelab-eastus2? Mostre em formato de tabela com categoria, impacto
e recurso afetado.
```

**O que a audiência vê:**
Tabela com recomendações reais do Advisor (reliability, cost, security, etc.)

---

## Act 2: Quick Wins (3 min)

**Narrativa:**

> "Primeiro, vamos identificar o que podemos fazer AGORA, sem risco."

### Prompt 2 — Identificar ações seguras

```
Quais dessas recomendações são "quick wins" — posso executar agora,
sem causar downtime e sem risco? Classifique cada uma por nível de risco.
```

**O que a audiência vê:**
- Tabela com classificação 🟢🟡🟠🔴 para cada recomendação
- Quick wins destacadas (ex: habilitar diagnostic settings, soft delete)
- Mensagem clara: "Estas 3 podem ser executadas agora sem impacto"

**Talking point:**
> "Vejam — X recomendações podem ser resolvidas agora mesmo, sem nenhum risco.
> São as que ficam paradas porque ninguém separou o joio do trigo."

---

## Act 3: Deep Dive em Recomendação de Risco (5 min)

**Narrativa:**

> "Agora vamos pegar uma recomendação que causa medo — uma mudança de
> redundância ou resize que ninguém quer executar sem saber o impacto."

### Prompt 3 — Análise de impacto detalhada

```
Analise em profundidade o impacto de executar a recomendação de
[escolher uma recomendação de reliability ou performance].
Quero saber: downtime estimado, serviços afetados, se tem rollback,
e o plano completo de execução.
```

**Se não houver recomendações de reliability, use:**
```
Analise o impacto de fazer upgrade do node pool do AKS para a
próxima versão do Kubernetes. Quero o plano completo com pre-checks,
execução, post-checks e rollback.
```

**O que a audiência vê:**
- Risk Level com emoji (🟠 Medium Risk)
- Downtime estimado em minutos
- Tabela de serviços afetados com flag customer-facing
- **Plano de execução completo:**
  - ☐ Pre-checks (snapshot, verificar fila, parar load)
  - Comandos az cli específicos
  - ☐ Post-checks (validar pods, testar fluxo)
  - Rollback plan com comandos

**Talking point:**
> "É ISSO que faltava. Não é a recomendação em si — é o plano de execução
> com análise de risco. Agora o cliente pode tomar uma decisão informada."

---

## Act 4: Plano de Execução Batch (3 min)

**Narrativa:**

> "E se eu quiser resolver TODAS as recomendações? Qual a melhor ordem?"

### Prompt 4 — Plano completo ordenado

```
Crie um plano de execução para TODAS as recomendações pendentes,
ordenado do menor para o maior risco. Identifique quais podem ser
feitas em paralelo e estime o tempo total.
```

**O que a audiência vê:**
- Ordem de execução otimizada
- Agrupamento: primeiro 🟢, depois 🟡, depois 🟠, depois 🔴
- Quais podem ser paralelizadas
- Tempo total estimado
- Recomendação: "As primeiras 5 podem ser feitas em 1 hora sem janela de manutenção"

**Talking point:**
> "Em vez de recomendações isoladas que ninguém age, temos um plano
> operacional completo. O cliente pode agendar uma janela e resolver tudo."

---

## Act 5: Execução e Validação (2 min, opcional)

**Se o tempo permitir e houver uma recomendação 🟢 Safe:**

### Prompt 5 — Executar uma quick win

```
Execute a recomendação [quick win escolhida] e valide que tudo
continua funcionando após a mudança.
```

**O que a audiência vê:**
- Agente executa os pre-checks
- Aplica a mudança
- Roda os post-checks
- Confirma: "✅ Recomendação aplicada com sucesso. Todos os serviços operacionais."

---

## Encerramento

**Narrativa final:**

> "O Azure Advisor sabe O QUE fazer. O SRE Agent sabe diagnosticar problemas.
> O Advisor Impact Analyzer é a ponte que faltava: ele analisa SE é seguro
> fazer e COMO fazer. É isso que transforma recomendações paradas em ações
> executadas."

---

## Prompts Alternativos

Se precisar adaptar o demo:

```
# Foco em custo
Quais recomendações do Advisor vão gerar economia? Para cada uma,
compare o saving estimado com o risco operacional de executar.

# Foco em segurança
Analise as recomendações de segurança do Advisor. Quais são as mais
urgentes e quais posso aplicar sem causar disrupção?

# Cenário específico
Preciso fazer upgrade do Kubernetes no AKS de 1.28 para 1.29.
Analise o impacto completo e me dê o plano de execução.

# Cenário de disco
O Advisor recomenda mudar o disco managed de LRS para ZRS.
Esse disco é usado pelo MongoDB no AKS. Analise o impacto.
```

---

## Troubleshooting

| Problema | Solução |
|----------|---------|
| Advisor não mostra recomendações | Lab precisa rodar 24-48h para Advisor gerar recomendações. Use cenários hipotéticos no demo. |
| Recomendações são apenas "generic" | Rode o cenário `high-cpu` por 30-60 min para gerar recomendações de right-sizing. |
| Agente não consegue listar recommendations | Verifique que o SRE Agent tem role Reader na subscription. |
