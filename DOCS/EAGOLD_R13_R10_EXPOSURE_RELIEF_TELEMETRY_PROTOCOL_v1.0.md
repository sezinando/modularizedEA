# EAGOLD — R13 → R10 Exposure Relief Telemetry Protocol v1.0

## Objetivo

Provar operacionalmente se o capital realizado pelo R13 é convertido em **desmontagem econômica da cesta Master** ou se apenas produz realização de lucro sem redução estrutural relevante do risco.

## Fluxo observado

```text
R13 Satellite
    ↓ realiza lucro
Recovery Capital
    ↓ autoriza
R10 Average Adjustment
    ↓ fecha parcialmente a pior posição Master
Exposure / Gross / preço médio
    ↓ medir antes e depois
Telemetria
```

## Arquivo

`EAGOLD_EXPOSURE_RELIEF_TELEMETRY.csv`

A telemetria é observer-only. Ela não envia, modifica ou fecha ordens.

## Eventos

### R13_CAPITAL_CREDIT
Registra cada crédito de Recovery Capital originado por realização positiva do R13.

### R13_R10_ADJUSTMENT
Registra cada tentativa do R13 de financiar o R10 Average Adjustment, inclusive `BLOCKED`, `FAILED`, `PARTIAL` e `COMPLETED`.

## Métricas principais

### Exposure Reduction
```text
EXPOSURE_REDUCTION = EXPOSURE_BEFORE - EXPOSURE_AFTER
```
Deve ser > 0 para caracterizar redução real de exposição.

### Gross Reduction
```text
GROSS_REDUCTION = GROSS_BEFORE - GROSS_AFTER
```
É a métrica mais direta para comprovar desmontagem física da cesta.

### Exposure Relief Efficiency
```text
RELIEF_EFFICIENCY_LOTS_PER_DOLLAR =
    EXPOSURE_REDUCTION / CAPITAL_USED
```
Mede quantos lotes de exposição foram retirados por dólar de capital de recuperação consumido.

### Average Entry Improvement
Para BUY:
```text
AVG_IMPROVEMENT_POINTS = AVG_ENTRY_AFTER - AVG_ENTRY_BEFORE
```
Para SELL:
```text
AVG_IMPROVEMENT_POINTS = AVG_ENTRY_BEFORE - AVG_ENTRY_AFTER
```
Valor positivo significa que a retirada da posição adversa melhorou o preço médio da cesta.

### Average Improvement per Dollar
```text
AVG_IMPROVEMENT_POINTS_PER_DOLLAR =
    AVG_IMPROVEMENT_POINTS / CAPITAL_USED
```

## Critério de sucesso econômico

Uma execução R13 → R10 é considerada **Exposure Relief efetivo** quando:

1. `RESULT = COMPLETED` ou existe redução efetiva em `PARTIAL`;
2. `EXPOSURE_AFTER < EXPOSURE_BEFORE`;
3. `GROSS_AFTER < GROSS_BEFORE`;
4. a redução ocorre no lado Master pesado;
5. o preço médio do lado alvo melhora ou, no mínimo, não piora;
6. o capital consumido é compatível com a perda realizada na redução;
7. não ocorre aumento de exposição no mesmo ciclo econômico.

## O que não caracteriza sucesso

- somente aumento do Recovery Capital;
- somente lucro realizado pelo R13;
- fechamento do R13 sem redução do Master;
- redução acompanhada por nova entrada que repõe o mesmo GROSS;
- simples transferência contábil de lucro entre operações;
- melhora momentânea do P/L sem redução de exposição.

## Experimento operacional

Executar Strategy Tester/forward assistido com R13 ativo e observar ciclos em que:

```text
Master exposure >= R13MinDirectionalImbalance
R13 gera lucro >= R13ProfitTarget
Recovery Capital > 0
Master possui pelo menos uma posição perdedora
```

Para cada `R13_R10_ADJUSTMENT`, reconstruir:

```text
Capital gerado
      ↓
Capital consumido
      ↓
Lotes retirados
      ↓
GROSS antes/depois
      ↓
NET antes/depois
      ↓
Preço médio antes/depois
      ↓
P/L flutuante do lado alvo
```

## Hipótese a validar

> **H1 — R13/R10 funciona como mecanismo de desmontagem progressiva:** lucros realizados pelo R13 são convertidos em redução seletiva da pior parte da cesta Master, diminuindo GROSS e melhorando a localização média da exposição.

Hipótese alternativa:

> **H0 — R13/R10 apenas recicla capital:** o R13 realiza lucro, mas o capital consumido pelo R10 não produz redução persistente de exposição ou é rapidamente reposto por novas entradas/recoveries.

## Status

- Instrumentação estrutural: **IMPLEMENTADA**
- Telemetria observer-only: **IMPLEMENTADA**
- Evidência operacional suficiente: **PENDENTE**
- Runtime/Strategy Tester: **PENDENTE**
- Alteração de comportamento da estratégia: **NÃO REALIZADA**
- Hard Broker Stop: **FORA DO ESCOPO DESTA ETAPA**
