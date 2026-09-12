# MAIA — Adaptive Intelligence, Market Regimes, Experience Memory and Profit Asymmetry

**Status:** FUTURE IMPLEMENTATION / RESEARCH  
**Baseline protection:** EAGOLD v0.106 must remain unchanged until a future implementation is independently validated.  
**Scope:** Architecture and research proposal for the future MAIA adaptive intelligence layer.

---

## 1. Purpose

This document consolidates the ideas developed for a future adaptive intelligence layer, referred to as **MAIA**, for the EAGOLD/Modularized EA project.

The objective is not to modify the current EA.

The objective is to define a future architecture capable of:

- observing market conditions;
- classifying market regimes into known states;
- recording the context in which decisions are made;
- recording the actions taken by the EA;
- measuring the results of those actions;
- identifying actions with consistently good or poor performance;
- gradually adapting decision preferences over time;
- preserving historical knowledge;
- detecting changes in market behavior;
- improving profit realization without simply increasing exposure;
- and remaining auditable and reversible.

The central principle is:

> **The EA should learn from experience gradually, using persistent memory and controlled adaptation, rather than changing its behavior abruptly after individual wins or losses.**

---

## 2. Problem Identified

The current operational behavior has highlighted an important asymmetry:

- the EA can realize small profits frequently;
- however, favorable movements can sometimes generate substantially larger unrealized profits before the basket is closed;
- at the same time, unfavorable situations can accumulate considerably larger negative exposure.

This creates a strategic imbalance:

> **small realized gains versus potentially large temporary losses.**

The research direction proposed here is not simply to increase the profit target.

Instead, MAIA should eventually learn to distinguish between:

1. weak/short-lived favorable movements;
2. normal favorable movements;
3. strong directional movements;
4. exceptional movements with high profit potential;
5. consolidation or uncertain conditions.

The same basic position-management engine could therefore behave differently depending on the market regime and the historical effectiveness of each action.

---

## 3. Core Concept: State → Action → Result → Learning

The fundamental MAIA experience record should follow this structure:

**MARKET STATE → ACTION → RESULT**

For example:

```text
Market State:
    Trend = UP
    Volatility = HIGH
    Structure = EXPANSION
    Basket Direction = BUY

Action:
    PROTECT_AND_RUNNER

Result:
    MFE = +420 USD
    MAE = -85 USD
    Final P&L = +310 USD
    Outcome = SUCCESS
```

Another example:

```text
Market State:
    Trend = RANGE
    Volatility = LOW
    Structure = COMPRESSION

Action:
    AGGRESSIVE_RUNNER

Result:
    MFE = +32 USD
    Final P&L = +4 USD

Outcome:
    LOW_VALUE
```

Over many observations, MAIA can learn which actions are more appropriate for each state.

---

## 4. Market Regime Detection

MAIA should not depend on a single indicator.

A future regime classifier should combine multiple observable characteristics.

Possible dimensions:

### 4.1 Direction

- structural bullish;
- structural bearish;
- neutral;
- transition bullish;
- transition bearish.

### 4.2 Trend strength

Possible measurements:

- moving-average slope;
- separation between moving averages;
- price displacement;
- directional persistence;
- ADX or equivalent trend-strength measurement;
- consecutive directional candles.

### 4.3 Volatility

Possible measurements:

- ATR;
- ATR relative to historical ATR;
- candle range;
- range expansion/contraction;
- volatility percentile.

### 4.4 Market structure

Possible states:

- expansion;
- contraction;
- breakout;
- pullback;
- continuation;
- reversal;
- consolidation.

### 4.5 Location

Possible contextual variables:

- distance from moving averages;
- VWAP;
- previous highs/lows;
- session extremes;
- support/resistance;
- liquidity zones;
- basket average price.

---

## 5. Proposed Initial Regime Set

A first conceptual state machine could use states such as:

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

These states are **hypotheses**, not final classifications.

