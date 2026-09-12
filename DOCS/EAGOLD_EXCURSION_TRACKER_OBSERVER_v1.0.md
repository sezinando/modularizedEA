# EAGOLD Excursion Tracker — Observer v1.0

## Objetivo

Adicionar telemetria para medir a qualidade da captura de lucro por ciclo, sem alterar a economia do EA.

A primeira pergunta experimental é:

> Quanto lucro flutuante favorável o EAGOLD alcança antes de realizar, quanto ele devolve e qual foi o resultado realizado do ciclo?

A implementação é **observer-only**. Ela não autoriza, bloqueia, fecha, modifica ou abre ordens.

## Escopo do ciclo

Um ciclo começa quando o universo Master do EAGOLD possui posições abertas e o tracker ainda não possui ciclo ativo.

O ciclo termina quando `CountEAGOLDOrders()==0`, isto é, quando não existem mais posições nem ordens pendentes pertencentes ao universo Master.

A fronteira é integrada ao Action Contract: quando uma ação `COMPLETED` deixa o universo totalmente flat, o tracker é finalizado antes que o fluxo de restart possa iniciar o próximo ciclo no mesmo tick.

## Métricas registradas

| Campo | Definição |
|---|---|
| `CYCLE_ID` | Identificador da instância do ciclo |
| `START_TIME` | Início do ciclo |
| `END_TIME` | Final do ciclo |
| `DIRECTION` | BUY, SELL ou BIDIR conforme exposição observada |
| `BUY_LOTS_MAX` | Máxima exposição BUY observada |
| `SELL_LOTS_MAX` | Máxima exposição SELL observada |
| `GROSS_LOTS_MAX` | Máxima soma BUY + SELL |
| `NET_LOTS_MAX` | Máximo `abs(BUY-SELL)` |
| `MFE` | Maior P/L flutuante agregado observado |
| `MAE` | Menor P/L flutuante agregado observado |
| `PEAK_FLOATING_PL` | Pico máximo de P/L flutuante |
| `FINAL_REALIZED_PL` | Delta do resultado realizado do histórico do broker entre início e fim do ciclo |
| `GIVEBACK` | `MFE - último P/L flutuante observado antes da realização final`, limitado a zero |
| `DURATION_SEC` | Duração do ciclo em segundos |
| `REALIZATION_ENGINE` | Último engine que produziu `COMPLETED` ou `PARTIAL` no ciclo |
| `REALIZATION_TYPE` | Ação associada ao último evento de realização |

## Arquivo de saída

O tracker grava:

`EAGOLD_EXCURSION_CYCLES.csv`

O arquivo é CSV separado por `;` e é escrito no diretório de arquivos do terminal/tester conforme o ambiente do MT4.

## Integração

`EA/EAGOLD.mq4` inclui `Core/EAGOLD_ExcursionTracker.mqh`.

A observação ocorre:

1. no `OnInit()` após a criação inicial do ciclo;
2. no início de cada `OnTick()`;
3. após a execução econômica do tick;
4. na conclusão transacional de uma ação que deixa o Master completamente flat.

A integração não altera:

- R1;
- R4/R5/R7;
- BRX;
- R9;
- R10/R10.2;
- R11;
- R13;
- lotes;
- TP;
- grid;
- trailing;
- Action Contract.

## Interpretação experimental

O tracker prepara a próxima camada de análise:

```text
CYCLE
  ↓
MFE / MAE / PEAK / GIVEBACK
  ↓
EXPOSURE
  ↓
REALIZATION ENGINE
  ↓
FINAL REALIZED P/L
  ↓
COUNTERFACTUAL PROFIT CAPTURE
```

Isso permite testar posteriormente se um ciclo com `MFE` muito superior ao `FINAL_REALIZED_PL` teria espaço para:

- realização parcial;
- proteção do restante em BE;
- runner;
- trailing de basket;
- realização adaptativa por regime.

Nenhuma dessas ações é implementada nesta versão.

## Limitações deliberadas da v1.0

1. A telemetria é baseada em amostragem por tick; não existe reconstrução intratick.
2. `MFE` e `MAE` são agregados do Master, não por posição individual.
3. `FINAL_REALIZED_PL` depende do histórico do broker e da fronteira de ownership de `IsEAGOLDOrder()`.
4. O `GIVEBACK` é uma métrica de pesquisa: representa o recuo do pico até o último P/L flutuante observado antes da realização final, não uma estimativa intratick do drawdown pós-pico.
5. A memória do tracker não é persistida entre reinicializações; um ciclo interrompido por restart não é artificialmente reconstruído.

## Critério de aceitação da etapa

A etapa será considerada estruturalmente concluída quando:

- o módulo compilar;
- o EA iniciar sem alteração de comportamento econômico;
- ciclos completos gerarem uma linha no CSV;
- ciclos bidirecionais e direcionais forem registrados;
- `MFE >= MAE` para cada ciclo;
- `GROSS_LOTS_MAX >= NET_LOTS_MAX`;
- o ciclo seguinte após restart de basket receber novo `CYCLE_ID`;
- nenhum evento do tracker gerar chamada de execução de ordem.

## Próxima etapa

Executar uma bateria observacional de backtest, começando pelo mesmo conjunto de dados usado na análise dos 21 pregões de junho, e produzir a matriz:

`CYCLE × MFE × MAE × GIVEBACK × MAX_EXPOSURE × FINAL_REALIZED_PL × REALIZATION_ENGINE`.

Somente depois dessa evidência será avaliada a camada **counterfactual** de profit management.
