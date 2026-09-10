#property strict
#property version   "0.106"
#property description "EAGOLD - BUY/SELL independent machines - Rules 1 to 10 + R10.2 Recovery Realization + Dynamic Recovery Step Multiplier + Persistent Global Variables + Isolated R1 Admission Control"

//==================================================================
// GENERAL / IDENTITY
//==================================================================
input string INPUT_GROUP_GENERAL="=== GENERAL / IDENTITY ===";
extern int MagicNumber=3001;

//==================================================================
// CORE MONEY / LOT PROGRESSION
//==================================================================
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

//==================================================================
// R1 — FIRST ENGINE / CORE
//==================================================================
input string INPUT_GROUP_R1_CORE="=== R1 FIRST ENGINE / CORE ===";
extern double FirstStep=160.0;

//==================================================================
// R1.1 — FIRST ADMISSION CONTROL
//==================================================================
input string INPUT_GROUP_R1_ADMISSION="=== R1.1 FIRST ADMISSION CONTROL ===";
extern bool EnableR1AdmissionGate=false;
extern bool EnableR1BrokerGuard=false;
extern bool EnableR1LotGuard=false;
extern bool EnableR1MarginGuard=false;
extern bool EnableR1TradePermissionGuard=false;
extern double R1BrokerSafetyBufferPoints=0.0;
extern double R1MinFreeMarginAfterOrder=0.0;
extern bool EnableR1DecisionLog=true;

//==================================================================
// R4 / R5 / R7 — EXISTING LIFECYCLE RULES
//==================================================================
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

//==================================================================
// R9 — EXPOSURE CONTROLLER
//==================================================================
input string INPUT_GROUP_R9="=== R9 EXPOSURE CONTROLLER ===";
extern bool EnableR9Hedge=true;
extern double R9ExposureTriggerLots=1.00;
extern double R9TriggerLotMinimum=0.00;
extern double R9HedgeFraction=0.6666666667;
extern double R9BalanceCap=0.50;

//==================================================================
// R10 — EXPOSURE REDUCTION
//==================================================================
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

//==================================================================
// R10.2 — RECOVERY REALIZATION
//==================================================================
input string INPUT_GROUP_R102="=== R10.2 RECOVERY REALIZATION ===";
extern bool EnableR10RecoveryRealization=false;
extern double R10RecoveryMinDebt=100.0;
extern double R10RecoveryProfitTarget=50.0;
extern double R10RecoveryDebtTargetPercent=0.0;
extern bool R10RecoveryRequireDebtRepaid=true;

//==================================================================
// R11 — RECOVERY STEP CONTROL
//==================================================================
input string INPUT_GROUP_R11="=== R11 RECOVERY STEP CONTROL ===";
extern bool EnableRecoveryStepMultiplier=true;
extern double RecoveryStepMultiplier=1.15;
extern double RecoveryStepMax=500.0;

//==================================================================
// UI / PANEL
//==================================================================
input string INPUT_GROUP_UI="=== UI / PANEL ===";
extern int PanelBackgroundX=260;
extern int PanelBackgroundY=8;
extern int PanelBackgroundHeight=450;
extern int PanelBottomY=8;
extern int PanelBottomX1=15;
extern int PanelBottomX2=190;
extern int PanelBottomX3=520;
extern int PanelBottomX4=850;

string EA_NAME="EAGOLD";
string PANEL_PREFIX="EAGOLD_BT_";
string R10_MARKER_PREFIX="EAGOLD_R10_MARKER_";
string ENGINE_MARKER_PREFIX="EAGOLD_ENGINE_";
string TELEMETRY_PREFIX="EAGOLD_TELEM_";
string STATE_PREFIX="EAGOLD_STATE_";
double g_panelMinProfit=0.0;
double g_panelMaxLots=0.0;
bool g_panelInitialized=false;
bool g_r9HedgeActive=false;
int g_r9ProcessedTickets[];
datetime g_r10LastAction=0;
string g_r1LastDecision="DISABLED";
string g_r1LastReason="";
datetime g_r1LastDecisionTime=0;
bool g_r10RecoveryCycleActive=false;
double g_r10RecoveryStartEquity=0.0;
double g_r10RecoveryWorstEquity=0.0;

#include "../Core/EAGOLD_Orders.mqh"
#include "../UI/EAGOLD_ModularizationPanel.mqh"

