# EAGOLD — Modularized EA

Repositório de reconstrução modular do EAGOLD em MQL4.

## Estado atual — restauração v0.106

O ponto de entrada `EA/EAGOLD.mq4` foi restaurado para o **baseline operacional autoritativo v0.106** de `sezinando/newbot/EA/EAGOLD.mq4`.

O arquivo restaurado contém novamente o fluxo que efetivamente operava:

- R1 — criação dos primeiros BUY STOP / SELL STOP;
- R1.1 — admission control;
- R4 — realização/reentrada;
- R5 — basket close e recovery;
- R7 — restart/keep-alive;
- R9 — hedge e controle de exposição;
- R10 — redução de exposição e profit-funded pair;
- R10.2 — recovery realization;
- R11 — dynamic recovery step;
- trailing dos pending stops;
- persistência em Global Variables;
- telemetry;
- painel e markers;
- orquestração completa de `OnInit`, `OnDeinit` e `OnTick`.

A identidade do baseline pode ser verificada pelo SHA do conteúdo do arquivo: `187dcfa4fd6d382c7f2ff4b0f555e29b19c2b9d7`.

## Por que esta restauração foi feita

A versão modular anterior tinha apenas a infraestrutura de Context/State/Orders/Execution e um R10 isolado. Ela não possuía nenhuma rotina de entrada; portanto, partindo de um basket vazio, não havia caminho para criar a primeira ordem.

O princípio agora é:

> **Primeiro recuperar o comportamento comprovadamente operacional. Depois modularizar, uma engine por vez, com regressão contra o v0.106.**

## Arquitetura de destino

- `EA/` — ponto de entrada/orquestração;
- `Core/` — estado, inspeção e execução;
- `Engines/` — R1, R4/R5/R7, R9, R10, R10.2 e R11;
- `UI/` — apresentação;
- `Persistence/` — estado durável;
- `Tests/` — regressão;
- `DOCS/` — contratos e rastreabilidade.

Os módulos já existentes permanecem como material de reconstrução. **Não devem substituir o baseline operacional até que cada comportamento tenha sido validado no Strategy Tester.**

## Validação necessária

A compilação final e os testes de execução devem ser realizados no MetaEditor/Strategy Tester MT4. O ambiente GitHub não fornece o compilador MT4, portanto este repositório não declara um `compile PASS` sem essa validação.
