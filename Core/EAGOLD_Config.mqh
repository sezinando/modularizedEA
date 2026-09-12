#ifndef EAGOLD_CONFIG_MQH
#define EAGOLD_CONFIG_MQH

//==================================================================
// EAGOLD CONFIGURATION CONTRACT
// Centralized input configuration extracted from EAGOLD v0.106.
// Keep business behavior out of this file.
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

input string INPUT_GROUP_GENERAL="=== GENERAL / IDENTITY ===";
// -1 = TODOS os pedidos/ordens do símbolo, independentemente do Magic.
extern int MagicNumber=-1;

input string INPUT_GROUP_MONEY="=== CORE MONEY / LOT PROGRESSION ===";
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

input string INPUT_GROUP_R1_CORE="=== R1 FIRST ENGINE / CORE ===";
extern double FirstStep=160.0;

input string INPUT_GROUP_R1_ADMISSION="=== R1.1 FIRST ADMISSION CONTROL ===";
extern bool EnableR1AdmissionGate=false;
extern bool EnableR1BrokerGuard=false;
extern bool EnableR1LotGuard=false;
extern bool EnableR1MarginGuard=false;
extern bool EnableR1TradePermissionGuard=false;
extern double R1BrokerSafetyBufferPoints=0.0;
extern double R1MinFreeMarginAfterOrder=0.0;
extern bool EnableR1DecisionLog=true;

input string INPUT_GROUP_LIFECYCLE="=== R4 / R5 / R7 LIFECYCLE ===";
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

input string INPUT_GROUP_GLOBAL_TRAIL="=== GLOBAL STOP TRAIL CONTROL ===";
extern bool EnableGlobalStopTrail=true;
extern double GlobalStopTrailCooldownSeconds=0.0;
extern double GlobalStopTrailMinStepPoints=0.0;

input string INPUT_GROUP_BRX="=== BRX BASKET REALIZATION ENGINE ===";
extern bool EnableBasketRealization=true;
extern int BRXRealizationMode=3;
extern double BRXDirectionalMinProfit=5.00;
extern double BRXBidirectionalMinProfit=5.00;
// Extra floating-P/L cushion required before a realization is authorized.
// This protects the realization floor against normal execution movement/slippage.
// Runtime validation baseline: nominal floor 5.00 + safety buffer 5.00 = 10.00.
extern double BRXRealizationSafetyBuffer=5.00;
extern bool BRXRequireWeightedBE=false;

input string INPUT_GROUP_R13="=== R13 RECOVERY SATELLITE ===";
extern bool EnableR13=false;
extern int R13Mode=1;
extern double R13TriggerMasterLoss=100.0;
extern double R13MaxSatelliteLots=1.00;
extern int R13MaxSatellitePositions=10;
extern double R13TargetProfit=5.0;
extern double R13CooldownSeconds=60.0;
extern double R13MinMasterExposureLots=0.10;
extern double R13MinMasterDirectionalLots=0.10;
extern double R13MaxSpreadPoints=100.0;
extern double R13MaxDrawdown=0.0;
extern double R13MaxDailyLoss=0.0;
extern int R13StartHour=0;
extern int R13EndHour=23;
extern double R13MinATRPoints=0.0;
extern double R13MaxRangePoints=0.0;
extern double R13MaxDriftPoints=0.0;
extern bool R13RequireComplementarity=true;
extern bool R13RequireDirectionalMaster=true;
extern bool R13RequireTradingAllowed=true;
extern bool R13EnableMasterAdjustment=true;
extern double R13MasterAdjustmentTarget=5.0;
extern double R13MasterAdjustmentMinLots=0.01;
extern double R13CapitalMinRealized=0.0;
extern bool R13PersistCapital=true;

input string INPUT_GROUP_R10="=== R10 / R10.2 RECOVERY ===";
extern bool EnableR10Reduce=false;
extern bool EnableR10RecoveryRealization=false;
extern double R10RecoveryMinDebt=5.0;
extern double R10RecoveryTargetProfit=5.0;
extern bool R10RecoveryRequireDebtRepaid=true;
extern double R10RecoveryReductionRatio=1.0;
extern double R10RecoveryMinLot=0.01;
extern double R10RecoveryMaxLot=3.00;

input string INPUT_GROUP_R11="=== R11 EXPOSURE GOVERNOR ===";
extern bool EnableR11ExposureGovernor=true;
extern double R11TaperStartGrossExposureLots=8.0;
extern double R11BlockGrossExposureLots=12.0;
extern double R11MinNetToGrossRatio=0.10;
extern double R11MinRecoveryLotFactor=0.25;

input string INPUT_GROUP_R9="=== R9 HEDGE ===";
extern bool EnableR9Hedge=false;
extern double R9HedgeRatio=0.50;
extern double R9HedgeMaxLot=1.00;
extern int R9HedgeMagic=9009;

input string INPUT_GROUP_PERSISTENCE="=== OPERATIONAL PERSISTENCE ===";
extern double PersistenceWorstEquityStep=10.0;

input string INPUT_GROUP_UI="=== MODULARIZATION PANEL / UI ===";
extern bool EnableModularizationPanel=true;
extern bool EnableModularizationDebug=false;
extern int PanelBackgroundWidth=430;
extern bool EnableEngineActionMarkers=true;

#endif
