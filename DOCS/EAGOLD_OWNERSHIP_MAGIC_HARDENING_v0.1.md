# EAGOLD — Ownership / Magic Hardening v0.1

## Objetivo

Eliminar o modo de ownership `MagicNumber=-1` (ALL SYMBOL ORDERS) do EAGOLD Master e estabelecer uma fronteira determinística de propriedade:

```text
EAGOLD Master = Symbol + MagicNumber
R13           = Symbol + R13MagicNumber
``` 

O comentário da ordem é apenas observacional e não participa da identificação de propriedade.

## Implementação v0.112

- `Core/EAGOLD_Config.mqh`
  - `MagicNumber` passa de `-1` para `1101`.
  - `RequireCleanLegacyOwnership=true` por padrão.
  - versão EAGOLD `0.112`.
- `Core/EAGOLD_Orders.mqh`
  - `IsEAGOLDOrder()` aceita somente o Magic dedicado do Master.
  - `MagicNumber<=0` é rejeitado.
  - colisão Master/R13 é rejeitada.
  - ordens abertas do símbolo com `MagicNumber=-1` são detectadas como legado inseguro.
  - `EAGOLDValidateOwnershipConfiguration()` bloqueia o startup quando existe ownership legado inseguro.
- `EA/EAGOLD.mq4`
  - `OnInit()` executa a validação de ownership antes de `R9SeedExistingPositions()` e antes de `CreateFirstOrdersIfFlat()`.
  - falha de ownership retorna `INIT_FAILED`, impedindo que o EA inicie um novo ciclo sob identidade ambígua.

## Regra de migração

A mudança para Magic dedicado **não tenta adivinhar quais ordens com Magic=-1 pertencem ao EAGOLD**. Isso seria incompatível com o objetivo de isolamento quando outro EA ou operação manual usa o mesmo símbolo.

Portanto:

1. Não instalar o v0.112 sobre um basket ativo que ainda utilize `Magic=-1`.
2. Isolar/encerrar o legado `Magic=-1` de forma controlada.
3. Confirmar que não restam ordens abertas do símbolo com `Magic=-1`.
4. Instalar o v0.112 com `MagicNumber=1101`, ou alterar esse valor para um identificador dedicado e não utilizado na conta.
5. Confirmar no terminal que as novas ordens do Master recebem `Magic=1101` e que R13 continua em `Magic=3010`.
6. Somente depois iniciar a validação de execução.

## Por que o bloqueio é deliberado

Antes desta correção, `MagicNumber=-1` fazia `IsEAGOLDOrder()` tratar todas as ordens do símbolo como pertencentes ao Master, exceto R13. Isso permitia que contagem, exposição, realização, fechamento e demais rotinas operassem sobre ordens externas.

O v0.112 prefere **não operar** a operar com ownership ambíguo.

## Validação pendente

O GitHub não fornece MetaEditor/MT4. Portanto este documento não declara compile/runtime PASS. Após o checkout no MT4, validar:

- compilação sem erro;
- startup com conta limpa;
- criação das primeiras ordens com Magic dedicado;
- coexistência com R13=3010;
- coexistência com outro EA/manual no mesmo símbolo;
- bloqueio correto quando existir legado `Magic=-1`;
- reinício com posições EAGOLD do Magic dedicado;
- ausência de gerenciamento de ordens externas.
