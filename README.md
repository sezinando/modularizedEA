# EAGOLD — Modularized EA

Novo repositório para a reescrita modular do EAGOLD em MQL4.

## Objetivo

Migrar o comportamento validado do EA legado para uma arquitetura modular, mantendo rastreabilidade, contratos explícitos entre módulos e capacidade de validação/regressão.

## Baseline

O EA legado `EAGOLD(2).mq4` será tratado como referência comportamental durante a migração. A implementação modular não deve alterar regras por acidente.

## Arquitetura inicial

- `EA/` — orquestração e ponto de entrada
- `Core/` — contexto, estado, ordens, execução, eventos e telemetria
- `Engines/` — engines R1, R4/R5/R7, R9, R10, R10.2 e R11
- `UI/` — painel e relógios
- `Persistence/` — estado persistente
- `Tests/` — regressão e validação
- `DOCS/` — contratos e arquitetura

## Princípio

**Primeiro preservar comportamento; depois melhorar a arquitetura.**

Toda mudança funcional deve ser identificável e validada separadamente da refatoração estrutural.
