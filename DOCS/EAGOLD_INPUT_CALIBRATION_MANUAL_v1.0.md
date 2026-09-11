# EAGOLD — Manual de Auditoria e Calibração de Inputs v1.0

**Objetivo:** preparar o EAGOLD para operação real por meio de uma auditoria input → código → comportamento → interação entre engines.

**Baseline auditado:** `sezinando/modularizedEA`, branch `main`, versão `0.106`.

**Princípio:** nenhum input será considerado operacional apenas porque aparece na janela de propriedades. Ele só será classificado como **ATIVO** quando existir caminho de execução verificável que altere o comportamento do EA.

---

## 1. Regra de auditoria

Cada input recebe cinco avaliações:

1. **Implementação:** onde aparece no código e qual função o consome.
2. **Efeito:** o que muda matematicamente/operacionalmente quando seu valor muda.
3. **Momento de atuação:** em qual evento ou decisão ele é consultado.
4. **Interações:** quais outras regras/engines são afetadas.
5. **Importância:** CRÍTICA, ALTA, MÉDIA, BAIXA/visual ou INATIVA.

### Status

- **ATIVO:** influencia uma decisão, cálculo, execução ou proteção real.
- **ATIVO — UI:** influencia somente visualização/telemetria.
- **ATIVO CONDICIONAL:** atua somente quando outra configuração/modo permite.
- **PARCIAL:** existe implementação, mas parte da intenção do input não é aplicada.
- **INATIVO:** declarado, porém sem referência operacional no código executado.

**Regra para operação real:** inputs INATIVOS não devem ser usados para calibrar comportamento. Inputs PARCIAIS devem ser tratados como risco de interpretação até que a implementação seja corrigida ou a documentação declare explicitamente a limitação.

---

# SESSÃO A — IDENTIDADE, UNIVERSO DE ORDENS E EXECUÇÃO

## A.1 `MagicNumber`

**Default:** `-1`  
**Status:** ATIVO  
**Importância:** **CRÍTICA**

**Código:** `Core/EAGOLD_Orders.mqh` → `IsEAGOLDOrder()`; `Core/EAGOLD_Execution.mqh` → `SendMarket()`/`SendPending()`; `Core/EAGOLD_Persistence.mqh` → `StateKey()`; painel.

**Regra atual:**
- `MagicNumber == -1`: todas as ordens do **símbolo atual** são consideradas universo Master, independentemente do Magic.
- `MagicNumber != -1`: somente ordens do símbolo atual com aquele Magic pertencem ao Master.
- Ordens com `R13MagicNumber` são sempre excluídas do universo Master.

**Implicação:** este input não é apenas identificação. Ele define quais posições entram em `DirectionLots()`, `ExposureLots()`, `DirectionBasketProfit()`, R9, R10, Recovery, BRX, lifecycle e painel.

**Interação crítica:** com `-1`, outra estratégia/EA/manual operando o mesmo símbolo pode ser absorvida pelo EAGOLD. A exceção R13 é feita pelo Magic reservado.

**Quando alterar:** somente quando a segregação do universo de ordens for deliberadamente redefinida. Em conta real, confirmar que não há outra estratégia no mesmo símbolo se `-1` for mantido.

---

# SESSÃO B — DINHEIRO, LOTES E PROGRESSÃO

## B.1 `Lot`

**Default:** `0.01`  
**Status:** ATIVO  
**Importância:** **CRÍTICA**

**Código:** `NormalizeLot()`, `CreateFirstOrdersIfFlat()`, `R7`, `Recovery`, `R13`.

É o lote-base do Master. Também funciona como piso lógico em várias rotinas: operações abaixo de `Lot` são rejeitadas.

**Efeito:** aumentar `Lot` aumenta diretamente a exposição inicial e altera toda a progressão subsequente.

**Interações:** `Multiplier`, `LotIncrement`, `MaxOpenLot`, R9, R11 e limites do broker.

**Quando alterar:** somente após validar impacto monetário por operação, margem e pior cesta. É um dos inputs que não deve ser alterado casualmente em conta real.

## B.2 `Multiplier`

**Default:** `1.10`  
**Status:** ATIVO  
**Importância:** **CRÍTICA**

**Código:** `Engines/EAGOLD_Recovery.mqh` → `NextRecoveryLot()`.

Próximo lote = `lote_anterior * Multiplier + LotIncrement`, posteriormente normalizado.

**Efeito:** controla a velocidade de crescimento dos lotes de Recovery. Pequenos aumentos podem produzir crescimento significativo após várias ativações.

**Interações:** `LotIncrement`, `MaxOpenLot`, `DigitsLots` e R11, que pode reduzir o lote candidato antes do envio.

**Quando alterar:** somente em calibração específica de risco. Não confundir com `RecoveryStepMultiplier`, que controla distância, não lote.

## B.3 `DigitsLots`

**Default:** `2`  
**Status:** ATIVO  
**Importância:** **ALTA**

Controla a normalização decimal dos lotes e várias exibições. Não cria precisão de lote que o broker não aceite.

**Interações:** `Lot`, `LotIncrement`, `Multiplier`, R9, R10 e Recovery.

## B.4 `LotIncrement`

**Default:** `0.02`  
**Status:** ATIVO  
**Importância:** **ALTA**

Participa diretamente da fórmula `NextRecoveryLot(previousLot)`.

**Efeito:** adiciona um incremento fixo a cada novo lote de Recovery.

**Interação:** somado após `Multiplier`; portanto o crescimento não é puramente multiplicativo.

## B.5 `MaxOpenLot`

**Default:** `3.00`  
**Status:** ATIVO  
**Importância:** **CRÍTICA**

**Código:** `NormalizeLot()` usado pelo envio Master/R9 e pelo Recovery.