The historical dataset should determine whether these states are useful and whether additional or fewer states are necessary.

---

## 6. Multi-Timeframe Concept

The initial research direction should prioritize **M5** as the main regime timeframe.

Potential hierarchy:

```text
M1  = execution / microstructure
M5  = primary regime
M15 = macro confirmation
```

The important principle is that each timeframe should have a clearly defined responsibility.

MAIA should avoid allowing multiple timeframes to independently modify the same decision without a hierarchy.

---

## 7. Experience Memory

MAIA should maintain persistent experience records.

A conceptual experience table could contain:

| Field | Description |
|---|---|
| timestamp | Time of experience |
| symbol | Instrument |
| timeframe | Main decision timeframe |
| regime | Classified market state |
| regime_confidence | Confidence in classification |
| direction | BUY / SELL / BOTH / NONE |
| basket_state | Current basket condition |
| exposure | Exposure at decision |
| action | Action selected |
| action_parameters | Relevant parameters |
| entry_price | Entry reference |
| peak_profit | Maximum favorable P&L |
| max_drawdown | Maximum adverse excursion |
| final_profit | Final result |
| duration | Time in state/trade |
| outcome | WIN / LOSS / NEUTRAL |
| model_version | Learning model version |

---

## 8. MAE and MFE

Two particularly important measurements are:

### MAE — Maximum Adverse Excursion

The worst unrealized loss reached during the experience.

### MFE — Maximum Favorable Excursion

The greatest unrealized profit reached during the experience.

These measurements are critical because final P&L alone can hide important information.

Example:

```text
Final P&L = +5 USD
MFE       = +250 USD
MAE       = -40 USD
```

This is not equivalent to an operation that was never above +10 USD.

The first case indicates a potentially significant **profit-capture failure**.

MAIA should therefore learn not only:

> "Did the action make money?"

but also:

> "How much opportunity existed before the final exit?"

---

## 9. Profit Asymmetry

One of the main research objectives is to investigate a **profit-asymmetric management policy**.

Instead of:

```text
small profit → immediate realization
```

the future system could use states such as:

```text
PROFIT_DEVELOPING
        ↓
PROFIT_PROTECTION
        ↓
RUNNER
        ↓
TRAILING
        ↓
REALIZATION
```

The exact thresholds should NOT be hard-coded initially.

They should be investigated through historical data.

Possible future parameters:

- minimum profit activation;
- protected profit;
- trailing distance;
- volatility-adjusted trailing;
- basket-level trailing;
- partial realization;
- runner allocation;
- maximum giveback;
- time-based protection.

---

## 10. Bidirectional Runner

The runner concept should be direction-neutral.

It should work for:

```text
BUY basket
SELL basket
```

The logic should ask:

> "Is the current market movement sufficiently favorable, persistent and historically associated with larger MFE?"

rather than:

> "Is this a BUY or SELL?"

Therefore, the same conceptual policy can be applied to both sides.

---

## 11. Adaptive Learning

The proposed learning architecture should evolve in stages.

### Stage 1 — Observation

MAIA only records:

```text
state
action
result
MFE
MAE
```

No autonomous behavioral change.

### Stage 2 — Statistical Memory

MAIA calculates:

- success rate;
- average P&L;
- median P&L;
- MFE;
- MAE;
- expectancy;
- drawdown;
- sample size;
- confidence;
- recent performance.

### Stage 3 — Regime × Action Matrix

Example:

| Regime | Action | Trades | Win Rate | Avg P&L | Avg MFE | Score |
|---|---|---:|---:|---:|---:|---:|
| Trend Up | Runner | 120 | 61% | +82 | +143 | 0.78 |
| Trend Up | Fast Exit | 120 | 76% | +21 | +95 | 0.49 |
| Range | Runner | 90 | 43% | -12 | +31 | 0.22 |
| Range | Fast Exit | 90 | 71% | +14 | +28 | 0.57 |

