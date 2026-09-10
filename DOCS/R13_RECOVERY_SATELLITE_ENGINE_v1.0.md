# EAGOLD — R13 Recovery Satellite Engine

**Documento:** `R13_RECOVERY_SATELLITE_ENGINE_v1.0.md`  
**Versão:** 1.0  
**Data:** 2026-09-10  
**Status:** proposta arquitetural / não implementada  
**Repositório:** `sezinando/modularizedEA`

---

## 1. Objetivo

Definir uma nova engine candidata do EAGOLD para operar como um **satélite de recuperação** quando o ciclo principal estiver estruturalmente pressionado e o mercado apresentar um regime no qual a máquina principal tenha baixa capacidade de produzir novas oportunidades de recuperação.

A R13 não substitui R10, R10.2, R11 ou BRX. Sua função é potencialmente **gerar P/L independente** em um regime apropriado e transformar parte desse resultado em **Recovery Capital**, que poderá posteriormente financiar uma redução de exposição do Master através do R10.

> **R13 é uma proposta de engenharia. Este documento não autoriza execução real até que a estratégia seja validada por replay/backtest.**

---

# 2. Problema que a R13 pretende resolver

Um ciclo do Master pode chegar a uma condição como:

```text
DD elevado
Preço médio muito distante
Exposição relevante
Mercado entra em consolidação
Novas ordens do Master deixam de ser economicamente úteis
Recuperação do basket fica lenta ou improvável
```

Nesse estado, o mercado pode continuar oferecendo movimentos exploráveis dentro do range, porém esses movimentos não necessariamente permitem que o Master retorne ao seu preço médio.

A R13 investiga a hipótese de utilizar um **motor especializado em consolidação** para produzir lucro realizado enquanto o Master permanece em modo de recuperação.

---

# 3. Conceito central

```text
                         MERCADO
                            │
                            ▼
                     R12 / REGIME
                            │
                     CONSOLIDAÇÃO
                            │
              ┌─────────────┴─────────────┐
              │                           │
              ▼                           ▼
          MASTER                       R13 SATELLITE
       ciclo estressado               especialista
              │                        no regime
              │                           │
              │                           ▼
              │                     P/L realizado
              │                           │
              │                           ▼
              │                  RECOVERY CAPITAL
              │                           │
              └──────────────┬────────────┘
                             ▼
                            R10
                             │
                             ▼
                    redução do Master
```

A premissa é que **o Master não precisa ser excelente em todos os regimes**. Um motor especializado pode explorar um regime diferente e transferir parte do resultado para a camada de recuperação.

---

# 4. Identidade e ownership das ordens

A R13 deve possuir identidade operacional separada do Master.

## 4.1 Comentário obrigatório

Proposta de comentário reservado:

```mql4
#define EAGOLD_RECOVERY_SATELLITE_COMMENT "EAGOLD_RECOVERY_SATELLITE"
```

Toda ordem aberta pela R13 deve carregar esse identificador.

## 4.2 Magic separado

A R13 deve possuir um Magic próprio configurável, por exemplo:

```text
Master Magic    = 3001
Satellite Magic = 3010
```

O número é apenas referência arquitetural; o valor definitivo deve ser definido na implementação.

## 4.3 Regra de isolamento

O Master não deve contabilizar ordens R13 como suas.

A R13 não deve contabilizar ordens do Master como suas.

Isso deve proteger especialmente:

- contagem de posições;
- lotes;
- P/L direcional;
- exposição;
- R9;
- R10;
- R10.2;
- R11;
- BRX;
- lifecycle/restart.

### Regra importante

O comentário deve ser uma segunda camada de identificação, não a única barreira de segurança. A implementação deve preferir **Magic + símbolo + comentário/ownership** quando houver informação suficiente.

---

# 5. Modos de acionamento

A R13 deve possuir dois modos de ativação.

## 5.1 Automático

O próprio EAGOLD pode sugerir ou, posteriormente, autorizar a ativação quando as condições forem satisfeitas.

Fluxo:

```text
R12 = RANGE / CONSOLIDATION
        +
Master stressed
        +
Recovery opportunity insuficiente
        +
R13 risk checks OK
        ↓
R13 SUGGESTED
        ↓
R13 ACTIVE (somente se auto activation estiver habilitado)
```

Primeira versão recomendada:

```text
EnableR13AutoActivation = false
```

Assim a classificação pode ser validada antes de permitir execução automática.

## 5.2 Manual

O operador pode solicitar a ativação mesmo quando não houver sugestão automática.

