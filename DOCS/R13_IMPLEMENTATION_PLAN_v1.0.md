# EAGOLD — R13 Recovery Satellite Engine

**Documento:** `R13_IMPLEMENTATION_PLAN_v1.0.md`  
**Versão:** 1.0  
**Data:** 2026-09-10  
**Status:** plano de implementação — sem execução real  
**Repositório:** `sezinando/modularizedEA`

---

## 1. Objetivo

Transformar a proposta `R13_RECOVERY_SATELLITE_ENGINE_v1.0` em uma implementação incremental, auditável e reversível.

A primeira prioridade é **não alterar o comportamento econômico do Master**. A R13 será construída inicialmente como uma engine observadora, depois como Satellite isolada e somente após validação poderá fornecer Recovery Capital ao R10.

A arquitetura seguirá o contrato já definido para a R13: leitura de contexto, decisão própria, execução somente das próprias ordens, telemetria e persistência independentes.

> **Regra de promoção:** nenhuma etapa posterior poderá ser habilitada apenas porque o código compila. Cada nível exige evidência de replay/backtest e critérios de aceitação definidos neste documento.

---

# 2. Princípios de implementação

1. **Master primeiro:** preservar integralmente R1/R4/R5/R7/R9/R10/R10.2/R11/BRX.
2. **Isolation by ownership:** R13 nunca pode ser confundida com ordens do Master.
3. **Observer before execution:** a classificação de regime e a estratégia serão observadas antes de enviar ordens.
4. **No hidden coupling:** R13 não manipulará diretamente estado interno de outras engines.
5. **Recovery Capital não é saldo:** capital elegível será um ledger econômico próprio.
6. **R10 continua dono da redução:** R13 gera recurso; R10 escolhe a redução do Master.
7. **Fail closed:** qualquer dúvida de ownership, margem, spread, estado ou permissão bloqueia a ação.
8. **Reversibilidade:** cada promoção deve poder ser desligada por input sem remover a implementação anterior.
9. **Auditabilidade:** decisões e ações materiais devem ser reconstruíveis por logs/eventos.
10. **Validação por evidência:** nenhuma hipótese de estratégia será tratada como comprovada antes dos testes.

---

# 3. Problema arquitetural crítico: `MagicNumber=-1`

O Master atualmente pode operar com:

```text
MagicNumber = -1
```

Nesse modo, o universo do Master é **todas as ordens do símbolo atual**, independentemente do Magic.

Isso é incompatível, por si só, com a introdução de um Satellite no mesmo símbolo.

Portanto, antes da execução real da R13 será obrigatório introduzir uma distinção explícita entre:

```text
MASTER UNIVERSE
≠
R13 SATELLITE UNIVERSE
```

A solução deverá ser implementada no núcleo de ownership/filtro de ordens, e não apenas no painel.

### Regra de segurança

Mesmo que `MagicNumber=-1`, as rotinas do Master não podem absorver ordens identificadas como pertencentes à R13.

Da mesma forma, R13 deverá aceitar somente ordens que satisfaçam simultaneamente os critérios de seu próprio universo.

O comentário será uma camada adicional; a implementação não dependerá somente dele.

---

# 4. Estrutura de arquivos planejada

```text
modularizedEA/
│
├── EA/
│   └── EAGOLD.mq4
│
├── Core/
│   ├── EAGOLD_Config.mqh
│   ├── EAGOLD_Orders.mqh
│   ├── EAGOLD_Execution.mqh
│   ├── EAGOLD_Persistence.mqh
│   └── EAGOLD_R13_State.mqh              [planejado]
│
├── Engines/
│   ├── EAGOLD_R9.mqh
│   ├── EAGOLD_R10.mqh
│   ├── EAGOLD_Recovery.mqh
│   ├── EAGOLD_Lifecycle.mqh
│   ├── EAGOLD_R1_Admission.mqh
│   ├── EAGOLD_BRX.mqh
│   └── EAGOLD_R13_Satellite.mqh          [planejado]
│
├── UI/
│   ├── EAGOLD_ModularizationPanel.mqh
│   └── EAGOLD_ChartBasketGuides.mqh
│
└── DOCS/
    ├── R13_RECOVERY_SATELLITE_ENGINE_v1.0.md
    └── R13_IMPLEMENTATION_PLAN_v1.0.md
```

Um módulo de persistência separado para R13 só será criado se a persistência existente não oferecer uma separação suficientemente segura. Evita-se duplicação desnecessária no primeiro passo.

---

