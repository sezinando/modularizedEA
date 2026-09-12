# EAGOLD — Audit Checkpoint: Transaction Contract & Economic Action Integrity

**Version:** v1.3  
**EA baseline:** EAGOLD v0.106  
**Branch:** `main`  
**Checkpoint date:** 2026-09-12  
**Status:** PRE-LIVE BLOCK

## 1. Purpose

This checkpoint records the implementation stage of the EAGOLD transaction-contract audit. The objective is to prevent partial broker execution from being interpreted as no action, force broker-state reconciliation before subsequent economic actions, and preserve non-reconstructible economic state across EA restart.

This document is an audit checkpoint, not a LIVE approval and not a claim of runtime validation.

## 2. Implemented transaction contract

The core contract defines:

```text
EAGOLD_ACTION_RESULT
  NONE
  BLOCKED
  COMPLETED
  PARTIAL
  FAILED
```

and:

```text
EAGOLD_TICK_POLICY
  CONTINUE
  CONSUME
  HALT_FOR_RECONCILIATION
```

The invariant is explicit:

```text
PARTIAL
  -> persist/reconcile broker state
  -> halt remaining economic engines for the tick
  -> retry only after reconciliation
```

## 3. R10 implementation status

R10 classifies partial pair/balanced reduction outcomes and requests reconciliation when economic state changed without full completion. The EA tick policy blocks subsequent economic engines after `PARTIAL`.

A persistent MT4 Global Variable is used as the reconciliation-required boundary, keyed by account, symbol and MagicNumber. On the next tick, the reconciliation module performs a fresh broker-visible census and only clears the barrier after the census is valid.

## 4. R10 reconciliation engine v1.0

Implemented at:

`Engines/EAGOLD_R10_Reconciliation.mqh`

Responsibilities:

1. persist the `reconciliation required` state;
2. block economic execution while reconciliation is unresolved;
3. enumerate EAGOLD market positions and pending orders;
4. verify BUY/SELL lots against the existing authoritative order helpers;
5. accept broker-visible state as authoritative;
6. clear the reconciliation barrier only after validation.

No synthetic lot/ticket repair is performed.

## 5. R4/R5 lifecycle migration

`Engines/EAGOLD_Lifecycle.mqh` provides `CloseDirectionPositionsTransactional()` with explicit `BLOCKED`, `COMPLETED`, `PARTIAL`, and `FAILED` outcomes.

The legacy `CloseDirectionPositionsRobust()` remains as a compatibility wrapper and returns `true` only for a fully completed close.

`BuyBasketCloseTransactional()` and `SellBasketCloseTransactional()` propagate transaction outcomes and request reconciliation after partial basket closure.

The BUY/SELL machines stop their remaining economic actions when the basket operation is `PARTIAL`. A completed basket close does not fall through to recovery on the same direction path.

## 6. Pending cleanup is transactional

`CloseAllDirectionPending()` returns `bool` and verifies that no EAGOLD pending order of the direction remains after deletion attempts.

R4 single-TP reentry therefore follows:

```text
close market position
  -> delete old directional pending orders
  -> verify cleanup
  -> create replacement pending
```

If cleanup or replacement creation fails after an economic close, the action is treated as incomplete and reconciliation is requested. The code does not blindly create a replacement while an old pending may still exist.

## 7. R13 transactional migration v1.0 — IMPLEMENTED

`Engines/EAGOLD_R13_Satellite.mqh` has been migrated from boolean `changed` semantics to the transaction contract.

`R13CloseAllTransactional()`:

1. captures the Satellite ticket set before mutation;
2. records requested position count and requested lots;
3. attempts each close independently;
4. records completed positions/lots and realized P/L;
5. verifies the postcondition `R13CountOwnPositions()==0`;
6. returns `COMPLETED` only when every requested Satellite position is closed and the postcondition is true;
7. returns `PARTIAL` when any economic close succeeded but Satellite exposure remains or another close failed;
8. returns `FAILED` when no close succeeds;
9. returns `BLOCKED` when there is no closeable Satellite position.