Exemplo conceitual:

```text
R13 MANUAL ACTIVATION
```

A ativação manual **não elimina os hard constraints de risco**.

---

# 6. Máquina de estados proposta

```text
OFF
 │
 ▼
ELIGIBLE
 │
 ▼
SUGGESTED
 │
 ├──────────────► BLOCKED
 │
 ▼
AUTHORIZED
 │
 ▼
ACTIVE
 │
 ▼
PAUSING
 │
 ▼
STOPPED
```

Possíveis significados:

- **OFF:** engine desabilitada.
- **ELIGIBLE:** condições preliminares atendidas.
- **SUGGESTED:** EAGOLD identificou oportunidade.
- **AUTHORIZED:** ativação permitida pelos controles.
- **ACTIVE:** Satellite pode operar.
- **PAUSING:** novas entradas bloqueadas; posições podem ser gerenciadas.
- **STOPPED:** engine encerrada para o ciclo.
- **BLOCKED:** oportunidade detectada, mas algum hard constraint impede execução.

---

# 7. Contrato da engine

Seguindo o padrão de contratos do EAGOLD:

| Boundary | R13 |
|---|---|
| **INPUT** | regime, estado do Master, exposição, DD, parâmetros R13, mercado |
| **STATE READ** | estado do Master, R12, condições de mercado, próprias ordens |
| **DECISION** | elegibilidade, ativação, entradas/saídas e alocação de lucro |
| **ACTION** | abertura/fechamento exclusivamente de ordens Satellite |
| **OUTPUT** | estado R13, posições, P/L, capital elegível |
| **EVENT** | ativação, entrada, saída, bloqueio, stop, geração de capital |

A R13 não deve alterar diretamente o estado proprietário do R10.

---

# 8. Estratégia do Satellite

A estratégia específica ainda deve ser pesquisada e validada.

A hipótese inicial é um motor especializado em **consolidação/range**, e não uma cópia do algoritmo do Master.

Possível estrutura:

```text
Range detection
      ↓
Range boundaries
      ↓
Entry candidate
      ↓
Position management
      ↓
Profit realization
```

A estratégia poderá utilizar posteriormente filtros como:

- ATR;
- amplitude do range;
- persistência de range;
- distância da borda do range;
- volatilidade relativa;
- spread;
- horário;
- estrutura de máximas/mínimas.

Nenhum desses filtros deve ser considerado definitivo antes de teste.

---

# 9. Recovery Capital Ledger

Este é o componente central que diferencia a proposta R13 de um simples EA de recuperação.

O lucro da Satellite deve ser contabilizado separadamente.

Exemplo:

```text
R13 SATELLITE

Gross Profit              +120.00
Trading Costs               -8.00
Net Profit                 +112.00

Eligible Recovery Capital  +80.00
Reserve                     +32.00

R10 Consumed                -50.00
Remaining Capital           +30.00
```

Os percentuais de alocação não devem ser definidos por antecipação. Devem ser parâmetros de teste.

---

# 10. Por que não transferir simplesmente 100% do lucro?

Porque isso pode criar um segundo ciclo de risco:

```text
Satellite ganha
     ↓
Master recebe tudo
     ↓
Master reduz exposição
     ↓
Mercado continua adverso
     ↓
Master perde novamente
```

A R13 deve possuir limites próprios e o capital elegível precisa ser definido por uma política de alocação testável.

---

# 11. Relação com R10

A R13 **não deve decidir qual posição do Master será reduzida**.

Ela produz um recurso econômico:

```text
Satellite P/L
      ↓
Recovery Capital
```

O R10 continua sendo responsável por avaliar a redução:

```text
Recovery Capital disponível
          ↓
R10 Candidate
          ↓
Simulation
          ↓
Hard Constraints
          ↓
Lexicographic Rank
          ↓
Reduction
```

Isso preserva a separação de responsabilidades.

---

# 12. Exemplo operacional

Master:

```text
BUY exposure       2.80 lots
Average price      4325.40
Current price      4318.20
Master P/L        -1,200
```

R12:

```text
REGIME = RANGE
```

Master não possui uma nova oportunidade eficiente de Grid.

R13 é ativada.

Durante o range:

```text
Trade 1       +18
Trade 2       +12
Trade 3       +22
Trade 4       +15
Trade 5       +11
```

Net R13:

```text
+$78
```

Recovery Capital elegível:

```text
+$50
```

O R10 recebe uma oportunidade econômica de redução de até o limite autorizado e escolhe a ação que apresentar melhor resultado dentro dos hard constraints.

