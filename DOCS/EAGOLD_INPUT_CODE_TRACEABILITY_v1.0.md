# EAGOLD — INPUT → CODE TRACEABILITY MATRIX v1.0

## 1. Finalidade

Este documento é a segunda camada da calibração pré-LIVE. A matriz de testes responde **o que testar**; esta matriz responde **onde o input entra no código, qual engine o consome, qual decisão ele altera e quais outras Rules podem ser afetadas**.

A fonte primária é o código atual da branch `main` de `sezinando/modularizedEA`, EAGOLD `v0.106`. A análise abaixo não transforma a existência de um `extern` em prova de funcionamento: somente referências efetivamente observadas no código são tratadas como operacionais.

## 2. Legenda

- **ATIVO:** há caminho de execução identificado.
- **CONDICIONAL:** há caminho de execução, mas depende de outro gate/modo/estado.
- **UI:** altera somente apresentação/telemetria.
- **INATIVO:** declarado, mas sem efeito identificado no caminho operacional atual.
- **PARCIAL:** existe referência ou efeito, porém o contrato aparente do nome/input é mais amplo que o comportamento efetivamente implementado.

## 3. Núcleo — identidade, dinheiro e execução

| Input | Classificação | Código consumidor | Efeito direto | Interações críticas |
|---|---|---|---|---|
| `MagicNumber` | ATIVO / CRITICAL | `Core/EAGOLD_Orders.mqh`, `Core/EAGOLD_Execution.mqh`, `StateKey()` | Define ownership Master por símbolo + Magic; `-1` significa todos os orders do símbolo, exceto R13 | Afeta contagem, exposição, P/L, R9/R10/Recovery/BRX e identificação da persistência |
| `Lot` | ATIVO / CRITICAL | `NormalizeLot()`, Lifecycle, Recovery, R9/R13 | Lote mínimo operacional e lote das sementes/restarts | Interage com `MaxOpenLot`, broker min lot, R11 e progressão |
| `Multiplier` | ATIVO / CRITICAL | `NextRecoveryLot()` | Multiplica o lote anterior na próxima recuperação | Atua junto com `LotIncrement`, `MaxOpenLot` e R11 |
| `DigitsLots` | ATIVO | `NormalizeLot()` e formatação | Normalização das casas decimais de lote | Pode alterar o resultado efetivo de progressões pequenas |
| `LotIncrement` | ATIVO / CRITICAL | `NextRecoveryLot()` | Soma incremento à progressão: `previousLot × Multiplier + LotIncrement` | Pode acelerar crescimento mesmo com multiplicador baixo |
| `MaxOpenLot` | ATIVO / CRITICAL | `NormalizeLot()` | Limita o lote individual | Não limita o total da cesta; R9/R11 continuam podendo atuar sobre exposição total |
| `TakeProfit` | CONDICIONAL | Lifecycle `Buy/SellSingleTakeProfit`, fallback legacy | Fecha single position quando P/L direcional atinge o valor; também participa do modo legacy de cesta | BRX pode substituir a lógica legacy; R10.2 pode bloquear fechamento |
| `SellProfit` | INATIVO | Nenhuma referência operacional identificada | Sem efeito na execução modular atual | Não deve ser usado como controle de SELL sem implementação adicional |
| `BasketLoss` | INATIVO | Nenhuma referência operacional identificada | Não funciona como limite de perda da cesta | Não confundir com R10.2/R11 |
| `SpreadLimit` | UI/LEGACY | Sem gate de execução Master identificado | Não bloqueia novas ordens Master | R13 possui `R13MaxSpread` independente |
| `WaitSeconds` | INATIVO | Nenhuma referência operacional identificada | Sem efeito | — |

## 4. R1 / R1.1 — primeira admissão

