# EAGOLD — Future Improvements Roadmap

**Documento:** `FUTURE_IMPROVEMENTS_ROADMAP_v1.0.md`  
**Versão:** 1.0  
**Data:** 2026-09-10  
**Repositório:** `sezinando/modularizedEA`  
**Status:** Documento de referência para futuras melhorias

---

## 1. Objetivo

Este documento registra ideias de evolução identificadas durante a análise da arquitetura atual do EAGOLD e de abordagens avançadas utilizadas em soluções de Grid, Hedge, Recovery e Basket Management, especialmente em materiais publicados no ecossistema MQL5.

O documento **não autoriza automaticamente mudanças de comportamento no EA**. Seu objetivo é servir como backlog técnico e fonte de consulta para futuras pesquisas, implementações e testes.

Princípio central:

> **Toda nova feature deve ser tratada como hipótese de engenharia até ser validada por replay/backtest e comparação contra o baseline.**

---

## 2. Estado atual do EAGOLD

A arquitetura modular atual já reúne diversos mecanismos:

- **R1 — Admission / First Order Control**
- **R4 — Lifecycle / Grid Machine**
- **R5 — Basket Realization / Close**
- **R7 — Restart**
- **R9 — Exposure Controller / Hedge**
- **R10 — Exposure Reduction**
- **R10.2 — Recovery Realization / Accounting**
- **R11 — Recovery Step Control**
- **BRX — Basket Realization Engine**
- Core de ordens e medição
- Core de execução
- Persistência
- Telemetria
- Painel operacional
- Guias visuais no gráfico

A arquitetura deve continuar evoluindo sem destruir o comportamento já validado. Novos mecanismos devem preferencialmente ser adicionados como módulos independentes antes de alterar os engines existentes.

---

# 3. Principais oportunidades identificadas

## 3.1 R12 — Market Regime & Adaptive Grid

**Prioridade:** ⭐⭐⭐⭐⭐  
**Complexidade:** média  
**Status:** proposta / próxima grande feature

### Conceito

Criar um engine de classificação de regime de mercado que observe volatilidade, expansão, drift/tendência e comportamento de preço e transforme essas informações em um estado operacional.

Estados iniciais propostos:

```text
R12_REGIME_RANGE
R12_REGIME_TREND
R12_REGIME_HIGH_VOL
R12_REGIME_EXTREME
```

Variáveis candidatas:

- ATR
- ATR relativo à sua própria média/histórico
- expansão de range
- deslocamento direcional (drift)
- inclinação de médias
- relação entre volatilidade atual e baseline
- distância/preço em relação ao regime anterior

### Primeira implementação recomendada

A primeira versão deve ser **observer-only**:

```text
Mercado
  ↓
R12 Measure
  ↓
R12 Classify
  ↓
Regime
  ↓
Painel / Log / Telemetria
```

Nesta fase, R12 não modifica ordens, lotes ou distâncias.

### Segunda fase

Depois de validada a classificação, testar adaptação de espaçamento:

```text
Grid Base
   ↓
R12 Grid Factor
   ↓
MiniGrid / SmartGrid / RecoveryMinDistance
```

A recomendação é recalcular o fator **no início/reinício do ciclo**, evitando alterações agressivas da estrutura de um ciclo que já está em andamento.

### Por que esta feature é importante

A principal fragilidade estrutural de um Grid não é apenas a distância entre ordens; é a permanência de uma mesma lógica quando o regime de mercado muda.

Uma grade que funciona em range pode se comportar de maneira completamente diferente durante tendência forte ou expansão extrema de volatilidade.

---

# 4. Market Regime Engine independente

**Prioridade:** ⭐⭐⭐⭐⭐  
**Complexidade:** alta  
**Status:** proposta futura

Pode evoluir a classificação R12 para um verdadeiro **state machine de regime**.

Exemplo conceitual:

```text
RANGE
  ↓ expansão
HIGH_VOL
  ↓ persistência direcional
TREND
  ↓ aceleração
EXTREME
  ↓ normalização
RANGE / TREND
```

O engine pode registrar:

- regime atual
- regime anterior
- timestamp de mudança
- duração do regime
- confiança da classificação
- número de transições
- regime no momento da entrada
- regime no momento da recuperação
- regime no momento do fechamento do basket

Isso permitiria posteriormente estudar perguntas importantes:

- Quais regimes geram maior drawdown?
- Quais regimes favorecem R10?
- Quais regimes favorecem BRX?
- Em quais regimes a recuperação tende a alongar?
- O restart ocorre em regimes diferentes daqueles que originaram o ciclo?