É teto lógico de lote por ordem enviada pelo caminho Master. Não é teto de exposição total da cesta.

**Implicação importante:** uma cesta pode ultrapassar `MaxOpenLot` em lotes totais por possuir várias ordens.

**Interações:** `Multiplier`, `LotIncrement`, R11 e número de níveis de Recovery.

## B.6 `TakeProfit`

**Default:** `5.00`  
**Status:** ATIVO CONDICIONAL  
**Importância:** **ALTA**

**Código:** `BuySingleTakeProfit()`, `SellSingleTakeProfit()`, e fallback legado de `BuyBasketTargetReached()`/`SellBasketTargetReached()`.

**Uso atual:**
- Single position: fecha quando lucro direcional ≥ `TakeProfit`, respeitando `CanCloseLightBasket()` e R10.2.
- BRX desativado/modo 0: alvo legado da cesta é `count * TakeProfit`.

**Interação:** com `EnableBasketRealization` e `BRXRealizationMode`, BRX pode substituir o alvo legado.

**Quando alterar:** somente sabendo qual modo BRX está ativo. Em modo BRX 1/2/3, não interpretar `TakeProfit` como alvo principal da cesta.

## B.7 `SellProfit`

**Default:** `30.00`  
**Status:** **INATIVO**  
**Importância:** N/A até implementação.

Não há referência no código modular executado. Não influencia o fechamento SELL atual.

**Conclusão:** não calibrar este input. Se a intenção original era possuir alvo SELL diferente, a implementação precisa ser restaurada explicitamente antes de operação real.

## B.8 `BasketLoss`

**Default:** `100.00`  
**Status:** **INATIVO**  
**Importância:** **RISCO DE INTERPRETAÇÃO**

Não há referência no código modular executado. Portanto não existe, hoje, uma proteção automática de cesta em `-BasketLoss`.

**Conclusão crítica:** nunca assumir que `BasketLoss=100` limita a perda. Ele é atualmente apenas um parâmetro declarado.

## B.9 `SpreadLimit`

**Default:** `100` pontos  
**Status:** ATIVO — UI  
**Importância:** **ALTA COMO SINAL, NULA COMO GATE MASTER**

**Código:** painel calcula `spreadPoints` e gera alerta visual.

**Não faz:** não bloqueia `SendMarket()`, `SendPending()`, Recovery, R9 ou R10.

**Interação:** R13 possui seu próprio `R13MaxSpread`, que é efetivamente usado como gate de entrada R13.

**Conclusão:** o nome sugere proteção de execução, mas atualmente é telemetria. Não calibrar como se fosse limitador de trading Master.

## B.10 `WaitSeconds`

**Default:** `0`  
**Status:** **INATIVO**.

Não há referência operacional no modularizado. Não existe espera geral configurável entre operações.

## B.11 `FirstStep`

**Default:** `160` pontos  
**Status:** ATIVO  
**Importância:** **CRÍTICA**

**Código:** `CreateFirstOrdersIfFlat()` cria BUY STOP em `Ask + FirstStep` e SELL STOP em `Bid - FirstStep`. `TrailAllStopOrders()` também usa `FirstStep` para a família R1 FIRST.

**Efeito:** controla a distância inicial dos dois gatilhos.

**Interação:** R1.1 valida o preço calculado; Global Stop Trail pode posteriormente reposicionar os pendentes R1.

---

# SESSÃO C — R1.1: CONTROLE DE ADMISSÃO DA PRIMEIRA CESTA

## C.1 `EnableR1AdmissionGate`

**Default:** `false`  
**Status:** ATIVO  
**Importância:** **CRÍTICA PARA SEGURANÇA DE ENTRADA**

Quando `true`, o primeiro ciclo BUY+SELL é submetido aos gates configurados. O bloqueio é **atômico**: se um dos lados falhar, o ciclo inicial inteiro é bloqueado.

Quando `false`, os gates não bloqueiam o primeiro ciclo.

**Interações:** todos os C.2–C.8.

## C.2 `EnableR1BrokerGuard`

**Default:** `false`  
**Status:** ATIVO CONDICIONAL  
**Importância:** ALTA.

Com gate mestre ligado, verifica `MODE_STOPLEVEL + R1BrokerSafetyBufferPoints` contra a distância entre preço candidato e mercado.

## C.3 `EnableR1LotGuard`

**Default:** `false`  
**Status:** ATIVO CONDICIONAL  
**Importância:** ALTA.

Valida min/max/step do broker para o lote inicial.

**Interação:** não substitui `NormalizeLot()`; é uma validação adicional do R1.1.

## C.4 `EnableR1MarginGuard`

**Default:** `false`  
**Status:** ATIVO CONDICIONAL  
**Importância:** ALTA.

Usa `AccountFreeMarginCheck()` para testar margem após a ordem e opcionalmente exige `R1MinFreeMarginAfterOrder`.

## C.5 `EnableR1TradePermissionGuard`

**Default:** `false`  
**Status:** ATIVO CONDICIONAL  
**Importância:** ALTA.

Verifica `MODE_TRADEALLOWED` antes do primeiro ciclo.

## C.6 `R1BrokerSafetyBufferPoints`

**Default:** `0`  
**Status:** ATIVO CONDICIONAL.

É adicionado ao `MODE_STOPLEVEL` no R1 Broker Guard.

**Efeito:** valor maior = exigência maior de distância do mercado.

## C.7 `R1MinFreeMarginAfterOrder`

**Default:** `0`  
**Status:** ATIVO CONDICIONAL.

Se > 0, a margem livre restante após a ordem deve ser ≥ este valor.

**Unidade:** moeda da conta, não pontos.

## C.8 `EnableR1DecisionLog`

**Default:** `true`  
**Status:** ATIVO — LOG/UI  
**Importância:** MÉDIA.