| Input | Classificação | Código consumidor | Efeito direto | Interações |
|---|---|---|---|---|
| `FirstStep` | ATIVO / CRITICAL | Lifecycle `CreateFirstOrdersIfFlat`, `TrailAllStopOrders` | Distância das sementes R1 e referência de trailing R1 | Afeta preço inicial, stop level e comportamento posterior de pendências |
| `EnableR1AdmissionGate` | CONDICIONAL / HIGH | `R1AdmissionAllowed()` | Liga/desliga o conjunto de guards | Se OFF, os guards individuais não são avaliados |
| `EnableR1BrokerGuard` | CONDICIONAL / HIGH | `R1AdmissionAllowed()` → `R1BrokerGuard()` | Verifica stop level + `R1BrokerSafetyBufferPoints` | Depende do gate mestre R1 |
| `EnableR1LotGuard` | CONDICIONAL / HIGH | `R1ValidateLot()` | Valida min/max/step do broker | Depende do gate mestre |
| `EnableR1MarginGuard` | CONDICIONAL / HIGH | `R1MarginGuard()` | Verifica margem após ordem e `R1MinFreeMarginAfterOrder` | Depende do gate mestre |
| `EnableR1TradePermissionGuard` | CONDICIONAL / HIGH | `R1TradePermissionGuard()` | Verifica `MODE_TRADEALLOWED` | Depende do gate mestre |
| `R1BrokerSafetyBufferPoints` | CONDICIONAL | `R1BrokerGuard()` | Acrescenta margem ao stop level exigido | Quanto maior, mais restritiva a admissão |
| `R1MinFreeMarginAfterOrder` | CONDICIONAL | `R1MarginGuard()` | Exige margem livre residual mínima | Quanto maior, mais restritiva a admissão |
| `EnableR1DecisionLog` | UI/TELEMETRIA | `R1Decision()` | Controla `Print()` das decisões R1 | Não altera a decisão |

## 5. Lifecycle — R4/R5/R7

| Input | Classificação | Código consumidor | Efeito direto | Interações |
|---|---|---|---|---|
| `MiniGrid1` | ATIVO | Lifecycle | Distância do próximo BUY R4 e reset/trailing dessa família | Single BUY TP → R4 BUY NEXT |
| `SmartGrid1` | ATIVO | Recovery | Filtro de deslocamento adverso antes de criar recovery | Atua antes de `RecoveryStepForLevel()` e R11 |
| `RecoveryMinDistance` | ATIVO / CRITICAL | Recovery + trailing | Base da distância de recovery e reset de pendências | Multiplicada por R11 step multiplier |
| `MiniGrid2` | ATIVO | Lifecycle | Distância do próximo SELL R4 | Single SELL TP → R4 SELL NEXT |
| `SmartGrid2` | INATIVO | Nenhuma referência operacional identificada no caminho atual | Sem efeito | Não confundir com `SmartGrid1` usado pela Recovery |
| `PendingStepTrail` | ATIVO | `TrailAllStopOrders()` | Passo do trailing global de pendências | Interage com `FirstStep`, Recovery, MiniGrid e R7 |
| `BasketRestartStep` | ATIVO | `EnsureDirectionMachineAlive()`, `RestartEmptyBasket()`, trailing R7 | Distância do restart R7 | Pode recriar máquina direcional após fechamento |
| `MaxTrades` | INATIVO | Nenhuma referência operacional identificada | Não limita `OrdersTotal()`/cesta no caminho atual | Não deve ser considerado hard cap |
| `EnableCloseBy` | INATIVO | Nenhuma referência operacional identificada | Não habilita `OrderCloseBy()` no caminho atual | Sem efeito |
| `BuyProgressionTolerance` | INATIVO | Nenhuma referência operacional identificada | Sem efeito | — |

## 6. Global Stop Trail

| Input | Classificação | Código consumidor | Efeito direto | Interações |
|---|---|---|---|---|
| `EnableGlobalStopTrail` | ATIVO | `TrailAllStopOrders()` | Habilita trailing de pendências | Afeta R1, Recovery, R4 e R7 |
| `GlobalStopTrailCooldownSeconds` | ATIVO | `TrailAllStopOrders()` | Impõe intervalo entre modificações por ticket | Reduz frequência de `OrderModify()` |
| `GlobalStopTrailMinStepPoints` | ATIVO | `TrailAllStopOrders()` | Exige deslocamento mínimo do mercado antes de modificar | Reduz churn de modificações |

## 7. BRX — realização

