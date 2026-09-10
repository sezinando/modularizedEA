# R10 Regression Scenarios — initial modular port

These scenarios are derived from the validated R10 documentation and are the minimum regression contract for the first modular implementation.

| ID | Before BUY | Before SELL | Expected |
|---|---:|---:|---|
| R10-01 | 1.00 | 0.40 | Pair reduction of 0.40; gross decreases 1.40 -> 0.60; net exposure remains 0.60 |
| R10-02 | 1.00 | 1.00 | No pair candidate solely because the basket is balanced; R10 must not increase exposure |
| R10-03 | 1.00 | 0.00 | Pair reduction unavailable because no opposing position exists |
| R10-04 | 0.40 | 1.00 | Symmetric SELL-heavy case; reduce 0.40 from both sides |
| R10-05 | broker-invalid volume | any | Candidate rejected before execution |
| R10-06 | valid basket | valid basket | Post-execution verification must confirm gross did not increase and the logical action is not repeated during cooldown/idempotency protection |

## Architectural regression

- R10 must not open an order.
- R10 must not mutate R10.2 debt variables.
- R10 must not control R11 recovery-step progression.
- R10 must not depend on UI state.
- R10 event data must contain action identity and before/after basket state.

## Validation status

The repository currently contains the implementation skeleton and the pair-reduction path. MetaEditor/Strategy Tester compilation and runtime validation remain an explicit next step; no compilation PASS is claimed by this repository bootstrap commit.
