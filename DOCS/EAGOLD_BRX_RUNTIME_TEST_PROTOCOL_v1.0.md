# EAGOLD — BRX Runtime Test Protocol v1.0

**Status:** TEST PROTOCOL / NOT RUN
**Baseline:** EAGOLD v0.106 / `sezinando/modularizedEA` / branch `main`
**Purpose:** Define the controlled runtime evidence required to validate the BRX realization paths before LIVE release.

## 1. Execution rule

These tests are runtime tests. Static code inspection is not sufficient for PASS.

Each execution must register:

`TEST | DATE/TIME | SYMBOL | TIMEFRAME | EA COMMIT | SET HASH | MODE | SCENARIO | EXPECTED | OBSERVED | RESULT | NOTES`

The same EA build and `.set` must be retained for the complete test batch unless the test explicitly changes one parameter.

The tests must be executed in MT4 Strategy Tester or an equivalent controlled runtime capable of producing the EAGOLD journal. This repository audit environment does not contain an MT4 runtime, therefore no test below is marked PASS by this document alone.

## 2. Required evidence

For every test capture:

- EAGOLD initialization line and complete inputs;
- EA commit SHA;
- exact `.set` file hash;
- symbol and timeframe;
- entry state immediately before the BRX decision;
- BUY and SELL position count/lots;
- directional and total floating profit;
- BRX floor;
- safety buffer;
- weighted BE values when applicable;
- R10.2 state when applicable;
- BRX decision (`HOLD`, `CLOSE`, or partial/failed execution);
- actual realized P/L after execution;
- remaining positions/pending orders;
- next lifecycle action (`R1`, `R7`, R10, Recovery, or none);
- swap and commission where applicable.

## 3. T-BRX-01 — Nominal floor protected by buffer

**Parameters**

- `EnableBasketRealization=true`
- `BRXRealizationMode=1` or `3`
- `BRXDirectionalMinProfit=5.00`
- `BRXRealizationSafetyBuffer=5.00`
- `BRXRequireWeightedBE=false`

**Scenario**

Create a multi-position directional basket whose current directional profit is strictly between 5.00 and 10.00.

**Expected**

`HOLD`.

No BRX directional close may occur. The subsequent Lifecycle path must also not bypass the protected floor.

**Acceptance**

PASS only if the journal demonstrates no close authorized in the interval `5.00 <= profit < 10.00`.

## 4. T-BRX-02 — Protected floor reached

**Parameters**

Same as T-BRX-01.

**Scenario**

Raise the same basket above 10.00 while all other conditions remain eligible.

**Expected**

BRX directional realization becomes eligible, subject to `R10RecoveryAllowBasketClose()` and other close guards.

**Acceptance**

PASS only if the decision changes from HOLD to close eligibility at the protected floor and the actual execution is recorded.

## 5. T-BRX-03 — Zero safety buffer

**Parameters**

- `BRXDirectionalMinProfit=5.00`
- `BRXRealizationSafetyBuffer=0.00`

**Scenario**

Test a directional basket between 5.00 and the next meaningful execution increment, then above 5.00.

**Expected**

No additional safety cushion is required by BRX. Behavior is equivalent to the nominal floor.

**Acceptance**

PASS only if changing the buffer from 5.00 to 0.00 removes exactly the BRX authorization cushion and does not alter unrelated controls.

## 6. T-BRX-04 — Weighted BE protection

**Parameters**

- `BRXRequireWeightedBE=true`
- `BRXWeightedBEBufferPoints > 0`
- `BRXRealizationSafetyBuffer=5.00`

**Scenario**

Create a multi-position directional basket where the profit floor is reached but the market price has not yet reached weighted BE plus/minus the configured BE buffer.

Then move price to a valid weighted-BE-protected state.

**Expected**

First state: `HOLD`.

Second state: close eligible, subject to remaining guards.

**Acceptance**

