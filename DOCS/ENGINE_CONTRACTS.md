# Engine Contracts

Every engine documents these six boundaries:

| Field | Meaning |
|---|---|
| INPUT | configuration and runtime facts accepted by the engine |
| STATE READ | state the engine may observe |
| DECISION | policy owned by the engine |
| ACTION | broker/account action the engine may request |
| OUTPUT | state/result returned to the orchestrator |
| EVENT | auditable event emitted after a material action |

## Ownership

- **R1**: first-order admission.
- **R4/R5/R7**: existing lifecycle, grid and restart behavior.
- **R9**: exposure detection and hedge behavior.
- **R10**: reduction of already-existing exposure.
- **R10.2**: recovery realization/accounting.
- **R11**: recovery-step progression.
- **Core**: shared state, order inspection and broker execution primitives.
- **UI**: presentation only.
- **Persistence**: durable state only.

## R10 hard boundary

R10 may observe R9/R10.2/R11 state, but cannot mutate their owned state. R10 cannot open a position merely to make a reduction possible.

The formal R10 pipeline is:

`MEASURE -> CLASSIFY -> CANDIDATE -> SIMULATE -> HARD CONSTRAINTS -> LEXICOGRAPHIC RANK -> EXECUTE -> VERIFY -> RECONCILE -> EVENT`

This follows the existing R10 formal documentation in `sezinando/newbot`.
