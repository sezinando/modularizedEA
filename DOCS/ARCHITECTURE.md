# EAGOLD Modular Architecture

## 1. Purpose

`modularizedEA` is the rewrite target for EAGOLD. The legacy EA remains the behavioral baseline; the modular code is built by responsibility rather than by copying the monolithic source structure.

## 2. Rules

1. Refactoring must not silently change trading behavior.
2. Each engine owns one responsibility and exposes an explicit contract.
3. Core modules provide state and execution primitives; engines make policy decisions.
4. UI and persistence cannot contain trading decisions.
5. R10 cannot create exposure to reduce exposure.
6. R10.2 owns recovery accounting; R11 owns recovery-step progression.
7. Every safety-critical engine must be testable independently of the panel.

## 3. Target tree

```text
EA/EAGOLD.mq4
Core/
  EAGOLD_Context.mqh
  EAGOLD_State.mqh
  EAGOLD_Orders.mqh
  EAGOLD_Execution.mqh
  EAGOLD_Events.mqh
  EAGOLD_Telemetry.mqh
Engines/
  R1/R1_Admission.mqh
  R4/R4_Lifecycle.mqh
  R5/R5_Recovery.mqh
  R7/R7_Restart.mqh
  R9/R9_Exposure.mqh
  R10/R10_Core.mqh
  R10.2/R102_RecoveryAccounting.mqh
  R11/R11_RecoveryStep.mqh
Persistence/EAGOLD_GlobalState.mqh
UI/EAGOLD_Clock.mqh
UI/EAGOLD_Panel.mqh
Tests/
DOCS/
```

## 4. Migration order

`baseline -> core -> R1 -> R9 -> R10 -> R10.2 -> R11 -> lifecycle -> UI/persistence -> regression`

R10 is being rebuilt from the formal specification rather than treating the old `Rule10Reduce()` as the final architecture.
