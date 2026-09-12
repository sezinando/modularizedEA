# EAGOLD — Audit Checkpoint: Transaction Contract & Economic Action Integrity

**Version:** v1.0  
**EA baseline:** EAGOLD v0.106  
**Branch:** `main`  
**Checkpoint date:** 2026-09-12  
**Status:** PRE-LIVE BLOCK

## 1. Purpose

This checkpoint records the next stage of the EAGOLD static audit after the BRX safety-buffer review. The objective is to identify whether material economic actions are represented consistently across engines, especially when broker execution is partial.

This document is an audit checkpoint, not a LIVE approval and not a claim of runtime validation.

## 2. Current execution order

The current `OnTick()` sequence is:

1. `R10RecoveryUpdateState()`
2. `Rule9DetectActivatedOrders()`
3. `BuyMachine()`
4. `SellMachine()`
5. `CreateFirstOrdersIfFlat()`
6. `TrailAllStopOrders()`
7. `R13Observe()`
8. UI/telemetry updates
9. `PersistAllState(false)`

This establishes that several economic engines can act during one tick and that there is no explicit global transaction/action-budget contract.

## 3. Primary architectural finding

### I2 — PARTIAL must not equal NO_ACTION

**Severity: HIGH — PRE-LIVE BLOCK**

The codebase repeatedly uses `bool` return values for multi-order economic operations. A partial broker execution can therefore be represented as either `false` or `true`, depending on the engine.

Observed patterns:

| Engine | Operation | Partial behavior | Current return semantics | Risk |
|---|---|---|---|---|
| R10 | pair/balanced reduction | one leg can close while another fails | `false` | caller may fall through to another economic engine |
| R4/R5 | directional basket close | earlier tickets can close while later ticket fails | `false` | lifecycle may continue to SingleTP/Recovery |
| R13 | Satellite `R13CloseAll()` | one or more tickets can close while others remain | `true` if any ticket changed | caller may treat incomplete exit as successful |

The defect is therefore architectural rather than isolated to R10.

## 4. R10 finding

`Rule10ProfitFundedPartial()` and `Rule10Reduce()` execute sequential broker closes. If the first economic leg succeeds and a subsequent leg fails, the function can return `false` after an economic state change.

`BuyMachine()` / `SellMachine()` then continue to later lifecycle paths when R10 returns false.

Required invariant:

```text
PARTIAL R10 ACTION
  -> reconcile broker state
  -> record realized result
  -> emit PARTIAL event
  -> stop subsequent economic engines for this tick
```

A simple `false -> true` change is not an adequate fix because it loses the distinction between completed and partial transactions.

## 5. R4/R5 finding

`CloseDirectionPositionsRobust()` returns success only when all captured direction positions are closed. It can nevertheless close some tickets before a later close fails.

The caller treats the final boolean as the only result:

```text
BuyBasketClose() = false
       |
       +--> BuySingleTakeProfit()
       +--> BuyRecovery()
```

This creates a confirmed same-tick fall-through hazard after partial economic execution.

Required behavior is to halt further economic actions after a partial close until broker state is reconciled.

## 6. R13 finding

`R13CloseAll()` uses a `changed` flag and returns it. Therefore one successful close can produce `true` even when another Satellite position remains open.

This is particularly important because `R13ManageOpenPositions()` can subsequently:

1. add realized R13 profit to recovery capital;
2. attempt an R10 Master adjustment;
3. return while the Satellite is still exposed.

This conflicts with the R13 contract that the Satellite must leave the market when Master exposure is flat.

**Classification: HIGH — PRE-LIVE BLOCK.**

## 7. Persistence finding

Current strategic persistence stores R10 recovery-cycle fields, R10 last-action state, R9 hedge state and panel extrema. It does not persist:

- `g_r13RecoveryCapitalAvailable`
- `g_r13RecoveryCapitalUsed`

These values are economic state, not merely display telemetry: realized R13 profit can be reserved as capital for a later R10 Master adjustment.

**Classification: MEDIUM/HIGH architectural gap; requires resolution before LIVE continuity approval.**

## 8. R10 implementation duplication

