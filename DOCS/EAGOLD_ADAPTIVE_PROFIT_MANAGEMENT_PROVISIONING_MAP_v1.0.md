# EAGOLD — Adaptive Profit Management / Provisioning Map v1.0

**Documento:** `EAGOLD_ADAPTIVE_PROFIT_MANAGEMENT_PROVISIONING_MAP_v1.0.md`  
**Data:** 2026-09-12  
**Baseline:** EAGOLD v0.106  
**Status:** PROVISIONING / ARCHITECTURAL MAPPING  
**Operational impact:** NONE  
**Branch:** `main`

---

## 1. Objetivo

Este documento transforma as pesquisas já consolidadas no EAGOLD em um mapa de aprovisionamento para a próxima fase de desenvolvimento: **Adaptive Profit Management**.

A intenção não é substituir BRX, R10, R11 ou Lifecycle. A intenção é preparar uma camada de decisão que possa responder, de forma observável e posteriormente controlada:

1. Qual é o regime de mercado?
2. O basket está carregado a favor ou contra o movimento primário?
3. Em cenário contrário, vale aceitar uma realização menor para reduzir exposição?
4. Em cenário favorável, existe evidência suficiente de expansão de lucro para evitar o fechamento integral?
5. Se houver expansão favorável, quanto deve ser realizado agora e quanto deve permanecer como runner protegido por BE/trailing?
6. Quando a oportunidade perder qualidade, como realizar o restante sem devolver desnecessariamente o ganho?

A regra arquitetural permanece:

> **R12/MAIA podem recomendar ações dentro do envelope de risco; não podem redefinir o envelope de risco.**

O `FUTURE_RESEARCH_BASE_v1.0.md` define R12 como camada de regime, MAIA como memória/experiência e BRX como ponto de evolução para basket trailing, partial realization e runner. A pesquisa explicitamente não autoriza alteração do baseline operacional.  

---

## 2. Baseline atual que será preservado

O EAGOLD atual já possui:

- R1 — Admission / First Order Control
- R4 — Lifecycle / Grid Machine
- R5 — Basket Realization / Close
- R7 — Restart / Keep-Alive
- R9 — Exposure Controller / Hedge
- R10 — Exposure Reduction
- R10.2 — Recovery Realization / Accounting
- R11 — Recovery Step / Exposure Governor
- BRX — Basket Realization Engine
- Core de execução
- Action Contract
- Persistence
- Telemetria
- Painel operacional

O roadmap atual recomenda que novas capacidades sejam inicialmente módulos independentes e que o comportamento validado do v0.106 permaneça protegido.  

### Configuração operacional observada

O baseline atual mantém:

```text
EAGOLD_VERSION                 = 0.106
EnableBasketRealization       = true
BRXRealizationMode            = 3
BRXDirectionalMinProfit       = 5.00
BRXBidirectionalMinProfit     = 5.00
BRXRealizationSafetyBuffer    = 5.00
BRXRequireWeightedBE          = false
EnableR13                     = false
EnableR9Hedge                 = false
EnableR10Reduce               = false
EnableR10RecoveryRealization  = false
EnableR11ExposureGovernor     = true
```

A configuração centralizada confirma que o BRX já possui floor, safety buffer e opção de weighted BE, enquanto o trailing existente atualmente está relacionado ao gerenciamento de pending orders, não a um basket-profit runner. 

---

# 3. Mapa geral: ideia × código atual