---

# 5. Basket Trailing

**Prioridade:** ⭐⭐⭐⭐  
**Complexidade:** média  
**Status:** proposta

Evolução natural do BRX.

Em vez de apenas:

```text
Basket Profit >= Target → fecha
```

avaliar:

```text
Basket Profit
      ↓
Peak Profit
      ↓
Trailing Giveback
      ↓
Close Basket
```

Exemplo conceitual:

```text
Target = +$50
Peak   = +$82
Trail  = $15

Profit atual = +$67

82 - 67 = 15
→ realizar basket
```

O objetivo é capturar operações que entram em lucro significativamente maior que o alvo mínimo, evitando devolver todo o excesso ao mercado.

### Cuidados

O Basket Trailing deve considerar:

- P/L líquido
- exposição restante
- spread
- comissão/swap quando disponível
- estado de recuperação
- weighted breakeven
- cooldown/idempotência

Não deve simplesmente substituir o BRX atual sem comparação experimental.

---

# 6. Recovery Overlap / Partial Recovery Close

**Prioridade:** ⭐⭐⭐⭐  
**Complexidade:** média/alta  
**Status:** proposta para investigação

Abordagem observada em sistemas de recuperação: utilizar lucro de uma posição favorável e/ou de maior volume para absorver parcialmente uma posição muito negativa, reduzindo a exposição líquida sem exigir que todo o basket alcance um alvo tradicional.

Conceito:

```text
Posição favorável
      +
Lucro realizado
      ↓
Financia redução parcial
      ↓
Posição adversa
      ↓
Menor exposição / menor dívida
```

Esta abordagem é particularmente interessante para o EAGOLD porque conversa diretamente com:

- R9
- R10
- R10.2
- BRX
- R11

### Regra fundamental

Não implementar como "fechar a pior ordem porque existe lucro".

Deve haver uma decisão formal contendo:

- exposição antes
- redução proposta
- exposição depois
- P/L realizado
- impacto no recovery debt
- impacto no weighted BE
- impacto na margem
- preservação da integridade do hedge

---

# 7. Dynamic Grid Spacing

**Prioridade:** ⭐⭐⭐⭐⭐  
**Complexidade:** média  
**Status:** dependente do R12

A ideia é abandonar uma distância de Grid completamente estática e relacionar o espaçamento à volatilidade do ativo.

Conceito:

```text
GridBase × VolatilityFactor = GridEffective
```

Exemplo conceitual:

```text
ATR baixo  → grid menor
ATR normal → grid base
ATR alto   → grid maior
ATR extremo → proteção / bloqueio / novo ciclo
```

### Regra arquitetural recomendada

O fator não deve necessariamente ser aplicado a cada tick.

Preferência inicial:

```text
Novo ciclo
   ↓
Medir ATR/regime
   ↓
Calcular GridFactor
   ↓
Fixar parâmetros do ciclo
```

Isso reduz o risco de a própria grade se mover estruturalmente enquanto já possui exposição aberta.

---

# 8. Progressive Grid Distance

**Prioridade:** ⭐⭐⭐⭐  
**Complexidade:** média  
**Status:** proposta

Além de adaptar o Grid à volatilidade, pode ser estudado um aumento progressivo da distância conforme a exposição cresce.

Exemplo:

```text
Nível 1 → 160 pts
Nível 2 → 176 pts
Nível 3 → 194 pts
Nível 4 → 213 pts
...
```

O objetivo é evitar concentração excessiva de novas posições durante deslocamentos persistentes.

Esta ideia deve ser avaliada em conjunto com R11 para evitar duas camadas independentes alterando a mesma lógica de recuperação sem coordenação.

---

# 9. Drawdown-Based Lot Reduction

**Prioridade:** ⭐⭐⭐⭐  
**Complexidade:** média  
**Status:** proposta

Em vez de aumentar exposição apenas conforme regras tradicionais de recuperação, estudar redução de lote quando o drawdown atingir determinadas faixas.

Conceito:

```text
DD baixo    → lote normal
DD moderado → lote reduzido
DD alto     → lote mínimo / bloqueio
DD extremo  → proteção / encerramento
```

Esta abordagem pode ser especialmente útil para limitar a aceleração de risco em cenários onde o mercado permanece direcional por muito tempo.

Deve ser comparada com o comportamento atual de R11.

---

# 10. Volatility Gate

**Prioridade:** ⭐⭐⭐⭐  
**Complexidade:** média  
**Status:** proposta

Criar uma barreira de volatilidade antes de novas entradas ou expansões de Grid.

