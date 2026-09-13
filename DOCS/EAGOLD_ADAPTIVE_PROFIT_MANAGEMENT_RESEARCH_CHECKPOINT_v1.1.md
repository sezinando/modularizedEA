# EAGOLD — Adaptive Profit Management Research Checkpoint v1.1

**Data:** 2026-09-13  
**Escopo:** avanço da pesquisa de Adaptive Profit Management após a instrumentação Counterfactual Path e análise causal do pregão de 01/06/2026.

## 1. Objetivo

Investigar uma gestão adaptativa de lucro que:

1. reconheça o regime de mercado;
2. reduza exposição/realize mais cedo quando o EAGOLD estiver fortemente posicionado contra o movimento primário;
3. preserve continuidade quando o posicionamento estiver alinhado e o preço continuar favorável;
4. permita evolução posterior para partial + BE + runner/trailing;
5. permaneça observer/counterfactual antes de qualquer alteração do comportamento live.

Arquitetura de referência:

```text
R12 / MAIA
      ↓
CONTEXT
      ↓
ADAPTIVE PROFIT MANAGEMENT
      ↓
AUTORIZAÇÃO ECONÔMICA
      ↓
BRX / R4 / R5
      ↓
ACTION CONTRACT
      ↓
CORE EXECUTION
      ↓
BROKER
```

R9/R10/R11 continuam sendo o envelope de risco/exposição.

## 2. Infraestrutura consolidada

### Counterfactual Path

`Core/EAGOLD_CounterfactualPathTelemetry.mqh` registra o estado observável do basket/tickets em resolução de tick, associado ao contexto R12 em M5.

A telemetria foi otimizada para amostragem temporal de aproximadamente 2 segundos, mantendo registros em mudanças estruturais relevantes. A intenção é preservar resolução suficiente para replay sem tornar o tester excessivamente pesado.

Arquivo de pesquisa principal:

`EAGOLD_COUNTERFACTUAL_PATH.csv`

### R12

R12 é o observador de regime primário em M5, baseado em candle fechado e permanece observer-only.

Estados principais utilizados na pesquisa:

- BULLISH_TREND
- BEARISH_TREND
- BULLISH_PULLBACK
- BEARISH_PULLBACK
- HIGH_VOLATILITY
- LOW_VOLATILITY
- TRANSITION_BULLISH
- TRANSITION_BEARISH
- EXHAUSTION
- CONFLICT
- UNKNOWN

### Excursion Tracker

Permanece observer-only e fornece estado de ciclo/inter-evento para a telemetria counterfactual. Os arquivos de pesquisa redundantes `EAGOLD_EXCURSION_CYCLES.csv` e `EAGOLD_EXCURSION_EVENTS.csv` foram removidos da gravação operacional da pesquisa; o estado em memória foi preservado.

## 3. Baseline P0

O baseline histórico é a realização efetivamente ocorrida no EAGOLD:

- evento ledger = fonte econômica primária;
- Counterfactual Path = fonte primária do estado dos tickets/posições;
- R12 = contexto sincronizado.

Reconstrução anterior identificou 47.734 linhas PATH, 66 tickets, 5 ciclos no primeiro conjunto de reconstrução e confirmou que eventos terminais podem não possuir linhas POST_ACTION porque o basket já ficou flat. Portanto, a realização econômica terminal deve ser reconciliada pelo event ledger.

## 4. P1 — resultado inicial

O primeiro replay P1 foi definido como uma realização parcial feasibility-aware, fechando 0,01 lote do ticket mais lucrativo elegível em timestamps de eventos P0.

No primeiro conjunto de 5 ciclos, 4 ciclos completos produziram:

- P0 = US$ 241,21
- P1 = US$ 273,01
- Delta = +US$ 31,80
- 1 ciclo melhorado / 3 piorados

Isso não constituiu evidência de deploy.

O teste de sensibilidade mostrou que políticas simplistas como `COUNTER -> realize` e `CONFLICT -> realize` não foram confirmadas. A amostra era pequena e as regras dependiam dos próprios timestamps P0, portanto a pesquisa migrou para decisão causal independente dos eventos P0.

## 5. P1 causal

O replay causal foi construído sem utilizar:

- MFE futuro;
- MAE futuro;
- resultado final;
- regime futuro;
- timestamp de decisão P0.

Variáveis permitidas no instante da decisão:

- floating P/L;
- equity econômica histórica;
- pico histórico;
- giveback histórico;
- slope calculada somente com passado/presente;
- R12 atual;
- exposição atual;
- BID/ASK;
- estado dos tickets.

No conjunto inicial de 4 ciclos completos:

| Política | Delta P1-P0 | Melhorados | Piorados |
|---|---:|---:|---:|
| Giveback 25% | +US$ 57,00 | 2 | 2 |
| Giveback 40% | +US$ 49,73 | 2 | 2 |
| Counter Profit | -US$ 53,74 | 1 | 3 |
| Aligned Giveback | +US$ 15,46 | 2 | 2 |
| Slope Reversal | -US$ 37,98 | 1 | 3 |

A varredura de thresholds também mostrou que o valor exato do threshold de giveback não é, neste estágio, o principal determinante do comportamento.

## 6. Dataset 01/06 — amostra mais recente

O arquivo `EAGOLD_COUNTERFACTUAL_PATH(4).csv` contém:

- 121.416 linhas;
- 49 colunas;
- período de 01/06/2026 01:00:05 até 02/06/2026 03:11:06;
- 11 ciclos;
- 178 tickets;
- 14 eventos;
- 100% R12 válido;
- 121.337 registros PRE_ACTION;
- 79 registros POST_ACTION.

O 11º ciclo permaneceu aberto e é censurado para comparação de performance. Os 10 primeiros ciclos são tratados como completos para a análise econômica do dia.

P0 realizado dos 10 ciclos completos: **US$ 561,02**.

## 7. Gatilho causal investigado

Foi testado o estado:

```text
Equity Econômica >= US$ 20
AND
Giveback >= 25%
AND
GrossLots >= 0,02
```

Definição:

`Equity Econômica = REALIZED_CYCLE_PL + BASKET_FLOATING_PL`

Foram encontrados 8 pontos de decisão:

| Ciclo | Hora | Equity | Giveback | Gross | R12 | Resultado posterior |
|---|---|---:|---:|---:|---|---|
| 1 | 01:04:30 | 24,67 | 26,99% | 0,05 | BEARISH_TREND | forte deterioração |
| 3 | 05:32:14 | 20,62 | 25,56% | 0,05 | BEARISH_PULLBACK | deterioração moderada |
| 4 | 08:49:39 | 53,00 | 26,44% | 0,05 | BULLISH_TREND | continuidade saudável |
| 5 | 10:51:30 | 22,35 | 26,79% | 0,05 | BEARISH_TREND | forte deterioração |
| 6 | 15:42:40 | 38,53 | 26,37% | 0,05 | BEARISH_TREND | continuidade saudável |
| 7 | 16:22:20 | 25,71 | 31,22% | 0,05 | HIGH_VOLATILITY | forte deterioração |
| 9 | 17:21:02 | 21,94 | 32,05% | 0,05 | BEARISH_TREND | forte deterioração |
| 10 | 20:02:00 | 20,78 | 25,89% | 0,05 | BULLISH_TREND | deterioração relevante |

Amostra: 8 pontos. **Exploratória, não estatisticamente validada.**

## 8. Hipóteses eliminadas / enfraquecidas

### 8.1 Giveback isolado

Não separa adequadamente continuidade saudável de deterioração perigosa.

### 8.2 Velocidade de deterioração isolada

Também não separa os grupos. Houve casos de forte slope negativa que posteriormente permaneceram saudáveis.

Exemplo importante:

- ciclo 4 teve deterioração rápida no instante do gatilho, mas posteriormente permaneceu saudável;
- ciclo 1 teve deterioração igualmente detectável e posteriormente sofreu drawdown muito maior.

### 8.3 R12 isolado

O regime contextualiza, mas não é uma autorização direta de realização.

### 8.4 Exposição isolada

Estar alinhado ou contra o regime não foi suficiente para determinar o resultado posterior.

### 8.5 Preço favorável à exposição isoladamente

Mesmo quando o preço aparenta favorecer a exposição dominante, o basket pode estar entrando em deterioração.