---

# 13. Hard constraints da R13

Mesmo quando ativada manualmente, a Satellite deve respeitar:

- máximo de lotes;
- máximo de posições;
- máximo de drawdown próprio;
- perda máxima por ciclo;
- perda máxima diária;
- spread máximo;
- margem mínima;
- horário permitido;
- limite de duração;
- estado do Master;
- estado do mercado;
- permissão de negociação;
- integridade de ownership das ordens.

A R13 nunca deve ser autorizada a aumentar indefinidamente o risco apenas porque o Master está em drawdown.

---

# 14. Regra: Satellite deve morrer antes do Master

O Satellite é um auxiliar de recuperação.

Portanto, seus limites devem ser significativamente menores que o risco que se pretende solucionar.

Conceito:

```text
Master DD máximo      = X
Satellite DD máximo   = fração de X
```

Se a R13 começar a consumir capital de forma persistente, ela deve ser desligada em vez de receber mais risco para tentar compensar o Master.

---

# 15. Integração com R12

A integração recomendada é:

```text
R12
 │
 ├── RANGE       → candidato R13
 ├── TREND       → normalmente R13 OFF
 ├── HIGH_VOL    → normalmente R13 OFF
 └── EXTREME     → R13 OFF / proteção
```

Essas associações são hipóteses e devem ser validadas empiricamente.

A R13 não deve depender de R12 na primeira implementação se isso impedir testes isolados. Deve ser possível ativá-la manualmente para pesquisa.

---

# 16. Integração com o Master

A R13 deve observar, no mínimo:

- Master ativo/inativo;
- ciclo atual;
- direção pesada;
- exposição líquida;
- exposição bruta;
- preço médio;
- distância até o preço médio;
- P/L;
- recovery debt;
- recovery level;
- existência de pending orders úteis;
- estado R10;
- estado BRX;
- regime R12.

A comunicação deve ser somente de informação/coordenação. A R13 não deve manipular diretamente as variáveis internas proprietárias das outras engines.

---

# 17. Segurança contra contaminação entre engines

O maior risco arquitetural inicial é a mistura das ordens.

Exemplo que deve ser impossível:

```text
R13 abre BUY 0.20
       ↓
R9 contabiliza +0.20
       ↓
R10 interpreta +0.20 como exposição Master
```

Da mesma forma:

```text
Master abre BUY
       ↓
R13 contabiliza como Satellite
```

Todos os enumeradores de ordens usados pela R13 devem possuir filtros próprios de ownership.

A eventual evolução do atual modo `MagicNumber=-1` deve preservar a semântica de escopo e impedir que Satellite seja absorvida pelo universo do Master.

---

# 18. Persistência

A R13 deverá possuir estado persistente próprio, incluindo no mínimo:

- ciclo R13;
- estado atual;
- activation mode;
- timestamp de ativação;
- Satellite P/L realizado;
- custos;
- Recovery Capital gerado;
- Recovery Capital alocado;
- Recovery Capital consumido;
- capital restante;
- peak profit;
- drawdown próprio;
- número de operações;
- motivo de parada.

A persistência deve ser separada do estado econômico proprietário do Master.

---

# 19. Telemetria e auditoria

Cada ação material deve ser reconstruível.

Eventos sugeridos:

```text
R13_SUGGESTED
R13_AUTHORIZED
R13_BLOCKED
R13_ACTIVATED
R13_ENTRY
R13_EXIT
R13_PROFIT_REALIZED
R13_CAPITAL_ALLOCATED
R13_CAPITAL_CONSUMED
R13_PAUSED
R13_STOPPED
R13_RISK_BLOCK
```

Cada evento deve, quando aplicável, registrar:

- action ID;
- timestamp;
- symbol;
- master cycle ID;
- Master Magic;
- Satellite Magic;
- comment/ownership;
- ticket;
- lots;
- entry/exit;
- realized P/L;
- capital antes/depois;
- motivo da decisão;
- status de execução;
- error code.

---

# 20. Modos de desenvolvimento

## Fase 1 — Observer

Nenhuma ordem real.

Registrar:

- quando R13 teria sido elegível;
- range detectado;
- entradas hipotéticas;
- saídas hipotéticas;
- P/L hipotético;
- drawdown hipotético;
- Recovery Capital hipotético.

## Fase 2 — Satellite isolada

R13 pode operar com Magic próprio, mas não transfere capital ao Master.

Objetivo: provar que o motor é economicamente viável no regime-alvo.

## Fase 3 — Recovery Capital simulado

