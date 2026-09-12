# EAGOLD — Future Research Base v1.0

**Status:** RESEARCH / FUTURE ROADMAP  
**Operational impact:** NONE  
**Baseline protection:** EAGOLD v0.106 remains the operational reference until each future capability is independently validated.  
**Scope:** Consolidated external research and internal architectural directions to guide future EAGOLD development.

---

## 1. Purpose

This document consolidates research directions identified for future EAGOLD development. It is a **research base**, not an implementation authorization.

The principal rule is:

> **Research may influence the roadmap; only validated implementation may influence the operational baseline.**

The current project architecture explicitly prioritizes restoration and regression against the operational v0.106 before replacing validated behavior. fileciteturn964file0L2-L2

---

## 2. Architecture and Design Patterns

### 2.1 Modular architecture reference — Fintor-AI / WealthPole

The Fintor-AI WealthPole architecture is retained as an external reference for modular Grid/Hedge systems, especially:

- separation of UI, inputs and core logic;
- modular engines;
- testability;
- explicit risk-aware hooks;
- resilient execution architecture.

This is a **reference pattern**, not a requirement to copy the external implementation.

### 2.2 EAGOLD architectural principle

Future modules should preserve the separation already established in the project:

```text
EA / Orchestration
        ↓
Core / State + Orders + Execution
        ↓
Engines / Strategy and Risk Decisions
        ↓
UI / Presentation
        ↓
Persistence / Durable State
        ↓
Tests + Docs / Validation and Audit
```

The current repository already documents this destination architecture and explicitly protects the v0.106 baseline until modular behavior is validated. fileciteturn964file0L2-L2

---

## 3. Persistence and Resilience

### Research direction

Prefer **state reconstruction from broker/server state** whenever the state can be deterministically derived from:

- open positions;
- pending orders;
- Magic Number ownership;
- order history;
- current market data.

Persistent storage should be reserved for state that cannot be reconstructed reliably, including candidates such as:

- sequence levels that are not derivable from surviving order/history state;
- adaptive learning state;
- experience memory;
- model metadata;
- long-term analytical aggregates;
- risk checkpoints that intentionally survive restarts.

### Design principle

> **Persistence should be the exception, not the primary source of truth.**

This direction is especially relevant to the current `PersistenceWorstEquityStep` mechanism: it should remain narrowly scoped to non-reconstructible durable state rather than becoming a generic state cache.

### Research references

- MQL5 community discussion on robust EA state persistence and reconstruction.
- MQL5 article: *Keeping Memory Across Restarts: EA State Persistence Using Binary Files*.

These references support investigation; they do not override the current EAGOLD persistence contract.

---

## 4. R12 — Market Regime Detection

R12 is retained as a **high-priority future research layer**.

The preferred conceptual role is not merely observation, but **regime-aware gating** of permitted Grid/Hedge behavior.

### 4.1 Candidate regime dimensions

The future classifier may combine:

- direction;
- trend strength;
- volatility;
- market structure;
- price/location context;
- basket state;
- liquidity context.

A candidate state set remains:

```text
S0  UNKNOWN / INSUFFICIENT DATA
S1  BULLISH TREND
S2  BEARISH TREND
S3  BULLISH PULLBACK
S4  BEARISH PULLBACK
S5  HIGH-VOLATILITY EXPANSION
S6  LOW-VOLATILITY CONSOLIDATION
S7  TRANSITION BULLISH
S8  TRANSITION BEARISH
S9  EXHAUSTION / EXTENSION
S10 CONFLICT / INDETERMINATE
```

These states remain hypotheses and must be tested against historical data before becoming operational labels. The MAIA research document already defines this state-machine concept and assigns M5 as the primary regime timeframe, with M1 for execution/microstructure and M15 for macro confirmation. fileciteturn961file0L2-L2

### 4.2 Multi-timeframe hierarchy

Proposed responsibility:

```text
M1  = execution / microstructure
M5  = primary regime
M15 = macro confirmation
```

Future implementation must prevent independent timeframe logic from modifying the same decision without an explicit hierarchy. fileciteturn961file0L2-L2

