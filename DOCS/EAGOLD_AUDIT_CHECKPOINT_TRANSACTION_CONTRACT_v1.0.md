# EAGOLD — Audit Checkpoint: Transaction Contract & Economic Action Integrity

**Version:** v1.1  
**EA baseline:** EAGOLD v0.106  
**Branch:** `main`  
**Checkpoint date:** 2026-09-12  
**Status:** PRE-LIVE BLOCK

## 1. Purpose

This checkpoint records the implementation stage of the EAGOLD transaction-contract audit. The objective is to prevent partial broker execution from being interpreted as no action and to force broker-state reconciliation before subsequent economic actions.

This document is an audit checkpoint, not a LIVE approval and not a claim of runtime validation.

## 2. Implemented transaction contract

The core contract now defines:

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

R10 now classifies partial pair/balanced reduction outcomes and requests reconciliation when economic state changed without full completion. The EA tick policy blocks subsequent economic engines after `PARTIAL`.

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

`Engines/EAGOLD_Lifecycle.mqh` now provides:

`CloseDirectionPositionsTransactional()`

with explicit `BLOCKED`, `COMPLETED`, `PARTIAL`, and `FAILED` outcomes.

The legacy `CloseDirectionPositionsRobust()` remains as a compatibility wrapper and returns `true` only for a fully completed close.

`BuyBasketCloseTransactional()` and `SellBasketCloseTransactional()` now propagate transaction outcomes and request reconciliation after partial basket closure.

The BUY/SELL machines stop their remaining economic actions when the basket operation is `PARTIAL`. A completed basket close does not fall through to recovery on the same direction path.

## 6. Pending cleanup is now transactional

`CloseAllDirectionPending()` now returns `bool` and verifies that no EAGOLD pending order of the direction remains after deletion attempts.

R4 single-TP reentry therefore follows:

```text
close market position
  -> delete old directional pending orders
  -> verify cleanup
  -> create replacement pending
```

If cleanup or replacement creation fails after an economic close, the action is treated as incomplete and reconciliation is requested. The code does not blindly create a replacement while an old pending may still exist.

## 7. R13 finding remains open

`R13CloseAll()` and the R13 recovery-capital lifecycle have not yet been migrated to the same transactional result contract.

The known risk remains:

```text
one Satellite ticket closes
  -> R13 may interpret `changed=true`
  -> capital may be released
  -> another Satellite ticket may remain exposed
```

R13 remains a HIGH / PRE-LIVE BLOCK item until migrated and runtime-tested.

## 8. Persistence gap remains open

R13 recovery capital state is still not persisted:

- `g_r13RecoveryCapitalAvailable`
- `g_r13RecoveryCapitalUsed`

This remains an economic continuity gap across EA restart.

## 9. R10 implementation duplication remains open

Two R10 concepts still exist:

- `Engines/EAGOLD_R10.mqh` — integrated execution path;
- `Engines/R10/R10_Core.mqh` — newer candidate/simulation/verify/reconcile architecture not used as the primary include path.

This remains architectural debt until the authoritative R10 implementation is consolidated.

## 10. Current invariant status

| Invariant | Status |
|---|---|
| I1 — reduction must not increase exposure | GREEN static / runtime pending |
| I2 — PARTIAL != NO_ACTION | GREEN static for R10/R5 paths / runtime pending |
| I3 — one realized event must not fund two reductions | NOT YET PROVEN |
| I4 — realized capital consumed once | NOT YET PROVEN |
| I5 — R10 cannot create exposure | GREEN static |
| I6 — R7 cannot recreate during incomplete transaction | IMPROVED / runtime pending |
| I7 — Satellite exits when Master is flat | RED |
| I8 — persistence must not lose economic state | ORANGE/RED for R13 capital |
| I9 — ticket cannot be counted twice | GREEN static / runtime pending |
| I10 — material actions emit auditable events | ORANGE / complete call-site audit pending |

## 11. Runtime status

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
- R13 runtime lifecycle/partial-close scenarios.

No runtime PASS is claimed by this checkpoint.

## 12. Gate decision

**PRE-LIVE BLOCK remains active.**

The transaction-contract implementation reduces the identified same-tick fall-through risk but does not authorize LIVE operation.

## 13. Next audit step

The next high-priority implementation is the R13 transactional migration, followed by the full broker-action call-site audit and runtime validation matrix.

The target map remains:

```text
CALL SITE
 -> ENGINE
 -> ACTION
 -> RESULT SEMANTICS
 -> BROKER STATE CHANGE
 -> REALIZED P/L
 -> EVENT
 -> PERSISTENCE
 -> TICK CONSUMPTION
 -> NEXT ENGINE
```