The system can then gradually favor the action historically better suited to the current state.

---

## 12. Forgetting / Time Decay

Market behavior changes.

Therefore, historical observations should not necessarily have equal weight forever.

A future MAIA implementation could use:

**Time-decayed weighting**

Recent experiences receive greater weight than very old experiences.

Conceptually:

```text
Weight = BaseWeight × TimeDecay
```

This allows adaptation without deleting history.

The complete history remains available for research, while the operational model emphasizes more recent behavior.

---

## 13. Short-Term and Long-Term Memory

A two-layer memory model is recommended.

### Long-Term Memory

Represents stable historical knowledge.

Examples:

- regime/action performance;
- long-term expectancy;
- typical MFE;
- typical MAE;
- historical distribution.

### Short-Term Memory

Represents current market behavior.

Examples:

- last 20 trades;
- last 50 regime observations;
- current volatility condition;
- recent runner performance.

The operational score can combine both.

Example:

```text
FinalScore =
    70% RecentPerformance
  + 30% LongTermPerformance
```

The exact percentages should be empirically determined.

---

## 14. Learning Should Be Slow

The system must avoid overreaction.

A single loss should not cause:

```text
RUNNER → DISABLED
```

Likewise, a single large win should not cause:

```text
RUNNER → ALWAYS ENABLED
```

Changes should require:

- minimum sample size;
- confidence threshold;
- statistical significance or stability;
- repeated evidence;
- bounded parameter changes.

This prevents the EA from chasing noise.

---

## 15. Machine Learning Techniques

Several machine-learning approaches are candidates for future research.

### 15.1 Supervised Classification

Predict:

```text
Probability of favorable expansion
Probability of continuation
Probability of reversal
Probability of consolidation
```

Potential models:

- Logistic Regression;
- Random Forest;
- Gradient Boosting;
- XGBoost/LightGBM-type models;
- neural networks.

The first models should preferably remain simple and interpretable.

### 15.2 Clustering

Unsupervised learning can discover market regimes without requiring predefined labels.

Possible techniques:

- K-Means;
- Gaussian Mixture Models;
- hierarchical clustering.

The objective is to discover whether historical observations naturally form distinct behavioral groups.

### 15.3 Contextual Bandits

This is particularly interesting for MAIA.

The system observes:

```text
Context = current market regime
```

and chooses:

```text
Action = management policy
```

Then it receives:

```text
Reward = result
```

Over time, it learns which action tends to produce better rewards in each context.

### 15.4 Reinforcement Learning

A more advanced future possibility.

Conceptually:

```text
STATE → ACTION → REWARD → NEW STATE
```

Possible rewards could incorporate:

- realized profit;
- MFE capture;
- drawdown;
- exposure;
- duration;
- risk-adjusted return.

However, reinforcement learning should be considered a later stage, not the starting point.

---

## 16. Recommended Learning Hierarchy

The safest development sequence is:

```text
1. Data Collection
        ↓
2. Experience Memory
        ↓
3. Regime Classification
        ↓
4. Statistical Performance Matrix
        ↓
5. Time-Decay Adaptation
        ↓
6. Controlled Action Selection
        ↓
7. Contextual Bandit
        ↓
8. Advanced ML / Reinforcement Learning
```

This creates a progression from deterministic and auditable behavior toward adaptive intelligence.

---

## 17. CSV as Persistent Memory

CSV is suitable for the historical memory layer because it provides:

- simplicity;
- portability;
- auditability;
- easy analysis in Python/Excel;
- human-readable records;
- easy backup;
- compatibility with the existing project workflow.

However:

> **The EA should not repeatedly read the CSV on every tick.**

Recommended architecture:

```text
CSV
 ↓
LOAD
 ↓
RAM / In-Memory Knowledge
 ↓
REAL-TIME DECISION
 ↓
NEW EXPERIENCE
 ↓
RAM UPDATE
 ↓
PERIODIC CSV PERSISTENCE
```