Controla `Print()` das decisões R1.1. Não altera a decisão, apenas observabilidade.

---

# SESSÃO D — LIFECYCLE R4 / R5 / R7

## D.1 `MiniGrid1`

**Default:** `320` pontos  
**Status:** ATIVO.

Usado no próximo BUY após realização single R4 e no trailing de pendente R4 BUY.

## D.2 `SmartGrid1`

**Default:** `280` pontos  
**Status:** ATIVO.

No Recovery BUY/SELL, a criação do próximo pending exige deslocamento adverso de pelo menos `2 * SmartGrid1` a partir da posição mais recente.

**Importante:** ele é um filtro de distância para criação do pending, não a distância final do pending; a distância final vem de `RecoveryStepForLevel()`.

## D.3 `RecoveryMinDistance`

**Default:** `340` pontos  
**Status:** ATIVO — **CRÍTICO**.

É o passo base do Recovery e também o `resetPoints` do trailing de pendentes Recovery.

**Interação:** `RecoveryStepMultiplier` e `RecoveryStepMax` podem transformar este valor no passo efetivo por nível.

## D.4 `MiniGrid2`

**Default:** `80` pontos  
**Status:** ATIVO.

Usado no próximo SELL após single TP e no trailing dos pendentes R4 SELL.

## D.5 `SmartGrid2`

**Default:** `60` pontos  
**Status:** **INATIVO**.

Não há referência no código atual. O Recovery BUY e SELL usa `SmartGrid1` para o filtro de ativação.

**Conclusão:** não calibrar acreditando que exista um SmartGrid2 específico para SELL.

## D.6 `PendingStepTrail`

**Default:** `50` pontos  
**Status:** ATIVO — **ALTA**.

Controla o trailing global de pendentes. Para R1 FIRST, o gatilho é `FirstStep + PendingStepTrail`; para família GLOBAL, o gatilho base é `PendingStepTrail`.

**Interação:** `EnableGlobalStopTrail`, cooldown e min-step.

## D.7 `BasketRestartStep`

**Default:** `160` pontos  
**Status:** ATIVO.

Quando uma direção fica sem posições e sem pending, R7 recria um STOP na direção correspondente a esta distância.

Também é usado no trailing de R7 RESTART.

## D.8 `MaxTrades`

**Default:** `2000`  
**Status:** **INATIVO**.

Não há limite efetivo de quantidade de operações baseado neste input no código modular atual.

**Conclusão crítica:** `MaxTrades=2000` não é uma trava de segurança.

## D.9 `EnableCloseBy`

**Default:** `true`  
**Status:** **INATIVO**.

Não há uso de `OrderCloseBy()` condicionado por este input no código modular atual.

## D.10 `BuyProgressionTolerance`

**Default:** `10` pontos  
**Status:** **INATIVO**.

Não influencia a progressão BUY atual.

---

# SESSÃO E — GLOBAL STOP TRAIL

## E.1 `EnableGlobalStopTrail`

**Default:** `true`  
**Status:** ATIVO — **CRÍTICA**.

Habilita `TrailAllStopOrders()`, que pode modificar BUY STOP/SELL STOP pendentes.

## E.2 `GlobalStopTrailCooldownSeconds`

**Default:** `0` s  
**Status:** ATIVO — ALTA.

Impede nova modificação do mesmo ticket até transcorrer o intervalo desde a última modificação registrada.

**Observação:** usa `TimeCurrent()` e estado em memória por ticket.

## E.3 `GlobalStopTrailMinStepPoints`

**Default:** `0`  
**Status:** ATIVO — ALTA.

Exige deslocamento mínimo do preço de mercado desde a última modificação do ticket antes de nova alteração.

**Interação:** atua junto com cooldown; ambos podem bloquear uma modificação.

---

# SESSÃO F — BRX: REALIZAÇÃO DE CESTA

## F.1 `EnableBasketRealization`

**Default:** `true`  
**Status:** ATIVO — **CRÍTICA**.

Habilita o mecanismo BRX e altera a lógica de alvo da cesta.

## F.2 `BRXRealizationMode`

**Default:** `3` — HYBRID  
**Status:** ATIVO — **CRÍTICA**.

- `0`: legado; usa `count * TakeProfit` para alvo de cesta.
- `1`: direcional.
- `2`: bidirecional.
- `3`: híbrido: tenta bidirecional e também direcional.

**Interação decisiva:** em modo 2/3, `BuyMachine()`/`SellMachine()` chama `BRX_Run()` antes do fechamento tradicional; em modo 2, se BRX não fechar, a máquina retorna e não prossegue com a realização tradicional.

## F.3 `BRXDirectionalMinProfit`

**Default:** `$5`  
**Status:** ATIVO CONDICIONAL.

Piso monetário para realização direcional BRX. O código exige também o `BRXRealizationSafetyBuffer`.

## F.4 `BRXBidirectionalMinProfit`

**Default:** `$5`  
**Status:** ATIVO CONDICIONAL.

Piso monetário da realização bidirecional.

## F.5 `BRXRealizationSafetyBuffer`

**Default:** `$5`  
**Status:** ATIVO — **CRÍTICA**.

É somado ao piso: `required = floor + safetyBuffer`.

**Unidade:** dinheiro da conta, não pontos.

**Função:** criar margem operacional contra movimento entre cálculo e fechamento. Não constitui garantia matemática de lucro realizado.

## F.6 `BRXRequireWeightedBE`

**Default:** `false`  
**Status:** ATIVO CONDICIONAL.

Quando `true`, a realização direcional BRX também exige validação do preço atual contra o BE ponderado.

**Importante:** com `false`, `BRXWeightedBEBufferPoints` não impede a realização.

## F.7 `BRXWeightedBEBufferPoints`