# 5. Contrato de configuração

A próxima alteração de código deverá adicionar um grupo próprio no `Core/EAGOLD_Config.mqh`.

Proposta inicial:

```mql4
input string INPUT_GROUP_R13="=== R13 RECOVERY SATELLITE ===";
extern bool EnableR13=false;
extern bool EnableR13AutoActivation=false;
extern int R13MagicNumber=3010;
extern string R13OrderComment="EAGOLD_RECOVERY_SATELLITE";
extern double R13MaxLots=0.20;
extern int R13MaxPositions=3;
extern double R13MaxDrawdown=50.00;
extern double R13MaxDailyLoss=50.00;
extern double R13MaxSpread=100.0;
extern int R13StartHour=0;
extern int R13EndHour=23;
extern double R13RangeMinATRRatio=0.0;
extern double R13RangeMaxATRRatio=0.0;
extern double R13RangeMaxDrift=0.0;
extern double R13RecoveryCapitalFraction=0.0;
```

### Observação importante

Os valores acima são **contrato de implementação / placeholders de teste**, não parâmetros otimizados.

A estratégia de range ainda precisa ser validada. Inputs que não possuírem utilização real na primeira fase não devem ser usados para simular uma implementação inexistente.

A primeira implementação deve preferir poucos parâmetros funcionais e claramente auditáveis.

---

# 6. Estado R13

O estado mínimo deverá ser independente do estado proprietário das outras engines.

Estados:

```text
OFF
ELIGIBLE
SUGGESTED
AUTHORIZED
ACTIVE
PAUSING
STOPPED
BLOCKED
```

Estado econômico mínimo:

```text
R13 realized P/L
R13 costs
R13 net P/L
R13 peak profit
R13 drawdown
Recovery Capital generated
Recovery Capital reserved
Recovery Capital available
Recovery Capital allocated
Recovery Capital consumed
Recovery Capital remaining
```

O estado deverá possuir uma função clara de reset por ciclo para evitar carregamento indevido de capital ou drawdown entre ciclos.

---

# 7. API da engine

A interface planejada será deliberadamente pequena.

Conceito:

```text
R13_UpdateContext()
R13_Measure()
R13_Classify()
R13_CheckEligibility()
R13_FindEntry()
R13_FindExit()
R13_RiskCheck()
R13_Execute()
R13_UpdateLedger()
R13_Persist()
R13_GetState()
```

Não é obrigatório implementar todas essas funções na primeira versão. A fase Observer deve limitar-se ao necessário para medir e classificar.

---

# 8. Ownership e enumeradores

Será necessário criar filtros explícitos para:

```text
IsR13Order()
CountR13Orders()
CountR13Positions()
R13Lots()
R13DirectionLots()
R13BasketProfit()
R13OwnDrawdown()
```

A regra conceitual é:

```text
R13 order
= Symbol atual
+ R13 Magic
+ ownership/comment esperado
```

Quando houver conflito ou inconsistência, a ordem não será considerada pertencente à R13.

### Proteção do Master

O comportamento atual de `IsEAGOLDOrder()` deverá ser revisado antes da Fase 2 para excluir explicitamente ordens R13 quando `MagicNumber=-1`.

Essa mudança é uma **mudança de isolamento**, não uma alteração da lógica de trading do Master.

Ela deverá receber teste específico de regressão.

---

# 9. Fase 0 — preparação

### Objetivo

Criar contrato, documentação e configuração sem permitir execução R13.

### Entregáveis

- `R13_IMPLEMENTATION_PLAN_v1.0.md`.
- Grupo de configuração R13.
- `EnableR13=false` por padrão.
- Nenhuma chamada a `OrderSend()` para R13.
- Nenhuma alteração de alvo, grid, recovery ou redução do Master.

### Critério de aceitação

Com R13 desligada, o comportamento do Master deve permanecer funcionalmente equivalente ao baseline modular atual.

---

# 10. Fase 1 — Observer

### Objetivo

Determinar quando a R13 teria sido candidata sem executar ordens.

Registrar:

```text
regime observado
range score / classificação
Master stressed
exposição Master
DD Master
pending úteis
spread
horário
R13 eligible
motivo de bloqueio
entrada hipotética
saída hipotética
P/L hipotético
DD hipotético
Recovery Capital hipotético
```

### Proibição

```text
OrderSend = NÃO
OrderClose = NÃO
OrderDelete = NÃO
```

### Critério de aceitação

O Observer deve produzir sinais reproduzíveis em replay e permitir comparação com candles/ticks sem lookahead.

