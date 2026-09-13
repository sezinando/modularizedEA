# EAGOLD — Adaptive Profit Management / Exposure Relief Systematization v1.0

**Data:** 2026-09-13  
**Baseline:** EAGOLD v0.111  
**Status:** RESEARCH / SYSTEMATIZATION / OBSERVER-ONLY  
**Operational impact:** NONE  
**Branch:** `main`

---

## 1. Purpose

This document consolidates the Adaptive Profit Management research already present in the EAGOLD repository and adds a functional reference model based on the observed behavior of a third-party recovery system (**AW Recovery — Possible Closures / Reduce Volume**).

The external behavior is treated as a **functional reference**, not as an implementation specification and not as permission to copy its algorithm.

The objective is to formalize the EAGOLD capability to:

1. recognize the current market regime;
2. identify whether the basket is aligned or counter to the primary movement;
3. detect when accumulated exposure has become economically expensive;
4. identify a partial reduction opportunity without requiring full basket closure;
5. reduce gross exposure progressively when economically justified;
6. preserve a profitable/favorable remainder when continuation has positive evidence;
7. evolve later to partial + BE + runner + trailing;
8. remain fully observable and counterfactual before live execution.

---

## 2. Research already consolidated in EAGOLD

The repository already established the following architecture and conclusions:

```text
R12 / MAIA
      ↓
CONTEXT
      ↓
ADAPTIVE PROFIT MANAGEMENT
      ↓
ECONOMIC AUTHORIZATION
      ↓
BRX / R4 / R5
      ↓
ACTION CONTRACT
      ↓
CORE EXECUTION
      ↓
BROKER
```

R9/R10/R11 remain the risk/exposure envelope. R12/MAIA may recommend economic actions but may not redefine the risk envelope. The provisioning map explicitly identifies Position × Regime, MFE/MAE, Profit Development, Partial Realization, BE, Runner and Basket Trailing as the relevant evolution path. `EAGOLD_R10_ADAPTIVE_EXPOSURE_RELIEF_SPEC_v0.1.md` subsequently refined R10 toward state-oriented exposure reduction.

The latest research checkpoint identifies **Response-to-Regime** as the most promising causal variable: not merely whether the basket is aligned with R12, but whether the basket is actually being economically rewarded by the active regime.

---

## 3. External functional reference — AW Recovery

### 3.1 Observed behavior

The reference terminal exposes a function named **Possible Closures → Reduce Volume**.

The observed example showed, among other values:

```text
BUY  0.20   +42.04
SELL 0.77   -39.07

Possible Closures
→ Reduce Volume
```

The relevant functional characteristic is not the exact number. It is the existence of an explicit **partial exposure-relief decision** while the basket remains open.

### 3.2 What this demonstrates functionally

The reference behavior suggests the following control loop:

```text
CURRENT BASKET
      ↓
ASSESS POSSIBLE CLOSURE
      ↓
IDENTIFY REDUCIBLE VOLUME
      ↓
REDUCE PART OF EXPOSURE
      ↓
RECALCULATE BASKET
      ↓
POSSIBLE NEXT REDUCTION
```

This is the key behavior we want to investigate in EAGOLD.

It is materially different from:

```text
DD > threshold → close everything
```

and also different from:

```text
basket profit > target → close everything
```

The target behavior is **progressive economic exposure relief**.

### 3.3 What must not be assumed

The screenshots do not prove:

- the exact AW algorithm;
- whether it uses pair matching, weighted averages, FIFO, hedge accounting, margin, regime, or another mechanism;
- whether it is profit-funded;
- whether it selects the largest ticket, most profitable ticket, oldest ticket, or another candidate;
- the exact recurrence/cooldown logic.

Those details must be discovered experimentally or left as explicit EAGOLD design decisions.

---

## 4. EAGOLD translation of the functional objective

The functional objective is defined as:

> **Find a partial reduction that lowers economic exposure while preserving as much of the basket's future recovery/upside optionality as possible.**

The first optimization target is therefore not raw realized profit.

It is:

```text
RISK RELIEF / ECONOMIC COST
```

Subject to:

```text
gross exposure decreases
net exposure does not become materially worse
risk envelope remains valid
transaction is deterministic
broker state remains authoritative
```

---

## 5. Core state model

At each decision point, calculate:

```text
BUY_LOTS
SELL_LOTS
GROSS_LOTS = BUY_LOTS + SELL_LOTS
NET_LOTS = abs(BUY_LOTS - SELL_LOTS)
DOMINANT_DIRECTION
FLOATING_BASKET_PL
REALIZED_CYCLE_PL
ECONOMIC_EQUITY
CYCLE_AGE
CYCLE_DD
PEAK_BASKET_PL
GIVEBACK
MFE
MAE
R12_REGIME
POSITION_REGIME_ALIGNMENT
RECOVERY_STATE
MARGIN_SAFETY
TIME_SINCE_LAST_RELIEF
```

The distinction between **gross**, **net**, and **floating DD** is mandatory. A small net position can coexist with dangerously large gross exposure.

Example already documented in the R10 research:

```text
BUY  = 5.08 lots
SELL = 6.42 lots
GROSS = 11.50 lots
NET = 1.34 lot SELL
DD ≈ -9,838.74
```

Therefore:

```text
NET ≠ TOTAL ECONOMIC RISK
```

---

## 6. Position × Regime matrix

The first contextual classification is:

```text
                    R12 REGIME
                       │
             ┌─────────┴─────────┐
             │                   │
          ALIGNED             COUNTER
             │                   │
             ▼                   ▼
      PROFIT DEVELOPMENT     EARLY RELIEF
      / HOLD / RUNNER        / EXPOSURE REDUCTION
```

For a bullish regime:

```text
BUY-heavy  → ALIGNED
SELL-heavy → COUNTER
```

For a bearish regime:

```text
SELL-heavy → ALIGNED
BUY-heavy  → COUNTER
```

The classification alone does **not** authorize a reduction. The research checkpoint demonstrated that regime and exposure in isolation do not reliably separate healthy continuation from deterioration.

---

## 7. Response-to-Regime

The next layer asks:

> Is the basket economically responding to the active regime?

Example:

```text
R12 = BEARISH
SELL-heavy basket

Equity improves
      ↓
positive response
      ↓
continuation evidence
      ↓
HOLD / PROFIT DEVELOPMENT
```

Versus:

```text
R12 = BEARISH
SELL-heavy basket

Equity fails to improve
or continues deteriorating
      ↓
response failure
      ↓
RELIEF candidate
```

This prevents the system from confusing:

```text
ALIGNED POSITION
```

with:

```text
ECONOMICALLY WORKING POSITION
```

---

## 8. Relief candidate model

A relief candidate is a specific partial-close hypothesis, not merely a state flag.

Candidate fields:

```text
candidate_id
cycle_id
timestamp
target_ticket
target_direction
requested_lots
realized_pl_now
remaining_lots
before_gross
before_net
after_gross_hypothetical
after_net_hypothetical
R12_regime
alignment
response_to_regime
MFE
MAE
peak_profit
giveback
cycle_age
recovery_state
margin_safety
relief_score
reason
```

Initial candidate preference is conservative:

1. EAGOLD market position;
2. partial lot compatible with broker constraints;
3. preferably profitable or economically fundable;
4. gross exposure must decrease;
5. net exposure must not worsen unnecessarily;
6. must respect R9/R10/R10.2/R11 envelope;
7. cooldown/hysteresis must be respected;
8. action must be reconstructible from telemetry.

---

## 9. Progressive reduction — the key behavior

The system should be designed to support repeated relief decisions.

Conceptually:

```text
T0
│
├─ Basket: heavy exposure
│
├─ Candidate 0.01
│
└─ REDUCE 0.01
      │
      ▼
T1 — re-read broker state
      │
      ├─ exposure lower
      ├─ basket re-evaluated
      └─ candidate recalculated
             │
             ▼
T2
│
└─ REDUCE again only if a NEW valid opportunity exists
```

This is **not** an instruction to execute multiple reductions in one tick.

Each successful transaction must establish a new broker state. A partial result must halt economic execution for reconciliation according to the Action Contract.

---

## 10. Two major operating modes

### Mode A — Counter-regime relief

When the basket is strongly counter to the primary regime:

```text
COUNTER
 +
STRESS
 +
ECONOMIC REDUCTION OPPORTUNITY
      ↓
MODE A
      ↓
EARLIER / MODEST REALIZATION
      ↓
LOWER GROSS EXPOSURE
```

The purpose is not to force a loss. The purpose is to exploit an economically favorable partial-close window before the basket becomes more expensive to carry.

### Mode B — Aligned profit development

When the basket is aligned and the regime is rewarding it:

```text
ALIGNED
 +
POSITIVE RESPONSE
 +
PROFIT DEVELOPMENT
      ↓
MODE B
      ↓
PARTIAL REALIZATION
      ↓
PROTECT REMAINDER
      ↓
BE
      ↓
RUNNER
      ↓
TRAILING
```

