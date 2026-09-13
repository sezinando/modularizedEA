# EAGOLD — Counterfactual Path Integrity Audit v1.0

**Status:** AMBER / STRUCTURALLY SUITABLE WITH ONE TELEMETRY GAP

## 1. Evidence

Input: `EAGOLD_COUNTERFACTUAL_PATH.csv`

Scope observed:
- 47,734 path records
- 49 fields
- 5 EAGOLD cycles
- 66 unique tickets
- 7,470 distinct timestamps
- 100% `R12_VALID=1`
- phases: 23,898 `PRE_ACTION` and 23,836 `POST_ACTION`
- PATH_SEQ is strictly monotonic and unique, with no gaps

Observed period: 2026-06-01 01:00:10 through 2026-06-01 11:34:15.

## 2. Integrity checks

### 2.1 Path sequence

PASS.

`PATH_SEQ` is monotonic, unique and increments by exactly one across all 47,734 records.

### 2.2 Ticket identity

PASS for the observed path.

Across the 66 tickets:
- no ticket appears in more than one cycle;
- no ticket changes `TYPE`;
- no ticket changes `LOTS`.

This preserves a stable ticket-level identity for path reconstruction.

### 2.3 Action boundary coverage

The existing excursion-event telemetry contains 34 realization events for the five cycles represented in this path file.

- 33/34 events have an exact timestamp represented in the path telemetry.
- 28/33 represented events have both `PRE_ACTION` and `POST_ACTION` states.
- 5/33 represented events have only `PRE_ACTION` because the action leaves no open EAGOLD market position to be written by the current ticket-only path writer.
- 1/34 event occurs after the end of this path capture (2026-06-01 11:42:40), while the path file ends at 11:34:15.

The five PRE-only boundaries are consistent with basket-flattening actions: the post-action open-ticket set is empty. However, the current telemetry does not explicitly write a zero-position POST_ACTION state.

### 2.4 R12 synchronization

PASS.

All path records contain valid R12 state. R12 regime, previous regime, transition and event-boundary fields are populated throughout the captured path.

### 2.5 Event sequence continuity

PASS within the captured path.

`EVENT_SEQ` is stable between actions and advances at realization boundaries. The sequence resets at cycle boundaries as expected.

`ENGINE_ACTION_SEQ` is stable per cycle and increments from cycle to cycle.

### 2.6 Cycle lifecycle

The path contains five cycles. Each cycle begins with an active position set and evolves through additions/removals of tickets. The capture terminates while cycle 5 still has open tickets; therefore the file is not a complete terminal-cycle record.

This is a test-window limitation, not evidence of a broken ticket lifecycle.

## 3. Cross-check with excursion events

For every represented realization event, the event timestamp can be located in the path telemetry. The realized cycle P/L visible in the path advances consistently through the represented action sequence.

The final realization event of each cycle is not followed by ticket-level POST_ACTION rows when the action closes the remaining basket. This is the principal structural limitation identified.

The path file therefore supports reconstruction of the **pre-action state** and the surviving ticket state after non-flattening actions, while terminal flattening requires the existing realization-event telemetry to establish the zero-position post-state and realized delta.

## 4. Counterfactual suitability

### Suitable now

The dataset is sufficient to begin the next analytical stage for:
- ticket-level path reconstruction;
- exposure evolution;
- regime-at-state analysis;
- action-boundary reconstruction;
- candidate Partial simulations where surviving tickets can be followed;
- MFE/MAE and continuation analysis at observed timestamps;
- deterministic replay of states using only information available up to each timestamp.

### Not yet certified for production counterfactual replay

Before implementing P1–P4 as a formal engine, the telemetry contract should explicitly represent the post-action empty basket state for flattening actions and should capture the complete test window through the terminal state of every cycle.

## 5. Required telemetry refinement

Recommended next telemetry refinement:

1. Preserve current ticket-level rows.
2. Add an explicit basket/state boundary row for `POST_ACTION` when zero market positions remain.
3. Include action/result/realized-delta linkage at that boundary.
4. Preserve `PRE_ACTION` immediately before the transaction.
5. Keep R12 fields synchronized on both boundaries.
6. Repeat the replay over a multi-day sample after this refinement.

This is a telemetry completeness refinement only. It does **not** authorize adaptive live profit management.

## 6. Decision

**Counterfactual Path Telemetry v1.0: PASS WITH GAP.**

The architecture is producing the required ticket-level path data and is suitable for the next reconstruction analysis. The identified gap is deterministic and localized to post-action representation when the basket becomes flat, plus the current replay-window cutoff.

**Next analytical step:** reconstruct the five observed cycles into a canonical ticket lifecycle and action timeline, then quantify the available counterfactual opportunity at each realization boundary before coding the P1–P4 simulation engine.