Exemplo:

```text
ATR normal       → permitido
ATR alto         → permitido com espaçamento maior
ATR muito alto   → somente gestão
ATR extremo      → bloquear novas exposições
```

O gate deve ser independente da execução inicialmente.

Primeiro registrar:

- quantas entradas teriam sido bloqueadas
- em quais momentos
- qual seria o resultado hipotético
- impacto sobre drawdown
- impacto sobre lucro

Somente depois transformar a observação em regra operacional.

---

# 11. Trend / Range Filter

**Prioridade:** ⭐⭐⭐⭐  
**Complexidade:** média/alta  
**Status:** proposta

Estudar uma camada capaz de diferenciar:

```text
RANGE
TREND
TRANSITION
EXTREME TREND
```

Possíveis sinais:

- inclinação de médias
- ATR
- amplitude relativa
- persistência de direção
- deslocamento acumulado
- estrutura de máximas/mínimas

O objetivo não é prever preço, mas responder:

> "A estrutura atual ainda é compatível com o comportamento esperado pela máquina de Grid?"

---

# 12. Formal Basket Manager

**Prioridade:** ⭐⭐⭐⭐  
**Complexidade:** média  
**Status:** em evolução através do BRX

O BRX representa o início dessa camada.

Evolução desejada:

```text
Basket Manager
 ├── Directional P/L
 ├── Bidirectional P/L
 ├── Weighted BE
 ├── Exposure
 ├── Recovery state
 ├── Basket target
 ├── Basket trailing
 ├── Margin safety
 └── Close authorization
```

A realização não deve depender de uma única fórmula histórica como:

```text
count × TakeProfit
```

O comportamento moderno deve considerar o estado econômico do basket como um todo.

---

# 13. Virtual Order Manager

**Prioridade:** ⭐⭐  
**Complexidade:** alta  
**Status:** não recomendado para curto prazo

Virtual orders podem permitir controle interno de SL/TP/pending e arquiteturas mais complexas de hedge/grid.

Entretanto, introduzem uma camada operacional adicional e podem aumentar o risco caso o terminal, EA ou conexão falhe.

Por isso:

> **Não priorizar enquanto as camadas reais de execução, recuperação e proteção ainda estiverem em evolução.**

---

# 14. Hierarquia recomendada de desenvolvimento

## Fase A — Observação

1. R12 Market Regime observer-only
2. ATR/volatility telemetry
3. regime transition logging
4. estatísticas por regime

## Fase B — Adaptação controlada

5. Dynamic Grid Spacing
6. Volatility Gate
7. Progressive Grid Distance

## Fase C — Gestão avançada

8. Basket Trailing
9. Recovery Overlap
10. Drawdown-Based Lot Reduction

## Fase D — Arquitetura avançada

11. Market Regime State Machine
12. Formal Basket Manager completo
13. Virtual Order Manager, somente se houver justificativa

---

# 15. Metodologia de validação

Nenhuma dessas features deve ser considerada melhoria apenas porque parece sofisticada.

Para cada feature:

### Teste 1 — Baseline

Executar o EA atual sem alteração comportamental.

### Teste 2 — Observer

Registrar a nova variável sem permitir que ela altere a execução.

### Teste 3 — Counterfactual

Calcular o que teria acontecido se a nova regra estivesse ativa.

### Teste 4 — A/B

Comparar:

- lucro líquido
- lucro bruto
- perda bruta
- profit factor
- win rate
- drawdown máximo
- duração média do ciclo
- número de operações
- exposição máxima
- lote máximo
- recovery debt
- quantidade de hedges
- quantidade de reduções R10
- quantidade de fechamentos BRX
- margem mínima
- eventos de proteção

### Teste 5 — Robustez

Avaliar diferentes:

- pregões
- períodos
- volatilidades
- spreads
- ativos, quando aplicável
- parâmetros próximos do ótimo

Uma feature só deve avançar para produção quando demonstrar benefício consistente e não apenas um resultado isolado.

---

# 16. Regras de segurança para futuras features

1. Não alterar diretamente uma regra validada sem baseline.
2. Não misturar duas features novas no primeiro teste.
3. Preferir observer-only antes de execution-changing.
4. Preservar R9/R10/BRX como camadas independentes durante os testes.
5. Toda ação que reduz exposição deve ser mensurável antes/depois.
6. Toda nova regra deve ser idempotente.
7. Toda nova regra de execução deve possuir tratamento de erro.
8. Mudanças de Grid devem respeitar o ciclo operacional.
9. Não introduzir lookahead em indicadores ou classificadores.
10. Toda feature deve possuir logs suficientes para reconstruir sua decisão.