### 4.3 Regime-aware Grid/Hedge research

The Taranto / Bi-Directional Grid Constrained research direction is retained because it raises a critical structural question:

> Can Grid/Hedge operation remain bounded and restartable only when admission and continuation are conditioned on market regime?

Future EAGOLD R12 research should investigate, at minimum:

- finite and restartable operational cycles;
- regime-aware admission gates;
- dynamic spacing;
- exposure-aware sizing;
- structural-break detection;
- explicit behavior for ranging versus trending conditions.

This should be treated as a **risk-control research program**, not as an automatic optimization objective.

---

## 5. Entropy and Statistical Regime Signals

Shannon entropy and entropy-derived volatility measures are retained as candidate signals for R12.

Potential uses include:

- distinguishing compression from expansion;
- measuring information disorder/change;
- identifying transitions that ATR or moving averages may recognize later;
- conditioning recovery/grid behavior.

Research references:

- MQL5 work on market entropy and information theory;
- entropy-based adaptive volatility research.

The first implementation, if ever authorized, should be an **observer** whose outputs are logged and validated before they become a gate.

---

## 6. CUSUM — Structural Break Detection

CUSUM is retained as a candidate change-detection mechanism for R12.

Research objective:

```text
Stable regime
     ↓
CUSUM detects structural change
     ↓
R12 reassesses regime
     ↓
Risk gate evaluates whether continuation is permitted
```

The key hypothesis is that a structural-break detector may react to regime change earlier than slower volatility/trend aggregates.

CUSUM must therefore be evaluated on:

- false-positive rate;
- detection delay;
- behavior around news/spikes;
- persistence after transient shocks;
- incremental predictive value versus existing features.

---

## 7. BRX — Basket Realization and Safety Buffer

### 7.1 Current lesson

The project identified an internally discovered critical risk: a nominal Lifecycle realization floor could bypass the intended BRX safety buffer.

This finding is retained as a **first-class architectural lesson**:

> **Protection constraints must be enforced at every execution path, not only inside the primary engine.**

### 7.2 Future BRX research

Retain the following future directions:

- basket trailing;
- virtual trailing at basket level;
- profit protection after favorable expansion;
- partial realization;
- runner allocation;
- explicit economic reconciliation after partial close.

The future implementation must preserve the principle that declared economic safeguards are enforced consistently across BRX, Lifecycle, R10 and any other execution path.

The current MAIA architecture independently identifies the same profit-capture problem through MFE/MAE and profit asymmetry research. fileciteturn961file0L2-L2

---

## 8. R13 — Ownership and Isolation

R13 remains an isolated operational domain.

The architectural rule retained from community practice is:

```text
EAGOLD master orders
        ≠
R13 satellite orders
```

Isolation must be explicit through:

- Symbol;
- Magic Number;
- ownership filters;
- execution-path exclusions.

In particular, wildcard ownership behavior such as `MagicNumber=-1` must never unintentionally absorb R13 orders.

This should remain a regression item whenever order-inspection or ownership code changes.

---

## 9. MAIA — Experience Memory and Adaptive Intelligence

The existing MAIA document remains the principal detailed research specification for adaptive intelligence. Its explicit status is **FUTURE IMPLEMENTATION / RESEARCH**, with no authorization to alter the current baseline. fileciteturn961file0L2-L2

### 9.1 Core research loop

```text
MARKET STATE
      ↓
ACTION
      ↓
RESULT
      ↓
LEARNING
```

The desired knowledge model must capture more than final P&L. Candidate measurements include:

- MFE — Maximum Favorable Excursion;
- MAE — Maximum Adverse Excursion;
- final P&L;
- duration;
- exposure;
- regime;
- action;
- confidence;
- model version.

The MAIA specification explicitly frames experience as State → Action → Result and treats MFE/MAE as critical for detecting profit-capture failure. fileciteturn961file0L2-L2

### 9.2 Learning hierarchy

The preferred sequence remains:

```text
1. Data Collection
2. Experience Memory
3. Regime Classification
4. Statistical Performance Matrix
5. Time-Decay Adaptation
6. Controlled Action Selection
7. Contextual Bandit
8. Advanced ML / Reinforcement Learning
```

