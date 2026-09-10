#property strict
#property version   "0.106"
#property description "EAGOLD - BUY/SELL independent machines - Rules 1 to 10 + R10.2 Recovery Realization + Dynamic Recovery Step Multiplier + Persistent Global Variables + Isolated R1 Admission Control"

//==================================================================
// GENERAL / IDENTITY
//==================================================================
input string INPUT_GROUP_GENERAL="=== GENERAL / IDENTITY ===";
extern int MagicNumber=3009;

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
#include "../Core/EAGOLD_Execution.mqh"
#include "../Core/EAGOLD_Persistence.mqh"
#include "../UI/EAGOLD_ModularizationPanel.mqh"

double PointsToPrice(double points){return(points*Point);}
double NormalizePrice(double price){return(NormalizeDouble(price,Digits));}
double NormalizeLot(double lot){if(lot<Lot)lot=Lot;if(MaxOpenLot>0.0&&lot>MaxOpenLot)lot=MaxOpenLot;return(NormalizeDouble(lot,DigitsLots));}
#include "../Engines/EAGOLD_R9.mqh"
#include "../Engines/EAGOLD_R10.mqh"
#include "../Engines/EAGOLD_Recovery.mqh"
#include "../Engines/EAGOLD_Lifecycle.mqh"
#include "../Engines/EAGOLD_R1_Admission.mqh"


//==================================================================
// R10.2 — RECOVERY REALIZATION STATE
//==================================================================

//==================================================================
// R1.1 — FIRST ADMISSION CONTROL
//==================================================================






string TelemetryKey(string metric){return(TELEMETRY_PREFIX+Symbol()+"_"+IntegerToString(MagicNumber)+"_"+metric);}
void UpdateExposureTelemetry(){double buyLots=DirectionLots(OP_BUY),sellLots=DirectionLots(OP_SELL),gross=buyLots+sellLots,net=MathAbs(buyLots-sellLots),maxIndividual=0.0;int openPositions=0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder())continue;int type=OrderType();if(type!=OP_BUY&&type!=OP_SELL)continue;openPositions++;if(OrderLots()>maxIndividual)maxIndividual=OrderLots();}double balance=AccountBalance(),equity=AccountEquity(),currentDD=MathMax(0.0,balance-equity),ddEquityPct=equity>0.0?(currentDD/equity)*100.0:0.0;int buyRecovery=RecoveryLevel(OP_BUY),sellRecovery=RecoveryLevel(OP_SELL),recoveryLevel=MathMax(buyRecovery,sellRecovery);GlobalVariableSet(TelemetryKey("BUY_EXPOSURE"),buyLots);GlobalVariableSet(TelemetryKey("SELL_EXPOSURE"),sellLots);GlobalVariableSet(TelemetryKey("GROSS_EXPOSURE"),gross);GlobalVariableSet(TelemetryKey("NET_EXPOSURE"),net);GlobalVariableSet(TelemetryKey("MAX_INDIVIDUAL_LOT"),maxIndividual);GlobalVariableSet(TelemetryKey("OPEN_POSITIONS"),openPositions);GlobalVariableSet(TelemetryKey("CURRENT_DD"),currentDD);GlobalVariableSet(TelemetryKey("DD_EQUITY_PCT"),ddEquityPct);GlobalVariableSet(TelemetryKey("BUY_RECOVERY_LEVEL"),buyRecovery);GlobalVariableSet(TelemetryKey("SELL_RECOVERY_LEVEL"),sellRecovery);GlobalVariableSet(TelemetryKey("RECOVERY_LEVEL"),recoveryLevel);GlobalVariableSet(TelemetryKey("BALANCE"),balance);GlobalVariableSet(TelemetryKey("EQUITY"),equity);GlobalVariableSet(TelemetryKey("R10_RECOVERY_DEBT"),R10RecoveryDebt());GlobalVariableSet(TelemetryKey("R10_RECOVERY_REMAINING"),R10RecoveryRemainingDebt());GlobalVariableSet(TelemetryKey("R10_RECOVERY_SURPLUS"),R10RecoverySurplus());GlobalVariableSet(TelemetryKey("R10_RECOVERY_TARGET"),R10RecoveryTarget());GlobalVariableSet(TelemetryKey("TIMESTAMP"),(double)TimeCurrent());}

