# EAGOLD — R12 Economic State Classification / MFE-MAE / Realization Checkpoint v1.0

**Checkpoint:** R12 Economic State Classification v1.0  
**Repository:** `sezinando/modularizedEA`  
**Dataset:** `EAGOLD_EXCURSION_EVENTS - EAGOLD_R12_M5_EVENT_BOUNDARY_HISTORY_v1.0.csv`  
**Period:** 2026-06-01 01:00:20 → 2026-06-08 05:44:30  
**Events:** 371  
**Cycles:** 75  
**BRX events:** 195  
**R4 events:** 176  
**R12 valid:** 371/371  
**Completed:** 371/371  
**Total realized:** $3,946.38

---

## 1. Objective

Classify the 371 realization events into economic states combining:

- R12 regime;
- EAGOLD directional exposure;
- MFE (Maximum Favorable Excursion);
- MAE (Maximum Adverse Excursion);
- realization result.

The purpose is to determine where **Partial / BE / Runner / adaptive realization** could eventually have economic justification, before adding any new action to the EA.

This checkpoint is **analysis-only**. No trading rule or execution behavior is introduced by this document.

---

## 2. Exposure methodology

For this analysis, exposure direction is inferred from the **maximum BUY/SELL lots observed during the interval**, rather than only the post-action snapshot.

```text
INTERVAL_BUY_LOTS_MAX > INTERVAL_SELL_LOTS_MAX → BUY exposure
INTERVAL_SELL_LOTS_MAX > INTERVAL_BUY_LOTS_MAX → SELL exposure
Tie → NO_DIRECTION
```

This is preferable for event-boundary analysis because the post-action `BUY_LOTS` / `SELL_LOTS` can already represent a reduced or closed basket.

### Important limitation

Exposure direction is an analytical reconstruction. It is not a new canonical EAGOLD exposure state and must not be promoted to runtime authorization without further validation.

---

## 3. R12 directional mapping

For the alignment study:

### Bullish
- `BULLISH_TREND`
- `BULLISH_PULLBACK`
- `TRANSITION_BULLISH`

### Bearish
- `BEARISH_TREND`
- `BEARISH_PULLBACK`
- `TRANSITION_BEARISH`

### Conflict
- `CONFLICT`

### Neutral regime
- `HIGH_VOLATILITY`
- `LOW_VOLATILITY`
- `EXHAUSTION`
- `UNKNOWN`

Alignment is defined as:

```text
BUY  + bullish R12 → ALIGNED
SELL + bearish R12 → ALIGNED
BUY  + bearish R12 → COUNTER
SELL + bullish R12 → COUNTER
any exposure + CONFLICT → CONFLICT
```

---

## 4. Opportunity and stress thresholds

The dataset itself was used to establish exploratory thresholds, avoiding arbitrary external values.

### High opportunity

`INTERVAL_MFE >= 75th percentile`

Threshold:

**MFE >= 9.465**

### High stress

`abs(INTERVAL_MAE) >= 75th percentile`

Threshold:

**MAE absolute >= 20.115**

These thresholds are **research buckets**, not trading parameters.

---

## 5. Economic-state classification

| State | Definition |
|---|---|
| A — ALIGNED / LOW STRESS | Aligned exposure, MFE below high-opportunity threshold |
| B — ALIGNED / HIGH OPPORTUNITY | Aligned exposure, MFE at/above high-opportunity threshold |
| C — COUNTER / LOW OPPORTUNITY | Counter exposure, MFE below high-opportunity threshold |
| D — COUNTER / HIGH OPPORTUNITY | Counter exposure, MFE at/above high-opportunity threshold |
| E — CONFLICT / HIGH OPPORTUNITY | Conflict regime, MFE at/above threshold without high-stress classification |
| F — CONFLICT / HIGH STRESS | Conflict regime with MAE stress at/above threshold |
| NEUTRAL REGIME | Directional exposure present, but R12 regime is neutral/extension/high-volatility |
| NO DIRECTION | No dominant directional exposure reconstructed from interval maxima |

---

## 6. Results