| Ideia | Situação atual | Reutilização | Gap | Prioridade de aprovisionamento |
|---|---|---|---|---|
| Market Regime | Documentada; não operacional | Configuração/telemetria existentes | **R12 inexistente como engine** | P0 |
| M5/M1/M15 hierarchy | Documentada na pesquisa | Nenhum engine específico identificado | **Classifier + hierarchy** | P0 |
| ATR / volatility telemetry | Candidata documentada | Indicadores/telemetria podem ser acoplados | **Medição padronizada** | P0 |
| Trend/Range | Documentada | Nenhum regime formal | **Classifier** | P0 |
| CUSUM | Pesquisa | Nenhum componente operacional | **Observer** | P1 |
| Entropy | Pesquisa | Nenhum componente operacional | **Observer opcional** | P2 |
| Position × Regime | Conceito documentado | Basket/exposure APIs | **Decision matrix** | P0 |
| MFE | Pesquisa MAIA | Histórico/P&L existentes | **Peak favorable tracking** | P0 |
| MAE | Pesquisa MAIA | Exposição/P&L existentes | **Adverse excursion tracking** | P0 |
| Peak Basket Profit | Parcialmente possível via estado do painel | `g_panelMaxProfit` já existe, mas é painel | **Estado econômico próprio do basket/ciclo** | P0 |
| Profit Protection | Pesquisa | BRX + Action Contract | **State machine** | P1 |
| Partial Realization | Existem closes parciais em outras camadas, mas não como profit-development policy | `CloseMarketOrderLots()` | **Política de partial realization** | P1 |
| BE | Weighted BE já existe no BRX | `BRX_WeightedBreakeven()` / `BRX_BEDirectionValid()` | **BE aplicado ao runner/remaining exposure** | P1 |
| Basket Trailing | Documentado, não operacional | BRX é ponto de evolução | **Peak → giveback → close** | P1 |
| Runner | Documentado, não operacional | BRX + lifecycle | **Allocation + protected remainder** | P1 |
| Recovery Overlap | Documentado | R9/R10/R10.2/R11 | **Formal economic transaction** | P2 |
| Dynamic Grid Spacing | Roadmap | R11/grid inputs | **R12 → cycle parameter** | P2 |
| Progressive Grid Distance | Roadmap | R11 | **Coordenação com R11** | P3 |
| Volatility Gate | Roadmap | R1/R11 | **Observer → counterfactual → gate** | P2 |
| DD-based Lot Reduction | Roadmap | R11/exposure data | **Policy + validation** | P3 |
| Formal Basket Manager | BRX é o embrião | BRX/R10.2/weighted BE | **Unified economic state** | P1 |
| Experience Memory | MAIA document | Persistence/telemetry | **Canonical experience record** | P0 |
| Regime × Action Matrix | MAIA document | Telemetry | **Offline analytics** | P1 |
| Contextual Bandit / ML | Research only | Nenhum | **Não aprovisionar agora** | P4 |

---

# 4. O que já existe e deve ser reutilizado

## 4.1 BRX — principal ponto de extensão

O BRX v1.4 já possui uma arquitetura transacional de realização. O caminho bidirecional protegido utiliza uma estratégia **heavy-first**, relê o estado do broker depois da primeira perna e só conclui quando as pós-condições da liquidação são satisfeitas.

Isso é extremamente útil para a próxima fase porque o novo Adaptive Profit Management não deve criar um segundo mecanismo independente de fechamento. Ele deve produzir uma **autorização econômica** para o BRX executar.

Estrutura pretendida:

```text
Adaptive Profit Manager
        ↓
Close Authorization / Action Plan
        ↓
BRX transactional execution
        ↓
Action Contract
        ↓
Broker state
        ↓
Reconciliation / telemetry
```

O BRX atual já calcula P/L direcional e de basket, possui safety buffer, weighted BE opcional e classificação transacional. 

## 4.2 Weighted BE

`BRX_WeightedBreakeven()` e `BRX_BEDirectionValid()` já fornecem uma base concreta para a futura camada de proteção.

Não devemos criar outro cálculo de BE sem necessidade.

A evolução deve separar claramente:

```text
BE como condição de autorização
        ≠
BE como proteção de uma posição/runner
```

A segunda função ainda precisa ser aprovisionada.

## 4.3 Action Contract

O contrato existente fornece exatamente o comportamento necessário para partial realization:

```text
NONE
BLOCKED
COMPLETED
PARTIAL
FAILED
```

Em especial:

```text
PARTIAL
   ↓
Persistir estado real
   ↓
Reconciliar
   ↓
Parar o restante da execução econômica do tick
```

Portanto, a futura partial realization deve obrigatoriamente utilizar o Action Contract e não criar um retorno booleano paralelo.

