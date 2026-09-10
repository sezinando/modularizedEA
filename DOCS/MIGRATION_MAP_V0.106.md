# Migration Map — EAGOLD v0.106

The uploaded `EAGOLD(2).mq4` contains 86 functions in the monolithic baseline.

## Core candidates

`PointsToPrice`, `NormalizePrice`, `NormalizeLot`, `IsEAGOLDOrder`, order counters, `DirectionBasketProfit`, `DirectionLots`, `ExposureLots`, `HeavyDirection`.

## Persistence candidates

`StateKey`, `ConfigKey`, `PersistConfigState`, `LoadPersistedConfig`, `PersistAllState`.

## R1

`R1Decision`, `R1ValidateLot`, `R1BrokerGuard`, `R1TradePermissionGuard`, `R1MarginGuard`, `R1AdmissionAllowed`.

## R9

`R9Processed`, `R9MarkProcessed`, `R9SeedExistingPositions`, `R9GetNewExposureState`, `R9HedgeFromActivatedTicket`, `Rule9DetectActivatedOrders`.

## R10

`R10FindProfitFundedPair`, `Rule10ProfitFundedPartial`, `ReduceDirectionByLots`, `Rule10Reduce`, plus the visual/action markers that will move to UI/events.

## R10.2

`R10RecoveryDebt`, `R10RecoveryRemainingDebt`, `R10RecoverySurplus`, `R10RecoveryTarget`, `R10RecoveryStartCycle`, `R10RecoveryResetCycle`, `R10RecoveryUpdateState`, `R10RecoveryAllowBasketClose`.

## R11 / lifecycle

`RecoveryStepForLevel`, `RecoveryLevel`, `NextRecoveryLot`, `BuyRecovery`, `SellRecovery`, `RestartEmptyBasket`, and the buy/sell machine orchestration are migrated only after the shared core is stable.

## UI

`PanelCreate`, `PanelCreateLabel`, `PanelCreateBottomLabel`, `PanelSet`, `PanelSetBottom`, `PanelDelete`, `PanelMoney`, `PanelUpdate`, `CreateEngineActionMarker`, `CreateR10VisualMarker`, plus the clock presentation.

## Execution

`SendPending`, `SendMarket`, `CloseMarketOrder`, `CloseMarketOrderLots`, `DeletePendingOrder`, `CloseAllDirectionPending`.

## Entry point

`OnInit`, `OnDeinit`, `OnTick` become a thin orchestrator. They must not contain engine policy.

The legacy source is preserved conceptually as the reference behavior; migration is performed module by module with regression checks.
