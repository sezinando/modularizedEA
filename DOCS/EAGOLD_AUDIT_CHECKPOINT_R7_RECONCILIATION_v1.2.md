# EAGOLD Audit Checkpoint — R7 / Pending Reconciliation v1.2

**EA baseline:** v0.106  
**Repository:** sezinando/modularizedEA  
**Branch:** audit/r7-reconciliation-v1  
**Status:** PRE-LIVE BLOCK

## Scope
Audit of restart/keep-alive behavior, pending-order cleanup, and reconciliation after partial broker actions.

## Findings

### 1. R7 is state-based, not transaction-aware
`EnsureDirectionMachineAlive()` recreates a pending order only when a direction has neither positions nor pending orders. `RestartEmptyBasket()` has the same precondition. Therefore R7 itself does not knowingly distinguish a clean completed transaction from a transaction that became partial.

### 2. R5 partial close does not enter reconciliation
`CloseDirectionPositionsRobust()` attempts every captured ticket and returns `ok && CountDirectionPositions(direction)==0`. If one or more tickets close and a later ticket fails, it returns false even though broker state changed. `BuyBasketClose()` / `SellBasketClose()` then return false to the lifecycle.

The lifecycle subsequently executes SingleTP and Recovery. This is a confirmed fall-through path from a partial economic action into additional engines.

### 3. R7 is not the direct trigger in the same partial path
`RestartEmptyBasket()` is called only when `BuyBasketClose()` / `SellBasketClose()` return true. Consequently a partial R5 close does not directly trigger R7 in that same call. However the remaining positions can continue through Recovery, and a later tick can reach R7 after the direction becomes empty. There is no explicit transaction identity tying the restart to completion of the preceding action.

### 4. Pending cleanup has weak result semantics
`CloseAllDirectionPending()` iterates pending orders and calls `DeletePendingOrder()`, but ignores individual deletion results and returns no aggregate status. A pending order can therefore remain while the caller proceeds as if cleanup were complete.

### 5. R1 seed creation is also non-transactional
The two initial pending seeds are submitted sequentially. Current code accepts the operation when `b>0 || s>0`; BUY success + SELL failure is therefore represented as successful initial seeding rather than PARTIAL.

### 6. R4 SingleTP can create a replacement pending after a successful close
This is intentional strategy behavior, but the close and replacement submission are two broker actions without an explicit atomic transaction/reconciliation result. If replacement submission fails, the realized close remains economically committed while the lifecycle has no explicit PARTIAL/REPAIR state.

## Contract conclusion
R7 itself is not the primary defect. The systemic defect is the absence of a shared transaction state between broker action, reconciliation, pending cleanup, restart, and subsequent engine execution.

Required contract:

```text
ACTION
  -> ActionResult { NONE | BLOCKED | COMPLETED | PARTIAL | FAILED }
  -> broker-state reconciliation
  -> pending reconciliation
  -> event
  -> persistence
  -> TickPolicy { CONTINUE | CONSUME | HALT_FOR_RECONCILIATION }
```

A `PARTIAL` result must prevent subsequent economic engines from executing until reconciliation establishes a coherent state.

## Severity
- **HIGH:** partial R5/R4 lifecycle fall-through.
- **HIGH:** missing transaction/reconciliation boundary around broker actions.
- **MEDIUM/HIGH:** pending deletion result ignored.
- **MEDIUM:** R1 two-seed partial admission/execution semantics.
- **MEDIUM:** R4 close-success/reentry-failure has no explicit recovery state.

## Evidence
`Engines/EAGOLD_Lifecycle.mqh`, `Core/EAGOLD_Execution.mqh`, `Core/EAGOLD_Orders.mqh`, and `EA/EAGOLD.mq4` were inspected on the current repository baseline.

## Gate
**PRE-LIVE remains BLOCKED.** No runtime evidence was produced by this static audit. MT4 Strategy Tester / Journal tests remain mandatory.

## Next stage
Audit the event/telemetry and realized-P/L accounting chain: determine whether every material broker action is represented exactly once, whether partial actions can generate misleading success events, and whether realized capital can be consumed more than once or lost across restart.