**Default:** `0`  
**Status:** ATIVO CONDICIONAL.

Só tem efeito se `BRXRequireWeightedBE=true` e > 0. Para BUY, exige `Ask >= BE + buffer`; para SELL, `Bid <= BE - buffer`.

---

# SESSÃO G — R13 RECOVERY SATELLITE

R13 possui universo próprio identificado por `R13MagicNumber`; ele é deliberadamente excluído das métricas Master.

## G.1 `EnableR13`

**Default:** `false`  
**Status:** ATIVO — gate mestre.

Sem ele, R13 não fica habilitado no observer/trading.

## G.2 `EnableR13AutoActivation`

**Default:** `false`  
**Status:** ATIVO CONDICIONAL — **CRÍTICO**.

`tradingEnabled = EnableR13 && EnableR13Trading && EnableR13AutoActivation`.

**Interação:** mesmo com R13 Trading ON, AutoActivation OFF impede entrada automática.

## G.3 `EnableR13Trading`

**Default:** `false`  
**Status:** ATIVO CONDICIONAL — CRÍTICO.

É a permissão efetiva de execução R13, mas precisa estar acompanhada de `EnableR13` e AutoActivation.

## G.4 `R13ProfitTarget`

**Default:** `$5`  
**Status:** ATIVO.

Fecha posições R13 quando lucro flutuante próprio ≥ alvo.

## G.5 `R13EntryCooldownSeconds`

**Default:** `30` s  
**Status:** ATIVO.

Após entrada/saída R13, impede nova entrada até o intervalo transcorrer.

## G.6 `R13CloseWhenMasterFlat`

**Default:** `true`  
**Status:** ATIVO — **CRÍTICO**.

Quando exposição Master cai abaixo de `R13MinDirectionalImbalance`, fecha o Satellite.

## G.7 `EnableR13MasterAdjustment`

**Default:** `true`  
**Status:** ATIVO.

Permite que lucro realizado R13 acumulado seja usado para financiar `R10ProfitFundedAverageAdjustment()` no Master.

## G.8 `R13MasterAdjustmentMaxLots`

**Default:** `0.20`  
**Status:** ATIVO.

Limita os lotes máximos reduzidos por uma operação de ajuste R10 financiada pelo capital R13.

## G.9 `R13MagicNumber`

**Default:** `3010`  
**Status:** ATIVO — **CRÍTICO**.

Define a identidade das ordens R13. `IsR13Order()` exige símbolo atual + este Magic.

**Proteção:** configuração é considerada inválida se `R13MagicNumber < 0` ou se coincidir com `MagicNumber` quando este não é `-1`.

## G.10 `R13OrderComment`

**Default:** `EAGOLD_RECOVERY_SATELLITE`  
**Status:** ATIVO.

É gravado nas ordens R13. Não é a fronteira de ownership; essa fronteira é Magic + símbolo.

## G.11 `R13MaxLots`

**Default:** `0.20`  
**Status:** ATIVO — ALTA.

Limita o espaço total disponível para posições R13 antes de nova entrada.

## G.12 `R13MaxPositions`

**Default:** `3`  
**Status:** ATIVO — ALTA.

É usado na elegibilidade do observer. A rotina de abertura também só abre se não houver posição R13 aberta, portanto o limite de 3 não implica três entradas simultâneas na implementação atual.

## G.13 `R13MaxDrawdown`

**Default:** `$50`  
**Status:** ATIVO.

Gate de entrada baseado no `R13OwnProfit()` flutuante atual. Não é drawdown histórico/equity drawdown.

## G.14 `R13MaxDailyLoss`

**Default:** `$50`  
**Status:** ATIVO.

Gate de entrada baseado no lucro líquido fechado R13 desde o início do dia do servidor.

## G.15 `R13MaxSpread`

**Default:** `100` pontos  
**Status:** ATIVO.

Bloqueia entrada R13 se `MODE_SPREAD` exceder o limite.

**Interação:** não controla entradas Master.

## G.16 `R13StartHour`

**Default:** `0`  
**Status:** ATIVO.

Controla janela horária R13.

## G.17 `R13EndHour`

**Default:** `23`  
**Status:** ATIVO.

Controla fim da janela. Quando Start ≤ End, ambos os extremos são inclusivos. Quando Start > End, a janela atravessa meia-noite.

## G.18 `EnableR13DirectionalComplementarity`

**Default:** `true`  
**Status:** ATIVO — **CRÍTICO**.

Exige que o Satellite esteja na direção complementar à direção Master. Em mudança de direção, fecha o Satellite existente.

## G.19 `R13MinDirectionalImbalance`

**Default:** `0.01` lot  
**Status:** ATIVO — **CRÍTICO**.

Define o mínimo de exposição Master para considerar que existe direção dominante suficiente para o R13.

Também é usado em `R13TryFundMasterAdjustment()` e no encerramento quando a exposição cai abaixo do limiar.

## G.20 `R13RecoveryCapitalFraction`

**Default:** `1.00`  
**Status:** ATIVO.

Percentual do lucro positivo realizado pelo R13 que vira capital interno disponível para financiar ajuste R10.

`1.0` = 100%; `0.5` = 50%.

---

# SESSÃO H — R9: CONTROLE DE EXPOSIÇÃO / HEDGE

## H.1 `EnableR9Hedge`

**Default:** `true`  
**Status:** ATIVO — **CRÍTICO**.

Habilita detecção de novas posições ativadas e hedge automático.

## H.2 `R9ExposureTriggerLots`

**Default:** `1.00` lot  
**Status:** ATIVO — **CRÍTICO**.

O R9 só considera hedge quando a exposição líquida `abs(BUY-SELL)` atinge este valor ou mais.

## H.3 `R9TriggerLotMinimum`