## 4.4 Core de execução

O Core já centraliza `SendMarket`, `SendPending`, `CloseMarketOrder`, `CloseMarketOrderLots` e limpeza de pending. Isso deve continuar sendo a única camada que conhece diretamente as chamadas de broker.

A nova inteligência não deve enviar ordens diretamente.

## 4.5 R11

R11 já representa um governador de exposição e controla **nova exposição de recovery**. Ele não deve ser substituído pelo Adaptive Profit Manager.

A relação futura deve ser:

```text
R12/Adaptive Manager
       ↓
recomenda gestão/proteção

R11
       ↓
limita nova exposição/recovery

R9/R10/R10.2
       ↓
executam controles de exposição/recovery existentes
```

---

# 5. Principal gap: R12 Market Regime Observer

O primeiro componente a ser aprovisionado deve ser um **observer-only**.

Não deve abrir, fechar, reduzir, aumentar lote ou alterar Grid.

## 5.1 Estado inicial

Usar o conjunto reduzido do roadmap para facilitar validação:

```text
R12_REGIME_UNKNOWN
R12_REGIME_RANGE
R12_REGIME_TREND
R12_REGIME_HIGH_VOL
R12_REGIME_EXTREME
```

Depois, se os dados justificarem, evoluir para os estados mais ricos da pesquisa MAIA:

```text
BULLISH TREND
BEARISH TREND
BULLISH PULLBACK
BEARISH PULLBACK
HIGH-VOLATILITY EXPANSION
LOW-VOLATILITY CONSOLIDATION
TRANSITION BULLISH
TRANSITION BEARISH
EXHAUSTION / EXTENSION
CONFLICT / INDETERMINATE
```

A versão inicial deve privilegiar estabilidade e auditabilidade sobre granularidade.

## 5.2 Hierarquia temporal

Aprovisionar explicitamente:

```text
M15 = contexto macro
M5  = regime primário
M1  = microestrutura / execução
```

A regra é uma única decisão de regime por ciclo de avaliação; M1 não pode sobrescrever M5 de maneira implícita.

## 5.3 Features iniciais

Primeiro conjunto:

- ATR atual;
- ATR relativo ao histórico;
- range da vela;
- expansão de range;
- deslocamento direcional acumulado;
- inclinação de média;
- persistência direcional;
- distância relativa ao regime anterior.

CUSUM e entropy ficam desacoplados e entram como experimentos de observer posteriores.

---

# 6. Position × Regime — núcleo da nova lógica

A segunda camada deve combinar:

```text
REGIME
   ×
NET POSITION
   ×
GROSS EXPOSURE
   ×
BASKET PROFIT
   ×
PROFIT DEVELOPMENT
```

## 6.1 Classificação econômica

Exemplo:

```text
Regime: BULLISH TREND

BUY lots  = 1.20
SELL lots = 0.30

→ carregado A FAVOR
```

ou:

```text
Regime: BULLISH TREND

BUY lots  = 0.30
SELL lots = 1.20

→ carregado CONTRA
```

A classificação deve ser independente do nome da direção. Deve comparar exposição líquida com o vetor direcional do regime.

## 6.2 Quatro quadrantes iniciais

```text
                     REGIME
                 FAVORÁVEL AO BUY

          CONTRA                     A FAVOR
        SELL-heavy                  BUY-heavy
            │                           │
            │                           │
       EARLY EXIT                 PROFIT DEVELOPMENT
            │                           │
       modest target               partial + protect
                                        │
                                      runner
```

E o espelho para regime bearish.

---

# 7. MFE / MAE — aprovisionamento obrigatório

O resultado final de P/L não é suficiente para saber se o EAGOLD está realizando cedo demais.

Exemplo da pesquisa MAIA:

```text
Final P/L = +5
MFE       = +250
MAE       = -40
```

Esse resultado é economicamente diferente de uma operação que nunca ultrapassou +10.

## 7.1 Estado mínimo por basket/ciclo

Aprovisionar:

```text
cycle_id
start_time
regime_at_start
regime_current
buy_lots_peak/current
sell_lots_peak/current
net_exposure
basket_profit_current
basket_profit_peak
MFE
MAE
peak_time
last_peak_time
giveback
realized_profit
remaining_profit
```

## 7.2 Fórmulas de pesquisa

Registrar pelo menos:

```text
Profit Capture Ratio = Realized / MFE

Risk/Opportunity Ratio = abs(MAE) / MFE

Capture vs Risk = Realized / abs(MAE)
```

Não usar essas métricas como gatilho operacional inicialmente. Elas serão usadas para descobrir se o comportamento atual está capturando pouco do movimento disponível.

---

# 8. Profit Development State Machine

O núcleo da gestão futura deve ser uma máquina de estados, não uma sequência de `if` independentes.

Proposta:

```text
PROFIT_IDLE
    ↓
PROFIT_DEVELOPING
    ↓
PROFIT_PROTECTION
    ↓
RUNNER
    ↓
TRAILING
    ↓
REALIZATION
```

Possíveis retornos:

```text
PROFIT_DEVELOPING → PROFIT_IDLE
PROFIT_PROTECTION → PROFIT_DEVELOPING
RUNNER             → PROFIT_PROTECTION
TRAILING           → RUNNER
```

O estado precisa ser persistível ou reconstruível de maneira segura após restart.

---

# 9. Política para basket carregado CONTRA o regime

Quando a exposição líquida estiver contra o regime primário, o sistema pode aceitar uma realização mais modesta.

Exemplo conceitual:

```text
Regime: BULLISH TREND
SELL-heavy basket

Objetivo:
reduzir risco antes de buscar grande deslocamento contrário.
```

Importante: isso não significa simplesmente reduzir o BRX floor.

A autorização futura deverá considerar:

- regime;
- intensidade do desalinhamento;
- exposição bruta;
- P/L atual;
- MFE disponível;
- MAE histórico do regime;
- recovery state;
- margem;
- R10.2;
- integridade do hedge.

---

# 10. Política para basket carregado A FAVOR

Quando a exposição estiver alinhada com o regime e o movimento continuar favorável, o objetivo muda:

```text
não realizar tudo imediatamente
```

Em vez disso:

```text
PROFIT DEVELOPMENT
       ↓
PARTIAL REALIZATION
       ↓
PROTECT REMAINDER
       ↓
BE
       ↓
RUNNER
       ↓
TRAILING
       ↓
REALIZATION
```

O tamanho da realização parcial não deve ser hard-coded antes da análise MFE/MAE.

Primeiro precisamos descobrir, por regime e exposição:

- quanto o basket normalmente devolve após atingir determinados níveis de MFE;
- qual fração do lucro tende a ser capturada pelo BRX atual;
- qual fração poderia ser mantida como runner;
- qual trailing giveback maximiza captura sem aumentar excessivamente a devolução.

---

# 11. Basket Trailing — componente a aprovisionar

O BRX atual é o local natural para a futura integração, mas o trailing deve ser implementado como uma camada econômica separada da execução.

Estado:

```text
basket_profit
basket_peak_profit
trailing_activation
trailing_distance
giveback
```

Regra conceitual:

```text
Peak >= Activation
AND
Peak - Current >= Trail
→ authorization to realize
```

Exemplo:

```text
Activation = +50
Peak       = +82
Trail      = 15
Current    = +67

Giveback = 15
→ realizar
```

Antes de execução, verificar:

- net P/L;
- exposure remaining;
- spread;
- comissão/swap quando disponível;
- weighted BE;
- recovery state;
- margin safety;
- cooldown/idempotência.

---

# 12. Runner — componente a aprovisionar

O runner não deve ser uma nova estratégia de entrada. É uma política de retenção de parte de uma exposição já lucrativa.

Estrutura conceitual:

```text
Basket favorável
      ↓
Realização parcial
      ↓
Remaining lots
      ↓
Protection / BE
      ↓
Trailing
      ↓
Final realization
```

O runner deve ser direction-neutral:

```text
BUY runner
SELL runner
```

A decisão depende de:

- alinhamento com regime;
- persistência do movimento;
- MFE;
- expansão de range;
- volatilidade;
- qualidade do deslocamento.