This avoids unnecessary disk I/O during market execution.

---

## 18. Possible Persistent Files

A future implementation could separate information into files.

### MAIA_EXPERIENCES.csv

Raw experiences.

### MAIA_REGIMES.csv

Detected regime observations.

### MAIA_ACTIONS.csv

Actions selected by the system.

### MAIA_PERFORMANCE.csv

Aggregated performance by regime/action.

### MAIA_MODEL.csv

Current adaptive weights and model metadata.

### MAIA_EVENTS.csv

Important transitions and learning events.

This separation improves auditability.

---

## 19. Example Knowledge Record

```text
REGIME = HIGH_VOLATILITY_EXPANSION
ACTION = RUNNER
SAMPLE = 184
WIN_RATE = 63.6%
AVG_PNL = +74.20
AVG_MFE = +161.40
AVG_MAE = -52.80
RECENT_SCORE = 0.81
LONG_TERM_SCORE = 0.72
CONFIDENCE = HIGH
```

The EA does not need to remember every historical trade in RAM.

It can load aggregated knowledge and keep the complete raw history in CSV.

---

## 20. Model Versioning

Every adaptive model should have a version.

Example:

```text
MAIA_MODEL_v0001
MAIA_MODEL_v0002
MAIA_MODEL_v0003
```

Each model should record:

- creation date;
- training period;
- sample count;
- features;
- regimes;
- actions;
- parameters;
- validation metrics.

This prevents an adaptive model from becoming an unexplained black box.

---

## 21. Safety Rules

MAIA must never be allowed to modify critical behavior without explicit validation.

Future safety mechanisms should include:

### Hard Limits

Maximum:

- exposure;
- drawdown;
- number of positions;
- recovery steps;
- parameter deviation.

### Change Limits

MAIA can only modify parameters within predefined ranges.

### Confidence Gate

No adaptation when sample size is insufficient.

### Stability Gate

No adaptation after isolated events.

### Rollback

Every adaptive model must be reversible.

### Baseline Fallback

If the model becomes invalid:

```text
MAIA → DISABLED
EA → BASELINE BEHAVIOR
```

---

## 22. Critical Design Principle

MAIA should not learn:

> "How to make money at any cost."

It should learn:

> **"Given this market state, which permitted action has historically produced the best risk-adjusted outcome?"**

This distinction is fundamental.

The learning system must operate inside a predefined risk envelope.

---

## 23. Research Questions

Before implementation, the following questions should be answered empirically:

1. How frequently does the EA experience large MFE before small final profits?
2. Which market regimes produce the largest MFE?
3. Which regimes produce the largest MAE?
4. Does a runner improve expectancy?
5. What amount of profit giveback is historically optimal?
6. Is basket trailing superior to fixed profit targets?
7. Does ATR-based trailing outperform fixed-distance trailing?
8. Does the optimal exit differ between trend and consolidation?
9. How quickly do market regimes change?
10. How much historical data should remain relevant?
11. What minimum sample size is required before adaptation?
12. Does recent performance predict future performance?
13. How much adaptation can occur without increasing drawdown?
14. Can contextual bandits improve action selection over static rules?

---

## 24. Proposed Future MAIA Architecture

```text
                    MARKET DATA
                         │
                         ▼
               ┌───────────────────┐
               │ FEATURE EXTRACTION │
               └─────────┬─────────┘
                         │
                         ▼
               ┌───────────────────┐
               │ REGIME DETECTOR   │
               └─────────┬─────────┘
                         │
                         ▼
               ┌───────────────────┐
               │ EXPERIENCE MEMORY  │
               │  SHORT + LONG     │
               └─────────┬─────────┘
                         │
                         ▼
               ┌───────────────────┐
               │ ACTION KNOWLEDGE   │
               │ REGIME × ACTION    │
               └─────────┬─────────┘
                         │
                         ▼
               ┌───────────────────┐
               │ ADAPTIVE POLICY    │
               └─────────┬─────────┘
                         │
                         ▼
               ┌───────────────────┐
               │ RISK / SAFETY GATE │
               └─────────┬─────────┘
                         │
                         ▼
                     EA ACTION
                         │
                         ▼
                      RESULT
                         │
                         └──────────────► EXPERIENCE MEMORY
```

