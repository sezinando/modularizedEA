# EAGOLD — INPUT TEST MATRIX v1.0

## 1. Objetivo

Matriz operacional para validação controlada dos inputs do EAGOLD antes da entrada em operação real. O objetivo é provar, por evidência observável, que cada input classificado como ativo ou condicional altera o comportamento previsto, que inputs inativos não são tratados como controles operacionais e que interações entre engines não introduzem efeitos não documentados.

**Baseline:** EAGOLD v0.106 / `sezinando/modularizedEA` / branch `main`.

## 2. Regra de execução

Cada teste deve alterar **uma variável ou uma condição por vez**, mantendo o restante do `.set` constante. O resultado deve ser registrado com commit do EA, hash do `.set`, cenário, comportamento esperado e comportamento observado.

Não considerar um teste aprovado apenas porque o EA compilou ou porque uma ordem foi aberta. A aprovação exige evidência do efeito específico do input.

## 3. Critérios de status

- **PASS:** comportamento observado corresponde ao esperado.
- **FAIL:** comportamento observado contradiz o contrato do input.
- **BLOCKED:** cenário não pôde ser reproduzido ou depende de condição externa não disponível.
- **NOT RUN:** teste ainda não executado.
- **NOT APPLICABLE:** teste não aplicável à configuração em avaliação.

## 4. Matriz de testes

### A — Identidade, lote e progressão

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T01 | `MagicNumber` | Comparar `-1` com magic específico em conta/símbolo contendo outras ordens | `-1` inclui todas as ordens EAGOLD do símbolo; magic específico restringe ao magic informado; R13 permanece excluído |
| T02 | `Lot` | Alterar lote inicial | Primeira ordem usa o novo lote normalizado |
| T03 | `Multiplier` | Alterar multiplicador e provocar recuperação | Próximo lote segue `lote anterior × Multiplier + LotIncrement`, sujeito à normalização/cap |
| T04 | `DigitsLots` | Alterar casas de lote | Normalização/apresentação do lote respeita a precisão configurada |
| T05 | `LotIncrement` | Alterar incremento | Progressão acrescenta o novo incremento |
| T06 | `MaxOpenLot` | Tentar progressão acima do limite | Lote individual não ultrapassa `MaxOpenLot` |

### B — R1 / R1.1 — admissão e primeira ordem

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T07 | `FirstStep` | Alterar distância da primeira ordem pendente | Distância da primeira ordem e referência R1 acompanham o novo valor |
| T08 | `EnableR1AdmissionGate` | ON/OFF em cenário elegível | Gate só bloqueia quando habilitado |
| T09 | `EnableR1BrokerGuard` | Criar cenário de restrição do broker | Guarda de broker impede admissão quando habilitada e condição é violada |
| T10 | `EnableR1LotGuard` | Criar lote inválido/excessivo | Guarda de lote bloqueia admissão quando habilitada |
| T11 | `EnableR1MarginGuard` | Reduzir margem livre disponível | Guarda de margem bloqueia quando habilitada e condição é violada |
| T12 | `EnableR1TradePermissionGuard` | Desabilitar permissão de trade | Guarda detecta ausência de permissão e impede admissão quando habilitada |
| T13 | `R1BrokerSafetyBufferPoints` / `R1MinFreeMarginAfterOrder` | Variar buffers | Aumentar o buffer torna a admissão mais restritiva, mantendo demais condições constantes |

### C — Lifecycle, grids e pendências

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T14 | `MiniGrid1` | Alterar espaçamento do lado BUY | Regras BUY que usam MiniGrid1 alteram sua distância |
| T15 | `SmartGrid1` | Variar filtro de deslocamento adverso | Critério de recuperação BUY/SELL dependente de SmartGrid1 muda conforme configuração |
| T16 | `RecoveryMinDistance` | Alterar distância base de recovery | Distância base e reset/trailing de recovery acompanham novo valor |
| T17 | `MiniGrid2` | Alterar espaçamento do lado SELL | Regras SELL que usam MiniGrid2 alteram sua distância |
| T18 | `SmartGrid2` | Alterar valor | Confirmar ausência de efeito na execução modular atual; registrar como INATIVO se permanecer sem referência |
| T19 | `PendingStepTrail` | Alterar trailing | Pendências existentes acompanham o novo passo de trailing |
| T20 | `BasketRestartStep` | Alterar restart/trailing da cesta | Lógica de restart/trailing usa o novo valor |

### D — Stop global

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T21 | `EnableGlobalStopTrail` | ON/OFF | Stop trail global é executado somente quando habilitado |
| T22 | `GlobalStopTrailCooldownSeconds` | Variar cooldown | Frequência mínima de atualização respeita cooldown |
| T23 | `GlobalStopTrailMinStepPoints` | Variar passo mínimo | Stop só é atualizado quando o deslocamento mínimo configurado é atingido |