Não deve depender simplesmente de `BUY` ser positivo ou `SELL` ser negativo.

---

# 13. Formal Basket Manager

O roadmap já identifica o BRX como embrião de um Basket Manager formal.

O aprovisionamento deve preparar a seguinte estrutura conceitual:

```text
Basket Manager
│
├── Directional P/L
├── Bidirectional P/L
├── Realized P/L
├── Floating P/L
├── Weighted BE
├── Gross Exposure
├── Net Exposure
├── Recovery State
├── Regime
├── MFE
├── MAE
├── Peak Profit
├── Giveback
├── Target
├── Protection
├── Runner
├── Trailing
├── Margin Safety
└── Close Authorization
```

O Basket Manager deve **calcular estado e autorização**; a execução continua no Core/BRX/Action Contract.

---

# 14. Recovery Overlap

Não aprovisionar ainda como execução automática.

Primeiro criar observabilidade para responder:

```text
posição favorável
      ↓
lucro disponível
      ↓
quanto da exposição adversa poderia ser reduzida?
      ↓
qual impacto no debt?
      ↓
qual impacto no BE?
      ↓
qual impacto na margem?
```

O objetivo é produzir uma decisão econômica verificável antes de permitir qualquer fechamento parcial de recovery.

---

# 15. Dynamic Grid / Volatility Gate

Esses componentes dependem da qualidade do R12.

Não aprovisionar como regra operacional no primeiro ciclo.

Primeiro registrar contrafactual:

```text
R12 regime
ATR
Grid atual
Grid hipotético
novas entradas hipoteticamente bloqueadas
exposição evitada
P/L hipotético
DD hipotético
```

Depois comparar contra baseline.

---

# 16. Experience Memory — fundamento da adaptação

A pesquisa MAIA estabelece a sequência:

```text
Data Collection
    ↓
Experience Memory
    ↓
Regime Classification
    ↓
Statistical Performance Matrix
    ↓
Time-Decay Adaptation
    ↓
Controlled Action Selection
    ↓
Contextual Bandit
    ↓
Advanced ML/RL
```

Para esta etapa, aprovisionar somente os primeiros níveis.

## Registro canônico sugerido

```text
experience_id
cycle_id
symbol
magic_scope
start_time
end_time
regime_start
regime_end
regime_duration
action
action_reason
confidence
buy_lots
sell_lots
net_exposure
gross_exposure
basket_profit_peak
basket_profit_final
realized_profit
MFE
MAE
giveback
partial_realization_lots
runner_lots
trailing_distance
recovery_state
R10_state
R11_state
margin_min
result
model_version
```

Este registro será a ponte entre R12 e MAIA.

---

# 17. Ordem de aprovisionamento

## P0 — Observabilidade segura

### P0.1 R12 Observer

Criar:

```text
R12 state
R12 confidence
R12 feature snapshot
R12 transition event
```

Sem impacto econômico.

### P0.2 Basket Economic Snapshot

Criar snapshot padronizado de:

```text
P/L
lots
net exposure
gross exposure
weighted BE
recovery state
```

### P0.3 MFE / MAE / Peak

Criar estado por ciclo/basket.

### P0.4 Canonical Experience Record

Gerar telemetria suficiente para análise offline.

---

## P1 — Gestão de lucro em modo observer/counterfactual

### P1.1 Position × Regime classifier

Produzir:

```text
ALIGNED
COUNTER
NEUTRAL
CONFLICT
```

### P1.2 Profit Development Observer

Classificar:

```text
IDLE
DEVELOPING
PROTECTION_CANDIDATE
RUNNER_CANDIDATE
TRAILING_CANDIDATE
REALIZATION_CANDIDATE
```

Sem executar.

### P1.3 Basket Trailing Counterfactual

Registrar quando o trailing teria realizado e comparar com o que o BRX efetivamente realizou.

### P1.4 Partial + Runner Counterfactual

Registrar:

```text
hypothetical partial lots
hypothetical protected lots
hypothetical BE
hypothetical runner outcome
```