| Input | Classificação | Código consumidor | Efeito direto | Interações |
|---|---|---|---|---|
| `EnableBasketRealization` | ATIVO / CRITICAL | `BRX_Run()`, Lifecycle | Liga BRX e substitui o fallback legacy quando habilitado | Interage diretamente com R10.2 e R10 |
| `BRXRealizationMode` | ATIVO / CRITICAL | `BRX_Run()`, Lifecycle | `0` legacy, `1` directional, `2` bidirectional, `3` hybrid | Determina qual caminho de realização pode ocorrer |
| `BRXDirectionalMinProfit` | ATIVO | `BRX_DirectionalFloor()` | Piso monetário direcional | Soma `BRXRealizationSafetyBuffer` para autorização |
| `BRXBidirectionalMinProfit` | ATIVO | `BRX_BidirectionalFloor()` | Piso monetário bidirecional | Soma buffer de segurança |
| `BRXRealizationSafetyBuffer` | ATIVO / HIGH | `BRX_RealizationBuffer()` | Cushion adicional antes da autorização | Não é garantia matemática contra slippage; eleva o piso operacional |
| `BRXRequireWeightedBE` | CONDICIONAL | `BRX_BEDirectionValid()` / Lifecycle | Exige condição de weighted BE quando habilitado | `BRXWeightedBEBufferPoints` define margem |
| `BRXWeightedBEBufferPoints` | CONDICIONAL | `BRX_BEDirectionValid()` | Distância adicional sobre weighted BE | Só tem efeito quando o requisito BE e buffer > 0 participam da condição |

**Interação crítica:** R10 pode realizar partes da cesta antes de BRX. Portanto, P/L realizado e composição remanescente devem ser observados conjuntamente durante a validação de fechamento.

## 8. R9 — hedge

| Input | Classificação | Código consumidor | Efeito direto | Interações |
|---|---|---|---|---|
| `EnableR9Hedge` | ATIVO / HIGH | `Rule9DetectActivatedOrders()` / `R9HedgeFromActivatedTicket()` | Habilita hedge ao ativar posição nova | Altera exposição e composição que serão lidas por R10/BRX |
| `R9ExposureTriggerLots` | ATIVO | `R9GetNewExposureState()` | Exposição líquida mínima para hedge | Depende da diferença entre lots BUY/SELL |
| `R9TriggerLotMinimum` | INATIVO | Nenhuma referência operacional identificada | Sem efeito no caminho atual | Não usar como proteção sem implementação |
| `R9HedgeFraction` | ATIVO | `R9HedgeFromActivatedTicket()` | Fração do lote gatilho usada no hedge | Limitada também por `R9BalanceCap` |
| `R9BalanceCap` | ATIVO | `R9HedgeFromActivatedTicket()` | Limita hedge por fração da exposição líquida | Pode tornar `R9HedgeFraction` efetivamente menor |

## 9. R10 — redução de exposição

| Input | Classificação | Código consumidor | Efeito direto | Interações |
|---|---|---|---|---|
| `EnableR10Reduce` | ATIVO / CRITICAL | `Rule10Reduce()` | Liga redução de exposição | Pode reduzir posições antes de BRX |
| `R10MinExposureLots` | ATIVO | `Rule10Reduce()` | Exposição mínima para redução | Define quando redução normal pode ocorrer |
| `EnableR10PairReduction` | ATIVO | `Rule10ProfitFundedPartial()` | Liga redução financiada por par lucro/perda | Executada antes da redução normal |
| `R10PairMinProfit` | ATIVO | `Rule10ProfitFundedPartial()` | Lucro líquido esperado mínimo do par | Filtra candidatos |
| `R10PairMaxLots` | ATIVO | `Rule10ProfitFundedPartial()` | Limita volume do par | Interage com lotes disponíveis |
| `R10PairCooldownSeconds` | ATIVO | `Rule10ProfitFundedPartial()` | Cooldown entre ações de pair reduction | Reduz frequência de reduções |
| `EnableR10VisualMarker` | UI | `CreateR10VisualMarker()` | Liga marcador RD | Sem efeito financeiro |
| `R10MarkerFont` | INATIVO/PARCIAL | `CreateR10VisualMarker()` | Código usa `"Segoe UI Semibold"` diretamente | Alteração do input não altera a fonte atual |
| `R10MarkerFontSize` | UI | `CreateR10VisualMarker()` | Tamanho do marcador | Somente visual |
| `R10BuyMarkerColor` | UI | `CreateR10VisualMarker()` | Cor do marcador BUY | Somente visual |
| `R10SellMarkerColor` | UI | `CreateR10VisualMarker()` | Cor do marcador SELL | Somente visual |
| `R10MarkerOffsetPoints` | UI | `CreateR10VisualMarker()` | Offset vertical | Somente visual |

## 10. R10.2 — recovery realization

