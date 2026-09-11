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

## 3. Achado crítico identificado na implementação atual

O BRX possui proteção explícita em `BRX_CloseBasket()` e `BRX_CloseDirection()`, utilizando `profit >= floor + safety buffer` antes da autorização. Entretanto, o caminho posterior `BuyBasketClose()` / `SellBasketClose()` do Lifecycle utiliza `BRXDirectionalMinProfit` como alvo, mas não adiciona `BRXRealizationSafetyBuffer` ao teste de fechamento.

Consequentemente, existe um caminho potencial de fechamento direcional que pode exigir apenas o piso nominal e não o piso nominal acrescido do buffer.

Esse achado deve ser tratado como **CRITICAL — PRE-LIVE BLOCK** até ser corrigido ou formalmente demonstrado como inalcançável no fluxo de produção.

## 4. Interação observada

O fluxo atual de `BuyMachine()` e `SellMachine()` executa primeiro `BRX_Run()` apenas em determinados modos e, se ele não realizar a cesta, continua para `BuyBasketClose()` / `SellBasketClose()`.

Portanto, a existência de uma proteção em `BRX_Run()` não é suficiente para provar que todos os caminhos posteriores possuem a mesma proteção.

## 5. Critério de correção recomendado

Quando `EnableBasketRealization=true` e `BRXRealizationMode!=0`, qualquer fechamento direcional executado pelo Lifecycle deve respeitar o mesmo contrato mínimo do BRX:

`required = BRXDirectionalMinProfit + max(0, BRXRealizationSafetyBuffer)`

Além disso, quando `BRXRequireWeightedBE=true`, deve permanecer obrigatório o teste de weighted BE correspondente ao buffer configurado.

O caminho legacy (`BRXRealizationMode=0` ou `EnableBasketRealization=false`) não deve receber essa regra BRX, preservando o contrato legacy.

## 6. Testes obrigatórios após a correção

### T-BRX-01 — piso nominal

Configuração:
- `BRXDirectionalMinProfit = 5`
- `BRXRealizationSafetyBuffer = 5`

Cenário: resultado direcional entre 5 e 10.

Esperado: **HOLD**.

### T-BRX-02 — piso protegido

Mesmo cenário com resultado acima de 10.

Esperado: fechamento elegível, sujeito aos demais guards.

### T-BRX-03 — buffer zero

`BRXRealizationSafetyBuffer = 0`.

Esperado: comportamento equivalente ao piso nominal, sem cushion adicional.

### T-BRX-04 — weighted BE

`BRXRequireWeightedBE = true` e buffer positivo.

Esperado: realização somente quando o weighted BE estiver protegido pelo buffer configurado.

### T-BRX-05 — R10 antes de BRX

Executar redução R10, registrar todo resultado realizado e depois provocar condição de realização.

Registrar:
- equity inicial do ciclo;
- pior equity;
- resultado realizado por R10;
- resultado flutuante restante;
- custos;
- resultado econômico acumulado;
- decisão BRX;
- resultado final após fechamento.

### T-BRX-06 — R10.2 ativo

Repetir T-BRX-05 com `EnableR10RecoveryRealization=true`.

Esperado: R10.2 continua sendo um guard independente e não pode ser bypassado por outro caminho de fechamento.

## 7. Gate econômico de aprovação

O bloco BRX/R10/R10.2 somente poderá ser marcado como `LIVE-VALIDATED` quando:

- nenhum caminho de fechamento bypassar o safety buffer quando BRX estiver ativo;
- R10 e BRX forem avaliados no mesmo ciclo econômico;
- fechamentos parciais forem contabilizados no resultado do ciclo;
- custos forem incluídos na evidência;
- todos os testes T-BRX-01 a T-BRX-06 forem `PASS` ou formalmente `NOT APPLICABLE`;
- o commit exato do EA e o hash do `.set` estiverem registrados.

## 8. Decisão atual

**STATUS: PRE-LIVE BLOCK.**

Não alterar parâmetros de produção para contornar este achado. Primeiro corrigir/validar o caminho de realização; depois executar a bateria controlada.

## 9. Próxima sequência

1. Corrigir o bypass potencial do safety buffer no Lifecycle.
2. Compilar e verificar ausência de regressão.
3. Executar T-BRX-01 a T-BRX-06.
4. Executar regressão R9/R10/R11.
5. Somente então iniciar a calibração fina do `.set` de produção.