**Default:** `0.00`  
**Status:** **INATIVO**.

Declarado na configuração, mas não consultado por `EAGOLD_R9.mqh`.

**Conclusão:** não existe hoje um piso adicional de lote do ticket disparador baseado neste input.

## H.4 `R9HedgeFraction`

**Default:** `0.6666666667`  
**Status:** ATIVO — **CRÍTICO**.

Lote de hedge candidato = `triggerLot * R9HedgeFraction`.

Depois o valor é limitado por `R9BalanceCap * exposure`.

**Interação decisiva:** o hedge efetivo é o menor entre a fração do trigger e o teto de balanceamento.

## H.5 `R9BalanceCap`

**Default:** `0.50`  
**Status:** ATIVO — **CRÍTICO**.

Calcula `maxHedge = exposure * R9BalanceCap`.

Exemplo: exposição 1,50 lot, cap 0,50 → hedge máximo 0,75 lot.

---

# SESSÃO I — R10: REDUÇÃO DE EXPOSIÇÃO

## I.1 `EnableR10Reduce`

**Default:** `true`  
**Status:** ATIVO — **CRÍTICO**.

Habilita `Rule10Reduce()`.

**Importante:** R10 não cria posições. Ele somente reduz posições existentes.

## I.2 `R10MinExposureLots`

**Default:** `0.01`  
**Status:** ATIVO.

Define exposição mínima para a redução normal e também participa da construção formal de candidatos no núcleo R10 legado/formal.

No caminho atual `Rule10Reduce()`, a redução só ocorre se a exposição for ≥ este valor.

## I.3 `EnableR10PairReduction`

**Default:** `true`  
**Status:** ATIVO — ALTA.

Permite a tentativa inicial de redução pareada financiada por lucro.

## I.4 `R10PairMinProfit`

**Default:** `$5`  
**Status:** ATIVO — ALTA.

A soma do lucro por lote do ticket lucrativo + ticket perdedor multiplicada pelos lotes reduzidos deve atingir este mínimo.

## I.5 `R10PairMaxLots`

**Default:** `1.00` lot  
**Status:** ATIVO — ALTA.

Limita o tamanho de uma redução pareada.

## I.6 `R10PairCooldownSeconds`

**Default:** `30` s  
**Status:** ATIVO.

Após uma ação R10 bem-sucedida ou uma falha parcial específica, impede nova tentativa pareada durante o cooldown.

**Importante:** este cooldown não é um cooldown global de todas as reduções R10; ele está na entrada `Rule10ProfitFundedPartial()`.

## I.7 `EnableR10VisualMarker`

**Default:** `true`  
**Status:** ATIVO — UI.

Cria o marcador textual `RD <lotes>` no gráfico para ações R10.

## I.8 `R10MarkerFont`

**Default:** `Segoe UI Semibold`  
**Status:** **PARCIAL/INATIVO COMO INPUT**.

O código de `CreateR10VisualMarker()` usa explicitamente `"Segoe UI Semibold"` e não lê `R10MarkerFont`.

**Conclusão:** alterar este input atualmente não muda a fonte.

## I.9 `R10MarkerFontSize`

**Default:** `9`  
**Status:** ATIVO — UI.

Controla tamanho do marcador R10.

## I.10 `R10BuyMarkerColor`

**Default:** `clrLime`  
**Status:** ATIVO — UI.

Cor do marcador R10 para redução na direção BUY.

## I.11 `R10SellMarkerColor`

**Default:** `clrTomato`  
**Status:** ATIVO — UI.

Cor do marcador R10 para redução na direção SELL.

## I.12 `R10MarkerOffsetPoints`

**Default:** `25` pontos  
**Status:** ATIVO — UI.

Deslocamento vertical do texto do marcador R10 em relação ao preço médio atual.

---

# SESSÃO J — MARCADORES DE AÇÕES DOS ENGINES

## J.1 `EnableEngineActionMarkers`

**Default:** `true`  
**Status:** ATIVO — UI.

Habilita criação de pontos/objetos de ação no gráfico e alimentação da cascata de ações.

## J.2 `EngineActionMarkerFont`

**Default:** `Impact`  
**Status:** **INATIVO COMO INPUT**.

A implementação atual cria `OBJ_ARROW` e não usa esta fonte.

## J.3 `EngineActionMarkerFontSize`

**Default:** `9`  
**Status:** **INATIVO COMO INPUT**.

Não há uso na criação atual do `OBJ_ARROW`.

## J.4 `EngineActionMarkerTextColor`

**Default:** `clrYellow`  
**Status:** **INATIVO COMO INPUT**.

A cor do ponto é definida por `CascadeEngineColor(engine)`.

## J.5 `EngineActionMarkerBackgroundColor`

**Default:** `clrBlack`  
**Status:** **INATIVO COMO INPUT**.

Não há objeto de texto/fundo correspondente na implementação atual.

## J.6 `EngineActionMarkerOffsetPips`

**Default:** `20` pips  
**Status:** **INATIVO COMO INPUT**.

Não é usado no `CreateEngineActionMarker()` atual.

## J.7 `EngineActionMarkerStackStepPips`

**Default:** `20` pips  
**Status:** **INATIVO COMO INPUT**.

Existe função `EngineMarkerStackLevel()`, mas a criação atual não usa esse nível para posicionamento.

**Conclusão:** a arquitetura antiga de texto/stack foi parcialmente substituída por ponto colorido; estes inputs ficaram sem efeito.

---

# SESSÃO K — R10.2: RECOVERY REALIZATION / DÍVIDA DE EQUITY

## K.1 `EnableR10RecoveryRealization`

**Default:** `false`  
**Status:** ATIVO — **CRÍTICO** quando ligado.

