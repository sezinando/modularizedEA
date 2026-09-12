# EAGOLD — Canonical Opportunity Accounting Checkpoint v1.0

**Date:** 2026-09-12  
**Scope:** R12 × EAGOLD Exposure × MFE/MAE × Realization  
**Dataset:** `EAGOLD_EXCURSION_EVENTS - EAGOLD_R12_M5_EVENT_BOUNDARY_HISTORY_v1.0.csv`  
**Sample:** 371 realization events / 75 cycles  
**Purpose:** establish a statistically reproducible economic-accounting layer before introducing Partial / BE / Runner / adaptive realization actions.

---

## 1. Executive conclusion

The 371-event sample confirms that R12 is useful as **economic context**, but it is not yet a direct realization signal.

The strongest observed opportunity is concentrated in R12 **CONFLICT / NEUTRAL** conditions. Of the 79 events classified as high-opportunity, all 79 occurred in the neutral/conflict group. These events produced **$1,599.88** realized, averaging **$20.25/event**, with mean MFE of **$20.25** and mean MAE of **-$172.78**.

This is the central finding:

> **High opportunity and high risk coexist. Opportunity cannot be treated as safety.**

BRX captures this expansion far more effectively than R4:
- Conflict/high-opportunity: **78 BRX / 1 R4**.
- Average realization in this state: **$20.25/event**.

Therefore R12 should contextualize the profit-management state; BRX/R4 remain execution/realization engines.

---

## 2. Canonical classification used in this checkpoint

### Exposure direction

At each event:
- `BUY` if `BUY_LOTS > SELL_LOTS`.
- `SELL` if `SELL_LOTS > BUY_LOTS`.
- `FLAT` if equal.

### Directional alignment

Bullish R12 states:
- `BULLISH_TREND`
- `BULLISH_PULLBACK`
- `TRANSITION_BULLISH`

Bearish R12 states:
- `BEARISH_TREND`
- `BEARISH_PULLBACK`
- `TRANSITION_BEARISH`

Neutral/conflict states:
- `CONFLICT`
- `HIGH_VOLATILITY`
- `LOW_VOLATILITY`
- `EXHAUSTION`
- `UNKNOWN`

Alignment:
- `ALIGNED`: exposure direction agrees with bullish/bearish R12.
- `COUNTER`: exposure direction opposes bullish/bearish R12.
- `NEUTRAL_CONFLICT`: R12 does not provide a clean directional agreement.

### Opportunity threshold

`INTERVAL_MFE > 0` observations were used as the opportunity population.

- Median positive MFE: **5.75**
- 75th percentile positive MFE: **10.7775**
- `OPP_HIGH = INTERVAL_MFE >= 10.7775`

### Stress threshold

Stress is measured as absolute adverse excursion:

`STRESS_ABS_MAE = max(-INTERVAL_MAE, 0)`

- 75th percentile stress: **20.115**
- `STRESS_HIGH = STRESS_ABS_MAE >= 20.115`

The thresholds are descriptive sample thresholds only. They are **not runtime parameters** and must not be promoted to production without OOS validation.

---

## 3. Economic states observed in the sample

| State | Events | Realized | Avg/event | Avg MFE | Avg MAE | BRX | R4 |
|---|---:|---:|---:|---:|---:|---:|---:|
| A — Aligned / Low Stress | 101 | $877.05 | $8.68 | 3.19 | -9.33 | 51 | 50 |
| B — Aligned / High Opportunity | 0 | $0.00 | — | — | — | 0 | 0 |
| C — Counter / Low Opportunity | 80 | $624.54 | $7.81 | 2.30 | -5.64 | 27 | 53 |
| D — Counter / High Opportunity | 0 | $0.00 | — | — | — | 0 | 0 |
| E — Conflict / High Opportunity | 79 | $1,599.88 | **$20.25** | **20.25** | -172.78 | **78** | 1 |
| F — Conflict / High Stress | 11 | $119.27 | $10.84 | — | -36.31 | 11 | 0 |
| G — Conflict / Low Stress | 100 | $725.64 | $7.26 | 3.06 | -4.87 | 28 | 72 |

### Important result

There were **no aligned-high-opportunity** or **counter-high-opportunity** events under the current empirical threshold.

That means the dataset does **not** support a rule such as:

> aligned exposure + high opportunity → hold longer

or:

> counter exposure + high opportunity → close immediately.

The high-opportunity population is dominated by neutral/conflict regimes.

---

## 4. Canonical opportunity accounting: what can and cannot be measured now

### 4.1 Observable opportunity

The current telemetry gives a valid observational metric:

`OBSERVED_OPPORTUNITY = INTERVAL_MFE`

This answers:

> What was the maximum observed floating P/L available during the interval before this realization event?

It is useful for regime/excursion analysis.

### 4.2 Realized economic result

`REALIZED_OUTCOME = REALIZED_DELTA`

This answers:

> How much P/L did the actual realization transaction produce?

### 4.3 Why `REALIZED / MFE` must NOT be called capture efficiency

The current event boundary does not guarantee that MFE and realized P/L represent the same liquidation opportunity.

A basket can contain positions with different entry prices and opposite directions. BRX can close multiple legs sequentially, and the realized result can exceed the interval's maximum aggregate floating value recorded before the action.

In the sample, this occurs frequently enough to invalidate a naïve ratio. Consequently:

`REALIZED_DELTA / INTERVAL_MFE`

is **not** a canonical capture-efficiency metric in v1.0.

