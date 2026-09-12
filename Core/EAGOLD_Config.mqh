#ifndef EAGOLD_CONFIG_MQH
#define EAGOLD_CONFIG_MQH

//==================================================================
// EAGOLD CONFIGURATION CONTRACT
// Centralized input configuration extracted from EAGOLD v0.106.
// Keep business behavior out of this file.
//
// ORGANIZATION RULE
// 01. General / identity
// 02. Core money / grid
// 03. Admission / lifecycle
// 04. Profit realization
// 05. Exposure / recovery control
// 06. Recovery satellite
// 07. Observability / UI
// 08. Persistence
//==================================================================

#define EAGOLD_VERSION "0.106"
#define EAGOLD_R13_DEFAULT_COMMENT "EAGOLD_RECOVERY_SATELLITE"
#define EAGOLD_EXPIRY_DATE D'2026.12.31 00:00'

double g_panelMinProfit=0.0;
double g_panelMaxProfit=0.0;
double g_panelMaxLots=0.0;
bool g_panelInitialized=false;

// Test-license policy: trading is allowed through 30/12/2026 23:59:59
// using broker/server time. From 31/12/2026 00:00 onward no new orders
// may be submitted. Existing orders remain manageable/closable.
bool EAGOLD_TradingAllowed()
{
   return(TimeCurrent()<EAGOLD_EXPIRY_DATE);
}

//==================================================================
// 01. GENERAL / IDENTITY
//==================================================================
input string INPUT_GROUP_GENERAL="=== 01 GENERAL / IDENTITY ===";
// -1 = TODOS os pedidos/ordens do símbolo, independentemente do Magic.
extern int MagicNumber=-1;

//==================================================================
// 02. CORE MONEY / GRID
//==================================================================
input string INPUT_GROUP_MONEY="=== 02 CORE MONEY / LOT PROGRESSION ===";
extern double Lot=0.01;
extern double Multiplier=1.10;
extern int DigitsLots=2;
extern double LotIncrement=0.02;
extern double MaxOpenLot=3.00;
extern double TakeProfit=5.00;
extern double SellProfit=30.00;
extern double BasketLoss=100.00;
extern int SpreadLimit=100;
extern int WaitSeconds=0;

input string INPUT_GROUP_GRID="=== 02A CORE GRID / DISTANCES ===";
extern double FirstStep=160.0;
extern double MiniGrid1=320.0;
extern double SmartGrid1=280.0;
extern double RecoveryMinDistance=340.0;
extern double MiniGrid2=80.0;
extern double SmartGrid2=60.0;
extern double PendingStepTrail=50.0;
extern double BasketRestartStep=160.0;
extern int MaxTrades=2000;
extern bool EnableCloseBy=true;
extern double BuyProgressionTolerance=10.0;

//==================================================================
// 03. ADMISSION / LIFECYCLE
//==================================================================
input string INPUT_GROUP_R1_ADMISSION="=== 03 R1 / FIRST ADMISSION CONTROL ===";
extern bool EnableR1AdmissionGate=false;
extern bool EnableR1BrokerGuard=false;
extern bool EnableR1LotGuard=false;
extern bool EnableR1MarginGuard=false;
extern bool EnableR1TradePermissionGuard=false;
extern double R1BrokerSafetyBufferPoints=0.0;
extern double R1MinFreeMarginAfterOrder=0.0;
extern bool EnableR1DecisionLog=true;

input string INPUT_GROUP_LIFECYCLE="=== 03 R4 / R5 / R7 LIFECYCLE ===";

input string INPUT_GROUP_GLOBAL_TRAIL="=== 03 GLOBAL STOP TRAIL CONTROL ===";
extern bool EnableGlobalStopTrail=true;
extern double GlobalStopTrailCooldownSeconds=0.0;
extern double GlobalStopTrailMinStepPoints=0.0;

//==================================================================
// 04. PROFIT REALIZATION
//==================================================================
input string INPUT_GROUP_BRX="=== 04 BRX / BASKET REALIZATION ===";
extern bool EnableBasketRealization=true;
extern int BRXRealizationMode=3;
extern double BRXDirectionalMinProfit=5.00;
extern double BRXBidirectionalMinProfit=5.00;
// Extra floating-P/L cushion required before a realization is authorized.
// This protects the realization floor against normal execution movement/slippage.
// Runtime validation baseline: nominal floor 5.00 + safety buffer 5.00 = 10.00.
extern double BRXRealizationSafetyBuffer=5.00;
extern bool BRXRequireWeightedBE=false;
extern double BRXWeightedBEBufferPoints=0.0;

//==================================================================
// 05. EXPOSURE / RECOVERY CONTROL
//==================================================================
input string INPUT_GROUP_R9="=== 05 R9 / EXPOSURE CONTROLLER ===";
// Runtime BRX isolation baseline: R9 disabled during isolated BRX tests.
extern bool EnableR9Hedge=false;
extern double R9ExposureTriggerLots=1.00;
extern double R9TriggerLotMinimum=0.00;
extern double R9HedgeFraction=0.6666666667;
extern double R9BalanceCap=0.50;

