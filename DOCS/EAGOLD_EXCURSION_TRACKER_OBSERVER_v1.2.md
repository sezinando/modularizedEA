# EAGOLD — EXCURSION TRACKER OBSERVER v1.2

## Objetivo

A v1.2 evolui a telemetria de realização para medir a excursão **entre realizações consecutivas** dentro do mesmo ciclo EAGOLD.

O objetivo é permitir análise posterior de profit capture sem alterar a economia do EA.

## Contrato de segurança

A v1.2 permanece estritamente observer-only.

O tracker:

- não envia ordens;
- não fecha posições;
- não altera lotes;
- não altera TP/SL;
- não altera BRX;
- não altera R9/R10/R11/R13;
- não decide realização;
- não interfere no Action Contract.

## Unidade de análise

A unidade principal continua sendo o **Master Cycle**.

Dentro de cada ciclo, cada realização `COMPLETED` ou `PARTIAL` cria um evento `R1`, `R2`, `R3`... e encerra o intervalo de excursão desde:

- o início do ciclo, para o primeiro evento; ou
- a realização anterior, para os eventos seguintes.

Após registrar o evento, um novo intervalo é iniciado usando o estado floating observado imediatamente após a ação.

## Arquivo

`EAGOLD_EXCURSION_EVENTS.csv`

A v1.2 acrescenta as métricas de intervalo:

- `INTERVAL_START_FLOATING_PL`
- `INTERVAL_MFE`
- `INTERVAL_MAE`
- `INTERVAL_PEAK_FLOATING_PL`
- `INTERVAL_GIVEBACK`
- `INTERVAL_DURATION_SEC`
- `INTERVAL_BUY_LOTS_MAX`
- `INTERVAL_SELL_LOTS_MAX`
- `INTERVAL_GROSS_LOTS_MAX`
- `INTERVAL_NET_LOTS_MAX`

Também mantém as métricas acumuladas do ciclo e o resultado realizado.

## Definições

### INTERVAL_MFE
Maior floating P/L observado desde o último evento de realização até o evento atual.

### INTERVAL_MAE
Menor floating P/L observado no mesmo intervalo.

### INTERVAL_PEAK_FLOATING_PL
Pico de floating P/L observado no intervalo.

### INTERVAL_GIVEBACK
Diferença entre o pico do intervalo e o último floating P/L observado antes da realização.

Importante: esta métrica não é uma reconstrução intratick. Ela representa a observação disponível ao tracker e deve ser interpretada como telemetria de estado.

### REALIZED_DELTA
Variação de `EAGOLDAccumulatedProfit()` desde o evento de realização anterior.

### REALIZED_CUMULATIVE
Resultado realizado acumulado desde o início do ciclo.

## Perguntas de pesquisa habilitadas

A v1.2 permite investigar:

1. Depois de uma realização, quanto lucro flutuante adicional o ciclo desenvolve?
2. Quanto drawdown ocorre antes da próxima realização?
3. Qual é o MFE típico entre realizações R4 e BRX?
4. Qual é o giveback antes de cada realização?
5. Quanto tempo passa entre realizações?
6. Como a exposição máxima muda entre eventos?
7. Em quais situações um partial + BE + runner teria evidência para superar a realização integral?

## Limitação deliberada

A v1.2 ainda não classifica notícias, regime, volatilidade ou eventos extremos.

Portanto, `INTERVAL_GIVEBACK` **não deve ser interpretado isoladamente como perda evitável**.

Um movimento adverso pode ser consequência de notícia, expansão excepcional ou transição de regime. A classificação contextual será adicionada em etapa posterior.

## Próximo estágio

A análise deve cruzar:

`INTER-EVENT EXCURSION × EXPOSURE × REALIZATION ENGINE × MARKET CONTEXT`

Somente depois disso será avaliada a necessidade de comportamento econômico real de:

`PARTIAL → BE → RUNNER → TRAILING`.

## Validação obrigatória

O próximo backtest deve ser executado com os mesmos parâmetros do baseline utilizado na validação anterior.

Critérios mínimos:

- CSV gerado sem erro;
- número de eventos consistente com o baseline;
- `REALIZED_DELTA` consistente com os eventos econômicos;
- primeiro intervalo iniciado no ciclo;
- intervalo reiniciado após cada realização;
- ausência de alteração comportamental no EA;
- ausência de novas ações de broker causadas pelo tracker.