Likewise:

`max(MFE - REALIZED, 0)`

must not be described as money left on the table.

It is only an **observed MFE gap**, and in this dataset it is structurally contaminated by the distinction between basket floating P/L and the subset/sequence of positions actually realized.

---

## 5. Canonical accounting model proposed

The correct accounting model is two-layered.

### Layer 1 — Observed opportunity

For each realization interval record:

- `INTERVAL_MFE`
- `INTERVAL_MAE`
- `INTERVAL_PEAK_FLOATING_PL`
- `INTERVAL_GIVEBACK`
- exposure at action
- maximum exposure during interval
- R12 state and state sequence
- realization engine/action
- realized delta

This is the current telemetry layer.

### Layer 2 — Counterfactual realizable opportunity

To answer:

> How much could Partial / BE / Runner have captured?

we need a deterministic replay/counterfactual engine operating on the same tick path.

It must simulate candidate actions without changing the historical baseline:

1. **Baseline** — existing EAGOLD realization.
2. **Partial** — close defined fraction/lot subset at a trigger.
3. **Partial + BE** — partial realization followed by stop protection on remainder.
4. **Partial + BE + Runner** — protected remainder with trailing/runner logic.
5. **Basket trailing** — dynamic basket protection.

Each candidate must produce:
- realized P/L;
- maximum favorable excursion of the remaining exposure;
- maximum adverse excursion;
- giveback;
- duration;
- exposure path;
- transaction count;
- execution sequence;
- hypothetical incremental P/L versus baseline.

Only this layer can legitimately produce a metric such as **counterfactual captured opportunity**.

---

## 6. What the current sample tells us about Partial / BE / Runner

### Partial

The strongest candidate environment is:

`CONFLICT + HIGH OPPORTUNITY`

because the sample shows large MFE and large realized BRX events.

However, partial should not be triggered solely by CONFLICT. The same state carries severe MAE. A trigger should require evidence that opportunity is actually developing.

### BE

BE becomes economically interesting after an observed favorable excursion has developed enough to justify sacrificing some future upside for protection.

The current telemetry is sufficient to study this counterfactually, but not sufficient to choose a production BE distance.

### Runner

Runner is most interesting in events with:
- high MFE;
- sustained regime sequence;
- favorable transition history;
- manageable giveback;
- sufficient remaining exposure.

The current dataset supports identifying these populations, but not yet setting runner parameters.

---

## 7. Core quantitative observations

Across all 371 events:

- Total realized: **$3,946.38**
- Mean MFE: **6.59**
- Mean MAE: **-42.94**
- Mean giveback: **0.98**
- High-opportunity events: **79 / 371 (21.3%)**
- High-stress events: **93 / 371 (25.1%)**

Previously established correlations remain important:
- `INTERVAL_MFE` vs realized delta: **+0.945**
- `INTERVAL_MAE` vs realized delta: **-0.744**
- `R12_EVENT_TRANSITIONS` vs realized delta: **+0.343**
- `INTERVAL_GIVEBACK` vs realized delta: **-0.198**

Interpretation:

**MFE is the strongest observed predictor of realization magnitude in this sample, while MAE is a strong inverse stress indicator.**

---

## 8. Required next telemetry for canonical accounting

Before production Adaptive Profit Management, add/validate the following observer-only fields at tick/event level:

### Exposure
- current BUY lots
- current SELL lots
- current gross lots
- current net lots
- peak BUY/SELL/gross/net lots during interval

### Opportunity
- peak total floating P/L
- timestamp of peak floating P/L
- peak floating P/L by directional liquidation candidate when mathematically well-defined
- MFE duration
- time from interval start to MFE

### Stress
- MAE
- timestamp of MAE
- time from interval start to MAE
- MAE duration

### Action boundary
- pre-action floating P/L
- action execution timestamp
- post-action floating P/L
- realized delta
- remaining exposure immediately after action

### R12
- regime at action
- previous regime
- regime sequence
- transition count
- duration in current regime
- event-boundary transition count
- event-boundary sequence

These fields remain observer-only.

---

## 9. Governance decision

**Status: RESEARCH PASS / EXECUTION BLOCKED**

The evidence is sufficient to advance the research from simple R12 classification to **counterfactual profit-management simulation**.

It is **not** sufficient to enable live Partial, BE, Runner, or adaptive realization logic.

No production action parameters are approved by this checkpoint.

---

## 10. Next stage

### R12 Counterfactual Profit Management Engine — research only

Build an offline deterministic evaluator capable of replaying the same historical path and comparing:

`BASELINE`
`vs`
`PARTIAL`
`vs`
`PARTIAL + BE`
`vs`
`PARTIAL + BE + RUNNER`
`vs`
`BASKET TRAILING`

The evaluator must preserve the original execution path and must not introduce lookahead.

The first objective is not to maximize P/L. It is to determine:

> **In which economic states does each management policy improve realized outcome, reduce MAE, reduce giveback, or preserve upside without materially increasing transaction/exposure risk?**

Only after that evidence should the policy graduate from observer/counterfactual research into a controlled EAGOLD runtime component.

---

## Checkpoint identity

**Checkpoint:** `EAGOLD_CANONICAL_OPPORTUNITY_ACCOUNTING_CHECKPOINT_v1.0`  
**Repository:** `sezinando/modularizedEA`  
**Branch:** `main`  
**Scope:** R12 / Adaptive Profit Management research  
**Runtime changes:** **NONE**  
**Production authorization:** **NO**