Ativa ciclo de recuperação baseado em equity e passa a bloquear certas realizações de cesta.

## K.2 `R10RecoveryMinDebt`

**Default:** `$100`  
**Status:** ATIVO CONDICIONAL.

A proteção de R10.2 só entra no modo de bloqueio quando a dívida calculada atingir este valor.

## K.3 `R10RecoveryProfitTarget`

**Default:** `$50`  
**Status:** ATIVO CONDICIONAL.

Define alvo de excedente de equity após recuperação.

## K.4 `R10RecoveryDebtTargetPercent`

**Default:** `0%`  
**Status:** ATIVO CONDICIONAL.

Quando > 0, adiciona ao alvo uma parcela percentual da dívida máxima observada.

`target = ProfitTarget + debt * percent/100`.

## K.5 `R10RecoveryRequireDebtRepaid`

**Default:** `true`  
**Status:** ATIVO CONDICIONAL — **CRÍTICO**.

Se verdadeiro, o fechamento de cesta é bloqueado enquanto `R10RecoveryRemainingDebt > 0.01` quando a dívida mínima foi atingida.

**Interação:** `R10RecoveryAllowBasketClose()` é consultado pelo lifecycle e BRX antes de determinadas realizações. Não bloqueia diretamente toda ação R10.

**Importante:** dívida/remaining são baseados em `AccountEquity()`, não em P/L realizado acumulado.

---

# SESSÃO L — R11: DISTÂNCIA DINÂMICA E GOVERNADOR DE EXPOSIÇÃO

## L.1 `EnableRecoveryStepMultiplier`

**Default:** `true`  
**Status:** ATIVO — ALTA.

Ativa multiplicação progressiva do passo Recovery por nível.

## L.2 `RecoveryStepMultiplier`

**Default:** `1.15`  
**Status:** ATIVO — ALTA.

Passo nível `n` = `RecoveryMinDistance * RecoveryStepMultiplier^n`, limitado por `RecoveryStepMax`.

**Não altera lote.**

## L.3 `RecoveryStepMax`

**Default:** `500` pontos  
**Status:** ATIVO — ALTA.

Teto do passo dinâmico.

## L.4 `EnableR11ExposureGovernor`

**Default:** `true`  
**Status:** ATIVO — **CRÍTICO**.

Controla somente **nova exposição de Recovery**. Não reduz nem fecha posições existentes.

## L.5 `R11TaperStartGrossExposureLots`

**Default:** `8` lotes  
**Status:** ATIVO — CRÍTICO.

A partir deste gross exposure começa a região de taper, salvo bloqueio por baixa relação net/gross.

## L.6 `R11BlockGrossExposureLots`

**Default:** `12` lotes  
**Status:** ATIVO — **CRÍTICO**.

Com gross ≥ este valor, `R11RecoveryLotFactor()` retorna zero e nova adição de Recovery é bloqueada.

## L.7 `R11MinNetToGrossRatio`

**Default:** `0.10`  
**Status:** ATIVO — CRÍTICO.

Quando gross ≥ taper e `net/gross < ratio`, o Recovery é bloqueado.

**Interação importante:** uma cesta muito equilibrada pode ser bloqueada mesmo antes de atingir 12 lotes, se já estiver na região de taper e tiver net/gross abaixo do limite.

## L.8 `R11MinRecoveryLotFactor`

**Default:** `0.25`  
**Status:** ATIVO.

Fator mínimo do lote candidato durante taper linear entre `TaperStart` e `BlockGross`.

**Atenção:** mesmo com fator > 0, o lote final passa por `NormalizeLot()`, podendo ficar abaixo de `Lot`; nesse caso a entrada é recusada.

---

# SESSÃO M — PERSISTÊNCIA E CONTINUIDADE OPERACIONAL

## M.1 `PersistenceWorstEquityStep`

**Default:** `$5`  
**Status:** ATIVO — ALTA.

Controla quando uma nova piora de `g_r10RecoveryWorstEquity` é considerada significativa para persistência.

Valores menores aumentam frequência de checkpoints; valores maiores reduzem escrita.

**Importante:** persistência estratégica está desabilitada no Strategy Tester; em operação real continua usando Global Variables do terminal.

---

# SESSÃO N — PAINEL / OBSERVABILIDADE

## N.1 `EnableModularizationPanel`

**Default:** `true`  
**Status:** ATIVO — UI.

Liga/desliga painel e também a cascata de ações/realizações.

**Interação:** desligar o painel também faz `EAGOLD_RealizationCascadeUpdate()` remover a cascata.

## N.2 `EnableModularizationDebug`

**Default:** `false`  
**Status:** ATIVO — UI.

Aumenta altura do painel e exibe estado/debug R1/R10.

Não altera decisões de trading.

## N.3 `EnableChartBasketGuides`

**Default:** `true`  
**Status:** ATIVO — UI.

Mostra apenas linhas de preço médio ponderado BUY/SELL. Não participa da execução.

## N.4 `ChartBasketGuideOffsetBars`

**Default:** `2` barras  
**Status:** ATIVO — UI.

É usado para definir o segundo ponto temporal das linhas dos guias. Não muda preço nem regra de trading.

## N.5 `PanelBackgroundX`

**Default:** `260`  
**Status:** **INATIVO COMO INPUT**.

A implementação atual usa `XDISTANCE=6` fixo para o background. O valor deste input não é consultado.

## N.6 `PanelBackgroundY`

**Default:** `8`  
**Status:** **INATIVO COMO INPUT**.

A implementação atual usa `YDISTANCE=4` fixo para o background.

## N.7 `PanelBackgroundHeight`

**Default:** `450`  
**Status:** **INATIVO COMO INPUT**.

A altura efetiva é definida pelo código como `550` ou `670`, dependendo de `EnableModularizationDebug`.

