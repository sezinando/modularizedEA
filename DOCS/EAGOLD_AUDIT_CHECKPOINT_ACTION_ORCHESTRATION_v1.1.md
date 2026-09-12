# EAGOLD Audit Checkpoint — Action Orchestration & Partial Execution v1.1

**EA baseline:** v0.106  
**Branch:** main  
**Date:** 2026-09-12  
**Gate:** PRE-LIVE BLOCK

## 1. Objective

Continue the transaction-contract audit from checkpoint v1.0 by tracing broker-action call sites through execution, lifecycle orchestration, telemetry and persistence. The focus is whether a material broker action can occur while the caller reports `false`, allowing a later economic engine to execute in the same tick as if nothing had happened.

## 2. Static evidence reviewed

- `Core/EAGOLD_Execution.mqh`
- `Core/EAGOLD_Events.mqh`
- `Core/EAGOLD_Telemetry.mqh`
- `Core/EAGOLD_Persistence.mqh`
- `Engines/EAGOLD_Lifecycle.mqh`
- `Engines/EAGOLD_R13_Satellite.mqh`
- `EA/EAGOLD.mq4`

No MT4 Strategy Tester runtime evidence was produced in this stage.

## 3. Confirmed findings

### F1 — R4/R5 basket close can execute partially and fall through
**Severity: HIGH / PRE-LIVE BLOCK**

`CloseDirectionPositionsRobust()` collects tickets and closes them sequentially. It returns `false` when any close fails, even if earlier tickets were successfully closed. `BuyBasketClose()` / `SellBasketClose()` propagate that `false`. `BuyMachine()` / `SellMachine()` then continue to `SingleTakeProfit()` and `Recovery()`.

Therefore:

```text
R5 basket close
  ticket A -> CLOSED
  ticket B -> CLOSED
  ticket C -> FAILED
        |
        v
CloseDirectionPositionsRobust() -> false
        |
        v
BuyBasketClose() -> false
        |
        v
BuySingleTakeProfit()
BuyRecovery()
```

This violates the transaction invariant that PARTIAL must not be interpreted as NO_ACTION.

### F2 — R10 has the same false-after-action pattern
**Severity: HIGH / PRE-LIVE BLOCK**

The integrated `Engines/EAGOLD_R10.mqh` can close one leg and fail on the next, returning `false`. The lifecycle then remains eligible to continue with later economic actions. The same class of issue exists in partial average adjustment.

### F3 — R13 close-all reports success when only one Satellite ticket closed
**Severity: HIGH / PRE-LIVE BLOCK**

`R13CloseAll()` uses `changed=true` after any successful close and returns `changed`, rather than verifying that all owned Satellite positions are gone. Consequently, one successful close plus one failed close can be treated as a successful exit. `R13ManageOpenPositions()` can then add recovery capital and attempt Master adjustment while Satellite exposure remains.

This directly conflicts with the R13 contract: when Master exposure is zero, Satellite must leave the market.

### F4 — R1 admission is atomic, seed execution is not
**Severity: MEDIUM / ORANGE**

`CreateFirstOrdersIfFlat()` validates BUY and SELL admission before sending either order, but executes the two `SendPending()` calls sequentially and accepts `b>0 || s>0` as initial success. A BUY-created / SELL-failed condition is therefore possible without an explicit partial transaction state or reconciliation phase.

### F5 — R13 economic capital is not persisted
**Severity: MEDIUM-HIGH**

`g_r13RecoveryCapitalAvailable` and `g_r13RecoveryCapitalUsed` are economic state variables. `Core/EAGOLD_Persistence.mqh` persists R10 recovery state and R9 hedge state but does not persist these R13 capital values. A terminal/EA restart can therefore lose the continuity of capital reserved for a future Master adjustment.

## 4. Orchestration finding

`EA/EAGOLD.mq4` currently executes:

```text
R10.2 state update
R9
BUY MACHINE
SELL MACHINE
R1 / flat initialization
R7 trailing
R13
telemetry / persistence
```

There is no global transaction/action-budget result shared across engines. BUY and SELL machines can each consume economic actions, and R13 can perform additional economic actions after them, including an internal R10 adjustment.

This is not by itself proof that BUY+SELL same-tick activity is economically wrong. The finding is that the contract does not explicitly define whether multiple independent economic actions in one tick are permitted, forbidden, or limited after PARTIAL execution.

## 5. Event/telemetry finding

`Core/EAGOLD_Events.mqh` defines an R10 event with a single boolean `success`. `Core/EAGOLD_Telemetry.mqh` logs that boolean plus before/after exposure and realized P/L. This is insufficient to distinguish:

```text
NONE / BLOCKED / COMPLETED / PARTIAL / FAILED
```

A richer action result is therefore still required. Existing telemetry can describe an R10 event but is not yet a universal transaction ledger for R1/R4/R5/R7/R9/R11/R13.

## 6. Required contract evolution

Introduce a common action result:

```text
EAGOLD_ActionResult
  NONE
  BLOCKED
  COMPLETED
  PARTIAL
  FAILED
```

and a tick-level policy:

```text
EAGOLD_TickPolicy
  CONTINUE
  CONSUME
  HALT_FOR_RECONCILIATION
```

Required rule:

```text
PARTIAL
  -> measure actual broker state
  -> emit auditable partial event
  -> persist required non-reconstructible state
  -> HALT_FOR_RECONCILIATION
  -> no subsequent economic engine in same tick
  -> reconcile on next tick before new action
```

## 7. Current action matrix

| Action | Partial possible | Current result semantics | Gate |
|---|---:|---|---|
| R1 initial BUY+SELL seeds | Yes | `b>0 || s>0` | ORANGE |
| R7 restart pending | Broker rejection | ticket / `-1` | YELLOW |
| R9 hedge | Broker rejection | ticket / `-1` | YELLOW |
| R4 single TP | Follow-up action can fail | bool | ORANGE |
| R5 basket | Yes | final bool | RED |
| R10 pair | Yes | bool | RED |
| R10 average | Yes | bool | RED |
| BRX directional/bidirectional | Yes | isolated from same-tick fall-through by `BRX_Run()` | ORANGE |
| R11 recovery | Broker rejection | ticket / `-1` | YELLOW |
| R13 close-all | Yes | `true` if any close | RED |
| R13 -> R10 adjustment | Yes | bool | RED |
| Pending deletion | Yes | per-order bool ignored by loop | ORANGE |

## 8. Next audit stage

The next stage is **R7/restart + pending-order lifecycle reconciliation**, specifically:

1. prove whether partial R1/R4/R5/R10/R13 states can cause R7 recreation in the same tick;
2. audit `ClearPendingOrders` / direction-specific pending deletion semantics;
3. determine whether failed pending deletion can leave stale orders that alter subsequent engine decisions;
4. map each restart path to an explicit transaction result and tick-consumption policy;
5. only then design the minimal Core contract implementation.

## 9. Gate decision

**PRE-LIVE remains BLOCKED.**

Static analysis has identified multiple material partial-execution paths. No runtime validation should be interpreted as approval until controlled MT4 tests demonstrate reconciliation and isolation behavior.