---

# 17. Fontes de pesquisa utilizadas

As ideias deste documento foram motivadas principalmente por abordagens encontradas em documentação e artigos do ecossistema MQL5, além de documentação de soluções de Grid/Recovery.

### MQL5 — artigos técnicos

- Building a Research-Grounded Grid EA in MQL5: Why Most Grid EAs Fail and What Taranto Proved — https://www.mql5.com/en/articles/21833
- Modified Grid-Hedge EA in MQL5 (Part I) — https://www.mql5.com/en/articles/13845
- Modified Grid-Hedge EA in MQL5 (Part III) — https://www.mql5.com/en/articles/13972
- Automating Trading Strategies in MQL5 (Part 11): Developing a Multi-Level Grid Trading System — https://www.mql5.com/en/articles/17350
- Automating Trading Strategies in MQL5 (Part 7): Building a Grid Trading EA with Dynamic Lot Scaling — https://www.mql5.com/en/articles/17190
- Formulating Dynamic Multi-Pair EA (Part 4): Volatility and Risk Adjustment — https://www.mql5.com/en/articles/18165
- A Virtual Order Manager for Complex Trading Systems — https://www.mql5.com/en/articles/88

### MQL5 Market / soluções de referência

- LL Smart Recovery Grid EA — https://www.mql5.com/en/market/product/168033
- Grid EA Dual Grid — https://www.mql5.com/en/market/product/186749
- Ultimate Dual Grid EA — https://www.mql5.com/en/market/product/190268
- Advanced Grid Recovery System — https://www.mql5.com/en/market/product/167461
- Dynamic Grid EA — https://www.mql5.com/en/market/product/180518
- Midas Grid EA — https://www.mql5.com/en/market/product/181235
- Trading Grid EA — https://www.mql5.com/en/market/product/193231

### Outras referências técnicas

- StockSharp Gridder — https://doc.stocksharp.com/en/api-examples/3330_Gridder_EA
- StockSharp Grid — https://doc.stocksharp.com/pt/api-examples/3743_Build_Your_Grid
- Horizon HFT Grid Arbitrage — https://www.horizonhft.com/strategies/grid-arbitrage
- FMZ Long Grid — https://www.fmz.com/lang/en/strategy/477600

---

# 18. Classificação das ideias

| Feature | Base encontrada | Estado EAGOLD | Prioridade |
|---|---|---|---|
| R12 Market Regime | Validada como abordagem de pesquisa | Proposta | Muito alta |
| Dynamic Grid Spacing | ATR/adaptive grid recorrente | Proposta | Muito alta |
| Volatility Gate | Abordagem recorrente | Proposta | Alta |
| Progressive Grid Distance | Encontrada em soluções de Grid | Proposta | Alta |
| Market Regime State Machine | Abordagem consolidável | Proposta | Alta |
| Basket Trailing | Presente em soluções avançadas | Proposta | Alta |
| Recovery Overlap | Presente em sistemas de recovery | Proposta | Alta |
| Drawdown-Based Lot Reduction | Presente em abordagens adaptativas | Proposta | Alta |
| Formal Basket Manager | Já parcialmente implementado via BRX | Em evolução | Alta |
| Virtual Order Manager | Técnica existente | Não priorizar | Baixa |

**Importante:** "Base encontrada" significa que a abordagem ou conceito foi encontrado em material técnico/comercial pesquisado. Isso **não significa que a implementação específica seja comprovadamente superior ao EAGOLD**. A superioridade precisa ser demonstrada pelos nossos testes.

---

# 19. Próximo candidato oficial

O próximo candidato recomendado para investigação é:

## `R12 — MARKET REGIME & ADAPTIVE GRID`

Primeiro objetivo:

```text
MEDIR → CLASSIFICAR → REGISTRAR
```

Somente depois:

```text
MEDIR → CLASSIFICAR → ADAPTAR → EXECUTAR → VALIDAR
```

A implementação deve começar sem alterar a lógica de entrada, recuperação, hedge, R10 ou BRX.

---

## 20. Registro de evolução

| Data | Versão | Evento |
|---|---|---|
| 2026-09-10 | 1.0 | Documento inicial criado como backlog estratégico de melhorias |

---

**Regra final:** este documento é um **reservatório de hipóteses e oportunidades**, não uma lista de mudanças autorizadas. Cada item deve retornar ao ciclo de pesquisa → implementação isolada → replay/backtest → comparação → decisão.