| Input | Classificação | Código consumidor | Efeito direto | Interações |
|---|---|---|---|---|
| `EnableR10RecoveryRealization` | CONDICIONAL / CRITICAL | `R10RecoveryUpdateState()`, `R10RecoveryAllowBasketClose()` | Ativa ciclo de dívida/equity e bloqueio de fechamento | Consultado por Lifecycle e BRX |
| `R10RecoveryMinDebt` | CONDICIONAL | `R10RecoveryAllowBasketClose()` | Dívida mínima antes de aplicar hold | Abaixo dela, fechamento é liberado |
| `R10RecoveryProfitTarget` | CONDICIONAL | `R10RecoveryTarget()` | Superávit exigido após dívida | Pode ser acrescido de percentual |
| `R10RecoveryDebtTargetPercent` | CONDICIONAL | `R10RecoveryTarget()` | Percentual adicional sobre dívida histórica | Aumenta alvo quando > 0 |
| `R10RecoveryRequireDebtRepaid` | CONDICIONAL | `R10RecoveryAllowBasketClose()` | Exige remaining debt praticamente zero | Pode bloquear BRX/Lifecycle mesmo com P/L atual positivo |

**Observação estrutural:** `R10RecoveryDebt` usa a diferença entre equity inicial e pior equity do ciclo; `R10RecoveryRemainingDebt` usa equity atual contra equity inicial. Não tratar `MaxDrawdown` do R13 como equivalente a este mecanismo.

## 11. R11 — recovery distance + exposure governor

| Input | Classificação | Código consumidor | Efeito direto | Interações |
|---|---|---|---|---|
| `EnableRecoveryStepMultiplier` | ATIVO | `RecoveryStepForLevel()` | Habilita crescimento da distância por nível | Atua sobre `RecoveryMinDistance`, não sobre lote |
| `RecoveryStepMultiplier` | ATIVO | `RecoveryStepForLevel()` | Multiplica distância a cada nível | Limitado por `RecoveryStepMax` |
| `RecoveryStepMax` | ATIVO | `RecoveryStepForLevel()` | Teto da distância dinâmica | Impede crescimento indefinido |
| `EnableR11ExposureGovernor` | ATIVO / HIGH | `R11RecoveryLotFactor()` / `R11RecoveryAdditionAllowed()` | Liga taper/block de novas recuperações | Não remove nem reduz posições existentes |
| `R11TaperStartGrossExposureLots` | ATIVO | `R11RecoveryLotFactor()` | Início da taper por exposição bruta | Entre taper e block, reduz fator |
| `R11BlockGrossExposureLots` | ATIVO | `R11RecoveryLotFactor()` | Bloqueio duro de nova recovery | Exposição existente permanece |
| `R11MinNetToGrossRatio` | ATIVO | `R11RecoveryLotFactor()` | Pode bloquear novas recovery na região taper quando ratio é baixo | Mede desequilíbrio estrutural |
| `R11MinRecoveryLotFactor` | ATIVO | `R11RecoveryLotFactor()` | Piso do fator de redução de lote | Ainda pode ser rejeitado se normalizado abaixo de `Lot` |

**Interação crítica:** R11 possui dois eixos independentes: multiplicador/teto de **distância** e governor de **lote/exposição**. Não confundir `RecoveryStepMultiplier` com `Multiplier`.

## 12. R13 — satellite