---

# 11. Fase 2 — detector de consolidação

A estratégia inicial será baseada em hipótese de range.

O detector deve separar pelo menos:

```text
RANGE
TREND
HIGH_VOL
EXTREME / UNSAFE
UNDEFINED
```

Possíveis componentes de medição:

- ATR relativo;
- amplitude recente;
- drift direcional;
- expansão de range;
- persistência;
- posição dentro do range;
- spread;
- horário.

Nenhum limiar será considerado definitivo antes do backtest.

### Regra temporal

O detector deverá utilizar somente informação disponível até o instante da decisão.

---

# 12. Fase 3 — Satellite isolada

Somente depois de provar o Observer.

A R13 poderá abrir e fechar apenas suas próprias ordens.

Requisitos obrigatórios:

- Magic próprio;
- comentário próprio;
- filtro de símbolo;
- filtro de ownership;
- limite de posições;
- limite de lotes;
- spread máximo;
- margem mínima;
- perda máxima própria;
- perda diária máxima;
- horário;
- bloqueio em estado de mercado incompatível.

### Regra econômica

R13 não recebe permissão para aumentar risco porque o Master está perdendo.

---

# 13. Fase 4 — Recovery Capital Ledger

O ledger deve ser separado do saldo da conta.

Modelo:

```text
capital_generated
        ↓
capital_reserved
        ↓
capital_available
        ↓
capital_allocated
        ↓
capital_consumed
        ↓
capital_remaining
```

A fonte de verdade do ledger deverá ser reconstruível a partir de eventos de P/L R13.

### Princípio

```text
Account Balance ≠ Recovery Capital
```

Recovery Capital só pode ser elegível quando as regras definidas para a R13 forem satisfeitas.

---

# 14. Fase 5 — R10 counterfactual

Antes de permitir que R13 financie uma redução real, executar uma camada de simulação.

Fluxo:

```text
R13 gera capital
       ↓
R10 recebe capital hipotético
       ↓
R10 Candidate
       ↓
SIMULATE
       ↓
HARD CONSTRAINTS
       ↓
LEXICOGRAPHIC RANK
       ↓
Reduction hipotética
       ↓
registrar resultado
```

Nenhuma ordem R13 deverá fechar uma posição Master nessa fase.

O objetivo é responder:

> O Recovery Capital gerado pela R13 realmente melhora a qualidade da redução escolhida pelo R10?

---

# 15. Fase 6 — integração real

Somente após evidência positiva nas fases anteriores.

R13 poderá fornecer capital elegível ao R10 através de uma interface explícita.

Conceito:

```mql4
double R13GetAvailableRecoveryCapital();
```

O R10 continua proprietário da decisão de redução.

R13 não poderá:

- escolher ticket Master;
- fechar ordem Master;
- alterar lote Master;
- alterar recovery step;
- alterar BRX diretamente.

---

# 16. Integração com R12

Quando o R12 estiver disponível para consumo, a relação esperada será:

```text
RANGE       → R13 candidato
TREND       → R13 normalmente OFF
HIGH_VOL    → R13 normalmente OFF
EXTREME     → R13 OFF
UNDEFINED   → R13 BLOCKED
```

Na primeira implementação, R13 deverá continuar testável sem dependência obrigatória de R12.

Isso permite validar o detector isoladamente e só depois acoplar a classificação de regime existente.

---

# 17. Telemetria

Eventos mínimos:

```text
R13_SUGGESTED
R13_AUTHORIZED
R13_BLOCKED
R13_ACTIVATED
R13_ENTRY
R13_EXIT
R13_PROFIT_REALIZED
R13_CAPITAL_ALLOCATED
R13_CAPITAL_CONSUMED
R13_PAUSED
R13_STOPPED
R13_RISK_BLOCK
```

Cada evento material deve carregar, quando aplicável:

- timestamp;
- symbol;
- Master cycle ID;
- Master Magic;
- R13 Magic;
- ownership;
- ticket;
- lots;
- entry;
- exit;
- realized P/L;
- capital antes/depois;
- motivo;
- status;
- error code.

---

# 18. Persistência

O estado persistente R13 deve possuir namespace próprio.

Exemplo conceitual:

```text
EAGOLD_R13_STATE_<Symbol>_<Magic>_<Key>
```

Chaves mínimas:

```text
STATE
CYCLE
ACTIVATION_TIME
REALIZED_PL
COSTS
CAPITAL_GENERATED
CAPITAL_RESERVED
CAPITAL_AVAILABLE
CAPITAL_ALLOCATED
CAPITAL_CONSUMED
CAPITAL_REMAINING
PEAK_PROFIT
DRAWDOWN
TRADES
STOP_REASON
```

Não reutilizar chaves do Master para valores economicamente pertencentes à R13.

---

# 19. Painel

A primeira versão do painel deverá mostrar somente o necessário para auditoria.

Proposta:

```text
R13 OFF / OBS / ACTIVE / BLOCKED
R13 REGIME
R13 POS
R13 LOTS
R13 P/L
R13 DD
R13 CAPITAL
R13 ELIGIBLE
R13 BLOCK REASON
```

Não substituir informações existentes do painel Master.

A UI será secundária: primeiro a engine precisa produzir dados confiáveis.

---

# 20. Testes obrigatórios

## T1 — R13 OFF

Verificar que não há alteração funcional no Master.

## T2 — Ownership

Criar ordens Master e R13 no mesmo símbolo e verificar que:

```text
Master counts = somente Master
R13 counts    = somente R13
```

## T3 — `MagicNumber=-1`

Este é um teste crítico.

Verificar que o wildcard do Master não absorve ordens R13.

## T4 — Spread block

Spread acima do limite deve bloquear novas entradas R13.

## T5 — Drawdown block

DD próprio acima do limite deve impedir novas entradas e conduzir à parada definida.

## T6 — Market regime

RANGE deve permitir elegibilidade; TREND/HIGH_VOL/EXTREME devem respeitar a política de bloqueio.

## T7 — No lookahead

Decisões devem utilizar somente dados disponíveis antes da entrada.

## T8 — Restart

Reiniciar o EA/tester sem corromper o estado persistente.

## T9 — Partial close / costs

Comissões, swaps e fechamentos parciais devem refletir corretamente no ledger.

## T10 — Counterfactual R10

Verificar que nenhuma ordem Master é realmente alterada durante a fase de simulação.

---

# 21. Critérios de promoção

## Level 0 — OFF

Implementação presente, execução desabilitada.

## Level 1 — Observer

Classificação e telemetria, sem execução.

## Level 2 — Real Isolated

R13 opera independentemente, sem Recovery Capital para R10.

## Level 3 — Counterfactual

R13 real + simulação de impacto R10.

## Level 4 — Integrated

R13 Recovery Capital pode ser consumido por uma redução real do R10.

### Regra

Não promover para o nível seguinte se os testes de segurança ou isolamento falharem, mesmo que o resultado financeiro pareça positivo.

---

# 22. Rollback

Toda promoção deve ser reversível por configuração.

Principalmente:

```text
EnableR13=false
EnableR13AutoActivation=false
```

A desativação deve impedir novas entradas. A política de gerenciamento das posições já existentes deverá ser definida antes de qualquer promoção para execução real.

---

# 23. Sequência de commits

A implementação será dividida para manter rastreabilidade:

```text
1. docs: add R13 implementation plan
2. feat: add R13 configuration contract
3. feat: add R13 observer engine
4. feat: add R13 range classification telemetry
5. feat: add R13 isolated satellite execution
6. feat: add R13 recovery capital ledger
7. feat: add R13 counterfactual R10 integration
8. feat: enable R13 recovery integration
```

Cada commit deve ser pequeno o suficiente para ser auditado e revertido isoladamente.

---

# 24. Próxima etapa imediata

A próxima alteração de código deve ser **somente a criação do contrato de configuração R13 em `Core/EAGOLD_Config.mqh`**, mantendo:

```text
EnableR13 = false
EnableR13AutoActivation = false
```

Nenhuma rotina R13 deve executar ordens nessa etapa.

Depois disso será criado o Observer.

---

# 25. Definition of Done da preparação

A preparação estará concluída quando:

- [x] arquitetura documentada;
- [x] separação Master/Satellite definida;
- [x] risco do `MagicNumber=-1` identificado;
- [x] fases de promoção definidas;
- [x] critérios de teste definidos;
- [x] sequência de commits definida;
- [ ] configuração R13 implementada;
- [ ] ownership isolado no código;
- [ ] Observer implementado;
- [ ] detector de regime validado;
- [ ] Satellite isolada validada;
- [ ] Recovery Capital validado;
- [ ] R10 counterfactual validado;
- [ ] integração real autorizada.

**Conclusão:** a R13 deve nascer como uma capacidade de pesquisa controlada, não como uma nova camada de risco imediatamente acoplada ao Master.