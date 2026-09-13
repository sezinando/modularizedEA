# EAGOLD — Counterfactual Canonical Baseline Reconstruction v1.0

## 1. Objetivo

Reconstruir o baseline P0 a partir da combinação da telemetria de caminho `EAGOLD_COUNTERFACTUAL_PATH.csv` e do ledger de eventos de realização R12/Excursion. O objetivo é determinar se o caminho observado contém informação suficiente para simular, posteriormente e sem lookahead, políticas P1–P4 de gestão de lucro.

## 2. Fonte analisada

`EAGOLD_COUNTERFACTUAL_PATH.csv`

- 47.734 registros
- 49 campos
- 5 ciclos observados
- 66 tickets distintos
- 7.470 timestamps distintos
- período do PATH: 2026-06-01 01:00:10 a 11:34:15
- R12 válido em 100% dos registros
- fases `PRE_ACTION` e `POST_ACTION`

Ledger de eventos correspondente:

- 34 eventos nos 5 ciclos
- 33 eventos possuem timestamp dentro do PATH
- 28/33 possuem estado pós-ação com tickets sobreviventes
- 5/33 são realizações terminais, nas quais o basket fica sem posição aberta e portanto não existe linha de ticket para `POST_ACTION`
- o 34º evento ocorre às 11:42:40, depois do fim do PATH, portanto não pode ser usado para reconstruir o caminho observado.

## 3. Regra canônica adotada

O PATH é a fonte primária para o **estado de posição/ticket**.

O ledger de eventos é a fonte primária para o **fato econômico de realização** (`ENGINE`, `ACTION`, `RESULT`, `REALIZED_DELTA`).

Não se deve usar `REALIZED_CYCLE_PL` do PATH isoladamente para reconciliar a realização de eventos terminais, porque a telemetria de ciclo pode ser resetada quando o basket é zerado antes de uma amostra pós-ação com posições abertas.

Consequentemente:

```text
estado do caminho = PATH
fato de realização = EVENT LEDGER
contexto de regime = R12 sincronizado no PATH/ledger
```

## 4. Integridade temporal

`PATH_SEQ` é sequencial e único no arquivo analisado.

Cada timestamp de ação apresenta a estrutura esperada:

```text
PRE_ACTION
    ↓
ação econômica
    ↓
POST_ACTION
```

Nos eventos não terminais, os tickets sobreviventes aparecem no `POST_ACTION`. Nos eventos terminais, os tickets presentes no `PRE_ACTION` desaparecem, o que é consistente com fechamento integral do basket.

Não foram observados, nesta amostra, tickets mudando de ciclo, tipo ou lote durante sua permanência no PATH.

## 5. Reconstrução dos eventos

Nos 33 eventos do ledger presentes no PATH:

- 33 possuem evidência de tickets no estado pré-ação quando a realização efetivamente ocorre;
- 33 apresentam redução/eliminação de exposição consistente com a realização;
- 28 possuem tickets sobreviventes após a ação;
- 5 são terminais.

Distribuição das ações presentes no PATH:

| Engine | Ação | Eventos | Tickets fechados inferidos |
|---|---|---:|---:|
| R4 | REALIZE | 15 | 15 |
| BRX | DIRECTIONAL | 13 | 26 |
| BRX | BIDIRECTIONAL | 5 | 21 |
| **Total** | | **33** | **62** |

A contagem acima é baseada na diferença entre os conjuntos de tickets no `PRE_ACTION` e `POST_ACTION` quando o estado pós-ação existe; eventos terminais são tratados pelo desaparecimento dos tickets do PATH e pelo ledger econômico.

## 6. Ciclos observados

| Ciclo | Eventos | Realização do ledger | MFE máximo observado no ledger |
|---|---:|---:|---:|
| 20260601_010010_1 | 5 | $66,39 | $21,63 |
| 20260601_033440_2 | 2 | $18,92 | $13,61 |
| 20260601_041540_3 | 4 | $34,62 | $12,64 |
| 20260601_053030_4 | 13 | $121,28 | $15,54 |
| 20260601_090018_5 | 10 | $94,41 | $14,06 |
| **Total** | **34** | **$335,62** | — |

