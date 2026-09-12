# EAGOLD — PRE-LIVE BASKET ECONOMIC AUDIT v1.0

## 1. Objetivo

Estabelecer o gate econômico para a realização de cestas antes da operação real. Este documento complementa a `EAGOLD_INPUT_TEST_MATRIX_v1.0.md` e não altera o comportamento do EA.

**Baseline:** EAGOLD v0.106 / `sezinando/modularizedEA` / branch `main`.

## 2. Regra de segurança

Nenhuma realização deve ser considerada validada apenas porque o resultado flutuante atual da cesta está positivo. A análise deve separar:

1. resultado flutuante atual das posições;
2. resultado já realizado pelo ciclo;
3. custos efetivos (swap e comissão);
4. resultado econômico acumulado/projetado do ciclo;
5. piso de realização configurado;
6. margem adicional de segurança para execução/slippage.

Não existe garantia matemática de lucro após execução de mercado. O objetivo operacional é impedir que a decisão de fechamento seja autorizada quando o resultado projetado já estiver abaixo do piso definido.

## 3. Achado crítico anterior — STATUS CORRIGIDO

A versão anterior deste documento registrava um bypass potencial no caminho `BuyBasketClose()` / `SellBasketClose()` do Lifecycle: o fechamento poderia usar apenas `BRXDirectionalMinProfit`, sem acrescentar `BRXRealizationSafetyBuffer`.

A implementação atual foi corrigida. Quando BRX está ativo, `BuyBasketClose()` e `SellBasketClose()` utilizam:

`required = BRXDirectionalMinProfit + max(0, BRXRealizationSafetyBuffer)`

O teste de weighted BE também permanece aplicado quando `BRXRequireWeightedBE=true`.

**Conclusão de código:** o achado de bypass nominal identificado anteriormente não permanece no código atual. A correção precisa continuar sendo validada em runtime, portanto isso não equivale a aprovação LIVE.

## 4. Proteção do BRX atual

`BRX_CloseDirection()` e `BRX_CloseBasket()` exigem o piso protegido antes da autorização.

No modo bidirecional, a execução é sequencial por perna. Depois da primeira perna, o código mede o resultado efetivamente realizado e impede a segunda perna quando o resultado realizado/projetado não preserva o piso nominal. A contabilização utiliza `OrderProfit()+OrderSwap()+OrderCommission()` das ordens efetivamente fechadas.

Essa arquitetura reduz o risco de decisão baseada somente no P/L flutuante, mas não fornece garantia matemática contra slippage, rejeição ou mudança de preço entre as execuções. O teste de runtime continua obrigatório.

## 5. Evidência de runtime — `Avaliacao= BRX.log`

A execução fornecida contém evidência do modo bidirecional no baseline de teste:

### Caso observado 01 — 01:45:18

- BUY realizado: `6.69`
- SELL realizado: `3.80`
- total realizado: `10.49`
- piso nominal: `5.00`
- autorização protegida: `10.00`
- fechamento bidirecional completo confirmado.
- após ficar flat, o ciclo foi recriado por R1 (`R1 FIRST BUY/SELL`).

### Caso observado 02 — 02:09:39

- BUY realizado: `5.10`
- SELL realizado: `5.02`
- total realizado: `10.12`
- piso nominal: `5.00`
- autorização protegida: `10.00`
- fechamento bidirecional completo confirmado.
- após ficar flat, o ciclo foi recriado por R1.

Esses casos sustentam **PASS observado para o limite protegido T-BRX-02**, mas não comprovam o cenário de HOLD entre `5` e `10`.

Também foram observados fechamentos direcionais acima do piso protegido, mas os registros direcionais não imprimem explicitamente `requiredAuthorization`. Por isso, eles não devem ser usados isoladamente como prova do enforcement do buffer.

## 6. Classificação atual dos testes BRX

| Teste | Status | Evidência / pendência |
|---|---|---|
| T-BRX-01 | NOT RUN | Ainda falta um caso inequívoco entre `5` e `10` com BRX HOLD e ausência de fechamento naquele tick/ciclo. |
| T-BRX-02 | PASS observado | Casos bidirecionais `10.49` e `10.12`, com `requiredAuthorization=10.00` e `realizedActual` correspondente. |
| T-BRX-03 | NOT RUN | Repetir com `BRXRealizationSafetyBuffer=0`. |
| T-BRX-04 | NOT RUN | Repetir com weighted BE habilitado e buffer positivo. |
| T-BRX-05 | NOT RUN | Validar interação R10 → BRX e resultado econômico completo do ciclo. |
| T-BRX-06 | NOT RUN | Validar interação R10.2 → BRX. |