void PanelCreate(){string bg=PANEL_PREFIX+"BG";if(ObjectFind(0,bg)<0){ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(0,bg,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,clrBlack);ObjectSetInteger(0,bg,OBJPROP_COLOR,clrDimGray);ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,bg,OBJPROP_SELECTED,false);ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);ObjectSetInteger(0,bg,OBJPROP_BACK,false);}ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(0,bg,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,PanelBackgroundX);ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,PanelBackgroundY);ObjectSetInteger(0,bg,OBJPROP_XSIZE,280);ObjectSetInteger(0,bg,OBJPROP_YSIZE,PanelBackgroundHeight);}
void PanelCreateLabel(string id,int row,color clr){string name=PANEL_PREFIX+id;if(ObjectFind(0,name)<0){ObjectCreate(0,name,OBJ_LABEL,0,0,0);ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);ObjectSetString(0,name,OBJPROP_FONT,"Consolas");ObjectSetInteger(0,name,OBJPROP_COLOR,clr);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_SELECTED,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);ObjectSetInteger(0,name,OBJPROP_BACK,false);}ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);ObjectSetInteger(0,name,OBJPROP_XDISTANCE,18);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,18+row*17);ObjectSetInteger(0,name,OBJPROP_COLOR,clr);}
void PanelCreateBottomLabel(string id,int x,int y,color clr){string name=PANEL_PREFIX+id;if(ObjectFind(0,name)<0){ObjectCreate(0,name,OBJ_LABEL,0,0,0);ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_LOWER);ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);ObjectSetString(0,name,OBJPROP_FONT,"Consolas");ObjectSetInteger(0,name,OBJPROP_COLOR,clr);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_SELECTED,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);ObjectSetInteger(0,name,OBJPROP_BACK,false);}ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_LOWER);ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_LOWER);ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);ObjectSetInteger(0,name,OBJPROP_COLOR,clr);}
void PanelSet(string id,string text,int row,color clr){string name=PANEL_PREFIX+id;PanelCreateLabel(id,row,clr);ObjectSetString(0,name,OBJPROP_TEXT,text);ObjectSetInteger(0,name,OBJPROP_COLOR,clr);}
void PanelSetBottom(string id,string text,int x,int y,color clr){string name=PANEL_PREFIX+id;PanelCreateBottomLabel(id,x,y,clr);ObjectSetString(0,name,OBJPROP_TEXT,text);ObjectSetInteger(0,name,OBJPROP_COLOR,clr);}
void PanelDelete(){for(int ei=ObjectsTotal()-1;ei>=0;ei--){string en=ObjectName(0,ei);if(StringFind(en,ENGINE_MARKER_PREFIX,0)==0||StringFind(en,R10_MARKER_PREFIX,0)==0)ObjectDelete(0,en);}string ids[]={"BG","TITLE","SEP1","BUY","BUYPL","BUYT","SELL","SELLPL","SELLT","SEP2","TOTAL","EQUITY","ACCUM","MIN","LOTS","MAXLOTS","NET","PEND","PBUY","PSELL","HEDGE","HEDGE2","R10","R10P","R11","R11S","SEP3","TIME","R12BG","EXPH","EXPB","EXPS","EXPG","EXPN","EXPM","EXPP","EXDD","EXDP","EXRB","EXRS","EXRL","SEP4"};for(int i=0;i<ArraySize(ids);i++){string name=PANEL_PREFIX+ids[i];if(ObjectFind(0,name)>=0)ObjectDelete(0,name);}}
string PanelMoney(double value){return(DoubleToString(value,2));}string PanelLots(double value){return(DoubleToString(value,2));}
void PanelUpdate(){PanelCreate();int buyCount=0,sellCount=0,buyPending=0,sellPending=0;double buyLots=0.0,sellLots=0.0,buyProfit=0.0,sellProfit=0.0,maxIndividual=0.0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder())continue;int type=OrderType();if(type==OP_BUY){buyCount++;buyLots+=OrderLots();buyProfit+=OrderProfit()+OrderSwap()+OrderCommission();if(OrderLots()>maxIndividual)maxIndividual=OrderLots();}else if(type==OP_SELL){sellCount++;sellLots+=OrderLots();sellProfit+=OrderProfit()+OrderSwap()+OrderCommission();if(OrderLots()>maxIndividual)maxIndividual=OrderLots();}else if(type==OP_BUYSTOP)buyPending++;else if(type==OP_SELLSTOP)sellPending++;}double totalProfit=buyProfit+sellProfit,totalLots=buyLots+sellLots,netLots=MathAbs(buyLots-sellLots),equity=AccountEquity(),accumulated=EAGOLDAccumulatedProfit();double balance=AccountBalance(),currentDD=MathMax(0.0,balance-equity),ddEquityPct=equity>0.0?(currentDD/equity)*100.0:0.0;int totalPending=buyPending+sellPending,openPositions=buyCount+sellCount,buyRecovery=RecoveryLevel(OP_BUY),sellRecovery=RecoveryLevel(OP_SELL),recoveryLevel=MathMax(buyRecovery,sellRecovery);if(!g_panelInitialized){g_panelMinProfit=totalProfit;g_panelMaxLots=totalLots;g_panelInitialized=true;}else{if(totalProfit<g_panelMinProfit)g_panelMinProfit=totalProfit;if(totalLots>g_panelMaxLots)g_panelMaxLots=totalLots;}int row=0;PanelSet("TITLE","EAGOLD  v0.106",row++,clrWhite);PanelSet("SEP1","==============================",row++,clrSilver);PanelSet("BUY",StringFormat("BUY   %3d pos   %6s lot",buyCount,PanelLots(buyLots)),row++,clrLime);PanelSet("BUYPL",StringFormat("P/L       %12s",PanelMoney(buyProfit)),row++,clrLime);PanelSet("BUYT",StringFormat("Target    %12s",PanelMoney(buyCount*TakeProfit)),row++,clrSilver);PanelSet("SELL",StringFormat("SELL  %3d pos   %6s lot",sellCount,PanelLots(sellLots)),row++,clrTomato);PanelSet("SELLPL",StringFormat("P/L       %12s",PanelMoney(sellProfit)),row++,clrTomato);PanelSet("SELLT",StringFormat("Target    %12s",PanelMoney(sellCount*TakeProfit)),row++,clrSilver);PanelSet("SEP2","==============================",row++,clrSilver);PanelSet("TOTAL",StringFormat("TOTAL P/L %12s",PanelMoney(totalProfit)),row++,clrWhite);PanelSet("EQUITY",StringFormat("EQUITY     %12s",PanelMoney(equity)),row++,clrAqua);PanelSet("ACCUM",StringFormat("LUCRO ACUM. %9s",PanelMoney(accumulated)),row++,accumulated>=0.0?clrLime:clrTomato);PanelSet("MIN",StringFormat("MENOR P/L %11s",PanelMoney(g_panelMinProfit)),row++,clrYellow);PanelSet("LOTS",StringFormat("LOTES ATUAIS %9s",PanelLots(totalLots)),row++,clrWhite);PanelSet("MAXLOTS",StringFormat("MAIOR ACUM. %9s",PanelLots(g_panelMaxLots)),row++,clrYellow);PanelSet("NET",StringFormat("EXPOS. LIQ. %10s",PanelLots(netLots)),row++,clrWhite);PanelSet("PEND",StringFormat("PENDENTES     %6d",totalPending),row++,clrSilver);PanelSet("PBUY",StringFormat("BUY STOP      %6d",buyPending),row++,clrSilver);PanelSet("PSELL",StringFormat("SELL STOP     %6d",sellPending),row++,clrSilver);if(g_r9HedgeActive){int heavy=HeavyDirection();string side=(heavy==OP_BUY?"SELL":"BUY");PanelSet("HEDGE","HEDGE: ATIVO",row++,clrYellow);PanelSet("HEDGE2",StringFormat("BALANCEANDO %s  EXP %s",side,PanelLots(ExposureLots())),row++,clrYellow);}else{PanelSet("HEDGE","HEDGE: INATIVO",row++,clrSilver);PanelSet("HEDGE2",StringFormat("EXPOS. %s",PanelLots(ExposureLots())),row++,clrSilver);}int displayDirection=HeavyDirection();if(displayDirection<0)displayDirection=OP_BUY;int displayLevel=RecoveryLevel(displayDirection);PanelSet("R11",StringFormat("R11 STEP x %.2f",EnableRecoveryStepMultiplier?RecoveryStepMultiplier:1.00),row++,EnableRecoveryStepMultiplier?clrAqua:clrSilver);PanelSet("R11S",StringFormat("STEP L%d = %s",displayLevel,PanelLots(RecoveryStepForLevel(displayLevel))),row++,clrSilver);PanelSet("SEP3","==============================",row++,clrSilver);PanelSet("TIME",TimeToString(TimeCurrent(),TIME_SECONDS),row++,clrSilver);PanelSetBottom("EXPH","R12 EXPOSURE",PanelBottomX1,PanelBottomY,clrAqua);PanelSetBottom("EXPB",StringFormat("BUY %s | SELL %s | GROSS %s | NET %s",PanelLots(buyLots),PanelLots(sellLots),PanelLots(totalLots),PanelLots(netLots)),PanelBottomX2,PanelBottomY,clrWhite);PanelSetBottom("EXPS",StringFormat("MAX %s | POS %d | DD %s | DD/EQ %.2f%%",PanelLots(maxIndividual),openPositions,PanelMoney(currentDD),ddEquityPct),PanelBottomX3,PanelBottomY,clrYellow);PanelSetBottom("EXPG",StringFormat("REC B%d S%d L%d",buyRecovery,sellRecovery,recoveryLevel),PanelBottomX4,PanelBottomY,clrAqua);ChartRedraw(0);}







