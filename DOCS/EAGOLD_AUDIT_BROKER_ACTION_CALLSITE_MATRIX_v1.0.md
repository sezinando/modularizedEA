# EAGOLD — Broker Action Call-Site Audit Matrix v1.0

**Date:** 2026-09-12  
**Baseline:** EAGOLD v0.106  
**Branch:** main  
**Status:** AUDIT IN PROGRESS / PRE-LIVE BLOCK

## 1. Audit objective

Trace every material broker mutation through:

```text
CALL SITE
 -> ENGINE
 -> EXECUTION API
 -> RESULT SEMANTICS
 -> BROKER STATE CHANGE
 -> REALIZED P/L
 -> EVENT
 -> PERSISTENCE
 -> TICK POLICY
 -> NEXT ENGINE
```

The audit is specifically looking for legacy `bool` semantics that can hide partial broker execution, bypass central trading policy, or allow economic fall-through.

## 2. Current findings

### F-01 — R13 direct execution bypasses central execution policy

**Severity:** HIGH / PRE-LIVE BLOCK

`Engines/EAGOLD_R13_Satellite.mqh` contains its own `R13SendMarket()` and `R13CloseTicket()` using direct `OrderSend()` / `OrderClose()` rather than the centralized EAGOLD execution layer.

The centralized `SendPending()` and `SendMarket()` enforce `EAGOLD_TradingAllowed()`. R13's own send path currently relies on its local risk gate and does not call the centralized expiry policy.

**Risk:** R13 can have different admission semantics from the Master execution path, including a possible mismatch with the global test/trading-expiry policy.

**Disposition:** OPEN — next correction should route R13 execution through a centralized R13-aware execution contract or explicitly apply the central trading-allowed policy before every new R13 order.

### F-02 — BRX still consumes legacy boolean lifecycle results

**Severity:** HIGH / PRE-LIVE BLOCK

`Engines/EAGOLD_BRX.mqh` uses `CloseDirectionPositionsRobust()` and treats `false` as a partial/failed condition. The lifecycle wrapper now returns `true` only for full completion, but BRX does not receive the explicit `PARTIAL` outcome and does not itself request reconciliation when a partial close occurred.

`BRX_Run()` does stop the current tick after a target is reached, which reduces same-tick fall-through, but the partial broker state is not promoted into the same transaction/reconciliation contract used by R5/R13.

**Risk:** BRX may leave a partially closed basket without the explicit reconciliation barrier and without a uniform transaction event.

**Disposition:** OPEN — migrate BRX to `EAGOLD_ActionResult`.

### F-03 — BRX pending cleanup result is ignored

**Severity:** HIGH / PRE-LIVE BLOCK

BRX calls `CloseAllDirectionPending()` after successful market closure but does not require the returned `bool` to succeed before treating the BRX direction/basket action as complete.

The R4/R5 path already treats pending cleanup failure as `PARTIAL` and requests reconciliation.

**Risk:** stale pending orders can survive a BRX realization and remain capable of future activation.

**Disposition:** OPEN — BRX must adopt the same cleanup postcondition used by R4/R5.

### F-04 — R1 seed remains economically non-atomic after admission

**Severity:** MEDIUM

`CreateFirstOrdersIfFlat()` performs BUY and SELL seed creation sequentially and considers the seed operation successful when `b>0 || s>0`.

Admission validation is atomic, but broker execution can still produce BUY success + SELL failure without an explicit transaction result/reconciliation boundary.

**Disposition:** OPEN — migrate R1 seed execution to explicit transaction semantics after higher-severity BRX/R13 execution-policy issues are closed.

### F-05 — R7 restart is guarded by broker census but remains boolean/legacy

**Severity:** MEDIUM

R7 uses `SendPending()` and checks position/pending counts before creation, which is materially safer than direct execution. However, restart creation still has no explicit action-result event or reconciliation outcome.

**Disposition:** OPEN — include in the final call-site audit.

## 3. Confirmed GREEN areas

### G-01 — R5 market close

`CloseDirectionPositionsTransactional()` explicitly distinguishes `BLOCKED`, `COMPLETED`, `PARTIAL`, and `FAILED` and verifies the direction postcondition.

### G-02 — R5 pending cleanup

`CloseAllDirectionPending()` attempts all deletions and verifies zero remaining directional pending orders.

### G-03 — R9 entry path

R9 uses the centralized `SendMarket()` execution wrapper rather than direct `OrderSend()`.

### G-04 — Recovery/R11 entry path

Recovery additions use centralized `SendPending()` and the R11 exposure governor before submission.

### G-05 — R13 exit transaction

R13 now captures its ticket set, tracks requested/completed counts and lots, verifies the postcondition, and distinguishes partial execution from full completion.

## 4. Priority order

```text
1. F-01 R13 central trading-policy bypass
2. F-02 BRX transaction-contract migration
3. F-03 BRX pending-cleanup transaction
4. F-04 R1 seed transaction
5. F-05 R7 explicit transaction semantics
6. R10 legacy/formal implementation consolidation
7. Runtime validation matrix
```

## 5. Gate

**PRE-LIVE BLOCK remains active.**

This document records static audit findings only. No runtime PASS is implied.