The exact partial fraction must be derived from MFE/MAE and out-of-sample research.

---

## 11. Relief state machine

R10 Adaptive Exposure Relief should use an explicit state machine:

```text
R10_NORMAL
    ↓
R10_TENSION
    ↓
R10_RELIEF_ELIGIBLE
    ↓
R10_RELIEF_EXECUTING
    ↓
R10_RECONCILIATION
    ↓
R10_COOLDOWN
    ↓
R10_NORMAL
```

Rules:

- NORMAL: no adaptive relief required;
- TENSION: observe increasing economic stress;
- RELIEF_ELIGIBLE: a valid candidate exists;
- RELIEF_EXECUTING: transactional action underway;
- RECONCILIATION: partial/ambiguous broker result;
- COOLDOWN: prevent repeated immediate action.

The existing R10 specification already defines this state model and should remain the authoritative R10 state contract.

---

## 12. Relief Score — research only

The initial score should rank opportunities without directly authorizing execution.

Suggested deterministic components:

```text
Gross Exposure Stress
DD / Economic Stress
Cycle Age
Giveback
Response-to-Regime
Position × Regime Alignment
Ticket Profitability
Ticket Contribution to Imbalance
Recovery Density
Margin Safety
Time Since Last Relief
```

A candidate should become more attractive when:

```text
stress increases
AND
response deteriorates
AND
partial close reduces gross exposure
AND
economic cost is acceptable
```

The score must not be a disguised single-threshold rule.

---

## 13. Counterfactual protocol

Every candidate must be evaluated against the no-action baseline.

```text
STATE T0
   │
   ├──────────────→ P0: NO RELIEF
   │
   ├──────────────→ P1: RELIEF 0.01
   │
   ├──────────────→ P2: RELIEF 0.02
   │
   └──────────────→ P3: RELIEF 0.03
```

For each path, evaluate:

- maximum DD;
- maximum gross exposure;
- maximum net exposure;
- cycle duration;
- realized P/L;
- terminal economic equity;
- relief cost;
- later recovery;
- upside retained;
- number of subsequent reductions;
- cycles improved;
- cycles degraded.

Future information may be used only to score the counterfactual after T0. It may never be used to choose T0.

---

## 14. Required telemetry

The principal research artifact is:

```text
EAGOLD_COUNTERFACTUAL_PATH.csv
```

It should support ticket-level and basket-level reconstruction of:

```text
cycle
position
lots
P/L
gross
net
realized
MFE
MAE
peak
giveback
R12
regime transition
position × regime
response-to-regime
relief candidate
hypothetical relief
actual relief
action result
```

The telemetry must distinguish:

```text
OBSERVED
COUNTERFACTUAL
ACTUAL
```

so that a research hypothesis cannot be mistaken for a live action.

---

## 15. Existing implementation to preserve

### BRX

BRX remains the primary transactional basket-realization execution point. Adaptive Profit Management should produce an **economic authorization/action plan**, not create a parallel broker-close mechanism.

### Action Contract

All real actions use:

```text
NONE
BLOCKED
COMPLETED
PARTIAL
FAILED
```

`PARTIAL` requires reconciliation and halts the remaining economic execution of the tick.

### Core

Broker execution remains centralized in the Core.

### R9

R9 remains responsible for directional hedge/exposure control.

### R10

R10 becomes the natural home for economic exposure relief, but the existing profit-funded and balanced mechanisms must not be confused with the new adaptive state machine.

### R11

R11 remains the governor of **new recovery exposure**. It is not the mechanism for reducing existing exposure.

### R13

R13 must not be converted into a generic DD/exposure-relief engine.

---

## 16. What the AW reference changes in our understanding

Before the functional reference, the problem could be summarized as:

```text
Adaptive Profit Management
→ partial realization
→ BE
→ runner
→ trailing
```

The observed **Possible Closures → Reduce Volume** behavior adds an important preceding layer:

```text
EXPOSURE RELIEF
      ↓
PROGRESSIVE REDUCTION
      ↓
THEN
      ↓
PROFIT DEVELOPMENT / PROTECTION
```

Therefore the complete target architecture becomes:

```text
                    R12 / MAIA
                        │
                        ▼
               MARKET / EXPERIENCE
                        │
                        ▼
              POSITION × REGIME
                        │
                        ▼
               RESPONSE-TO-REGIME
                        │
             ┌──────────┴──────────┐
             │                     │
         COUNTER                  ALIGNED
             │                     │
             ▼                     ▼
       EXPOSURE RELIEF       PROFIT DEVELOPMENT
             │                     │
             ▼                     ▼
       PARTIAL REDUCE        PARTIAL REALIZATION
             │                     │
             └──────────┬──────────┘
                        ▼
                  PROTECTION
                        │
                     BE / RUNNER
                        │
                     TRAILING
                        │
                  FINAL REALIZE
                        │
                        ▼
                  ACTION CONTRACT
                        │
                        ▼
                      BROKER
```

This is the target behavior to be researched — not yet the live implementation.

---

## 17. Implementation phases

### PHASE 0 — Research baseline

Status: existing.

- adaptive profit research;
- provisioning map;
- R10 adaptive exposure relief specification;
- Action Contract;
- Counterfactual Path telemetry.

### PHASE 1 — Observability

Implement/validate:

1. Basket Economic State;
2. Position × Regime;
3. Response-to-Regime;
4. Relief Candidate;
5. Relief Score;
6. explicit block/eligibility reasons;
7. telemetry fields.

No orders.

### PHASE 2 — Counterfactual

Evaluate:

```text
no relief
vs
0.01
vs
0.02
vs
0.03
```

over multiple complete cycles and multiple pregões.

### PHASE 3 — Controlled transactional execution

Only after validation:

1. transactional partial reduction;
2. post-action broker re-read;
3. reconciliation;
4. cooldown/hysteresis;
5. controlled progressive reduction.

### PHASE 4 — Profit development

After exposure-relief validation:

```text
partial
→ BE
→ runner
→ trailing
```

### PHASE 5 — Adaptive policy

Only after OOS validation:

```text
regime-aware relief
regime-aware realization
regime-aware runner
```

---

## 18. Acceptance criteria

The mechanism can only advance when it demonstrates, out-of-sample and across multiple pregões:

1. reduction of gross exposure when relief is executed;
2. no systematic increase in net directional risk;
3. lower DD tail or materially shorter stressed cycles;
4. no unacceptable degradation of economic result;
5. preservation of favorable upside when the regime continues;
6. deterministic candidate selection;
7. no lookahead;
8. compatibility with R9/R10/R10.2/R11;
9. Action Contract compliance;
10. reconciliation after partial action;
11. reproducible telemetry;
12. regression against the protected baseline.

---

## 19. Current decision

**DO NOT ENABLE LIVE ADAPTIVE REDUCTION.**

The correct next step is not parameter tuning.

The correct next step is:

```text
OBSERVE
   ↓
IDENTIFY CANDIDATE
   ↓
RECORD WHY
   ↓
COUNTERFACTUAL
   ↓
COMPARE WITH NO-ACTION
   ↓
VALIDATE OUT-OF-SAMPLE
   ↓
CONTROLLED EXECUTION
```

The AW Recovery screenshots are useful because they demonstrate the exact operational behavior we want to study: **partial reduction of accumulated exposure followed by recalculation of the remaining basket**.

---

## 20. Internal references

- `DOCS/EAGOLD_ADAPTIVE_PROFIT_MANAGEMENT_PROVISIONING_MAP_v1.0.md`
- `DOCS/EAGOLD_ADAPTIVE_PROFIT_MANAGEMENT_RESEARCH_CHECKPOINT_v1.1.md`
- `DOCS/EAGOLD_R10_ADAPTIVE_EXPOSURE_RELIEF_SPEC_v0.1.md`
- `Core/EAGOLD_CounterfactualPathTelemetry.mqh`
- `Core/EAGOLD_AdaptiveProfitGuard.mqh`
- `Engines/EAGOLD_R10.mqh`
- `Engines/EAGOLD_BRX.mqh`
- `Engines/EAGOLD_R9.mqh`
- `Engines/EAGOLD_R10_Reconciliation.mqh`
- `Engines/EAGOLD_R13_Satellite.mqh`

## 21. External research references already consolidated by the project

The existing provisioning map records external references including:

- Fintor-AI / WealthPole — modular Grid/Hedge architecture;
- MQL5 — state persistence;
- MQL5 — Market Regime Detection;
- MQL5 — Market Entropy;
- Aldo Taranto — Bi-directional Grid Constrained Stochastic Processes;
- MAIA research on MFE/MAE, profit asymmetry and contextual decision systems.

These references remain research inputs. The observed AW Recovery behavior in this document is an additional **functional observation**, not a claim about its proprietary implementation.