## N.8 `PanelBottomY`

**Default:** `8`  
**Status:** **INATIVO COMO INPUT**.

Não é consultado pelo painel atual.

## N.9 `PanelBottomX1`

**Default:** `15`  
**Status:** **INATIVO COMO INPUT**.

Não é consultado pelo painel atual.

## N.10 `PanelBottomX2`

**Default:** `190`  
**Status:** **INATIVO COMO INPUT**.

Não é consultado pelo painel atual.

## N.11 `PanelBottomX3`

**Default:** `520`  
**Status:** **INATIVO COMO INPUT**.

Não é consultado pelo painel atual.

## N.12 `PanelBottomX4`

**Default:** `850`  
**Status:** **INATIVO COMO INPUT**.

Não é consultado pelo painel atual.

## N.13 `PanelBackgroundWidth`

**Default:** `430`  
**Status:** ATIVO — UI.

Controla a largura do background principal do painel.

---

# SESSÃO O — INPUTS QUE NÃO PODEM SER CONFUNDIDOS COM PROTEÇÕES

Esta sessão é obrigatória antes da conta real.

| Input | Situação atual | Não assumir que faz |
|---|---|---|
| `SellProfit` | INATIVO | alvo SELL independente |
| `BasketLoss` | INATIVO | stop monetário da cesta |
| `SpreadLimit` | UI | bloqueio de entrada Master |
| `WaitSeconds` | INATIVO | cooldown geral |
| `SmartGrid2` | INATIVO | filtro Recovery SELL separado |
| `MaxTrades` | INATIVO | limite de número de ordens |
| `EnableCloseBy` | INATIVO | uso de `OrderCloseBy()` |
| `BuyProgressionTolerance` | INATIVO | tolerância de progressão BUY |
| `R9TriggerLotMinimum` | INATIVO | lote mínimo do ticket disparador R9 |
| `R10MarkerFont` | parcial | fonte configurável do marcador R10 |
| `EngineActionMarkerFont` | INATIVO | fonte configurável dos pontos |
| `EngineActionMarkerFontSize` | INATIVO | tamanho configurável dos pontos |
| `EngineActionMarkerTextColor` | INATIVO | cor configurável via input |
| `EngineActionMarkerBackgroundColor` | INATIVO | fundo configurável |
| `EngineActionMarkerOffsetPips` | INATIVO | deslocamento dos pontos |
| `EngineActionMarkerStackStepPips` | INATIVO | espaçamento dos pontos |
| `PanelBackgroundX/Y/Height` | INATIVOS | geometria efetiva correspondente aos nomes |
| `PanelBottomY/X1/X2/X3/X4` | INATIVOS | posicionamento inferior |

---

# SESSÃO P — MATRIZ DE INTERAÇÕES ENTRE ENGINES

## P.1 R1 → R1.1 → Execução

`FirstStep` define os preços candidatos. `EnableR1AdmissionGate` decide se esses candidatos passam pelos gates. Os gates podem rejeitar o ciclo antes de `SendPending()`.

## P.2 Lot → Recovery → R11

`Lot`, `Multiplier` e `LotIncrement` geram o lote candidato. `MaxOpenLot` limita a normalização. Depois R11 pode aplicar fator de taper ou bloquear completamente.

Fluxo:

`previousLot → Multiplier/LotIncrement → NormalizeLot → R11 factor → NormalizeLot → SendPending`.

## P.3 RecoveryMinDistance → R11 Step Multiplier

`RecoveryMinDistance` é a base. `RecoveryStepMultiplier` aumenta o passo por nível. `RecoveryStepMax` limita o resultado.

Isso altera **distância**, não lote.

## P.4 R9 → R10

R9 adiciona hedge na direção leve quando nova ativação aumenta a exposição. Isso altera `DirectionLots()` e `ExposureLots()`. Portanto a atuação do R9 pode mudar imediatamente as condições sob as quais R10 pode reduzir.

## P.5 R10 → BRX

R10 pode realizar lucro ou prejuízo parcial antes de uma realização final. Isso altera tanto exposição quanto P/L flutuante. BRX trabalha com o estado atual da cesta, não com uma contabilidade histórica completa de tudo que R10 já realizou.

Por isso uma sequência de reduções R10 pode mudar a elegibilidade BRX.

## P.6 R10.2 → BRX / Lifecycle

`R10RecoveryAllowBasketClose()` é consultado antes de determinados fechamentos. Quando R10.2 está ativo e a dívida mínima foi atingida, o EA pode segurar uma realização mesmo que BRX encontre seu piso monetário.

## P.7 R13 → R10

Lucro R13 realizado positivamente vira `g_r13RecoveryCapitalAvailable` segundo `R13RecoveryCapitalFraction`. Esse capital pode financiar `R10ProfitFundedAverageAdjustment()`.

Esse ajuste R10 pode realizar uma perda deliberada em uma posição Master, desde que o capital R13 cubra a perda e o ajuste reduza exposição.

## P.8 R11 → Recovery somente

R11 não fecha posições existentes. Se a cesta já estiver sobrecarregada, R11 apenas impede/reduz **novas** adições Recovery. A redução de estoque existente continua sendo responsabilidade de R9/R10/realizações.

## P.9 BRX → Lifecycle

Em modo BRX 2/3, BRX é chamado antes do fechamento tradicional. Isso significa que alterar `BRXRealizationMode`, pisos e safety buffer pode mudar o caminho que a máquina percorre antes de R4/R5/R7.

---

# SESSÃO Q — ACHADOS CRÍTICOS PARA A OPERAÇÃO REAL

## Q.1 Existem inputs declarados sem efeito

Sim. Eles precisam ser classificados como dívida técnica, não como parâmetros de segurança.

## Q.2 Há inputs com nome de proteção que hoje não protegem

