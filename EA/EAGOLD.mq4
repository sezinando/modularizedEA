#property strict
#property version   "0.106"
#property description "EAGOLD - BUY/SELL independent machines - Rules 1 to 10 + R10.2 Recovery Realization + Dynamic Recovery Step Multiplier + Persistent Global Variables + Isolated R1 Admission Control + R13 Recovery Satellite"

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

void CreateEngineActionMarker(string engine,string action,int direction,double lots)
{
   if(!EnableEngineActionMarkers)return;
   RefreshRates();

   double mid=NormalizePrice((Bid+Ask)/2.0);
   double offset=PointsToPrice(EngineActionMarkerOffsetPoints);
   double price=(direction==OP_SELL?mid+offset:mid-offset);
   datetime stamp=TimeCurrent();

   string text=engine+" "+action;
   if(lots>=Lot)text+=" "+DoubleToString(lots,DigitsLots);

   color c=clrSilver;
   if(engine=="R9")c=clrYellow;
   else if(engine=="R10")c=(direction==OP_BUY?clrLime:clrTomato);
   else if(engine=="R10.2")c=clrAqua;
   else if(engine=="R5")c=clrWhite;
   else if(engine=="R4")c=clrSilver;
   else if(engine=="R7")c=clrSilver;
   else if(engine=="R1")c=clrWhite;
   else if(engine=="R11")c=clrAqua;

   string baseName=ENGINE_MARKER_PREFIX+IntegerToString((int)stamp)+"_"+IntegerToString(GetTickCount())+"_"+IntegerToString(MathRand());
   string textName=baseName+"_TXT";
   string bgName=baseName+"_BG";

   int x=0,y=0;
   if(!ChartTimePriceToXY(0,0,stamp,price,x,y))
   {
      ChartRedraw(0);
      return;
   }

   // Same visual construction pattern used by the validated chart UI:
   // pixel-sized rectangle first, then OBJ_TEXT over it.
   // Tahoma 9 gives stable readability in the MT4 Strategy Tester.
   int textWidth=StringLen(text)*7+10;
   int textHeight=15;

   if(ObjectCreate(0,bgName,OBJ_RECTANGLE_LABEL,0,0,0))
   {
      ObjectSetInteger(0,bgName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,bgName,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bgName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,bgName,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,bgName,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,bgName,OBJPROP_XDISTANCE,x-(textWidth/2));
      ObjectSetInteger(0,bgName,OBJPROP_YDISTANCE,y-textHeight);
      ObjectSetInteger(0,bgName,OBJPROP_XSIZE,textWidth);
      ObjectSetInteger(0,bgName,OBJPROP_YSIZE,textHeight);
      ObjectSetInteger(0,bgName,OBJPROP_BGCOLOR,clrBlack);
      ObjectSetInteger(0,bgName,OBJPROP_COLOR,clrBlack);
      ObjectSetInteger(0,bgName,OBJPROP_BACK,false);
      ObjectSetInteger(0,bgName,OBJPROP_ZORDER,1);
   }

   // Create/update the text after the background so the text remains in the
   // foreground and follows the same anchor convention as the source pattern.
   if(ObjectCreate(0,textName,OBJ_TEXT,0,stamp,price))
   {
      ObjectSetInteger(0,textName,OBJPROP_ANCHOR,ANCHOR_LOWER);
      ObjectSetInteger(0,textName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,textName,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,textName,OBJPROP_HIDDEN,true);
      ObjectSetString(0,textName,OBJPROP_TEXT,text);
      ObjectSetString(0,textName,OBJPROP_FONT,"Tahoma");
      ObjectSetInteger(0,textName,OBJPROP_FONTSIZE,9);
      ObjectSetInteger(0,textName,OBJPROP_COLOR,c);
      ObjectSetInteger(0,textName,OBJPROP_BACK,false);
      ObjectSetInteger(0,textName,OBJPROP_ZORDER,2);
   }

   ChartRedraw(0);
}

int OnInit(){bool reloadPersistedConfig=(GlobalVariableCheck(ConfigKey("RELOAD_ON_REINIT"))&&GlobalVariableGet(ConfigKey("RELOAD_ON_REINIT"))>0.5);if(reloadPersistedConfig){LoadPersistedConfig();GlobalVariableSet(ConfigKey("RELOAD_ON_REINIT"),0.0);}else if(!GlobalVariableCheck(ConfigKey("CONFIG_INITIALIZED"))){PersistConfigState();}ArrayResize(g_r9ProcessedTickets,0);g_r9HedgeActive=false;g_r10LastAction=0;if(EnableR10RecoveryRealization){string r10Key=StateKey("g_r10RecoveryCycleActive");if(GlobalVariableCheck(r10Key)){g_r10RecoveryCycleActive=(GlobalVariableGet(r10Key)>0.5);g_r10RecoveryStartEquity=GlobalVariableGet(StateKey("g_r10RecoveryStartEquity"));g_r10RecoveryWorstEquity=GlobalVariableGet(StateKey("g_r10RecoveryWorstEquity"));}}g_r1LastDecision="DISABLED";g_r1LastReason="";g_r1LastDecisionTime=0;R13ResetObserverState(g_r13Observer);R9SeedExistingPositions();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(true);Print(EA_NAME," v0.106 initialized. R1 Admission Gate=",EnableR1AdmissionGate,"; R1 Broker=",EnableR1BrokerGuard," Lot=",EnableR1LotGuard," Margin=",EnableR1MarginGuard," TradePermission=",EnableR1TradePermissionGuard,"; R12 telemetry active; R13 observer/trading active=",EnableR13,"/",EnableR13Trading," auto=",EnableR13AutoActivation,"; event-driven Global Variables; R11 dynamic recovery step multiplier active=",EnableRecoveryStepMultiplier," multiplier=",DoubleToString(RecoveryStepMultiplier,2)," max=",DoubleToString(RecoveryStepMax,1),"; GLOBAL STOP TRAILING; ENGINE ACTION MARKERS active=",EnableEngineActionMarkers,".");CreateFirstOrdersIfFlat();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(true);return(INIT_SUCCEEDED);}
void OnDeinit(const int reason){
   // Persist only strategic/non-reconstructible state on unload. Runtime
   // telemetry is intentionally not written to GlobalVariables.
   PersistAllState(true);
   bool chartChange=(reason==REASON_CHARTCHANGE);
   if(!chartChange)PersistConfigState();

   // Only request a configuration reload when the configuration itself may
   // need to survive a full reinitialization. A chart-period change must use
   // the values supplied by MT4 for the current EA instance.
   bool restore=(reason==REASON_CLOSE||reason==REASON_CHARTCLOSE||reason==REASON_RECOMPILE);
   GlobalVariableSet(ConfigKey("RELOAD_ON_REINIT"),restore?1.0:0.0);
   GlobalVariablesFlush();
   EAGOLD_ChartBasketGuidesDelete();
   EAGOLD_ModPanelDelete();
}
void OnTick(){R10RecoveryUpdateState();Rule9DetectActivatedOrders();BuyMachine();SellMachine();CreateFirstOrdersIfFlat();TrailAllStopOrders();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(false);}