| Input | Classificação | Código consumidor | Efeito direto | Interações |
|---|---|---|---|---|
| `EnableR13` | CONDICIONAL | `R13Observe()` | Habilita R13 | Necessário para estado enabled |
| `EnableR13AutoActivation` | CONDICIONAL | `R13Observe()` | Participa de `tradingEnabled` | Exige também `EnableR13Trading` e `EnableR13` |
| `EnableR13Trading` | CONDICIONAL | `R13TryOpen()`/observer | Permite entrada R13 | Ainda depende de autoactivation no estado de trading |
| `R13ProfitTarget` | ATIVO | `R13ManageOpenPositions()` | Fecha Satellite ao atingir lucro | Lucro realizado pode virar capital de recuperação |
| `R13EntryCooldownSeconds` | ATIVO | `R13TryOpen()` | Intervalo entre entradas | Evita reentrada imediata |
| `R13CloseWhenMasterFlat` | ATIVO | `R13ManageOpenPositions()` | Fecha R13 quando Master fica flat | Pode gerar capital de recuperação |
| `EnableR13MasterAdjustment` | ATIVO | `R13TryFundMasterAdjustment()` | Permite financiar ajuste R10 pelo capital R13 | Liga R13 diretamente ao R10 |
| `R13MasterAdjustmentMaxLots` | ATIVO | `R13TryFundMasterAdjustment()` | Teto de lotes do ajuste financiado | Limita intervenção no Master |
| `R13MagicNumber` | ATIVO / CRITICAL | `IsR13Order()`, `IsR13OwnershipConfigurationValid()`, `R13SendMarket()` | Namespace exclusivo R13 | Se colidir com Magic Master, configuração é inválida |
| `R13OrderComment` | ATIVO | `R13SendMarket()` | Comentário das ordens R13 | Identificação observacional |
| `R13MaxLots` | ATIVO | `R13TryOpen()` | Limita espaço total de lotes R13 | Não substitui limite do broker |
| `R13MaxPositions` | PARCIAL | R13 observer/controle de estado | Limite configurado é observado no caminho de estado, mas a rotina de entrada atual só abre quando `R13CountOwnPositions()>0` é falso | `MaxPositions=3` não significa automaticamente três posições simultâneas |
| `R13MaxDrawdown` | ATIVO | `R13RiskGate()` | Bloqueia entrada quando P/L flutuante R13 <= negativo do limite | É perda flutuante própria, não histórico de equity drawdown |
| `R13MaxDailyLoss` | ATIVO | `R13RiskGate()` | Bloqueia entrada quando resultado R13 fechado do dia atinge limite | Dia baseado no horário do servidor |
| `R13MaxSpread` | ATIVO | `R13RiskGate()` | Gate de spread para entrada R13 | Independente de `SpreadLimit` Master |
| `R13StartHour` | ATIVO | `R13WithinSchedule()` | Início da janela | Horário servidor |
| `R13EndHour` | ATIVO | `R13WithinSchedule()` | Fim da janela | Suporta janela overnight |
| `EnableR13DirectionalComplementarity` | ATIVO | `R13ManageOpenPositions()` / elegibilidade | Mantém Satellite complementar ao Master | Pode fechar Satellite em mudança de direção |
| `R13MinDirectionalImbalance` | ATIVO | `R13TryOpen()` e gestão | Mínimo de exposição Master para R13 | Também participa da condição de ajuste/flat |
| `R13RecoveryCapitalFraction` | ATIVO | `R13AddRecoveryCapital()` | Percentual do lucro R13 que vira capital disponível | Alimenta R10 average adjustment |

## 13. Persistência

| Input | Classificação | Código consumidor | Efeito direto | Interações |
|---|---|---|---|---|
| `PersistenceWorstEquityStep` | ATIVO / LIVE | `PersistStrategicState()` | Define quanto a pior equity deve mudar para gerar checkpoint significativo | Persistência é desativada no Strategy Tester |

A política atual também persiste estado estratégico de R10.2/R9 e extremos do painel em terminal Global Variables no LIVE. No Tester, o código deliberadamente não lê nem grava essas variáveis. fileciteturn887file0

## 14. UI / observabilidade

| Input | Classificação | Efeito |
|---|---|---|
| `EnableModularizationPanel` | UI | Liga/desliga painel |
| `EnableModularizationDebug` | UI | Altera modo/conteúdo de debug |
| `EnableChartBasketGuides` | UI | Liga/desliga guias de cesta |
| `ChartBasketGuideOffsetBars` | UI | Offset horizontal das guias |
| `PanelBackgroundX` | INATIVO | Geometria atual não consome este input |
| `PanelBackgroundY` | INATIVO | Geometria atual não consome este input |
| `PanelBackgroundHeight` | INATIVO/PARCIAL | Geometria atual usa lógica própria; confirmar antes de tratar como configurável |
| `PanelBottomY` | INATIVO | Não consumido como layout atual |
| `PanelBottomX1` | INATIVO | Não consumido como layout atual |
| `PanelBottomX2` | INATIVO | Não consumido como layout atual |
| `PanelBottomX3` | INATIVO | Não consumido como layout atual |
| `PanelBottomX4` | INATIVO | Não consumido como layout atual |
| `PanelBackgroundWidth` | ATIVO UI | Largura do painel |
| `EnableEngineActionMarkers` | UI | Liga/desliga marcadores de ações |
| `EngineActionMarkerFont` | INATIVO | A implementação atual não usa este input para criação do marcador |
| `EngineActionMarkerFontSize` | INATIVO | Marcador atual é `OBJ_ARROW`, não texto |
| `EngineActionMarkerTextColor` | INATIVO | Marcador atual usa `CascadeEngineColor()` |
| `EngineActionMarkerBackgroundColor` | INATIVO | Não usado pelo `OBJ_ARROW` atual |
| `EngineActionMarkerOffsetPips` | INATIVO | Offset configurado não entra no marcador atual |
| `EngineActionMarkerStackStepPips` | INATIVO | Stack textual não é aplicado no marcador atual |
| `R10MarkerFont` | INATIVO/PARCIAL | Fonte está hardcoded em `CreateR10VisualMarker()` |
| `R10MarkerFontSize` | UI | Tamanho do marcador R10 |
| `R10BuyMarkerColor` | UI | Cor BUY |
| `R10SellMarkerColor` | UI | Cor SELL |
| `R10MarkerOffsetPoints` | UI | Offset vertical |