| State | Events | Realized $ | Avg realized $ | Avg MFE | Avg |MAE| | Avg giveback |
|---|---:|---:|---:|---:|---:|---:|
| A — ALIGNED / LOW STRESS | 30 | 308.36 | 10.28 | 6.42 | 9.38 | 0.00 |
| B — ALIGNED / HIGH OPPORTUNITY | 18 | 259.07 | 14.39 | 14.18 | 37.63 | 0.00 |
| C — COUNTER / LOW OPPORTUNITY | 49 | 543.61 | 11.09 | 6.22 | 13.99 | 0.04 |
| D — COUNTER / HIGH OPPORTUNITY | 48 | 938.02 | **19.54** | **19.44** | **170.41** | 0.00 |
| E — CONFLICT / HIGH OPPORTUNITY | 3 | 45.64 | 15.21 | 15.21 | 8.96 | 0.00 |
| F — CONFLICT / HIGH STRESS | 15 | 284.07 | 18.94 | 17.66 | **223.05** | 0.00 |
| NEUTRAL REGIME | 21 | 359.29 | 17.11 | 14.96 | 94.37 | 0.00 |
| NO DIRECTION | 187 | 1,208.32 | 6.46 | 1.91 | 4.16 | 1.93 |

### Primary result

The strongest directional signal in this sample is **D — COUNTER / HIGH OPPORTUNITY**:

- 48 events;
- $938.02 realized;
- $19.54 average realization;
- $19.44 average MFE;
- but **$170.41 average absolute MAE**.

This is a critical finding: an exposure can be against the R12 directional context and still produce substantial favorable opportunity. Therefore, **counter-regime exposure must not automatically trigger immediate realization**.

However, the very high MAE demonstrates that the opportunity comes with substantial stress. This is exactly the type of state where a future **Partial + BE/Runner** architecture may have value, but the current evidence is not sufficient to define the action thresholds.

---

## 7. Aligned high-opportunity state

State B:

- 18 events;
- $259.07 realized;
- $14.39 average realization;
- $14.18 average MFE;
- $37.63 average absolute MAE.

This is economically attractive because MFE is materially higher than the low-opportunity aligned state, but it also carries more adverse excursion.

Potential future interpretation:

```text
ALIGNED + HIGH OPPORTUNITY
        ↓
allow development
        ↓
protect realized portion
        ↓
retain runner if opportunity persists
```

This is a **candidate architecture**, not a runtime rule.

---

## 8. Counter low-opportunity state

State C:

- 49 events;
- $543.61 realized;
- $11.09 average realization;
- $6.22 average MFE;
- $13.99 average absolute MAE.

This state does **not** show a compelling high-MFE opportunity profile.

It is therefore a stronger candidate for studying **earlier realization / risk compression**, especially when exposure becomes large or persists without favorable development.

Again, this is a research hypothesis only.

---

## 9. Conflict / high-stress state

State F:

- 15 events;
- $284.07 realized;
- $18.94 average realization;
- $17.66 average MFE;
- $223.05 average absolute MAE.

This is the most important warning state.

It combines:

```text
high opportunity
+
high stress
```

Therefore the correct future question is not simply:

> close earlier?

It is:

> **can a partial realization convert part of the observed opportunity into protected equity before the adverse excursion becomes dominant?**

That is precisely the economic question for Partial/BE/Runner.

---

## 10. Critical methodological finding — MFE capture ratio is NOT valid with current telemetry

A first attempt was made to calculate:

```text
Realized Delta / Interval MFE
```

This metric is **not valid as a direct opportunity-capture ratio with the current event telemetry**.

Reason: in 371 events, 316 had positive MFE, but **210 of those events had `REALIZED_DELTA > INTERVAL_MFE`**.

This means the realized event result and interval MFE are not measuring exactly the same economic object/time boundary. Possible causes include realization occurring through basket mechanics, accumulated realized P/L, spread/price conversion, or the distinction between floating opportunity and actual leg realization.

Therefore this checkpoint explicitly rejects the following interpretation:

```text
Realized / MFE = percentage of opportunity captured
```

A future canonical opportunity-capture metric must be designed around a consistent economic boundary.

This is an important **telemetry/modeling checkpoint**, not a failure of R12.