double PointsToPrice(double points){return(points*Point);}
double NormalizePrice(double price){return(NormalizeDouble(price,Digits));}
double NormalizeLot(double lot){if(lot<Lot)lot=Lot;if(MaxOpenLot>0.0&&lot>MaxOpenLot)lot=MaxOpenLot;return(NormalizeDouble(lot,DigitsLots));}
double RecoveryStepForLevel(int level){double step=RecoveryMinDistance;if(level<0)level=0;if(EnableRecoveryStepMultiplier&&RecoveryStepMultiplier>1.0){for(int i=0;i<level;i++){step*=RecoveryStepMultiplier;if(RecoveryStepMax>0.0&&step>=RecoveryStepMax){step=RecoveryStepMax;break;}}}if(RecoveryStepMax>0.0&&step>RecoveryStepMax)step=RecoveryStepMax;return(step);}
int RecoveryLevel(int direction){int count=CountDirectionPositions(direction);if(count<=1)return(0);return(count-1);}

//==================================================================
// R10.2 — RECOVERY REALIZATION STATE
//==================================================================
double R10RecoveryDebt(){if(!g_r10RecoveryCycleActive)return(0.0);double debt=g_r10RecoveryStartEquity-g_r10RecoveryWorstEquity;if(debt<0.0)debt=0.0;return(debt);}
double R10RecoveryRemainingDebt(){if(!g_r10RecoveryCycleActive)return(0.0);double remaining=g_r10RecoveryStartEquity-AccountEquity();if(remaining<0.0)remaining=0.0;return(remaining);}
double R10RecoverySurplus(){if(!g_r10RecoveryCycleActive)return(0.0);double surplus=AccountEquity()-g_r10RecoveryStartEquity;if(surplus<0.0)surplus=0.0;return(surplus);}
double R10RecoveryTarget(){double debt=R10RecoveryDebt();double target=MathMax(0.0,R10RecoveryProfitTarget);if(R10RecoveryDebtTargetPercent>0.0)target+=debt*(R10RecoveryDebtTargetPercent/100.0);return(target);}
void R10RecoveryStartCycle(){g_r10RecoveryCycleActive=true;g_r10RecoveryStartEquity=AccountEquity();g_r10RecoveryWorstEquity=g_r10RecoveryStartEquity;Print(EA_NAME," R10.2 CYCLE START: equity=",DoubleToString(g_r10RecoveryStartEquity,2));CreateEngineActionMarker("R10.2","CYCLE",HeavyDirection(),0.0);}
void R10RecoveryResetCycle(){if(g_r10RecoveryCycleActive){Print(EA_NAME," R10.2 CYCLE RESET: debt=",DoubleToString(R10RecoveryDebt(),2)," surplus=",DoubleToString(R10RecoverySurplus(),2));CreateEngineActionMarker("R10.2","REALIZE",HeavyDirection(),0.0);}g_r10RecoveryCycleActive=false;g_r10RecoveryStartEquity=0.0;g_r10RecoveryWorstEquity=0.0;}
void R10RecoveryUpdateState(){if(!EnableR10RecoveryRealization)return;double equity=AccountEquity();if(CountEAGOLDOrders()==0){R10RecoveryResetCycle();return;}if(!g_r10RecoveryCycleActive)R10RecoveryStartCycle();if(equity<g_r10RecoveryWorstEquity)g_r10RecoveryWorstEquity=equity;}
bool R10RecoveryAllowBasketClose(int direction){if(!EnableR10RecoveryRealization)return(true);if(!g_r10RecoveryCycleActive)return(true);double debt=R10RecoveryDebt();if(debt<R10RecoveryMinDebt)return(true);double remaining=R10RecoveryRemainingDebt();double surplus=R10RecoverySurplus();double target=R10RecoveryTarget();if(R10RecoveryRequireDebtRepaid&&remaining>0.01){Print(EA_NAME," R10.2 HOLD: debt not repaid. remaining=",DoubleToString(remaining,2)," debt=",DoubleToString(debt,2));return(false);}if(surplus+0.01<target){Print(EA_NAME," R10.2 HOLD: recovery target not reached. surplus=",DoubleToString(surplus,2)," target=",DoubleToString(target,2));return(false);}return(true);}

