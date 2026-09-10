# EAGOLD v0.106 — Complete Restoration Audit

## Baseline

Authoritative behavioral source: `sezinando/newbot/EA/EAGOLD.mq4`, version `0.106`.

The operational entry point in `EA/EAGOLD.mq4` is restored to the same source content as the authoritative baseline. Content SHA: `187dcfa4fd6d382c7f2ff4b0f555e29b19c2b9d7`.

## Gaps corrected in the operational entry point

| Area | Restored |
|---|---|
| Full input contract | Yes |
| Core order inspection | Yes |
| Market execution | Yes |
| Pending execution | Yes |
| Pending deletion | Yes |
| R1 first-order seed | Yes |
| R1.1 admission gate | Yes |
| BUY lifecycle | Yes |
| SELL lifecycle | Yes |
| Basket close | Yes |
| R7 restart/keep-alive | Yes |
| Recovery lot progression | Yes |
| R9 activation detection | Yes |
| R9 hedge | Yes |
| R10 standard reduction | Yes |
| R10 profit-funded pair | Yes |
| R10 visual marker | Yes |
| R10.2 recovery accounting | Yes |
| R11 dynamic recovery step | Yes |
| Pending stop trailing | Yes |
| Telemetry | Yes |
| Global Variable persistence | Yes |
| Operational panel | Yes |
| Full OnInit/OnDeinit/OnTick orchestration | Yes |

## Critical root cause

The previous modular entry point only measured the basket, called the isolated R10 reducer, and updated the diagnostic panel. R10 is reduction-only and requires an already existing two-sided basket. Therefore a flat account could never reach an entry action.

The restored `OnTick()` sequence is again:

`R10.2 state -> R9 activation detection -> BUY machine -> SELL machine -> first-order creation/keep-alive -> pending trailing -> telemetry -> panel -> persistence`.

## Important boundary

The modular support files under `Core/`, `Engines/`, `UI/` and `Persistence/` are retained as reconstruction material. They are not silently substituted into the restored operational entry point until their behavior is regression-tested against v0.106.

This avoids the previous failure mode where a structurally modular EA looked complete but lacked the actual trading lifecycle.

## Validation status

Repository-level source restoration: **PASS** — the operational EA content matches the authoritative v0.106 baseline by content SHA.

MT4 compilation: **PENDING** — must be performed in MetaEditor because no MT4 compiler is available in the repository tooling environment.

Strategy Tester runtime regression: **PENDING** — required before any new modular engine is enabled in production.
