# EAGOLD — Trading Window + Spread Entry Guards v1.0

## Objective

Introduce two independent controls for NEW broker orders without changing the ability of an already active basket to close and conclude.

## 1. Trading window

Inputs:

- `EnableTradingTimeWindow`
- `TradeStartHour`
- `TradeStartMinute`
- `TradeEndHour`
- `TradeEndMinute`

The clock is the MT4 broker/server time (`TimeCurrent()`).

When enabled, NEW orders are admitted only inside the configured interval. The interval supports normal windows (for example 09:00 → 17:00) and overnight windows (22:00 → 05:00). Equal start/end is treated as a full-day window.

### End-of-window behavior

The guard applies only to NEW broker orders. It does **not** block:

- `OrderClose`
- partial close
- pending deletion
- pending modification/trailing

Therefore, when the entry window ends, an existing basket is allowed to conclude. New recovery/re-entry/keep-alive/hedge entries are also blocked outside the window, preventing the EA from rebuilding or expanding exposure after the cutoff.

## 2. Spread filter

Inputs:

- `EnableSpreadFilter`
- `MaxSpreadPoints`

Current spread is calculated as:

`(Ask - Bid) / Point`

If spread is greater than `MaxSpreadPoints`, NEW broker orders are rejected. Existing positions can still be closed and managed.

## 3. Central enforcement

The admission policy is centralized in:

`Core/EAGOLD_TradingGuards.mqh`

and enforced by the core entry wrappers:

- `SendPending()`
- `SendMarket()`
- `SendMarketByMagic()`

This covers Master entries and R13 reserved-Magic market entries while preserving the existing ownership model.

## 4. Strategy preservation

Both controls default to `false`, so the current strategy behavior is unchanged until explicitly enabled in the MT4 inputs.

No changes were made to profit targets, grid distances, recovery mathematics, R9/R10/R11 logic, R13 economics, or basket-closing rules.

## 5. Validation checklist

Runtime validation should prove:

1. Before Start: no new basket is created.
2. Inside window + acceptable spread: normal entries work.
3. Above maximum spread: no new broker order is created.
4. At End: no new basket/re-entry/recovery/keep-alive/hedge entry is created.
5. At End with active basket: existing basket remains manageable and can close normally.
6. After a close at End: R4/R5/BRX do not recreate a new entry.
7. Closing and pending deletion remain available when the entry guard is blocking.
8. Overnight windows behave correctly.
9. MT4 Strategy Tester and live/demo logs confirm no unintended entry bypass exists.

## Status

- Code: implemented.
- Runtime/Strategy Tester: pending.
- Default behavior: preserved (`false` / disabled).