O quinto ciclo permanece aberto no final do PATH e possui uma realização posterior às 11:42:40 que não está coberta pelo arquivo de caminho.

## 7. Achado econômico importante

A telemetria já permite observar a sequência econômica necessária para estudar gestão adaptativa de lucro.

Exemplo estrutural observado:

```text
exposição acumulada
      ↓
R12/regime
      ↓
P/L flutuante por ticket
      ↓
PRE_ACTION
      ↓
BRX ou R4
      ↓
realização registrada
      ↓
tickets sobreviventes
      ↓
continuação do caminho
```

Isso é substancialmente superior ao uso isolado de MFE/MAE agregado, porque permite saber quais tickets permaneciam abertos depois de uma realização.

## 8. Limitação atual

O PATH termina às 11:34:15 enquanto o último evento do ciclo 5 ocorre às 11:42:40. Portanto, o arquivo atual não representa um ciclo completo.

Isso **não bloqueia a construção do primeiro protótipo counterfactual**, desde que o ciclo incompleto seja marcado como censurado e não seja usado como ciclo completo para métricas finais de desempenho.

Para validação estatística/OOS, será necessário posteriormente obter mais pregões completos com a mesma telemetria.

## 9. Baseline P0 canônico

O P0 deve ser reconstruído como o caminho efetivamente observado:

1. posições e tickets conforme PATH;
2. preços e custos conforme PATH;
3. R12 somente no estado conhecido naquele timestamp;
4. realizações conforme ledger;
5. nenhuma informação futura (`MFE`, `MAE` final, resultado final ou regime futuro) pode participar da decisão counterfactual;
6. após cada ação, o conjunto de tickets sobreviventes deve ser atualizado para o estado observado;
7. evento terminal encerra o ciclo econômico.

## 10. Prontidão para P1

### P0 — baseline observado
**STATUS: APTO PARA PROTÓTIPO**

### P1 — Partial
**STATUS: APTO PARA PROTÓTIPO HISTÓRICO, com ressalva**

A unidade de decisão deve ser ticket/side, usando somente:

- tickets atualmente abertos;
- lotes atuais;
- preço atual;
- P/L atual;
- custos conhecidos;
- exposição BUY/SELL;
- estado R12 atual;
- histórico observado até aquele instante.

Não usar MFE futuro para decidir o partial.

### P2 — Partial + BE
**STATUS: PRONTO PARA ESPECIFICAÇÃO/SIMULAÇÃO, mas requer modelagem explícita de execução de SL/BE.**

### P3 — Partial + BE + Runner
**STATUS: PRONTO PARA ESPECIFICAÇÃO, ainda não para conclusão estatística.**

### P4 — Basket Trailing
**STATUS: POSTERIOR A P1–P3.**

## 11. Próxima etapa técnica

Construir o **Counterfactual Replay Engine v0.1 — P0/P1**, inicialmente offline e observer-only.

Entrada:

```text
PATH.csv + EVENT_LEDGER.csv
```

Saída por evento/ciclo:

```text
P0_REALIZED
P1_COUNTERFACTUAL_REALIZED
DELTA_P1_P0
MAX_EXPOSURE_P0
MAX_EXPOSURE_P1
MFE
MAE
GIVEBACK
DURATION
PARTIAL_COUNT
IMPROVED_CYCLE
WORSENED_CYCLE
```

A primeira política P1 não deve ser escolhida por otimização automática. Deve ser parametrizada de forma determinística e testada em análise de sensibilidade.

## 12. Conclusão

A telemetria atual **passa na auditoria estrutural necessária para iniciar a reconstrução counterfactual**.

O ponto crítico descoberto é que o PATH e o ledger possuem responsabilidades diferentes: o PATH preserva o estado dos tickets, enquanto o ledger preserva o fato econômico da realização. A arquitetura do Counterfactual deve combinar ambos, e não tentar reconstruir tudo de uma única fonte.

Nenhuma mudança de política live foi introduzida.

**PRE-LIVE: BLOQUEADO.**

**Próxima implementação: Counterfactual Replay Engine offline P0/P1.**