void CreateEngineActionMarker(string engine,string action,int direction,double lots){if(!EnableEngineActionMarkers)return;RefreshRates();double mid=NormalizePrice((Bid+Ask)/2.0);double offset=PointsToPrice(EngineActionMarkerOffsetPoints);double price=(direction==OP_SELL?mid+offset:mid-offset);string text=engine+" "+action;if(lots>=Lot)text+=" "+DoubleToString(lots,DigitsLots);color c=clrSilver;if(engine=="R9")c=clrYellow;else if(engine=="R10")c=(direction==OP_BUY?clrLime:clrTomato);else if(engine=="R10.2")c=clrAqua;else if(engine=="R5")c=clrWhite;else if(engine=="R4")c=clrSilver;else if(engine=="R7")c=clrSilver;else if(engine=="R1")c=clrWhite;else if(engine=="R11")c=clrAqua;string name=ENGINE_MARKER_PREFIX+IntegerToString((int)TimeCurrent())+"_"+IntegerToString(GetTickCount())+"_"+IntegerToString(MathRand());if(ObjectCreate(0,name,OBJ_TEXT,0,TimeCurrent(),price)){ObjectSetString(0,name,OBJPROP_TEXT,text);ObjectSetString(0,name,OBJPROP_FONT,"Arial");ObjectSetInteger(0,name,OBJPROP_FONTSIZE,EngineActionMarkerFontSize);ObjectSetInteger(0,name,OBJPROP_COLOR,c);ObjectSetInteger(0,name,OBJPROP_ANCHOR,(direction==OP_SELL?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER));ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_SELECTED,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,false);ObjectSetInteger(0,name,OBJPROP_BACK,false);}ChartRedraw(0);}