This sequence deliberately moves from deterministic/auditable behavior toward adaptive behavior. fileciteturn961file0L2-L2

### 9.3 Contextual Bandit reference

The *Queen of Gold UCB Agents* architecture is retained as a research reference for a later contextual-bandit phase, especially the concept of:

```text
Context → Action → Reward
```

Potential context fields include regime, spread, volume, tick-flow and account health.

No external EA behavior is to be copied into EAGOLD without independent specification, testing and validation.

### 9.4 Persistent experience memory

Future MAIA memory may use:

```text
CSV / historical store
        ↓
LOAD
        ↓
RAM / in-memory knowledge
        ↓
REAL-TIME DECISION
        ↓
NEW EXPERIENCE
        ↓
RAM UPDATE
        ↓
PERIODIC PERSISTENCE
```

The research rule is explicit: **do not read historical CSV data on every market tick**. The MAIA specification already defines this architecture. fileciteturn961file0L2-L2

Candidate persistent stores remain:

- `MAIA_EXPERIENCES.csv`
- `MAIA_REGIMES.csv`
- `MAIA_ACTIONS.csv`
- `MAIA_PERFORMANCE.csv`
- `MAIA_MODEL.csv`
- `MAIA_EVENTS.csv`

### 9.5 Safety envelope

MAIA must remain subordinate to hard risk constraints.

Required future controls include:

- hard exposure limits;
- drawdown limits;
- position/recovery limits;
- parameter deviation limits;
- confidence gates;
- stability gates;
- model versioning;
- rollback;
- baseline fallback.

The key principle is:

> **MAIA chooses among permitted actions; it does not redefine the risk envelope.**

The MAIA document explicitly establishes this distinction. fileciteturn961file0L2-L2

---

## 10. Inputs and Traceability

The current input-audit work remains a methodological reference for future development.

A declared input must not be considered operational merely because it exists in the configuration.

Every future parameter should be traceable to:

```text
Input
 ↓
Code path
 ↓
Condition
 ↓
Execution effect
 ↓
Test case
 ↓
Evidence
```

This methodology is especially important for adaptive systems, where a parameter may become active only under specific regimes or safety conditions.

---

## 11. Test Strategy for Future Research

Future research modules should enter the EAGOLD project through staged validation:

```text
RESEARCH
   ↓
OBSERVER
   ↓
TELEMETRY
   ↓
OFFLINE ANALYSIS
   ↓
CONTROLLED BACKTEST
   ↓
REGRESSION
   ↓
PAPER / DEMO
   ↓
LIVE-VALIDATED
   ↓
OPERATIONAL AUTHORIZATION
```

A research capability should not become an execution gate simply because its backtest appears profitable.

The existing project documentation already requires final compilation and execution validation in MetaEditor/Strategy Tester and does not declare compile PASS from GitHub alone. fileciteturn964file0L2-L2

---

## 12. Proposed Future Architecture

The combined research suggests the following future stack:

```text
                 ┌──────────────────────┐
                 │     MAIA / R12       │
                 │ Regime + Experience  │
                 └──────────┬───────────┘
                            │
                     Allowed Actions
                            │
                 ┌──────────▼───────────┐
                 │   Risk / Admission   │
                 │ R1 / R9 / R11 / etc. │
                 └──────────┬───────────┘
                            │
                 ┌──────────▼───────────┐
                 │   Execution Engines  │
                 │ R4 R5 R7 R10 BRX R13 │
                 └──────────┬───────────┘
                            │
                 ┌──────────▼───────────┐
                 │   Observation / Log  │
                 │ State Action Result   │
                 └──────────┬───────────┘
                            │
                 ┌──────────▼───────────┐
                 │ Experience / History │
                 └──────────────────────┘
```

The critical architectural dependency is that **MAIA/R12 advises within a predefined operational envelope** rather than directly overriding execution safety mechanisms.

---

## 13. Priority Backlog

### Priority A — Immediate research foundation