## 7. Qualidade da evidência atual

O log analisado é uma **execução de integração**, não uma bateria estéril de BRX: havia mecanismos de Recovery/R11 ativos no cenário relevante. Portanto, ele é válido para observar interação real do fluxo, mas não substitui os testes controlados da matriz.

O tester foi interrompido manualmente. As operações de encerramento provocadas pela parada não devem ser usadas como P/L natural de fim de período.

Não foi identificada evidência textual de erro `4109` no log analisado; essa busca não constitui prova de ausência de todos os erros de execução.

## 8. Interação BRX → Lifecycle confirmada

Quando o BRX bidirecional fecha completamente a cesta e deixa o Master flat, `CreateFirstOrdersIfFlat()` recria as sementes R1. O fluxo observado foi:

`BRX BIDIRECTIONAL CLOSE COMPLETE → MASTER FLAT → R1 FIRST BUY/SELL`

Não foi observado R7 como mecanismo de restart imediatamente após esse fechamento bidirecional.

Isso é consistente com a arquitetura atual: `BRX_Run()` encerra o ciclo de fechamento e `CreateFirstOrdersIfFlat()` trata o estado global flat posteriormente.

## 9. Pendências de auditoria identificadas no código

### 9.1 R10 partial execution

`Rule10ProfitFundedPartial()` e `Rule10Reduce()` são sequenciais. Se uma perna da redução for executada e a segunda falhar, o estado fica parcialmente alterado. O código registra a ocorrência e retorna `false`, mas a máquina pode continuar para caminhos posteriores no mesmo `OnTick` dependendo do fluxo.

Isso exige teste específico de falha parcial antes de LIVE, principalmente quando BRX estiver ativo.

### 9.2 `R10MarkerFont`

O input existe, mas `CreateR10VisualMarker()` utiliza o font hardcoded `"Segoe UI Semibold"`. O input deve permanecer classificado como **INATIVO** até eventual correção deliberada.

### 9.3 Engine Action Marker

A implementação atual utiliza `OBJ_ARROW` com código `159` e cor derivada do engine. Os antigos inputs de font/tamanho/background não controlam o objeto visual atual e devem permanecer classificados como inativos.

### 9.4 Performance

`OnTick()` atualiza painel, cascade, chart guides e persistência a cada tick. A persistência live foi condicionada a mudanças significativas, mas ainda existem operações gráficas por tick que devem ser consideradas na próxima auditoria de performance. Não atribuir a lentidão exclusivamente à persistência sem benchmark isolado.

## 10. Gate econômico de aprovação

O bloco BRX/R10/R10.2 somente poderá ser marcado como `LIVE-VALIDATED` quando:

- nenhum caminho de fechamento bypassar o safety buffer quando BRX estiver ativo;
- T-BRX-01 a T-BRX-06 forem `PASS` ou formalmente `NOT APPLICABLE`;
- R10 e BRX forem avaliados no mesmo ciclo econômico;
- fechamentos parciais forem contabilizados no resultado do ciclo;
- custos forem incluídos na evidência;
- falhas parciais de execução forem testadas;
- o commit exato do EA e o hash do `.set` estiverem registrados.

## 11. Decisão atual

**STATUS: PRE-LIVE BLOCK.**

O bypass de safety buffer anteriormente identificado está corrigido no código atual, mas a liberação permanece bloqueada por falta de validação runtime completa.

## 12. Próxima sequência de auditoria

1. Executar T-BRX-01: provocar resultado entre `5` e `10` e provar `HOLD`.
2. Executar T-BRX-03: buffer `0`.
3. Executar T-BRX-04: weighted BE.
4. Executar T-BRX-05: R10 antes de BRX.
5. Executar T-BRX-06: R10.2 antes de BRX.
6. Executar teste de falha parcial R10.
7. Executar regressão R9/R10/R11.
8. Registrar commit exato + hash do `.set` de cada bateria relevante.
9. Somente então revisar o gate final de PRE-LIVE.