## 15. Variáveis internas relevantes — não são inputs

| Variável | Função | Importância |
|---|---|---|
| `EngineActionMarkerOffsetPoints` | Declarada no EA | Não é `extern` e não deve ser confundida com input operacional |
| `g_r10RecoveryStartEquity` | R10.2 | Base do ciclo de recuperação |
| `g_r10RecoveryWorstEquity` | R10.2 | Pior equity observada no ciclo |
| `g_r10RecoveryCycleActive` | R10.2 | Estado do ciclo |
| `g_r10LastAction` | R10 | Cooldown/estado de ação |
| `g_r9HedgeActive` | R9 | Estado operacional do hedge |
| `g_r9ProcessedTickets[]` | R9 | Evita processar o mesmo ticket repetidamente |

## 16. Achados críticos para a calibração

### C1 — `MagicNumber=-1` é abrangente, mas limitado ao símbolo
Não significa “toda a conta”. A propriedade de ownership é símbolo + Magic; R13 é explicitamente excluído do Master. fileciteturn877file0

### C2 — `Multiplier` e `RecoveryStepMultiplier` são controles diferentes
`Multiplier` altera **lote** de recovery; `RecoveryStepMultiplier` altera **distância** de recovery. Misturá-los na calibração produzirá conclusões erradas. fileciteturn880file0

### C3 — R11 não desfaz exposição existente
O governor atua na adição de novas recuperações. R9/R10 continuam responsáveis pelo tratamento das posições existentes. fileciteturn880file0

### C4 — BRX e R10 precisam ser testados como sistema
A sequência em `BuyMachine()`/`SellMachine()` permite que R10 seja acionado quando o target direcional é alcançado e, posteriormente, que BRX/Lifecycle continue a operar. Portanto, não validar BRX isoladamente. fileciteturn883file0

### C5 — `R10RecoveryAllowBasketClose()` é uma trava de fechamento, não um freio universal de redução
Ela é consultada pelo fechamento de cesta/single e pelo BRX. A existência da trava não significa que toda redução R10 ficará bloqueada. fileciteturn880file0turn882file0

### C6 — R1.1 é atômico no primeiro ciclo quando habilitado
`CreateFirstOrdersIfFlat()` valida BUY e SELL antes de enviar as sementes. Se um dos lados falha, o primeiro ciclo é bloqueado. fileciteturn883file0turn884file0

### C7 — A expiração bloqueia novas ordens no Core Execution
`SendPending()` e `SendMarket()` verificam `EAGOLD_TradingAllowed()`. A data contratual atual é 31/12/2026 00:00 no horário do broker/servidor. fileciteturn874file0turn878file0

### C8 — Há inputs que não devem ser usados como controles LIVE
Pelo código atual, `SellProfit`, `BasketLoss`, `WaitSeconds`, `SmartGrid2`, `MaxTrades`, `EnableCloseBy`, `BuyProgressionTolerance`, `R9TriggerLotMinimum` e vários parâmetros visuais não têm efeito operacional correspondente. Esses itens precisam ser explicitamente tratados como INATIVOS durante a calibração. fileciteturn874file0

## 17. Regra de fechamento da auditoria estrutural

Um input somente poderá receber o selo **CODE-VERIFIED** quando:

1. sua declaração for identificada;
2. sua referência no código for localizada;
3. o caminho de execução estiver identificado;
4. a condição de entrada desse caminho estiver documentada;
5. o efeito direto estiver descrito;
6. as interações com outras Rules estiverem registradas;
7. o teste comportamental correspondente na `EAGOLD_INPUT_TEST_MATRIX_v1.0.md` estiver executado.

**CODE-VERIFIED não significa LIVE-VALIDATED.** O primeiro é prova estrutural; o segundo exige prova comportamental em cenário controlado.