Two R10 implementations/concepts exist:

- `Engines/EAGOLD_R10.mqh` — integrated by `EA/EAGOLD.mq4` and currently operational path.
- `Engines/R10/R10_Core.mqh` — newer candidate/simulation/verify/reconcile architecture, but not the current EA include path.

This creates audit and maintenance ambiguity. A future correction to `R10/R10_Core.mqh` would not necessarily affect the production execution path.

**Classification: MEDIUM/HIGH architectural debt; resolve before declaring R10 contract-complete.**

## 9. Proposed transaction contract

The audit recommends replacing boolean economic-operation semantics with an explicit result model:

```text
EAGOLD_ACTION_RESULT
  NONE
  BLOCKED
  COMPLETED
  PARTIAL
  FAILED
```

And an orchestration decision:

```text
EAGOLD_TICK_POLICY
  CONTINUE
  CONSUME
  HALT_FOR_RECONCILIATION
```

Minimum rule:

```text
COMPLETED -> engine-specific continuation policy
PARTIAL   -> persist/reconcile + event + HALT_FOR_RECONCILIATION
FAILED    -> engine-specific retry/block policy
```

## 10. Economic action matrix — audit baseline

| Action family | State mutation | Must verify broker state | Must record realized P/L | Partial possible | Must halt on partial |
|---|---|---:|---:|---:|---:|
| First seed / R1 | opens pending orders | yes | no | yes | yes |
| R4 Single TP | closes one market order | yes | yes | limited | yes if follow-up fails |
| R5 basket close | closes multiple tickets | yes | yes | yes | yes |
| R7 restart | creates pending order | yes | no | yes | yes |
| R9 hedge | opens market hedge | yes | no | broker-dependent | yes |
| R10 pair reduction | closes multiple legs | yes | yes | yes | yes |
| R10 average adjustment | partial close | yes | yes | yes | yes |
| R10.2 realization | closes/reconciles recovery | yes | yes | yes | yes |
| R11 recovery addition | opens recovery order | yes | no | broker-dependent | yes |
| R13 Satellite close | closes multiple Satellite tickets | yes | yes | yes | yes |
| R13 Master adjustment | invokes R10 partial close | yes | yes | yes | yes |
| Pending deletion | deletes pending orders | yes | no | yes | yes when part of a transaction |
| Stop modification | modifies pending order | yes | no | yes | context-dependent |

## 11. Current invariant status

| Invariant | Status |
|---|---|
| I1 — reduction must not increase exposure | GREEN static / runtime pending |
| I2 — PARTIAL != NO_ACTION | RED |
| I3 — one realized event must not fund two reductions | NOT YET PROVEN |
| I4 — realized capital consumed once | NOT YET PROVEN |
| I5 — R10 cannot create exposure | GREEN static |
| I6 — R7 cannot recreate during incomplete transaction | ORANGE / requires transaction contract |
| I7 — Satellite exits when Master is flat | RED |
| I8 — persistence must not lose economic state | ORANGE/RED for R13 capital |
| I9 — ticket cannot be counted twice | GREEN static / runtime pending |
| I10 — material actions emit auditable events | ORANGE / complete call-site audit pending |

## 12. Runtime status

The following remain unvalidated in controlled Strategy Tester/Journal execution:

- BRX T-BRX-01
- BRX T-BRX-03
- BRX T-BRX-04
- BRX T-BRX-05
- BRX T-BRX-06
- controlled R10 partial-failure scenario
- R9 runtime regression
- R11 runtime regression
- R13 runtime lifecycle/partial-close scenarios

Previously observed BRX T-BRX-02 evidence does not replace the complete runtime matrix.

## 13. Gate decision

**PRE-LIVE BLOCK remains active.**

No production parameter tuning or LIVE enablement should be used to bypass these findings.

## 14. Next audit step

The next stage is the complete broker-action call-site audit. It must enumerate every economic primitive and map:

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

The resulting map will be used to implement the transaction contract without changing the intended economic strategy logic.

## 15. Checkpoint reference

This document records the audit state immediately after identification of the systemic partial-execution contract gap and before implementation of the transaction-result abstraction.
