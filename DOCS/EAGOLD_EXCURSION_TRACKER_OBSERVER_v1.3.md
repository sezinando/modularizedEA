# EAGOLD EXCURSION TRACKER v1.3

## Change
Integrates the observer-only R12 M5 market-regime state into every realization event.

## Event context added
- R12_VALID
- R12_REGIME
- R12_TIME
- R12_CLOSE
- R12_ATR
- R12_ATR_RATIO
- R12_DRIFT
- R12_SLOPE_FAST
- R12_SLOPE_SLOW
- R12_RANGE_RATIO
- R12_BODY_RATIO

## Execution order
On each tick the EA updates R12 from closed M5 candles before economic engines. The excursion tracker then observes the current basket. When an action reaches COMPLETED or PARTIAL, the event record captures the R12 state that was current at that point.

## Safety contract
R12 is observer-only. No economic engine reads the R12 state for authorization, blocking, sizing, realization, hedge, recovery or trailing decisions in this increment.

## Research intent
The resulting event table can be analyzed as:

`R12 regime × engine × exposure × MFE × MAE × inter-event giveback × realized delta`

This is the required evidence base before adaptive profit-management behavior is enabled.

## Validation status
Implementation committed to `main`. MT4 compile and runtime validation remain required. A successful compile/backtest must confirm that the added observer produces no trading-action changes and that R12 state is populated on M5 events.