input string INPUT_GROUP_R10="=== 05 R10 / EXPOSURE REDUCTION ===";
// Runtime BRX isolation baseline: R10 disabled for the first BRX test battery.
extern bool EnableR10Reduce=false;
extern double R10MinExposureLots=0.01;
extern bool EnableR10PairReduction=false;
extern double R10PairMinProfit=5.00;
extern double R10PairMaxLots=1.00;
extern int R10PairCooldownSeconds=30;

input string INPUT_GROUP_R102="=== 05 R10.2 / RECOVERY REALIZATION ===";
// Runtime BRX isolation baseline: R10.2 disabled for the isolated battery.
extern bool EnableR10RecoveryRealization=false;
extern double R10RecoveryMinDebt=100.0;
extern double R10RecoveryProfitTarget=50.0;
extern double R10RecoveryDebtTargetPercent=0.0;
extern bool R10RecoveryRequireDebtRepaid=true;

input string INPUT_GROUP_R11="=== 05 R11 / RECOVERY STEP & EXPOSURE GOVERNOR ===";
extern bool EnableRecoveryStepMultiplier=true;
extern double RecoveryStepMultiplier=1.15;
extern double RecoveryStepMax=500.0;
// R11 controls only NEW recovery exposure. Existing positions remain under R10/R9.
extern bool EnableR11ExposureGovernor=true;
extern double R11TaperStartGrossExposureLots=8.00;
extern double R11BlockGrossExposureLots=12.00;
extern double R11MinNetToGrossRatio=0.10;
extern double R11MinRecoveryLotFactor=0.25;

//==================================================================
// 06. RECOVERY SATELLITE
//==================================================================
input string INPUT_GROUP_R13="=== 06 R13 / RECOVERY SATELLITE ===";
// Runtime BRX isolation baseline: R13 disabled so it cannot affect BRX tests.
extern bool EnableR13=false;
extern bool EnableR13AutoActivation=false;
extern bool EnableR13Trading=false;
extern double R13ProfitTarget=5.00;
extern double R13EntryCooldownSeconds=30.0;
extern bool R13CloseWhenMasterFlat=true;
extern bool EnableR13MasterAdjustment=true;
extern double R13MasterAdjustmentMaxLots=0.20;
extern int R13MagicNumber=3010;
extern string R13OrderComment=EAGOLD_R13_DEFAULT_COMMENT;
extern double R13MaxLots=0.20;
extern int R13MaxPositions=3;
extern double R13MaxDrawdown=50.00;
extern double R13MaxDailyLoss=50.00;
extern double R13MaxSpread=100.0;
extern int R13StartHour=0;
extern int R13EndHour=23;
extern bool EnableR13DirectionalComplementarity=true;
extern double R13MinDirectionalImbalance=0.01;
extern double R13RecoveryCapitalFraction=1.00;

//==================================================================
// 07. OBSERVABILITY / UI / MARKERS
//==================================================================
input string INPUT_GROUP_R10_MARKERS="=== 07 R10 / ACTION MARKERS ===";
extern bool EnableR10VisualMarker=true;
extern string R10MarkerFont="Segoe UI Semibold";
extern int R10MarkerFontSize=9;
extern color R10BuyMarkerColor=clrLime;
extern color R10SellMarkerColor=clrTomato;
extern double R10MarkerOffsetPoints=25.0;

input string INPUT_GROUP_ENGINE_MARKERS="=== 07 ENGINE ACTION MARKERS ===";
extern bool EnableEngineActionMarkers=true;
extern string EngineActionMarkerFont="Impact";
extern int EngineActionMarkerFontSize=9;
extern color EngineActionMarkerTextColor=clrYellow;
extern color EngineActionMarkerBackgroundColor=clrBlack;
extern double EngineActionMarkerOffsetPips=20.0;
extern double EngineActionMarkerStackStepPips=20.0;
double EngineActionMarkerOffsetPoints=100.0;

input string INPUT_GROUP_PANEL="=== 07 MODULAR PANEL / DEBUG ===";
extern bool EnableModularizationPanel=true;
extern bool EnableModularizationDebug=false;

input string INPUT_GROUP_CHART_GUIDES="=== 07 CHART BASKET GUIDES ===";
extern bool EnableChartBasketGuides=true;
extern int ChartBasketGuideOffsetBars=2;

input string INPUT_GROUP_UI="=== 07 UI / PANEL LAYOUT ===";
extern int PanelBackgroundX=260;
extern int PanelBackgroundY=8;
extern int PanelBackgroundHeight=450;
extern int PanelBottomY=8;
extern int PanelBottomX1=15;
extern int PanelBottomX2=190;
extern int PanelBottomX3=520;
extern int PanelBottomX4=850;
extern int PanelBackgroundWidth=430;

//==================================================================
// 08. PERSISTENCE
//==================================================================
input string INPUT_GROUP_PERSISTENCE="=== 08 PERSISTENCE / CHECKPOINT POLICY ===";
// Strategic state is persisted only on meaningful changes. A new worst-equity
// checkpoint is considered meaningful when it moves by at least this amount.
// Smaller changes remain in RAM and are persisted at the next significant event
// or forced lifecycle checkpoint (OnDeinit).
extern double PersistenceWorstEquityStep=5.00;

#endif