1. Preserve baseline and regression discipline.
2. Complete economic/ownership/lifecycle audits.
3. Improve observability and action/event telemetry.
4. Define a canonical experience record.

### Priority B — R12 observer

1. M5 primary regime classifier.
2. M1/M15 contextual roles.
3. Volatility and structure features.
4. CUSUM change detector.
5. Optional entropy feature.
6. Offline regime-quality evaluation.

### Priority C — Experience memory

1. Raw event/experience capture.
2. MFE/MAE measurement.
3. Regime × action matrix.
4. Time-decay analytics.
5. Model/version metadata.

### Priority D — Controlled adaptation

1. Action scoring.
2. Confidence gate.
3. Stability gate.
4. Bounded policy changes.
5. Baseline fallback.
6. Contextual bandit research.

### Priority E — Advanced research

1. Basket trailing / runner.
2. Advanced ML.
3. Reinforcement learning.
4. More sophisticated structural-break models.

---

## 14. Non-Goals

This document does **not** authorize:

- modification of EAGOLD v0.106 behavior;
- automatic parameter optimization in production;
- autonomous lot escalation by ML;
- removal of existing hard risk limits;
- replacing deterministic engines with black-box models;
- treating backtest profitability as proof of production safety.

---

## 15. External Research References

### Architecture
- Fintor-AI: WealthPole architecture and related modular trading repositories.
- MQL5 forum: architecture/persistence discussion, `mql5.com/pt/forum/510378`.
- MQL5 article: *Keeping Memory Across Restarts: EA State Persistence Using Binary Files*, `mql5.com/en/articles/22277`.

### Regime detection
- MQL5: *Building a Custom Market Regime Detection System: Indicator*, `mql5.com/en/articles/17737`.
- MQL5: *Building a Custom Market Regime Detection System: Expert Advisor*, `mql5.com/en/articles/17781`.
- MQL5: *Developing Market Entropy Indicator: Trading System Based on Information Theory*, `mql5.com/en/articles/22220`.

### Grid / risk / structural break
- MQL5: *Building a Research-Grounded Grid EA in MQL5: Why Most Grid EAs Fail and What Taranto Proved*, `mql5.com/en/articles/21833`.
- Aldo Taranto PhD research: *Bi-directional Grid Constrained Stochastic Processes and their Applications in Mathematical Finance*.
- MQL5: *Grid and martingale: what are they and how to use them?*, `mql5.com/en/articles/8390`.

### Basket / trailing
- MQL5: *Zone Recovery with Trailing and Basket Logic*, `mql5.com/en/articles/18778`.
- MQL5 forum discussion: `mql5.com/en/forum/490716`.

### Adaptive learning
- MQL5 Market: *Queen of Gold UCB Agents*, `mql5.com/en/market/product/170905`.
- GitHub: BAKOME-Hub/BAKOMEGoldScalper.

These references are research inputs. Their claims, implementation details and suitability for EAGOLD must be independently validated before adoption.

---

## 16. Relationship with MAIA Specification

This document is the **aggregated roadmap layer**.

The detailed MAIA specification remains the canonical research document for adaptive intelligence, market regimes, experience memory, MFE/MAE, profit asymmetry, model versioning and learning safety. fileciteturn961file0L2-L2

Therefore:

```text
FUTURE_RESEARCH_BASE
        ↓
roadmap / prioritization / references
        ↓
MAIA_SPEC
        ↓
future technical specifications
        ↓
validated implementation only
```

---

## 17. Final Principle

The objective of this research is not to make EAGOLD more complicated.

It is to make the system progressively more:

- observable;
- explainable;
- regime-aware;
- economically coherent;
- resilient;
- statistically informed;
- adaptive within limits;
- and reversible.

The future architecture should therefore evolve from:

```text
DETERMINISTIC BASELINE
        ↓
OBSERVABLE MODULAR SYSTEM
        ↓
REGIME-AWARE SYSTEM
        ↓
EXPERIENCE-AWARE SYSTEM
        ↓
CONTROLLED ADAPTIVE SYSTEM
```

without sacrificing the auditability and safety of the underlying EAGOLD execution core.
