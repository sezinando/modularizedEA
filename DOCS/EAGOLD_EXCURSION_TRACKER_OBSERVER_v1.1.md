# EAGOLD — EXCURSION TRACKER OBSERVER v1.1

## 1. Objetivo

A v1.1 amplia a telemetria observer-only criada na v1.0 para registrar não apenas o ciclo completo, mas também cada evento de realização `COMPLETED` ou `PARTIAL` ocorrido durante o ciclo.

O objetivo é permitir medir empiricamente a qualidade da captura de lucro antes de qualquer alteração econômica em BRX, R4, BE, partial close ou trailing.

## 2. Contrato de segurança

A telemetria:

- não envia ordens;
- não modifica ordens;
- não fecha ordens;
- não altera lote;
- não altera TP;
- não altera BRX;
- não altera R9, R10, R11 ou R13;
- não interfere no Action Contract;
- apenas observa estado e grava dados.

## 3. Arquivos produzidos

### 3.1 Ciclos

`EAGOLD_EXCURSION_CYCLES.csv`

Mantém o registro consolidado do ciclo master.

Campos principais:

`CYCLE_ID;START_TIME;END_TIME;DIRECTION;BUY_LOTS_MAX;SELL_LOTS_MAX;GROSS_LOTS_MAX;NET_LOTS_MAX;MFE;MAE;PEAK_FLOATING_PL;FINAL_REALIZED_PL;GIVEBACK;DURATION_SEC;REALIZATION_ENGINE;REALIZATION_TYPE`

### 3.2 Eventos de realização

`EAGOLD_EXCURSION_EVENTS.csv`

Registra cada realização observada dentro do ciclo.

Campos:

`EVENT_ID;CYCLE_ID;EVENT_TIME;ENGINE;ACTION;RESULT;REALIZED_DELTA;REALIZED_CUMULATIVE;PRE_ACTION_FLOATING_PL;POST_ACTION_FLOATING_PL;MFE_AT_ACTION;MAE_AT_ACTION;PEAK_FLOATING_PL_AT_ACTION;PEAK_TO_ACTION_GIVEBACK;BUY_LOTS;SELL_LOTS;GROSS_LOTS;NET_LOTS;BUY_LOTS_MAX;SELL_LOTS_MAX;GROSS_LOTS_MAX;NET_LOTS_MAX`

## 4. Semântica dos novos campos

### REALIZED_DELTA

Incremento de `EAGOLDAccumulatedProfit()` observado desde a última realização registrada no ciclo.

### REALIZED_CUMULATIVE

Resultado realizado acumulado desde o início do ciclo.

### PRE_ACTION_FLOATING_PL

Último floating P/L observado imediatamente antes da ação econômica registrada.

### POST_ACTION_FLOATING_PL

Floating P/L observado depois da ação, no momento do registro do evento.

### MFE_AT_ACTION

MFE acumulado até o evento.

### MAE_AT_ACTION

MAE acumulado até o evento.

### PEAK_FLOATING_PL_AT_ACTION

Pico de floating P/L registrado até o evento.

### PEAK_TO_ACTION_GIVEBACK

Diferença entre o pico de floating observado e o último floating observado antes da ação:

`max(0, PEAK_FLOATING_PL_AT_ACTION - PRE_ACTION_FLOATING_PL)`

Este campo é uma métrica de pesquisa. Ele não representa um giveback intratick.

## 5. Perguntas que a v1.1 permite responder

1. Quanto lucro é realizado em cada intervenção do R4/BRX?
2. Qual era o MFE acumulado quando a realização ocorreu?
3. Quanto do MFE havia sido devolvido antes da realização?
4. A realização ocorre cedo, no meio ou depois de uma excursão favorável relevante?
5. Quantas realizações ocorrem dentro de um mesmo ciclo?
6. Quanto do resultado final vem da primeira, segunda, terceira ou demais realizações?
7. Qual exposição estava presente no momento de cada realização?
8. Em quais ciclos existe evidência de que partial + BE poderia ser economicamente interessante?

## 6. Limitações conhecidas

- A telemetria continua dependente da frequência de observação do EA.
- Não há reconstrução intratick.
- Um evento é registrado depois da ação econômica, embora preserve o último estado observado antes dela.
- Ciclos interrompidos por restart do EA não são reconstruídos retroativamente.
- A métrica de `GIVEBACK` do arquivo de ciclos continua sendo uma métrica simples de estado final; a análise de captura deve priorizar `PEAK_TO_ACTION_GIVEBACK` no arquivo de eventos.

## 7. Próximo estágio

Executar novamente o mesmo backtest de junho usado para a v1.0 e coletar os dois arquivos:

- `EAGOLD_EXCURSION_CYCLES.csv`
- `EAGOLD_EXCURSION_EVENTS.csv`

A análise deve então produzir uma matriz:

`CICLO → EVENTO → MFE/MAE → GIVEBACK → EXPOSIÇÃO → REALIZAÇÃO → RESULTADO FINAL`

Somente depois dessa evidência deve ser desenhado o contrafactual de partial close + BE + runner.

## 8. Status

**OBSERVABILITY ONLY — NÃO AUTORIZA MUDANÇA ECONÔMICA.**

A v1.1 é uma etapa de instrumentação e pesquisa, não uma autorização para alterar o comportamento operacional do EAGOLD.
