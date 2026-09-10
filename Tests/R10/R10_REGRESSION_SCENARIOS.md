# R10 Regression Scenarios — formal pair-reduction core

These scenarios define the minimum regression contract for the modular R10 pair-reduction implementation.

| ID | Before BUY | Before SELL | Expected |
|---|---:|---:|---|
| R10-01 | 1.00 | 0.40 | Pair reduction of 0.40; gross decreases 1.40 -> 0.60; net exposure decreases 0.60 -> 0.20 |
| R10-02 | 1.00 | 1.00 | No pair candidate because the basket is balanced; R10 must not increase exposure |
| R10-03 | 1.00 | 0.00 | Pair reduction unavailable because no opposing position exists |
| R10-04 | 0.40 | 1.00 | Symmetric SELL-heavy case; reduce 0.40 from both sides; gross 1.40 -> 0.60; exposure 0.60 -> 0.20 |
| R10-05 | broker-invalid volume | any | Candidate rejected before execution |
| R10-06 | valid basket | valid basket | Post-execution verification must confirm gross and exposure both decreased; cooldown prevents immediate repetition |

## Formal hard constraints

- **HC-01 Ownership:** both selected tickets belong to the configured symbol/magic context.
- **HC-02 Valid order:** both tickets are live market positions with opposite directions.
- **HC-03 Broker volume:** reduction lots respect broker min/max/step constraints.
- **HC-04 Minimum retained exposure:** configured minimum exposure contract is respected.
- **HC-06 Gross reduction:** post-action gross lots must be strictly lower.
- **HC-07 Directional safety:** post-action net exposure must not increase.
- **HC-10 No new exposure:** R10 can only reduce existing positions; it never sends a new order.
- **HC-12 Idempotency/cooldown:** a successful action updates `lastAction` and blocks an immediate repeated action during the configured cooldown.

## Mathematical contract

For a balanced pair reduction of `r` lots:

- BUY-heavy: `afterBuy = beforeBuy - r`, `afterSell = beforeSell - r`.
- SELL-heavy: `afterBuy = beforeBuy - r`, `afterSell = beforeSell - r`.
- `afterExposure = abs(afterBuy - afterSell)`.
- `afterGross = afterBuy + afterSell`.

R10 must verify the **actual broker state** after execution rather than relying only on the pre-trade simulation.

## Architectural regression

- R10 must not open an order.
- R10 must not mutate R10.2 debt variables.
- R10 must not control R11 recovery-step progression.
- R10 must not depend on UI state.
- R10 event data must contain action identity and before/after basket state.

## Validation status

The formal pair-reduction implementation and regression contract are committed. MetaEditor/Strategy Tester compilation and runtime validation remain an explicit next step; no compilation PASS is claimed by this repository tooling.
