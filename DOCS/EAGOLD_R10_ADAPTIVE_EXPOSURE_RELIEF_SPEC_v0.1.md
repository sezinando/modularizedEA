# EAGOLD R10 — Adaptive Exposure Relief Specification v0.1

## Objetivo

Evoluir o R10 de uma redução predominantemente condicionada a lucro disponível para um mecanismo de **Exposure Reduction orientado por estado**, capaz de aliviar exposição acumulada durante ciclos longos e estressados sem transformar o EAGOLD em um recovery EA e sem forçar fechamento indiscriminado de posições perdedoras.

## Evidência operacional

Um ciclo recente observado no terminal apresentou aproximadamente:

- BUY: 5,08 lots
- SELL: 6,42 lots
- GROSS: 11,50 lots
- NET: 1,34 lot SELL
- DD: aproximadamente -9.838,74
- DD relativo observado: aproximadamente 24,46%
- duração: aproximadamente um dia dentro do mesmo ciclo

O estado demonstra que **neutralização direcional não equivale a redução de risco econômico**: o net exposure estava relativamente pequeno diante de 11,50 lots gross.

## Diagnóstico do R10 atual

O R10 atual contém:

1. Profit-Funded Pair Reduction;
2. Balanced Reduction;
3. Average Adjustment;
4. cooldown;
5. limites de exposição.

Porém, a decisão atual ainda depende fortemente de condições chamadas pelas máquinas de basket. Portanto, um ciclo pode permanecer com gross exposure elevada e DD elevado sem encontrar uma janela de redução compatível com o fluxo normal de R10.

Além disso, os caminhos booleanos legados de redução podem executar uma perna e falhar na segunda. A evolução deve preservar o Action Contract e tratar PARTIAL como estado transacional que interrompe o tick para reconciliação.

## Princípio da nova decisão

Não usar:

    DD > limite -> fechar posição

Usar:

    ESTADO DE ESTRESSE
        +
    OPORTUNIDADE ECONÔMICA DE REDUÇÃO
        +
    CANDIDATO COMPATÍVEL COM O BALANCEAMENTO
        +
    COOLDOWN / HISTERESIS
        -> R10 REDUCE

## Estado de exposição

A cada avaliação, calcular:

- BUY_LOTS
- SELL_LOTS
- GROSS_LOTS = BUY_LOTS + SELL_LOTS
- NET_LOTS = abs(BUY_LOTS - SELL_LOTS)
- direção dominante
- floating basket P/L
- cycle age
- cycle DD / worst equity
- densidade de recovery
- R12 regime
- distância desde a última redução

A prioridade é separar explicitamente **gross exposure**, **net exposure** e **floating DD**.

## Estados propostos

### R10_NORMAL

Exposição e duração normais. Não procurar redução adaptativa.

### R10_TENSION

Exposição ou duração acima do normal. Continuar observando, sem fechamento forçado.

### R10_RELIEF_ELIGIBLE

O ciclo está suficientemente estressado e existe candidato economicamente aceitável para reduzir gross exposure.

### R10_RELIEF_EXECUTING

Uma redução transacional foi autorizada e está sendo executada.

### R10_RECONCILIATION

Uma ação parcial ou estado ambíguo ocorreu. Nenhuma nova ação econômica deve ser tomada até reconciliação.

### R10_COOLDOWN

Uma redução foi concluída; aguardar o intervalo configurado antes de procurar outra.

## Candidato de relief

A seleção inicial deve ser conservadora:

1. posição EAGOLD de mercado;
2. lote parcial compatível com o lote mínimo;
3. posição preferencialmente lucrativa;
4. fechamento parcial deve reduzir gross exposure;
5. não deve aumentar desnecessariamente o net exposure;
6. não pode violar R9/R11 ou o envelope de risco;
7. deve respeitar cooldown;
8. deve registrar motivo e estado antes da execução.

A prioridade não é fechar o maior lucro absoluto. É maximizar **redução de risco econômico por unidade de custo de realização**.

## Relief Score — proposta inicial

O score não deve autorizar execução nesta etapa. Ele serve inicialmente para pesquisa e observabilidade.

Dimensões:

- stress de gross exposure;
- stress de DD;
- idade do ciclo;
- recuperação acumulada;
- contribuição do ticket para o imbalance;
- lucro atual do ticket;
- R12 regime;
- tempo desde última redução.

O score deve ser determinístico e reproduzível no histórico.

## Counterfactual obrigatório

Antes de habilitar execução adaptativa, cada oportunidade deve poder ser simulada como:

    estado T0
      |
      +-- sem relief -> trajetória original
      |
      +-- relief 0,01 -> trajetória hipotética
      +-- relief 0,02 -> trajetória hipotética
      +-- relief 0,03 -> trajetória hipotética

Medir para cada hipótese:

- max DD;
- max gross exposure;
- max net exposure;
- duração do ciclo;
- realized P/L;
- terminal economic equity;
- custo do relief;
- recuperação posterior;
- número de ações;
- quantidade de ciclos beneficiados/prejudicados.

Não usar informação futura para decidir o instante T0. Informação futura só pode ser usada para avaliar o resultado do counterfactual.

## Limitação atual dos dados

O arquivo histórico de eventos atualmente disponível para análise contém 1.211 eventos em 221 ciclos, mas seu `GROSS_LOTS_MAX` máximo observado é inferior a 1,00 lot. Portanto ele **não é suficiente para validar o caso recente de 11,50 lots gross**.

A validação desse caso exige um novo `EAGOLD_COUNTERFACTUAL_PATH.csv` produzido pelo build atual, com R9/R10/R11 habilitados e contendo a trajetória ticket-level do ciclo observado.

Não ajustar parâmetros nem habilitar execução adaptativa com base apenas no arquivo antigo.

## Integração arquitetural

A implementação final deve seguir:

    R12 / MAIA
         |
         v
    R10 State Evaluation
         |
         v
    Relief Candidate
         |
         v
    Economic Authorization
         |
         v
    Action Contract
         |
         v
    Transactional R10 Adapter
         |
         v
    Broker

R9 continua responsável pelo controle/hedge de exposição direcional.
R11 continua responsável por governar nova exposição de recovery.
R10 passa a ser responsável pela redução econômica da exposição existente.
R13 não deve ser convertido em mecanismo genérico de redução de DD.

## Acceptance Criteria — Phase 1

1. Observer calcula gross/net/DD/cycle age sem enviar ordens.
2. Observer identifica candidatos de relief determinísticos.
3. Counterfactual registra todas as oportunidades elegíveis.
4. Nenhuma execução ocorre com `EnableAdaptiveProfitGuardExecution=false`.
5. Qualquer ação parcial entra em `HALT_FOR_RECONCILIATION`.
6. Nenhuma redução aumenta gross exposure.
7. Nenhuma redução é autorizada somente porque DD ultrapassou um limite.
8. Validação deve demonstrar redução de cauda de DD ou de gross exposure sem degradação material do resultado econômico.

## Phase 2 — somente após validação

- adapter transacional R10;
- partial reduction real;
- break-even do restante quando aplicável;
- cooldown/hysteresis calibrados;
- integração com R12;
- runtime regression;
- replay histórico multi-pregão;
- somente então considerar habilitação controlada.