### E — BRX — realização de cesta

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T24 | `EnableBasketRealization` | ON/OFF | BRX só atua quando habilitado |
| T25 | `BRXRealizationMode=0` | Cenário de fechamento legacy | Caminho legacy é usado |
| T26 | `BRXRealizationMode=1` | Cesta direcional lucrativa | Fechamento direcional respeita `BRXDirectionalMinProfit` |
| T27 | `BRXRealizationMode=2` | Cesta bidirecional lucrativa | Fechamento bidirecional respeita `BRXBidirectionalMinProfit` |
| T28 | `BRXRealizationMode=3` | Cesta híbrida | Hybrid combina os critérios definidos para o modo 3 |
| T29 | `BRXRealizationSafetyBuffer` | Aumentar buffer | Autorização de realização fica mais conservadora |
| T30 | `BRXRequireWeightedBE` / `BRXWeightedBEBufferPoints` | ON e variar buffer | Quando habilitado, realização exige weighted BE conforme buffer configurado |

### F — R9 — hedge

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T31 | `EnableR9Hedge` | ON/OFF | Hedge R9 é habilitado/desabilitado |
| T32 | `R9ExposureTriggerLots` | Alterar gatilho | Hedge só é elegível a partir da exposição configurada |
| T33 | `R9TriggerLotMinimum` | Alterar valor | Confirmar ausência de efeito na implementação atual; registrar como INATIVO se permanecer sem referência |
| T34 | `R9HedgeFraction` | Alterar fração | Lote de hedge acompanha a fração configurada, limitado pelo cap |
| T35 | `R9BalanceCap` | Alterar cap | Hedge efetivo é limitado pelo percentual de exposição configurado |

### G — R10 — redução de exposição

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T36 | `EnableR10Reduce` | ON/OFF | Motor R10 de redução é habilitado/desabilitado |
| T37 | `R10MinExposureLots` | Variar mínimo | Redução respeita exposição mínima configurada |
| T38 | `EnableR10PairReduction` | ON/OFF | Pair reduction é habilitada/desabilitada |
| T39 | `R10PairMinProfit` | Variar lucro mínimo | Par só é candidato quando lucro esperado atinge o mínimo |
| T40 | `R10PairMaxLots` | Variar limite | Tamanho do par candidato respeita o limite |
| T41 | `R10PairCooldownSeconds` | Variar cooldown | Pair reduction respeita intervalo mínimo entre ações |
| T42 | `R10Marker*` | Alterar tamanho/cor/offset/font | Somente parâmetros efetivamente consumidos alteram marcador; `R10MarkerFont` deve ser confirmado contra hardcode |

### H — R10.2 — recuperação da realização

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T43 | `EnableR10RecoveryRealization` | ON/OFF | Proteção de realização R10.2 atua somente quando habilitada |
| T44 | `R10RecoveryMinDebt` | Variar dívida mínima | Regra só entra na condição configurada de dívida |
| T45 | `R10RecoveryProfitTarget` | Variar alvo | Autorização depende do alvo configurado |
| T46 | `R10RecoveryDebtTargetPercent` | Variar percentual | Critério de dívida recuperada acompanha percentual |
| T47 | `R10RecoveryRequireDebtRepaid` | ON/OFF | Exigência de quitação da dívida altera autorização de fechamento |

### I — R11 — progressão de distância e governor de exposição

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T48 | `EnableRecoveryStepMultiplier` | ON/OFF | Multiplicador de distância é aplicado somente quando habilitado |
| T49 | `RecoveryStepMultiplier` | Variar multiplicador | Distância de recovery cresce por nível segundo o multiplicador |
| T50 | `RecoveryStepMax` | Variar teto | Distância nunca ultrapassa o teto configurado |
| T51 | `EnableR11ExposureGovernor` | ON/OFF | Governor bloqueia/modula novas recuperações somente quando habilitado |
| T52 | `R11TaperStartGrossExposureLots` | Variar início da taper | Início da redução de fator acompanha exposição configurada |
| T53 | `R11BlockGrossExposureLots` | Variar bloqueio | Novas recuperações são bloqueadas a partir do limite configurado |
| T54 | `R11MinNetToGrossRatio` | Variar razão mínima | Governor fica mais/menos restritivo conforme razão mínima |
| T55 | `R11MinRecoveryLotFactor` | Variar fator mínimo | Lote de recovery é limitado pelo fator mínimo configurado |