---

## 11. What the data actually supports

The current sample supports the following conclusions:

### Supported

1. R12 event-boundary context contains useful information beyond instantaneous regime.
2. Directional alignment can be reconstructed from interval exposure maxima.
3. Counter-regime exposure can still produce substantial MFE.
4. High-opportunity counter-regime events also show substantially higher MAE.
5. BRX is the principal movement-capture mechanism in the current architecture.
6. R4 remains comparatively stable as an incremental realization/maintenance mechanism.
7. MFE and MAE should be treated jointly when evaluating adaptive profit management.
8. The current telemetry is insufficient for a mathematically clean `profit captured / opportunity available` ratio.

### Not yet supported

1. A fixed Partial threshold.
2. A fixed BE trigger.
3. A fixed Runner activation point.
4. A rule that closes whenever EAGOLD is counter to R12.
5. A rule that holds whenever EAGOLD is aligned to R12.
6. Any adaptive action based solely on R12 regime.

---

## 12. Implications for Adaptive Profit Management

The evidence points toward an economic state machine rather than a direct regime-to-action mapping:

```text
R12 REGIME
    +
EXPOSURE DIRECTION / SIZE
    +
MFE DEVELOPMENT
    +
MAE STRESS
    +
REGIME TRANSITIONS
    +
TIME IN STATE
    ↓
ECONOMIC BASKET STATE
    ↓
PROFIT MANAGEMENT DECISION
    ↓
PARTIAL / BE / RUNNER / BRX / R4
```

The key distinction is:

```text
OPPORTUNITY ≠ SAFETY
```

A state can have excellent MFE and unacceptable MAE at the same time.

---

## 13. Next research gate

Before implementing Partial/BE/Runner, perform:

### Gate P1 — Canonical Opportunity Accounting

Design telemetry that puts **MFE, realized P/L, and exposure on the same economic interval** and allows a defensible estimate of:

- favorable opportunity available;
- favorable opportunity realized;
- giveback after peak;
- adverse excursion before realization;
- exposure required to obtain that opportunity;
- time spent waiting for opportunity;
- BRX realization vs. opportunity;
- R4 realization vs. opportunity.

### Gate P2 — State persistence

Measure whether states A–F persist long enough to make a transaction meaningful rather than reacting to noise.

### Gate P3 — Counterfactual simulation

Only after the canonical opportunity accounting exists, simulate:

```text
Baseline
vs.
Partial only
vs.
Partial + BE
vs.
Partial + BE + Runner
```

using identical historical paths and no lookahead.

### Gate P4 — OOS validation

Do not promote any action rule until it survives an out-of-sample period not used for threshold selection.

---

## 14. Checkpoint status

**R12 Observer:** GREEN / observer-only evidence available  
**Event-boundary telemetry:** GREEN structurally, methodology caveat documented  
**Exposure × regime classification:** GREEN for research  
**Economic-state classification:** GREEN for research / NOT runtime  
**MFE/MAE relationship:** GREEN / strong evidence of economic relevance  
**Opportunity-capture ratio:** RED / telemetry boundary not yet canonical  
**Partial:** NOT AUTHORIZED  
**BE:** NOT AUTHORIZED  
**Runner:** NOT AUTHORIZED  
**Adaptive realization:** NOT AUTHORIZED  
**LIVE:** NO

---

## 15. Decision checkpoint

**Decision:** advance the project to **Canonical Opportunity Accounting + Counterfactual Profit Management**, without changing EA execution behavior yet.

The most promising state for future investigation is:

> **COUNTER / HIGH OPPORTUNITY**

The most dangerous state requiring protection research is:

> **CONFLICT / HIGH STRESS**

The most promising architecture for aligned opportunity is:

> **ALIGNED / HIGH OPPORTUNITY → Partial + protected remainder + Runner**, subject to counterfactual validation.

No production action should be derived directly from these labels.

---

## 16. Traceability

This checkpoint is based on the uploaded event-boundary dataset and the R12/Excursion architecture already present in the repository. It records analytical findings only and does not alter execution logic.

**Checkpoint purpose:** preserve the state of the research before introducing any adaptive profit-management action.
