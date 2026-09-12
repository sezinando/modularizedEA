# EAGOLD — Counterfactual Profit Management Specification v1.0

## 1. Objective

Establish a statistically defensible, observer-only methodology to test whether adaptive profit management can improve the economic behavior of EAGOLD before any production execution change.

The target policy is:

- recognize the current market regime;
- distinguish aligned, counter-directional and conflict exposure;
- protect accumulated profit earlier when the basket is economically vulnerable;
- realize part of a favorable move when evidence supports it;
- protect the remainder with BE and, where justified, allow a runner/trailing component;
- preserve BRX's ability to capture extended movement.

No counterfactual result authorizes production behavior by itself.

## 2. Current baseline

The current EAGOLD architecture has BRX as the principal movement-capture realization layer and R4 as the incremental maintenance/realization layer. R9/R10/R11 remain risk/exposure controls. R12 is observer-only and classifies M5 market regime.

Historical event telemetry contains realized P/L, MFE, MAE, giveback, duration and exposure snapshots/maxima. The June baseline contains 1,211 realization events across 221 cycles: 420 BRX events and 791 R4 events.

The historical dataset is useful for opportunity characterization, but it is **not sufficient to calculate a valid P0–P4 counterfactual directly**. In particular, aggregate interval MFE is not equivalent to the profit that a hypothetical partial/BE/runner policy could have captured.

A concrete validation of this limitation was observed in the 1,211-event dataset: among 932 events with positive interval MFE, 434 have `REALIZED_DELTA > INTERVAL_MFE`. Therefore `REALIZED_DELTA / MFE` must not be used as a capture-efficiency or money-left-on-table metric.

## 3. Counterfactual hierarchy

Every policy must be evaluated against the same historical path and the same entry/exposure state.

### P0 — BASELINE

Reproduce the current realization behavior without hypothetical intervention.

### P1 — PARTIAL

At a policy-defined economic trigger, hypothetically realize a defined fraction of the eligible exposure while leaving the remainder untouched.

### P2 — PARTIAL + BE

Apply P1 and then move the surviving eligible remainder to a break-even protection level according to the canonical position-level rules.

### P3 — PARTIAL + BE + RUNNER

Apply P2 and allow the protected remainder to continue while a runner exit condition is evaluated.

### P4 — BASKET TRAILING

Evaluate a basket-level trailing policy that protects a fraction of favorable basket excursion while preserving upside when continuation remains favorable.

The policies are nested for comparison, but each must also be evaluated independently to identify which component creates or destroys economic value.

## 4. Canonical decision state

At every hypothetical decision point, the simulator may use only information available at that timestamp:

- timestamp;
- bid/ask or execution-price representation appropriate to the historical dataset;
- open ticket set and ticket-level entry price, lot size, type and costs;
- current floating P/L by ticket and by side;
- gross and net exposure;
- basket age;
- realized P/L already produced by the cycle;
- current and historical MFE/MAE accumulated up to that timestamp;
- current drawdown/giveback from the observed path;
- R12 regime and regime duration known at that timestamp;
- regime transition count known at that timestamp;
- BRX/R4/R10/R11 state relevant to authorization;
- current profit floor and risk envelope.

Future candles, future MFE, final cycle result and post-decision regime transitions are forbidden inputs to the decision itself.

## 5. Canonical opportunity accounting

Opportunity must be represented in the same economic unit as the hypothetical action.

The canonical unit is **ticket-level executable P/L at a timestamp**, aggregated into:

1. eligible side;
2. eligible basket;
3. protected remainder;
4. realized hypothetical P/L;
5. residual unrealized P/L after intervention.

For a hypothetical intervention at time `t`:

`Counterfactual P/L(t) = Hypothetical Realized P/L(t) + Hypothetical Residual P/L at terminal state`

The simulator must retain both components. It must not substitute aggregate interval MFE for executable ticket-level P/L.

## 6. Required path data

A valid counterfactual replay requires, at minimum, a timestamped path with:

- price/execution information;
- complete open-ticket state at each observation;
- ticket entry price;
- ticket lot size;
- order type;
- realized close information;
- transaction costs;
- basket state;
- realization events;
- R12 state synchronized to the same timeline.

If the source is tick data, the simulator should preserve tick order and bid/ask semantics. If only bar data is available, the result must be explicitly labeled as an approximation and must use conservative intra-bar assumptions.

## 7. Hypothetical action semantics

### Partial

A partial action must specify:

- eligible tickets/side;
- fraction or lots removed;
- price used for the hypothetical close;
- costs applied;
- resulting ticket set;
- resulting gross/net exposure.

### Break-even

BE must be represented as a ticket-level stop transformation, not as an immediate profit realization.

The simulator must account for:

- actual entry price;
- direction;
- broker stop constraints;
- transaction costs where applicable;
- whether the stop would have been executable at the historical path.

### Runner

The runner must have an explicit exit rule. It cannot be represented merely as “keep the remaining MFE”.

### Basket trailing

Basket trailing must operate on a defined basket metric and maintain a deterministic trail. The trigger must be evaluated only from information known at each historical timestamp.

## 8. Metrics

For every cycle and policy, calculate:

- terminal realized P/L;
- total counterfactual P/L;
- delta versus P0;
- MFE;
- MAE;
- maximum drawdown;
- peak-to-action giveback;
- time to first realization;
- time to flat;
- number of realizations;
- maximum gross exposure;
- maximum net exposure;
- percentage of cycles improved;
- percentage of cycles worsened;
- downside tail (P5/P10 where sample permits);
- median and mean delta;
- profit factor / expectancy where trade-unit definition is valid;
- BRX upside preservation;
- fraction of favorable continuation destroyed by intervention.

The primary comparison is not win rate. It is **risk-adjusted economic improvement without unacceptable destruction of upside capture**.

## 9. Economic state matrix

The first analysis should segment results by:

- exposure alignment: ALIGNED / COUNTER / CONFLICT / NEUTRAL;
- R12 regime;
- R12 transition bucket: 0, 1–2, 3–5, 6+;
- engine: BRX / R4;
- stress bucket;
- opportunity bucket;
- exposure size.

The objective is to identify conditional advantage, for example:

`Policy X improves outcomes when exposure is COUNTER + high stress + adverse regime persistence.`

A global average improvement is insufficient if the policy destroys the high-value BRX cases.

## 10. Acceptance criteria for a future adaptive policy

A policy may progress beyond counterfactual research only if evidence demonstrates all of the following:

1. positive or economically material improvement in out-of-sample evaluation;
2. no unacceptable increase in left-tail loss;
3. reduction of harmful giveback or exposure in the intended states;
4. preservation of a material portion of BRX upside;
5. no dependency on future information;
6. deterministic and auditable action semantics;
7. compatibility with R9/R10/R11 risk envelopes;
8. transactional compatibility with the Action Contract;
9. no violation of lifecycle/reconciliation guarantees;
10. runtime telemetry sufficient to reproduce every intervention.

## 11. Data-generation phase

Because the existing aggregate event CSV cannot reconstruct valid hypothetical partial/BE/runner paths, the next implementation phase is **telemetry expansion, not live adaptive execution**.

The observer should produce a replayable path containing:

- cycle start/end;
- ticket-level state changes;
- ticket entry price and lots;
- every realization boundary;
- basket floating P/L;
- side floating P/L;
- peak basket P/L and timestamp;
- peak side-closeable P/L and timestamp;
- MAE/ MFE timestamps;
- exposure direction continuously at observation points;
- R12 regime synchronized to each observation;
- R12 transition history within the cycle;
- action authorization state;
- transaction result;
- broker-visible costs.

This data becomes the canonical input for a path-preserving counterfactual engine.

## 12. Execution gate

The architecture remains:

`R12 Observer -> Economic Context -> Counterfactual/Policy Research -> Authorization -> BRX/R4/R5 -> Action Contract -> Core Execution`

The current stage must stop before production policy execution.

**Status:** RESEARCH / SPECIFICATION COMPLETE — TELEMETRY EXPANSION REQUIRED.
