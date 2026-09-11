#property strict
#property version   "0.106"
#property description "EAGOLD - BUY/SELL independent machines - Rules 1 to 10 + R10.2 Recovery Realization + Dynamic Recovery Step Multiplier + Persistent Global Variables + Isolated R1 Admission Control"

//==================================================================
// EAGOLD MAIN EXECUTION UNIT
// Configuration, engines and operational UI are loaded from modules.
//==================================================================
#include "../Core/EAGOLD_Config.mqh"
#include "../Core/EAGOLD_Orders.mqh"
#include "../Core/EAGOLD_Execution.mqh"
#include "../Core/EAGOLD_Persistence.mqh"

string EA_NAME="EAGOLD";
string R10_MARKER_PREFIX="EAGOLD_R10_MARKER_";
string ENGINE_MARKER_PREFIX="EAGOLD_ENGINE_";
string TELEMETRY_PREFIX="EAGOLD_TELEM_";
string STATE_PREFIX="EAGOLD_STATE_";
bool g_r9HedgeActive=false;
int g_r9ProcessedTickets[];
datetime g_r10LastAction=0;
string g_r1LastDecision="DISABLED";
string g_r1LastReason="";
datetime g_r1LastDecisionTime=0;
bool g_r10RecoveryCycleActive=false;
double g_r10RecoveryStartEquity=0.0;
double g_r10RecoveryWorstEquity=0.0;

double PointsToPrice(double points){return(points*Point);}
double NormalizePrice(double price){return(NormalizeDouble(price,Digits));}
double NormalizeLot(double lot){if(lot<Lot)lot=Lot;if(MaxOpenLot>0.0&&lot>MaxOpenLot)lot=MaxOpenLot;return(NormalizeDouble(lot,DigitsLots));}

#include "../Engines/EAGOLD_R9.mqh"
#include "../Engines/EAGOLD_R10.mqh"
#include "../Engines/EAGOLD_Recovery.mqh"
#include "../Engines/EAGOLD_Lifecycle.mqh"
#include "../Engines/EAGOLD_R1_Admission.mqh"
#include "../Engines/EAGOLD_R13_Satellite.mqh"
#include "../UI/EAGOLD_ModularizationPanel.mqh"
#include "../UI/EAGOLD_ChartBasketGuides.mqh"

R13ObserverState g_r13Observer;

//==================================================================
// TELEMETRY / EXECUTION ORCHESTRATION
//==================================================================
string TelemetryKey(string metric){return(TELEMETRY_PREFIX+Symbol()+"_"+IntegerToString(MagicNumber)+"_"+metric);}
void UpdateExposureTelemetry(){double buyLots=DirectionLots(OP_BUY),sellLots=DirectionLots(OP_SELL),gross=buyLots+sellLots,net=MathAbs(buyLots-sellLots),maxIndividual=0.0;int openPositions=0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder())continue;int type=OrderType();if(type!=OP_BUY&&type!=OP_SELL)continue;openPositions++;if(OrderLots()>maxIndividual)maxIndividual=OrderLots();}double balance=AccountBalance(),equity=AccountEquity(),currentDD=MathMax(0.0,balance-equity),ddEquityPct=equity>0.0?(currentDD/equity)*100.0:0.0;int buyRecovery=RecoveryLevel(OP_BUY),sellRecovery=RecoveryLevel(OP_SELL),recoveryLevel=MathMax(buyRecovery,sellRecovery);GlobalVariableSet(TelemetryKey("BUY_EXPOSURE"),buyLots);GlobalVariableSet(TelemetryKey("SELL_EXPOSURE"),sellLots);GlobalVariableSet(TelemetryKey("GROSS_EXPOSURE"),gross);GlobalVariableSet(TelemetryKey("NET_EXPOSURE"),net);GlobalVariableSet(TelemetryKey("MAX_INDIVIDUAL_LOT"),maxIndividual);GlobalVariableSet(TelemetryKey("OPEN_POSITIONS"),openPositions);GlobalVariableSet(TelemetryKey("CURRENT_DD"),currentDD);GlobalVariableSet(TelemetryKey("DD_EQUITY_PCT"),ddEquityPct);GlobalVariableSet(TelemetryKey("BUY_RECOVERY_LEVEL"),buyRecovery);GlobalVariableSet(TelemetryKey("SELL_RECOVERY_LEVEL"),sellRecovery);GlobalVariableSet(TelemetryKey("RECOVERY_LEVEL"),recoveryLevel);GlobalVariableSet(TelemetryKey("BALANCE"),balance);GlobalVariableSet(TelemetryKey("EQUITY"),equity);GlobalVariableSet(TelemetryKey("R10_RECOVERY_DEBT"),R10RecoveryDebt());GlobalVariableSet(TelemetryKey("R10_RECOVERY_REMAINING"),R10RecoveryRemainingDebt());GlobalVariableSet(TelemetryKey("R10_RECOVERY_SURPLUS"),R10RecoverySurplus());GlobalVariableSet(TelemetryKey("R10_RECOVERY_TARGET"),R10RecoveryTarget());GlobalVariableSet(TelemetryKey("TIMESTAMP"),(double)TimeCurrent());}