## 9. Descoberta principal deste checkpoint

A hipótese mais promissora agora é uma variável composta de **resposta econômica ao regime**, e não simplesmente o regime em si.

Conceito provisório:

### Response-to-Regime

Pergunta causal:

> Dado o regime R12 atual e a direção da exposição dominante, o basket está efetivamente respondendo de forma econômica compatível com esse regime?

Exemplo:

```text
R12 = BEARISH
+
SELL exposure
+
regime deveria favorecer SELL
+
mas Equity não melhora / continua deteriorando

→ possível falha de continuidade
```

O inverso:

```text
R12 = BEARISH
+
SELL exposure
+
Equity responde positivamente

→ regime confirmado economicamente
→ maior evidência para HOLD
```

Isso diferencia:

**posição alinhada ao regime**

de

**posição que está efetivamente sendo recompensada pelo regime**.

## 10. Próximo experimento

O próximo estudo deve calcular, em cada ponto de decisão causal:

1. retorno da Equity após o início do estado R12;
2. slope da Equity condicionada ao regime;
3. persistência da resposta econômica;
4. resposta por direção da exposição;
5. mudança de resposta após transição R12;
6. relação entre resposta, giveback e composição do basket;
7. concentração de lucro/perda por ticket;
8. distância do basket para break-even econômico;
9. número de tickets vencedores/perdedores;
10. mudança da resposta antes/depois do pico de Equity.

Objetivo: procurar uma assinatura multivariada de:

```text
PROFIT DEVELOPMENT
        ↓
PROFIT PEAK
        ↓
PROFIT DETERIORATION
        ↓
R12 RESPONSE
        ↓
DECISION
```

Sem usar qualquer informação futura.

## 11. Estado da implementação

**NÃO IMPLEMENTAR AINDA EM LIVE.**

O Adaptive Profit Manager permanece em fase de:

```text
OBSERVE
   ↓
RECONSTRUCT
   ↓
COUNTERFACTUAL
   ↓
CAUSAL REPLAY
   ↓
SIGNATURE RESEARCH
   ↓
OOS VALIDATION
   ↓
CONTROLLED ACTION
```

A etapa atual é **SIGNATURE RESEARCH**.

## 12. Critério de promoção futura

Uma assinatura somente poderá avançar para ação real se demonstrar, em dados fora da amostra e em múltiplos pregões:

- melhoria econômica contra P0;
- redução de deterioração/giveback prejudicial;
- nenhuma deterioração inaceitável da cauda esquerda;
- preservação do upside capturado pelo BRX;
- comportamento determinístico;
- ausência de lookahead;
- compatibilidade com R9/R10/R11;
- compatibilidade com Action Contract;
- compatibilidade com lifecycle/reconciliation;
- telemetria reproduzível.

## 13. Commits relacionados

- `be1754008996b5e2460d70a592e7800d3834e90c` — provisioning map
- `a2c3554d2f58546b18eb109a1be61258a4327ca2` — canonical opportunity accounting checkpoint
- `c191651c9b85796ba45f4458b98bb32335161f6` — counterfactual specification
- `0ae3d23dc541a3e25953254b608cfd6d0ea5d13f` — canonical baseline reconstruction
- `34a0b2edeafc15f7b4bf944099c58ec3f58d6f7a` — telemetry consolidation
- `6cc3b55382ac650507a9a90a2f59b457add1efde` — path diagnostics v1.1
- `7c82370db573f9a5623bd706f7427ce1f91f6399` — telemetry sampling configuration
- `8b436c5edc3363ddd8c60bf8526334fdcaf278cb` — telemetry optimization
- `64d82ef204c7bfd2ba303200d20e9e7bc8a295f2` — telemetry close on deinit

## 14. Checkpoint decision

**Conclusão:** o EAGOLD já possui infraestrutura suficiente para pesquisar gestão adaptativa de lucro com replay causal. A evidência atual não justifica uma regra simples baseada em giveback, regime, velocidade, exposição ou direção isoladamente. A próxima fronteira é medir a **Response-to-Regime**, combinando contexto R12 com resposta econômica observável do basket e composição dos tickets.

**Status:** RESEARCH / NO LIVE DEPLOYMENT.