---

## P2 — Execução controlada

Somente após evidência suficiente:

1. Partial realization transacional.
2. Protection/BE do restante.
3. Basket trailing.
4. Runner.
5. Adaptive realization por regime.

Cada item deve ser habilitado individualmente.

---

## P3 — Adaptação de exposição

Somente depois da camada de lucro estar validada:

- Volatility Gate;
- Dynamic Grid Spacing;
- Progressive Grid Distance;
- DD-based Lot Reduction;
- Recovery Overlap.

---

## P4 — Inteligência adaptativa avançada

Não faz parte do próximo provisionamento operacional:

- contextual bandit;
- UCB;
- ML automático de parâmetros;
- reinforcement learning;
- autonomous policy optimization.

---

# 18. Contratos que não podem ser violados

1. **R12 não envia ordens.**
2. **MAIA não envia ordens.**
3. **Observer não altera o baseline.**
4. **Toda ação real usa Action Contract.**
5. **Partial implica reconciliação.**
6. **Core continua sendo a camada de broker execution.**
7. **BRX continua sendo a referência de basket realization.**
8. **R9/R10/R10.2/R11 continuam independentes.**
9. **MAIA não pode ampliar o envelope de risco.**
10. **Nenhum threshold adaptativo será otimizado em produção sem validação.**
11. **Nenhuma mudança de Grid deve reescrever um ciclo já exposto sem contrato explícito.**
12. **Não introduzir lookahead.**
13. **Toda decisão adaptativa deve ser reconstruível por log.**
14. **Broker state permanece autoridade sobre estado econômico real.**

---

# 19. Matriz de aprovisionamento por módulo

| Novo módulo | Responsabilidade | Depende de | Pode executar ordem? | Primeira fase |
|---|---|---|---|---|
| `R12_RegimeObserver` | Classificação de regime | Market data | NÃO | Observer |
| `EAGOLD_BasketState` | Estado econômico consolidado | Core orders | NÃO | Telemetry |
| `EAGOLD_ExcursionTracker` | MFE/MAE/Peak/Giveback | BasketState | NÃO | Telemetry |
| `EAGOLD_PositionRegime` | Alinhamento posição × regime | R12 + BasketState | NÃO | Observer |
| `EAGOLD_ProfitDevelopment` | Máquina de estados de lucro | R12 + excursions | NÃO | Observer |
| `EAGOLD_BasketTrail` | Counterfactual trailing | ProfitDevelopment | NÃO | Counterfactual |
| `EAGOLD_RunnerPlan` | Plano de partial/protection/runner | ProfitDevelopment | NÃO | Counterfactual |
| `EAGOLD_AdaptiveAuthorization` | Autorização econômica | todos acima + risk envelope | NÃO | Counterfactual |
| `BRX` | Execução de realização | Authorization | SIM, via Core | Existing |
| `ActionContract` | Resultado transacional | Execution | SIM indiretamente | Existing |
| `MAIA_Experience` | Memória/analytics | snapshots/events | NÃO | Persistence |

---

# 20. O que NÃO fazer agora

Não alterar nesta etapa:

- `BRXRealizationSafetyBuffer`;
- `BRXDirectionalMinProfit`;
- `BRXBidirectionalMinProfit`;
- `TakeProfit`;
- R9 hedge;
- R10 reduction;
- R10.2 recovery realization;
- R11 exposure governor;
- Grid distances;
- lot progression;
- operational expiry;
- R13.

A mudança desta etapa é **arquitetural e observacional**, não econômica.

---

# 21. Critério de passagem para implementação real

A camada Adaptive Profit Management só poderá começar a executar quando existirem dados suficientes para responder, por regime:

1. Qual é o MFE típico?
2. Qual é o MAE típico?
3. Quanto o BRX captura do MFE?
4. Quanto lucro é devolvido antes do fechamento?
5. Qual giveback é estatisticamente defensável?
6. Em quais regimes o basket contra o movimento deve realizar cedo?
7. Em quais regimes o basket a favor merece runner?
8. Qual fração deve ser realizada no partial?
9. Qual proteção reduz risco sem eliminar a assimetria favorável?
10. Qual o impacto sobre DD, exposição, recovery debt e margem?