void CreateEngineActionMarker(string engine,string action,int direction,double lots){if(!EnableEngineActionMarkers)return;RefreshRates();double mid=NormalizePrice((Bid+Ask)/2.0);double offset=PointsToPrice(EngineActionMarkerOffsetPoints);double price=(direction==OP_SELL?mid+offset:mid-offset);string text=engine+" "+action;if(lots>=Lot)text+=" "+DoubleToString(lots,DigitsLots);color c=clrSilver;if(engine=="R9")c=clrYellow;else if(engine=="R10")c=(direction==OP_BUY?clrLime:clrTomato);else if(engine=="R10.2")c=clrAqua;else if(engine=="R5")c=clrWhite;else if(engine=="R4")c=clrSilver;else if(engine=="R7")c=clrSilver;else if(engine=="R1")c=clrWhite;else if(engine=="R11")c=clrAqua;string name=ENGINE_MARKER_PREFIX+IntegerToString((int)TimeCurrent())+"_"+IntegerToString(GetTickCount())+"_"+IntegerToString(MathRand());if(ObjectCreate(0,name,OBJ_TEXT,0,TimeCurrent(),price)){ObjectSetString(0,name,OBJPROP_TEXT,text);ObjectSetString(0,name,OBJPROP_FONT,"Arial");ObjectSetInteger(0,name,OBJPROP_FONTSIZE,EngineActionMarkerFontSize);ObjectSetInteger(0,name,OBJPROP_COLOR,c);ObjectSetInteger(0,name,OBJPROP_ANCHOR,(direction==OP_SELL?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER));ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_SELECTED,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);ObjectSetInteger(0,name,OBJPROP_BACK,false);}ChartRedraw(0);}

int OnInit(){bool reloadPersistedConfig=(GlobalVariableCheck(ConfigKey("RELOAD_ON_REINIT"))&&GlobalVariableGet(ConfigKey("RELOAD_ON_REINIT"))>0.5);if(reloadPersistedConfig){LoadPersistedConfig();GlobalVariableSet(ConfigKey("RELOAD_ON_REINIT"),0.0);}else if(!GlobalVariableCheck(ConfigKey("CONFIG_INITIALIZED"))){PersistConfigState();}ArrayResize(g_r9ProcessedTickets,0);g_r9HedgeActive=false;g_r10LastAction=0;if(EnableR10RecoveryRealization){string r10Key=StateKey("g_r10RecoveryCycleActive");if(GlobalVariableCheck(r10Key)){g_r10RecoveryCycleActive=(GlobalVariableGet(r10Key)>0.5);g_r10RecoveryStartEquity=GlobalVariableGet(StateKey("g_r10RecoveryStartEquity"));g_r10RecoveryWorstEquity=GlobalVariableGet(StateKey("g_r10RecoveryWorstEquity"));}}g_r1LastDecision="DISABLED";g_r1LastReason="";g_r1LastDecisionTime=0;R13ResetObserverState(g_r13Observer);R9SeedExistingPositions();UpdateExposureTelemetry();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState();Print(EA_NAME," v0.106 initialized. R1 Admission Gate=",EnableR1AdmissionGate,"; R1 Broker=",EnableR1BrokerGuard," Lot=",EnableR1LotGuard," Margin=",EnableR1MarginGuard," TradePermission=",EnableR1TradePermissionGuard,"; R12 telemetry active; R13 observer active=",EnableR13,"; persistent Global Variables; R11 dynamic recovery step multiplier active=",EnableRecoveryStepMultiplier," multiplier=",DoubleToString(RecoveryStepMultiplier,2)," max=",DoubleToString(RecoveryStepMax,1),"; GLOBAL STOP TRAILING; ENGINE ACTION MARKERS active=",EnableEngineActionMarkers,".");CreateFirstOrdersIfFlat();UpdateExposureTelemetry();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState();return(INIT_SUCCEEDED);}
void OnDeinit(const int reason){PersistAllState();PersistConfigState();bool restore=(reason==REASON_CHARTCHANGE||reason==REASON_CLOSE||reason==REASON_RECOMPILE);GlobalVariableSet(ConfigKey("RELOAD_ON_REINIT"),restore?1.0:0.0);GlobalVariablesFlush();EAGOLD_ChartBasketGuidesDelete();EAGOLD_ModPanelDelete();}
void OnTick(){R10RecoveryUpdateState();Rule9DetectActivatedOrders();BuyMachine();SellMachine();CreateFirstOrdersIfFlat();TrailAllStopOrders();UpdateExposureTelemetry();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState();}