# EAGOLD R12 REGIME OBSERVER v1.0

## Objective
Observer-only market-regime classification used to contextualize excursion and realization telemetry. R12 does not authorize, block, close, modify, hedge, resize or otherwise alter trading behavior.

## Primary timeframe
M5. Only closed candles are used (`shift=1`). M1/M15 integration is intentionally deferred to a later increment.

## Regime vocabulary
- UNKNOWN
- BULLISH_TREND
- BEARISH_TREND
- BULLISH_PULLBACK
- BEARISH_PULLBACK
- HIGH_VOLATILITY
- LOW_VOLATILITY
- TRANSITION_BULLISH
- TRANSITION_BEARISH
- EXHAUSTION
- CONFLICT

## First observer features
- ATR(14) and ATR ratio versus five M5 bars earlier
- SMA(9) / SMA(21)
- normalized fast/slow slopes over three M5 bars
- normalized six-bar directional drift
- current M5 range / ATR
- candle body / range

## Classification priority
1. HIGH_VOLATILITY
2. EXHAUSTION
3. BULLISH_TREND / BEARISH_TREND
4. BULLISH_PULLBACK / BEARISH_PULLBACK
5. TRANSITION_BULLISH / TRANSITION_BEARISH
6. LOW_VOLATILITY
7. CONFLICT

## Integration
R12 state is sampled by the EA before economic engines and remains observer-only. Realization events record the current R12 regime and normalized market features alongside excursion/exposure measurements.

## Safety
No input gate is added in v1.0. No trading engine reads R12 to make an economic decision. Thresholds are provisional research thresholds and must not be treated as optimized trading parameters.

## Validation
Required before any economic use:
- MT4 compile
- M5 backtest
- non-empty R12 state distribution
- event-to-regime correlation
- no change in broker actions versus baseline
- no lookahead