Somente depois responderemos aos parâmetros.

---

# 22. Pipeline de validação

```text
RESEARCH
   ↓
R12 OBSERVER
   ↓
BASKET TELEMETRY
   ↓
MFE / MAE
   ↓
POSITION × REGIME
   ↓
PROFIT DEVELOPMENT OBSERVER
   ↓
COUNTERFACTUAL PARTIAL / BE / RUNNER / TRAILING
   ↓
OFFLINE ANALYSIS
   ↓
CONTROLLED BACKTEST
   ↓
REGRESSION AGAINST v0.106
   ↓
PAPER / DEMO
   ↓
LIVE VALIDATION
   ↓
OPERATIONAL AUTHORIZATION
```

---

# 23. Resultado do provisionamento

O ambiente de desenvolvimento fica preparado com uma separação clara:

```text
                ┌──────────────────────────────┐
                │       R12 / MAIA             │
                │ Regime + Experience Memory  │
                └──────────────┬───────────────┘
                               │
                       Economic Context
                               │
                ┌──────────────▼───────────────┐
                │ Adaptive Profit Management   │
                │ Position × Regime            │
                │ MFE / MAE                    │
                │ Profit Development            │
                │ Partial / BE / Runner        │
                │ Basket Trailing               │
                └──────────────┬───────────────┘
                               │
                     Allowed Economic Action
                               │
                ┌──────────────▼───────────────┐
                │ Existing Risk Envelope       │
                │ R1 / R9 / R10 / R10.2 / R11 │
                └──────────────┬───────────────┘
                               │
                ┌──────────────▼───────────────┐
                │ Existing Execution           │
                │ BRX / Lifecycle / Core       │
                │ Action Contract              │
                └──────────────┬───────────────┘
                               │
                           Broker State
                               │
                ┌──────────────▼───────────────┐
                │ Telemetry / Experience       │
                └──────────────────────────────┘
```

O aprovisionamento está pronto para a próxima etapa: **implementar primeiro os observers R12 + BasketState + MFE/MAE, sem alterar a execução do v0.106.**

---

## 24. Referências internas

- `DOCS/FUTURE_RESEARCH_BASE_v1.0.md`
- `DOCS/FUTURE_IMPROVEMENTS_ROADMAP_v1.0.md`
- `DOCS/EAGOLD_AUDIT_BROKER_ACTION_CALLSITE_MATRIX_v1.0.md`
- `DOCS/EAGOLD_AUDIT_CHECKPOINT_ACTION_ORCHESTRATION_v1.1.md`
- `DOCS/EAGOLD_AUDIT_CHECKPOINT_TRANSACTION_CONTRACT_v1.0.md`
- `DOCS/EAGOLD_BRX_RUNTIME_TEST_PROTOCOL_v1.0.md`
- `Core/EAGOLD_Config.mqh`
- `Core/EAGOLD_Execution.mqh`
- `Engines/EAGOLD_BRX.mqh`
- `Engines/EAGOLD_Lifecycle.mqh`
- `Engines/EAGOLD_R9.mqh`
- `Engines/EAGOLD_R10.mqh`
- `Engines/EAGOLD_R10_Reconciliation.mqh`
- `Engines/EAGOLD_Recovery.mqh`
- `Engines/EAGOLD_R13_Satellite.mqh`

## 25. Referências externas já consolidadas

A base de pesquisa do projeto mantém como referências, entre outras:

- Fintor-AI / WealthPole — arquitetura modular Grid/Hedge;
- MQL5 — persistência de estado;
- MQL5 — Market Regime Detection Indicator;
- MQL5 — Market Regime Detection EA;
- MQL5 — Market Entropy Indicator;
- Aldo Taranto — Bi-directional Grid Constrained Stochastic Processes;
- pesquisa MAIA sobre MFE/MAE, profit asymmetry e contextual bandits.

Essas fontes permanecem referências de pesquisa. Nenhuma implementação externa é copiada automaticamente para o EAGOLD.