int OnInit(){bool reloadPersistedConfig=(GlobalVariableCheck(ConfigKey("RELOAD_ON_REINIT"))&&GlobalVariableGet(ConfigKey("RELOAD_ON_REINIT"))>0.5);if(reloadPersistedConfig){LoadPersistedConfig();GlobalVariableSet(ConfigKey("RELOAD_ON_REINIT"),0.0);}else if(!GlobalVariableCheck(ConfigKey("CONFIG_INITIALIZED"))){PersistConfigState();}ArrayResize(g_r9ProcessedTickets,0);g_r9HedgeActive=false;g_panelInitialized=false;g_panelMinProfit=0.0;g_panelMaxLots=0.0;g_r10LastAction=0;if(EnableR10RecoveryRealization){string r10Key=StateKey("g_r10RecoveryCycleActive");if(GlobalVariableCheck(r10Key)){g_r10RecoveryCycleActive=(GlobalVariableGet(r10Key)>0.5);g_r10RecoveryStartEquity=GlobalVariableGet(StateKey("g_r10RecoveryStartEquity"));g_r10RecoveryWorstEquity=GlobalVariableGet(StateKey("g_r10RecoveryWorstEquity"));}}g_r1LastDecision="DISABLED";g_r1LastReason="";g_r1LastDecisionTime=0;R9SeedExistingPositions();UpdateExposureTelemetry();PanelUpdate();PersistAllState();Print(EA_NAME," v0.106 initialized. R1 Admission Gate=",EnableR1AdmissionGate,"; R1 Broker=",EnableR1BrokerGuard," Lot=",EnableR1LotGuard," Margin=",EnableR1MarginGuard," TradePermission=",EnableR1TradePermissionGuard,"; R12 telemetry active; persistent Global Variables; R11 dynamic recovery step multiplier active=",EnableRecoveryStepMultiplier," multiplier=",DoubleToString(RecoveryStepMultiplier,2)," max=",DoubleToString(RecoveryStepMax,1),"; GLOBAL STOP TRAILING; ENGINE ACTION MARKERS active=",EnableEngineActionMarkers,".");CreateFirstOrdersIfFlat();UpdateExposureTelemetry();PanelUpdate();EAGOLD_ModPanelUpdate();PersistAllState();return(INIT_SUCCEEDED);}
void OnDeinit(const int reason){PersistAllState();PersistConfigState();bool restore=(reason==REASON_CHARTCHANGE||reason==REASON_CLOSE||reason==REASON_RECOMPILE);GlobalVariableSet(ConfigKey("RELOAD_ON_REINIT"),restore?1.0:0.0);GlobalVariablesFlush();PanelDelete();EAGOLD_ModPanelDelete();}
void OnTick(){R10RecoveryUpdateState();Rule9DetectActivatedOrders();BuyMachine();SellMachine();CreateFirstOrdersIfFlat();TrailAllStopOrders();UpdateExposureTelemetry();PanelUpdate();EAGOLD_ModPanelUpdate();PersistAllState();}