Recovery capital is released only after `COMPLETED`. `PARTIAL` and `FAILED` do not release capital and request the existing reconciliation barrier through the action contract.

## 8. R13 -> R10 funding sequence

R13 Master adjustment is mediated by `R13TryFundMasterAdjustmentTransactional()`.

The sequence is intentionally separated across ticks:

```text
R13 exit COMPLETED
  -> realize profit
  -> add eligible recovery capital
  -> CONSUME current tick

next tick
  -> attempt R13 -> R10 adjustment
  -> verify Master exposure decreased
  -> consume capital only for observed broker-side reduction
  -> PARTIAL/FAILED blocks further economic progression when applicable
```

The adapter also detects a legacy R10 false-negative when broker-visible Master exposure decreased.

## 9. R13 recovery-capital persistence — IMPLEMENTED STATICALLY

`Core/EAGOLD_Persistence.mqh` now persists:

- `g_r13RecoveryCapitalAvailable`;
- `g_r13RecoveryCapitalUsed`;
- `g_r13LastEntry`.

The R13 state uses a two-slot snapshot:

```text
inactive slot
  -> write version
  -> write available
  -> write used
  -> write last entry
  -> commit slot LAST
```

On restart, only the committed slot is restored. If no valid committed snapshot exists, the R13 capital state starts at zero rather than trusting incomplete data.

Strategy Tester remains intentionally isolated from terminal Global Variables, preserving clean in-memory test runs.

The EA include order was adjusted so R13 state exists before the persistence module accesses it.

## 10. Remaining architectural debt

Two R10 concepts still exist:

- `Engines/EAGOLD_R10.mqh` — integrated execution path;
- `Engines/R10/R10_Core.mqh` — newer candidate/simulation/verify/reconcile architecture not used as the primary include path.

This remains architectural debt until the authoritative R10 implementation is consolidated.

## 11. Current invariant status

| Invariant | Status |
|---|---|
| I1 — reduction must not increase exposure | GREEN static / runtime pending |
| I2 — PARTIAL != NO_ACTION | GREEN static for R10/R5/R13 paths / runtime pending |
| I3 — one realized event must not fund two reductions | IMPROVED static / runtime not proven |
| I4 — realized capital consumed once | IMPROVED static / runtime not proven |
| I5 — R10 cannot create exposure | GREEN static |
| I6 — R7 cannot recreate during incomplete transaction | IMPROVED / runtime pending |
| I7 — Satellite exits when Master is flat | GREEN static / runtime pending |
| I8 — persistence must not lose economic state | GREEN static for R13 snapshot design / restart runtime pending |
| I9 — ticket cannot be counted twice | GREEN static / runtime pending |
| I10 — material actions emit auditable events | ORANGE / complete call-site audit pending |

## 12. Runtime status

The implementation has not been certified by controlled MT4 Strategy Tester/Journal evidence.

Still required:

- compile validation in MetaEditor;
- controlled R10 partial-failure scenario;
- R10 reconciliation recovery scenario;
- R5 partial-close scenario;
- pending cleanup failure scenario;
- BRX runtime matrix completion;
- R9 runtime regression;
- R11 runtime regression;
- R13 runtime lifecycle/partial-close scenarios;
- R13 restart/persistence scenario.

No runtime PASS is claimed by this checkpoint.

## 13. Gate decision

**PRE-LIVE BLOCK remains active.**

The static transaction-contract and persistence work materially reduces the identified economic-integrity risks, but does not authorize LIVE operation.

## 14. Next audit step

Next priority is no longer a new trading feature. It is the **full broker-action call-site audit**:

```text
OrderSend
OrderClose
OrderCloseLots
OrderDelete
   ↓
CALL SITE
   ↓
ENGINE
   ↓
RESULT SEMANTICS
   ↓
BROKER STATE CHANGE
   ↓
REALIZED P/L
   ↓
EVENT
   ↓
PERSISTENCE
   ↓
TICK CONSUMPTION
   ↓
NEXT ENGINE
```

After the call-site audit, consolidate the authoritative R10 implementation and then execute the controlled runtime validation matrix.