R13 real + R10 counterfactual.

Registrar:

```text
R13 P/L
↓
capital disponível
↓
qual R10 reduction teria sido escolhida?
↓
impacto no Master
```

## Fase 4 — Integração controlada

Somente após evidência suficiente:

```text
R13
 ↓
Recovery Capital
 ↓
R10
```

---

# 21. Testes obrigatórios

Comparar pelo menos:

### A — Master sozinho

Baseline atual.

### B — Master + R13

Satellite opera, mas seu lucro não é utilizado pelo Master.

### C — Master + R13 + Recovery Capital

Lucro elegível da R13 alimenta o R10.

Métricas:

- lucro líquido;
- profit factor;
- drawdown máximo;
- drawdown médio;
- duração dos ciclos;
- número de ciclos encerrados;
- exposição máxima;
- lote máximo;
- Recovery Debt;
- P/L R13;
- capital gerado;
- capital consumido;
- quantidade de reduções R10;
- margem mínima;
- número de bloqueios;
- custo operacional;
- frequência de parada da Satellite.

---

# 22. Hipóteses que precisam ser comprovadas

1. Consolidação realmente produz oportunidades suficientemente frequentes para a R13.
2. O P/L da R13 possui expectativa positiva após custos.
3. A R13 não aumenta materialmente o risco global.
4. O Recovery Capital melhora a capacidade do R10 de reduzir exposição.
5. A redução financiada melhora o ciclo do Master.
6. O benefício permanece em diferentes pregões e condições de volatilidade.
7. O resultado não depende de poucos casos extremos.
8. O sistema combinado não transforma perdas do Master em perdas duplas.

---

# 23. Abordagens semelhantes encontradas na comunidade

A pesquisa realizada identificou componentes próximos, mas não uma implementação claramente equivalente à composição completa desta proposta.

Precedentes relevantes incluem:

- Recovery EA operando sobre posições de outro EA por Magic Number.
- Sistemas de recovery que usam Magic específico para identificar posições problemáticas.
- Sistemas que utilizam ordens lucrativas para financiar o fechamento de ordens perdedoras.
- Sistemas multi-basket com identificação independente.
- Grid/Hedge/Recovery com módulos especializados.

A proposta R13 combina esses conceitos com uma camada de **regime + Satellite + Recovery Capital + R10**, cuja equivalência direta não foi identificada na pesquisa realizada.

Isso deve ser tratado como uma hipótese arquitetural, não como alegação de originalidade ou vantagem.

---

# 24. Relação com as demais engines

```text
R12
Market Regime
   │
   │ identifica condição
   ▼
R13
Recovery Satellite
   │
   │ produz P/L
   ▼
Recovery Capital
   │
   ▼
R10.2
Accounting
   │
   ▼
R10
Exposure Reduction
   │
   ▼
BRX / Master Lifecycle
```

Responsabilidades:

- **R12:** classificar regime.
- **R13:** explorar regime através de estratégia própria.
- **R10.2:** manter accounting de recuperação.
- **R10:** decidir e executar redução de exposição.
- **BRX/R4/R7:** continuar responsáveis pelo lifecycle e realização do Master.

---

# 25. Não objetivos

A R13 não deve:

- substituir o Master;
- duplicar R10;
- aumentar exposição do Master para criar uma redução artificial;
- misturar ordens Satellite com o basket Master;
- usar o Master como fonte ilimitada de margem;
- permanecer ativa indefinidamente para recuperar prejuízo próprio;
- ser considerada válida apenas por gerar lucro em um único replay.

---

# 26. Critério para promoção a produção

R13 somente deve sair de proposta para implementação operacional depois de:

```text
Observer
   ↓
Counterfactual
   ↓
Satellite isolada
   ↓
A/B
   ↓
Robustez
   ↓
Risk review
   ↓
Integração controlada
```

A decisão deve ser baseada em evidência estatística e operacional.

---

# 27. Status

**R13 Recovery Satellite Engine — PROPOSTA ARQUITETURAL v1.0**

Não implementada.

Próxima etapa recomendada:

1. definir o contrato mínimo de ownership;
2. estudar/selecionar uma estratégia de consolidação já validada;
3. construir versão observer-only;
4. medir P/L hipotético por regime;
5. somente então criar a engine executável.

---

## Princípio final

> **A Satellite não existe para "salvar" uma operação perdida. Ela existe para explorar uma oportunidade independente de mercado e, somente quando economicamente comprovado, transformar parte desse resultado em capital para reduzir o risco do ciclo principal.**