//==================================================================
// R1.1 — FIRST ADMISSION CONTROL
//==================================================================
void R1Decision(string decision,string reason){g_r1LastDecision=decision;g_r1LastReason=reason;g_r1LastDecisionTime=TimeCurrent();if(EnableR1DecisionLog)Print(EA_NAME," R1 ADMISSION: ",decision," reason=",reason);}
bool R1ValidateLot(double lots,string &reason){double minLot=MarketInfo(Symbol(),MODE_MINLOT);double maxLot=MarketInfo(Symbol(),MODE_MAXLOT);double lotStep=MarketInfo(Symbol(),MODE_LOTSTEP);double eps=0.0000001;if(minLot>0.0&&lots<minLot-eps){reason="BROKER_MIN_LOT";return(false);}if(maxLot>0.0&&lots>maxLot+eps){reason="BROKER_MAX_LOT";return(false);}if(lotStep>0.0){double steps=(lots-minLot)/lotStep;double nearest=MathRound(steps);if(MathAbs(steps-nearest)>0.000001){reason="BROKER_LOT_STEP";return(false);}}reason="PASS";return(true);}
bool R1BrokerGuard(int direction,double price,string &reason){double stopLevel=MarketInfo(Symbol(),MODE_STOPLEVEL);if(stopLevel<0.0)stopLevel=0.0;double requiredDistance=stopLevel+MathMax(0.0,R1BrokerSafetyBufferPoints);RefreshRates();double actualDistance=(direction==OP_BUY?(price-Ask):(Bid-price))/Point;if(actualDistance+0.000001<requiredDistance){reason="BROKER_STOPLEVEL";return(false);}reason="PASS";return(true);}
bool R1TradePermissionGuard(string &reason){double allowed=MarketInfo(Symbol(),MODE_TRADEALLOWED);if(allowed<0.5){reason="TRADE_NOT_ALLOWED";return(false);}reason="PASS";return(true);}
bool R1MarginGuard(int direction,double lots,string &reason){int marketType=(direction==OP_BUY?OP_BUY:OP_SELL);ResetLastError();double remaining=AccountFreeMarginCheck(Symbol(),marketType,lots);int err=GetLastError();if(remaining<=0.0||err==134){reason="INSUFFICIENT_MARGIN";return(false);}if(R1MinFreeMarginAfterOrder>0.0&&remaining<R1MinFreeMarginAfterOrder){reason="MIN_FREE_MARGIN";return(false);}reason="PASS";return(true);}
bool R1AdmissionAllowed(int direction,double lots,double price,string &reason){reason="PASS";if(!EnableR1AdmissionGate){R1Decision("DISABLED","MASTER_OFF");return(true);}string localReason="PASS";if(EnableR1TradePermissionGuard){if(!R1TradePermissionGuard(localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}if(EnableR1BrokerGuard){if(!R1BrokerGuard(direction,price,localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}if(EnableR1LotGuard){if(!R1ValidateLot(lots,localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}if(EnableR1MarginGuard){if(!R1MarginGuard(direction,lots,localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}R1Decision("ALLOW","ALL_ENABLED_GATES_PASS");return(true);}

string StateKey(string metric){return(STATE_PREFIX+Symbol()+"_"+IntegerToString(MagicNumber)+"_"+metric);}
string ConfigKey(string metric){return("EAGOLD_CFG_V1_"+Symbol()+"_"+IntegerToString(AccountNumber())+"_"+metric);}
void PersistConfigState(){GlobalVariableSet(ConfigKey("MagicNumber"),MagicNumber);GlobalVariableSet(ConfigKey("Lot"),Lot);GlobalVariableSet(ConfigKey("Multiplier"),Multiplier);GlobalVariableSet(ConfigKey("DigitsLots"),DigitsLots);GlobalVariableSet(ConfigKey("LotIncrement"),LotIncrement);GlobalVariableSet(ConfigKey("MaxOpenLot"),MaxOpenLot);GlobalVariableSet(ConfigKey("TakeProfit"),TakeProfit);GlobalVariableSet(ConfigKey("SellProfit"),SellProfit);GlobalVariableSet(ConfigKey("BasketLoss"),BasketLoss);GlobalVariableSet(ConfigKey("SpreadLimit"),SpreadLimit);GlobalVariableSet(ConfigKey("WaitSeconds"),WaitSeconds);GlobalVariableSet(ConfigKey("FirstStep"),FirstStep);GlobalVariableSet(ConfigKey("EnableR1AdmissionGate"),EnableR1AdmissionGate);GlobalVariableSet(ConfigKey("EnableR1BrokerGuard"),EnableR1BrokerGuard);GlobalVariableSet(ConfigKey("EnableR1LotGuard"),EnableR1LotGuard);GlobalVariableSet(ConfigKey("EnableR1MarginGuard"),EnableR1MarginGuard);GlobalVariableSet(ConfigKey("EnableR1TradePermissionGuard"),EnableR1TradePermissionGuard);GlobalVariableSet(ConfigKey("R1BrokerSafetyBufferPoints"),R1BrokerSafetyBufferPoints);GlobalVariableSet(ConfigKey("R1MinFreeMarginAfterOrder"),R1MinFreeMarginAfterOrder);GlobalVariableSet(ConfigKey("EnableR1DecisionLog"),EnableR1DecisionLog);GlobalVariableSet(ConfigKey("MiniGrid1"),MiniGrid1);GlobalVariableSet(ConfigKey("SmartGrid1"),SmartGrid1);GlobalVariableSet(ConfigKey("RecoveryMinDistance"),RecoveryMinDistance);GlobalVariableSet(ConfigKey("MiniGrid2"),MiniGrid2);GlobalVariableSet(ConfigKey("SmartGrid2"),SmartGrid2);GlobalVariableSet(ConfigKey("BasketRestartStep"),BasketRestartStep);GlobalVariableSet(ConfigKey("PendingStepTrail"),PendingStepTrail);GlobalVariableSet(ConfigKey("MaxTrades"),MaxTrades);GlobalVariableSet(ConfigKey("EnableCloseBy"),EnableCloseBy);GlobalVariableSet(ConfigKey("BuyProgressionTolerance"),BuyProgressionTolerance);GlobalVariableSet(ConfigKey("EnableR9Hedge"),EnableR9Hedge);GlobalVariableSet(ConfigKey("R9ExposureTriggerLots"),R9ExposureTriggerLots);GlobalVariableSet(ConfigKey("R9TriggerLotMinimum"),R9TriggerLotMinimum);GlobalVariableSet(ConfigKey("R9HedgeFraction"),R9HedgeFraction);GlobalVariableSet(ConfigKey("R9BalanceCap"),R9BalanceCap);GlobalVariableSet(ConfigKey("EnableR10Reduce"),EnableR10Reduce);GlobalVariableSet(ConfigKey("R10MinExposureLots"),R10MinExposureLots);GlobalVariableSet(ConfigKey("EnableR10PairReduction"),EnableR10PairReduction);GlobalVariableSet(ConfigKey("R10PairMinProfit"),R10PairMinProfit);GlobalVariableSet(ConfigKey("R10PairMaxLots"),R10PairMaxLots);GlobalVariableSet(ConfigKey("R10PairCooldownSeconds"),R10PairCooldownSeconds);GlobalVariableSet(ConfigKey("EnableR10VisualMarker"),EnableR10VisualMarker);GlobalVariableSet(ConfigKey("R10MarkerFontSize"),R10MarkerFontSize);GlobalVariableSet(ConfigKey("R10BuyMarkerColor"),R10BuyMarkerColor);GlobalVariableSet(ConfigKey("R10SellMarkerColor"),R10SellMarkerColor);GlobalVariableSet(ConfigKey("R10MarkerOffsetPoints"),R10MarkerOffsetPoints);GlobalVariableSet(ConfigKey("EnableEngineActionMarkers"),EnableEngineActionMarkers);GlobalVariableSet(ConfigKey("EngineActionMarkerFontSize"),EngineActionMarkerFontSize);GlobalVariableSet(ConfigKey("EngineActionMarkerOffsetPoints"),EngineActionMarkerOffsetPoints);GlobalVariableSet(ConfigKey("EnableR10RecoveryRealization"),EnableR10RecoveryRealization);GlobalVariableSet(ConfigKey("R10RecoveryMinDebt"),R10RecoveryMinDebt);GlobalVariableSet(ConfigKey("R10RecoveryProfitTarget"),R10RecoveryProfitTarget);GlobalVariableSet(ConfigKey("R10RecoveryDebtTargetPercent"),R10RecoveryDebtTargetPercent);GlobalVariableSet(ConfigKey("R10RecoveryRequireDebtRepaid"),R10RecoveryRequireDebtRepaid);GlobalVariableSet(ConfigKey("EnableRecoveryStepMultiplier"),EnableRecoveryStepMultiplier);GlobalVariableSet(ConfigKey("RecoveryStepMultiplier"),RecoveryStepMultiplier);GlobalVariableSet(ConfigKey("RecoveryStepMax"),RecoveryStepMax);GlobalVariableSet(ConfigKey("PanelBackgroundX"),PanelBackgroundX);GlobalVariableSet(ConfigKey("PanelBackgroundY"),PanelBackgroundY);GlobalVariableSet(ConfigKey("PanelBackgroundHeight"),PanelBackgroundHeight);GlobalVariableSet(ConfigKey("PanelBottomY"),PanelBottomY);GlobalVariableSet(ConfigKey("PanelBottomX1"),PanelBottomX1);GlobalVariableSet(ConfigKey("PanelBottomX2"),PanelBottomX2);GlobalVariableSet(ConfigKey("PanelBottomX3"),PanelBottomX3);GlobalVariableSet(ConfigKey("PanelBottomX4"),PanelBottomX4);GlobalVariableSet(ConfigKey("CONFIG_INITIALIZED"),1.0);GlobalVariablesFlush();}
