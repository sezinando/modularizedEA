# EAGOLD — Counterfactual Path Telemetry Checkpoint v1.0

## Objective

Implement the minimum observer-only telemetry required to generate a replayable, ticket-level historical path for future counterfactual profit-management research.

## Implemented

### New module

`Core/EAGOLD_CounterfactualPathTelemetry.mqh`

The module writes `EAGOLD_COUNTERFACTUAL_PATH.csv` and records one row per open EAGOLD market position at each sampled EA tick.

Each row contains:

- ordered path sequence;
- timestamp and execution phase (`INIT`, `PRE_ACTION`, `POST_ACTION`);
- cycle identity and active-cycle flag;
- realization sequence;
- ticket, direction, lot size and entry price;
- current executable-side price;
- current SL/TP;
- ticket floating P/L, swap and commission;
- basket, BUY-side and SELL-side floating P/L;
- BUY/SELL/gross/net exposure;
- cycle realized P/L and total realized P/L;
- cycle MFE/MAE/peak;
- interval MFE/MAE/peak;
- synchronized R12 state and regime sequences;
- synchronized Bid/Ask.

## Integration

`EA/EAGOLD.mq4` was advanced to v0.109 and now records:

1. `PRE_ACTION` snapshot before economic engines execute;
2. current transaction engines execute under the existing Action Contract;
3. `POST_ACTION` snapshot after economic execution.

This ordering is intentional: it allows a future replay to distinguish the ticket set immediately before and immediately after a realization without modifying the current trading policy.

## Configuration

`EnableCounterfactualPathTelemetry=true` was added to the centralized configuration under:

`=== 07A COUNTERFACTUAL PATH TELEMETRY ===`

The telemetry is observer-only and does not submit, modify or close orders.

## Counterfactual readiness

The resulting path is designed to support:

- ticket-level Partial simulation;
- position-level BE transformation simulation;
- explicit Runner exit simulation;
- basket trailing simulation;
- side/basket eligibility analysis;
- exposure and regime-conditioned policy analysis.

The telemetry does not itself implement any hypothetical policy and does not authorize production execution.

## Important limitation

The recorder uses the EA tick stream available to the runtime. It does not reconstruct ticks that were not supplied by the terminal/tester. Therefore validation quality remains dependent on the historical tick source and its Bid/Ask fidelity.

## Validation status

- Structural integration: PASS by source inspection.
- Observer-only contract: PASS by design/source inspection.
- Production behavior change: NONE intended.
- MT4 compiler validation: PENDING local MetaEditor/tester execution.
- Historical path generation: PENDING rerun with telemetry enabled.
- Counterfactual P0–P4 analysis: NOT YET EXECUTED.

## Next step

Run the June replay with v0.109 and collect `EAGOLD_COUNTERFACTUAL_PATH.csv`. Then validate:

1. path row continuity;
2. ticket lifecycle continuity;
3. PRE/POST action boundaries;
4. order entry-price persistence;
5. R12 synchronization;
6. realized P/L reconciliation against existing event telemetry;
7. suitability for the counterfactual simulator.

Only after these checks should P0–P4 counterfactual simulations be executed.

**Status: TELEMETRY IMPLEMENTED — HISTORICAL PATH VALIDATION PENDING.**