---

## 25. Development Philosophy

The implementation should follow:

**Observe → Record → Analyze → Validate → Adapt**

and never:

**Guess → Change → Hope**

The first version of MAIA should therefore be an **observer**, not an autonomous optimizer.

Only after sufficient evidence exists should MAIA be allowed to influence decisions.

---

## 26. Relationship with EAGOLD

MAIA is intended as a future intelligence layer.

It should not initially replace:

- R1;
- R4;
- R5;
- R7;
- R9;
- R10;
- R10.2;
- R11;
- or the v0.106 operational baseline.

Instead, the future architecture should preferably sit above the existing engines as a controlled decision-support/adaptation layer.

Conceptually:

```text
EAGOLD CORE
     │
     ├── Existing deterministic engines
     │
     └── MAIA
           ├── Regime
           ├── Memory
           ├── Statistics
           ├── Adaptive policy
           └── Confidence
```

---

## 27. Current Status

**NO IMPLEMENTATION AUTHORIZED BY THIS DOCUMENT.**

This document is a research and architecture specification only.

The current EAGOLD operational baseline must remain untouched.

Before implementation, the project should first collect and analyze enough historical experience to determine whether the proposed concepts actually improve:

- expectancy;
- average winning trade;
- profit factor;
- MFE capture;
- maximum drawdown;
- recovery behavior;
- risk-adjusted return.

---

## 28. Final Concept

The central idea of MAIA is not simply "machine learning inside an EA."

It is the creation of a **persistent operational memory**.

The EA should eventually be capable of remembering:

```text
WHAT WAS THE MARKET LIKE?
WHAT DID I DO?
WHAT HAPPENED?
HOW GOOD WAS THE RESULT?
WAS THERE MORE PROFIT AVAILABLE?
HOW MUCH RISK WAS TAKEN?
HAS THIS BEHAVIOR CHANGED RECENTLY?
```

From those observations, it can gradually develop:

```text
MARKET REGIME KNOWLEDGE
        +
ACTION PERFORMANCE KNOWLEDGE
        +
RECENT MARKET MEMORY
        +
LONG-TERM EXPERIENCE
        +
CONTROLLED ADAPTATION
```

The ultimate objective is a system that does not merely execute a fixed set of rules, but **adapts its permitted behavior according to evidence accumulated from its own operational history**, while remaining bounded, versioned, auditable and reversible.

---

## 29. Research References

The research direction discussed during the design phase includes material from the official **MQL5/MetaQuotes** ecosystem concerning:

- market regime detection;
- adaptive trading systems;
- trailing/profit protection concepts;
- experience-based decision making;
- reinforcement learning and Q-learning concepts in trading systems.

These references should be formally catalogued and linked to specific official MQL5 articles before implementation, so that each external concept used by MAIA has a traceable source.

---

## 30. Search Keywords

Use the following keywords when searching the repository in the future:

```text
MAIA
ADAPTIVE
MACHINE LEARNING
MARKET REGIME
REGIME DETECTION
EXPERIENCE MEMORY
EXPERIENCE LEARNING
MFE
MAE
PROFIT ASYMMETRY
RUNNER
BASKET TRAILING
PROFIT LOCK
TIME DECAY
CONTEXTUAL BANDIT
Q-LEARNING
REINFORCEMENT LEARNING
ACTION PERFORMANCE
REGIME ACTION MATRIX
ADAPTIVE POLICY
```

**Document classification:** FUTURE_IMPLEMENTATIONS  
**Operational impact:** NONE  
**Baseline modification:** NONE