### J — R13 — satellite / capital de recuperação

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T56 | `EnableR13` | ON/OFF | R13 fica globalmente habilitado/desabilitado |
| T57 | `EnableR13AutoActivation` | ON/OFF | Autoativação respeita o controle |
| T58 | `EnableR13Trading` | ON/OFF | Entrada R13 respeita o controle de trading |
| T59 | `R13ProfitTarget` | Variar alvo | Fechamento R13 usa o novo alvo |
| T60 | `R13EntryCooldownSeconds` | Variar cooldown | Entradas R13 respeitam cooldown |
| T61 | `R13CloseWhenMasterFlat` | ON/OFF | R13 fecha conforme estado flat do Master quando habilitado |
| T62 | `R13MasterAdjustmentMaxLots` | Variar limite | Ajuste de Master pelo R13 respeita teto |
| T63 | `R13MagicNumber` / `R13OrderComment` | Alterar identificação | Ordens R13 usam identificação configurada e permanecem fora das métricas Master |
| T64 | `R13MaxLots` / `R13MaxPositions` | Variar limites | Limites de lote/posição são respeitados; confirmar que `R13MaxPositions=3` não implica três posições simultâneas se o fluxo atual abre apenas quando não há R13 |
| T65 | `R13MaxDrawdown` / `R13MaxDailyLoss` | Criar perda flutuante e perda fechada diária | Drawdown usa P/L flutuante próprio; daily loss usa resultado fechado do dia do servidor |
| T66 | `R13MaxSpread` / horário | Variar spread e janela | Entrada é bloqueada por spread ou fora da janela configurada |
| T67 | `EnableR13DirectionalComplementarity`, `R13MinDirectionalImbalance`, `R13RecoveryCapitalFraction` | Variar critérios | Complementaridade, desequilíbrio mínimo e fração de capital alteram elegibilidade/ajuste conforme contrato |

### K — Persistência

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T68 | `PersistenceWorstEquityStep` | Live: variar passo e reiniciar EA | Checkpoints de pior equity respeitam passo; tester não deve gravar persistência |

### L — UI / observabilidade

| ID | Input/controle | Teste | Esperado |
|---|---|---|---|
| T69 | `EnableModularizationPanel` | ON/OFF | Painel aparece/desaparece |
| T70 | `EnableModularizationDebug` | ON/OFF | Conteúdo/altura de debug muda |
| T71 | `EnableChartBasketGuides` | ON/OFF | Guias de cesta aparecem/desaparecem |
| T72 | `ChartBasketGuideOffsetBars` | Variar offset | Posição horizontal das guias acompanha offset |
| T73 | `EnableEngineActionMarkers` | ON/OFF | Marcadores de ação aparecem/desaparecem |
| T74 | `EngineActionMarkerFont`, `FontSize`, cores, offsets | Alterar individualmente | Confirmar quais parâmetros ainda são consumidos; parâmetros não consumidos devem permanecer explicitamente classificados como INATIVOS |

## 5. Matriz de risco de calibração

| Classe | Risco | Conduta |
|---|---|---|
| CRITICAL | Pode alterar entrada, lote, recuperação, hedge ou realização | Testar isoladamente + cenário adverso + evidência antes do LIVE |
| HIGH | Pode alterar frequência/condição de execução | Testar isoladamente e validar interação com engines |
| MEDIUM | Pode alterar proteção ou comportamento secundário | Teste funcional e regressão |
| LOW | UI/observabilidade sem efeito operacional | Validar somente se necessário para operação |

## 6. Critérios de liberação LIVE

A configuração somente deve ser marcada como **LIVE-VALIDATED** quando:

1. Todos os inputs CRITICAL/HIGH relevantes ao `.set` de produção estiverem `PASS` ou formalmente `NOT APPLICABLE`.
2. Não houver input crítico classificado como INATIVO quando ele estiver sendo tratado operacionalmente como controle.
3. As interações R1/R1.1, R9, R10, R10.2, R11, R13 e BRX tiverem sido verificadas nos cenários em que coexistem.
4. O comportamento de fechamento de cesta tiver sido validado considerando a economia completa do ciclo, especialmente após reduções R9/R10.
5. O `.set` final estiver associado ao commit exato do EA utilizado no teste.
6. Qualquer diferença entre comportamento esperado e observado estiver registrada antes da liberação.

## 7. Registro de evidência

Usar uma linha por execução:

`ID | DATA/HORA | SYMBOL | EA COMMIT | SET HASH | INPUT | VALOR A | VALOR B | CENÁRIO | ESPERADO | OBSERVADO | MÉTRICAS | STATUS | OBSERVAÇÃO`

## 8. Regra de ouro

**Nenhum input deve ser considerado operacionalmente confiável apenas porque existe no `.mqh` ou aparece no `.set`. A evidência deve fechar o ciclo: input → referência no código → condição de execução → efeito observável → interação com outras engines → resultado.**
