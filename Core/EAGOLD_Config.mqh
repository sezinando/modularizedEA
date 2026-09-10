#ifndef EAGOLD_CONFIG_MQH
#define EAGOLD_CONFIG_MQH

//==================================================================
// EAGOLD CONFIGURATION CONTRACT
// Centralized input configuration extracted from EAGOLD v0.106.
// Keep business behavior out of this file.
//==================================================================

input string INPUT_GROUP_GENERAL="=== GENERAL / IDENTITY ===";
extern int MagicNumber=3009;

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
// 0=LEGACY COUNT*TP | 1=DIRECTIONAL | 2=BIDIRECTIONAL | 3=HYBRID
extern int BRXRealizationMode=3;
extern double BRXDirectionalMinProfit=5.00;
extern double BRXBidirectionalMinProfit=5.00;
extern bool BRXRequireWeightedBE=false;
extern double BRXWeightedBEBufferPoints=0.0;

input string INPUT_GROUP_PANEL="=== MODULAR PANEL / DEBUG ===";
extern bool EnableModularizationPanel=true;
extern bool EnableModularizationDebug=false;

input string INPUT_GROUP_R9="=== R9 EXPOSURE CONTROLLER ===";
extern bool EnableR9Hedge=true;
extern double R9ExposureTriggerLots=1.00;
extern double R9TriggerLotMinimum=0.00;
extern double R9HedgeFraction=0.6666666667;
extern double R9BalanceCap=0.50;

input string INPUT_GROUP_R10="=== R10 EXPOSURE REDUCTION ===";
extern bool EnableR10Reduce=true;
extern double R10MinExposureLots=0.01;
extern bool EnableR10PairReduction=true;
extern double R10PairMinProfit=5.00;
extern double R10PairMaxLots=1.00;
extern int R10PairCooldownSeconds=30;
extern bool EnableR10VisualMarker=true;
extern string R10MarkerFont="Arial Bold";
extern int R10MarkerFontSize=9;
extern color R10BuyMarkerColor=clrLime;
extern color R10SellMarkerColor=clrTomato;
extern double R10MarkerOffsetPoints=25.0;
extern bool EnableEngineActionMarkers=true;
extern int EngineActionMarkerFontSize=8;
extern double EngineActionMarkerOffsetPoints=18.0;

input string INPUT_GROUP_R102="=== R10.2 RECOVERY REALIZATION ===";
extern bool EnableR10RecoveryRealization=false;
extern double R10RecoveryMinDebt=100.0;
extern double R10RecoveryProfitTarget=50.0;
extern double R10RecoveryDebtTargetPercent=0.0;
extern bool R10RecoveryRequireDebtRepaid=true;

input string INPUT_GROUP_R11="=== R11 RECOVERY STEP CONTROL ===";
extern bool EnableRecoveryStepMultiplier=true;
extern double RecoveryStepMultiplier=1.15;
extern double RecoveryStepMax=500.0;

input string INPUT_GROUP_UI="=== UI / PANEL ===";
extern int PanelBackgroundX=260;
extern int PanelBackgroundY=8;
extern int PanelBackgroundHeight=450;
extern int PanelBottomY=8;
extern int PanelBottomX1=15;
extern int PanelBottomX2=190;
extern int PanelBottomX3=520;
extern int PanelBottomX4=850;

#endif