PASS only if the weighted BE condition is independently respected and cannot be bypassed by the nominal profit condition.

## 7. T-BRX-05 — R10 before BRX

**Parameters**

- BRX enabled in directional or hybrid mode;
- R10 enabled;
- `EnableR10RecoveryRealization=false` for the first execution.

**Scenario**

1. Establish a basket eligible for R10.
2. Allow R10 to execute a reduction.
3. Record actual R10 realized P/L.
4. Preserve the remaining basket.
5. Drive the remaining basket into a BRX realization condition.
6. Record BRX decision and actual realized result.

**Expected**

R10 and BRX must be distinguishable in the journal and in economic accounting.

The final economic result must include:

`R10 realized + BRX realized + remaining floating result - swap - commission`

No nominal pre-close profit may be substituted for actual realized P/L.

**Acceptance**

PASS only when the complete economic chain is reconstructible from the journal.

## 8. T-BRX-06 — R10.2 active

**Parameters**

Same as T-BRX-05 plus:

- `EnableR10RecoveryRealization=true`
- controlled `R10RecoveryMinDebt`
- controlled `R10RecoveryProfitTarget`
- `R10RecoveryRequireDebtRepaid=true`

**Scenario**

Repeat T-BRX-05 with R10.2 active.

**Expected**

R10.2 remains an independent economic guard. BRX must not bypass the R10.2 authorization state.

**Acceptance**

PASS only if the journal demonstrates the R10.2 decision and BRX decision independently and the final close cannot be attributed to an unguarded path.

## 9. Additional lifecycle observation — BRX bidirectional

This is not a replacement for T-BRX-01..06. It is a mandatory observation because the current modular implementation introduces a lifecycle path that did not exist in the legacy baseline.

**Scenario**

- `BRXRealizationMode=2` or `3`;
- both BUY and SELL positions present;
- bidirectional protected floor reached;
- allow complete BRX close.

**Expected observation to establish**

Determine whether the actual sequence is:

`BRX BIDIRECTIONAL CLOSE -> MASTER FLAT -> R1`

or whether another restart/continuity transition occurs.

This must be recorded as observed behavior first. It must not be classified as a bug solely because it differs from the legacy path, because the legacy EAGOLD did not contain BRX.

## 10. Partial execution test

A controlled execution failure/partial close must be attempted where the environment safely permits it.

**Expected**

- actual closed tickets/realized P/L are recorded;
- remaining exposure is explicitly visible;
- no rollback is assumed;
- no nominal result is reported as realized;
- in hybrid mode, a BRX target reached before the failed attempt must not fall through to R10/R4/Recovery in the same machine cycle.

## 11. Acceptance gate

The BRX block remains **PRE-LIVE BLOCK** until:

- T-BRX-01 = PASS;
- T-BRX-02 = PASS;
- T-BRX-03 = PASS;
- T-BRX-04 = PASS or formally NOT APPLICABLE;
- T-BRX-05 = PASS;
- T-BRX-06 = PASS or formally NOT APPLICABLE;
- partial execution behavior is evidenced;
- BRX bidirectional lifecycle transition is evidenced;
- exact EA commit and `.set` hash are registered.

## 12. Current execution status

| Test | Status | Reason |
|---|---|---|
| T-BRX-01 | NOT RUN | Requires MT4 runtime execution |
| T-BRX-02 | NOT RUN | Requires MT4 runtime execution |
| T-BRX-03 | NOT RUN | Requires MT4 runtime execution |
| T-BRX-04 | NOT RUN | Requires MT4 runtime execution |
| T-BRX-05 | NOT RUN | Requires MT4 runtime execution |
| T-BRX-06 | NOT RUN | Requires MT4 runtime execution |
| BRX bidirectional lifecycle | NOT RUN | Requires MT4 runtime execution |
| Partial execution | NOT RUN | Requires controlled execution-failure scenario |

**Decision:** PRE-LIVE BLOCK remains active.