`BasketLoss` e `SpreadLimit` são os exemplos mais importantes.

- `BasketLoss`: sem efeito operacional.
- `SpreadLimit`: somente alerta visual do painel para Master.

## Q.3 Há inputs de UI que ficaram desacoplados do código

Vários parâmetros de fonte, offset e geometria permanecem na configuração, mas a implementação atual usa valores fixos ou mudou para objetos diferentes.

## Q.4 R10.2 não é um stop-loss da cesta

Ele é uma política de bloqueio de certas realizações baseada em equity/dívida. Não deve ser interpretado como limite máximo de perda.

## Q.5 BRX não garante lucro realizado matematicamente

O código cria um piso de autorização usando P/L atual + safety buffer e, no modo bidirecional, projeta a segunda perna levando em conta o valor já realizado. Entretanto preço, spread e execução podem mudar entre medição e fechamento.

Portanto o objetivo técnico é **proteger a realização por condição de autorização**, não garantir um resultado impossível de violar em presença de execução adversa.

## Q.6 `MagicNumber=-1` exige atenção especial em conta real

Esse modo amplia o universo Master para todas as ordens do símbolo, independentemente do Magic, exceto R13. Deve ser tratado como configuração de arquitetura, não como simples identificação.

---

# SESSÃO R — PROTOCOLO DE CALIBRAÇÃO PARA LIVE

1. **Congelar código:** nenhum ajuste de input durante uma sessão de diagnóstico sem registrar versão/commit.
2. **Separar parâmetros de risco de parâmetros de UI.**
3. **Calibrar primeiro os limites absolutos:** `Lot`, `MaxOpenLot`, `FirstStep`, `RecoveryMinDistance`, R9, R10, BRX, R11.
4. **Depois calibrar dinâmica:** `Multiplier`, `LotIncrement`, `RecoveryStepMultiplier`, `RecoveryStepMax`.
5. **Depois calibrar realização:** BRX e R10.2.
6. **R13 deve ser calibrado isoladamente** antes de ser considerado parte do risco total do Master.
7. **Toda alteração deve possuir hipótese:** o que esperamos mudar, qual risco aumenta/reduz e qual métrica comprovará o efeito.
8. **Nenhum input INATIVO deve ser alterado como tentativa de corrigir comportamento.** Primeiro deve ser implementado ou removido da configuração.
9. **Toda mudança de input deve ser testada em cenário controlado antes do live.**
10. **Em live, alterar uma variável por vez**, salvo quando houver dependência matemática explícita.

---

# SESSÃO S — CHECKLIST DE GO-LIVE

Antes de colocar a conta real em produção, confirmar explicitamente:

- [ ] `MagicNumber` corresponde exatamente ao universo de ordens pretendido.
- [ ] Não existe outra estratégia no mesmo símbolo se `MagicNumber=-1` for usado.
- [ ] `Lot` compatível com risco monetário real.
- [ ] `MaxOpenLot` compatível com margem e risco por ordem.
- [ ] `Multiplier` + `LotIncrement` projetados por nível de Recovery.
- [ ] `FirstStep` validado contra spread/stop level do broker.
- [ ] `RecoveryMinDistance`, `SmartGrid1` e `RecoveryStepMax` validados.
- [ ] R9 testado com o lote e exposição reais.
- [ ] R10 testado com slippage e liquidez reais.
- [ ] BRX floor + safety buffer validados.
- [ ] Decisão sobre R10.2 explicitamente tomada.
- [ ] R11 taper/block validado com a capacidade de margem real.
- [ ] R13, se habilitado, validado como risco adicional e separado do Master.
- [ ] Inputs INATIVOS não estão sendo tratados como proteções.
- [ ] Logs e painel necessários para supervisão estão habilitados.
- [ ] Commit exato do EA compilado foi registrado.
- [ ] Arquivo `.set` usado no live foi versionado e associado ao commit.

---

# SESSÃO T — REGRA DE GOVERNANÇA

Este documento deve evoluir junto com o código.

**Qualquer novo input exige simultaneamente:**

1. declaração na configuração;
2. consumidor de código identificado;
3. teste de efeito;
4. documentação de interação;
5. classificação de risco;
6. atualização deste manual;
7. commit do código + documentação.

**Critério de aceitação:** não basta o input compilar. Precisamos demonstrar que alterar seu valor muda exatamente o comportamento documentado — e que não existe outra regra anulando ou sobrescrevendo seu efeito.

---

## Referências de implementação auditadas

- `EA/EAGOLD.mq4`
- `Core/EAGOLD_Config.mqh`
- `Core/EAGOLD_Orders.mqh`
- `Core/EAGOLD_Execution.mqh`
- `Core/EAGOLD_Persistence.mqh`
- `Engines/EAGOLD_R1_Admission.mqh`
- `Engines/EAGOLD_Lifecycle.mqh`
- `Engines/EAGOLD_Recovery.mqh`
- `Engines/EAGOLD_R9.mqh`
- `Engines/EAGOLD_R10.mqh`
- `Engines/EAGOLD_BRX.mqh`
- `Engines/EAGOLD_R13_Satellite.mqh`
- `UI/EAGOLD_ModularizationPanel.mqh`
- `UI/EAGOLD_ChartBasketGuides.mqh`
- `UI/EAGOLD_RealizationCascade.mqh`
- `Engines/R10/R10_Core.mqh`

**Observação:** `Engines/R10/R10_Core.mqh` contém uma implementação formal de R10 baseada em `EAGOLD_Context`, mas o `EA/EAGOLD.mq4` atual inclui/executa `Engines/EAGOLD_R10.mqh`. Portanto, durante a auditoria, não se deve assumir que uma variável usada apenas no núcleo formal está atuando no caminho de execução atual.
