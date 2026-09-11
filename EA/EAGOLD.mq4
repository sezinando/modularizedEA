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

#include "../UI/EAGOLD_RealizationCascade.mqh"
#include "../Engines/EAGOLD_R9.mqh"
#include "../Engines/EAGOLD_R10.mqh"
#include "../Engines/EAGOLD_Recovery.mqh"
#include "../Engines/EAGOLD_Lifecycle.mqh"
#include "../Engines/EAGOLD_R1_Admission.mqh"
#include "../Engines/EAGOLD_R13_Satellite.mqh"
#include "../UI/EAGOLD_ModularizationPanel.mqh"
#include "../UI/EAGOLD_ChartBasketGuides.mqh"

R13ObserverState g_r13Observer;

// Converts a visual pip offset to symbol price. For 3/5-digit symbols one
// pip is 10 points; for 2/4-digit symbols (including the current XAUUSD
// tester convention) one pip equals one point.
double EngineMarkerPipsToPrice(double pips)
{
   double pipSize=Point;
   if(Digits==3 || Digits==5)
      pipSize=Point*10.0;
   return(pips*pipSize);
}

// Assign each engine family to its own vertical lane. This prevents
// simultaneous actions from being painted on the same Y coordinate.
int EngineMarkerStackLevel(string engine)
{
   if(engine=="R1")   return(0);
   if(engine=="R1.1") return(1);
   if(engine=="R4")   return(2);
   if(engine=="R5")   return(3);
   if(engine=="BRX")  return(3);
   if(engine=="R7")   return(4);
   if(engine=="R10")  return(5);
   if(engine=="R13")  return(6);
   return(7);
}

// Resolve the requested display font while keeping the visual contract
// portable across MT4 terminals. Impact is preferred, followed by the
// supplied alternatives. TextSetFont() returns false when a font is absent.
string ResolveEngineMarkerFont()
{
   string fonts[3];
   fonts[0]=EngineActionMarkerFont;
   fonts[1]="Arial Black";
   fonts[2]="Trebuchet MS";

   for(int i=0;i<3;i++)
   {
      if(fonts[i]=="")continue;
      if(TextSetFont(fonts[i],EngineActionMarkerFontSize,FW_BLACK))
         return(fonts[i]);
   }

   return("Arial");
}

void CreateEngineActionMarker(string engine,string action,int direction,double lots)
{
   if(!EnableEngineActionMarkers)return;
   if(Bars<1)return;
   RefreshRates();

   datetime stamp=Time[0];
   int stackLevel=EngineMarkerStackLevel(engine);
   double offsetPips=EngineActionMarkerOffsetPips+(stackLevel*EngineActionMarkerStackStepPips);
   double price=NormalizePrice(High[0]+EngineMarkerPipsToPrice(offsetPips));
   string text=engine+" "+action;
   if(lots>=Lot)text+=" "+DoubleToString(lots,DigitsLots);

   string fontName=ResolveEngineMarkerFont();
   uint textWidth=0;
   uint textHeight=0;
   if(!TextGetSize(text,textWidth,textHeight))
   {
      textWidth=(uint)(StringLen(text)*8+10);
      textHeight=(uint)(EngineActionMarkerFontSize+7);
   }

   int boxWidth=(int)textWidth+10;
   int boxHeight=(int)textHeight+4;

   string baseName=ENGINE_MARKER_PREFIX+IntegerToString((int)stamp)+"_"+IntegerToString(GetTickCount())+"_"+IntegerToString(MathRand());
   string textName=baseName+"_TXT";
   string bgName=baseName+"_BG";

   int x=0,y=0;
   if(!ChartTimePriceToXY(0,0,stamp,price,x,y))
   {
      ChartRedraw(0);
      return;
   }

   // Pixel-sized opaque background, matching the supplied validated UI
   // pattern: flat rectangle first, then text in the foreground.
   if(ObjectCreate(0,bgName,OBJ_RECTANGLE_LABEL,0,0,0))
   {
      ObjectSetInteger(0,bgName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,bgName,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bgName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,bgName,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,bgName,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,bgName,OBJPROP_XDISTANCE,x-(boxWidth/2));
      ObjectSetInteger(0,bgName,OBJPROP_YDISTANCE,y-boxHeight);
      ObjectSetInteger(0,bgName,OBJPROP_XSIZE,boxWidth);
      ObjectSetInteger(0,bgName,OBJPROP_YSIZE,boxHeight);
      ObjectSetInteger(0,bgName,OBJPROP_BGCOLOR,EngineActionMarkerBackgroundColor);
      ObjectSetInteger(0,bgName,OBJPROP_COLOR,EngineActionMarkerBackgroundColor);
      ObjectSetInteger(0,bgName,OBJPROP_BACK,false);
      ObjectSetInteger(0,bgName,OBJPROP_ZORDER,1);
   }

   // Text is anchored by its lower edge at the same chart coordinate as the
   // label, so the black box remains immediately behind the glyphs.
   if(ObjectCreate(0,textName,OBJ_TEXT,0,stamp,price))
   {
      ObjectSetInteger(0,textName,OBJPROP_ANCHOR,ANCHOR_LOWER);
      ObjectSetInteger(0,textName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,textName,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,textName,OBJPROP_HIDDEN,true);
      ObjectSetString(0,textName,OBJPROP_TEXT,text);
      ObjectSetString(0,textName,OBJPROP_FONT,fontName);
      ObjectSetInteger(0,textName,OBJPROP_FONTSIZE,EngineActionMarkerFontSize);
      ObjectSetInteger(0,textName,OBJPROP_COLOR,EngineActionMarkerTextColor);
      ObjectSetInteger(0,textName,OBJPROP_BACK,false);
      ObjectSetInteger(0,textName,OBJPROP_ZORDER,2);
   }

   ChartRedraw(0);
}

int OnInit(){bool reloadPersistedConfig=(GlobalVariableCheck(ConfigKey("RELOAD_ON_REINIT"))&&GlobalVariableGet(ConfigKey("RELOAD_ON_REINIT"))>0.5);if(reloadPersistedConfig){LoadPersistedConfig();GlobalVariableSet(ConfigKey("RELOAD_ON_REINIT"),0.0);}else if(!GlobalVariableCheck(ConfigKey("CONFIG_INITIALIZED"))){PersistConfigState();}ArrayResize(g_r9ProcessedTickets,0);g_r9HedgeActive=false;g_r10LastAction=0;if(EnableR10RecoveryRealization){string r10Key=StateKey("g_r10RecoveryCycleActive");if(GlobalVariableCheck(r10Key)){g_r10RecoveryCycleActive=(GlobalVariableGet(r10Key)>0.5);g_r10RecoveryStartEquity=GlobalVariableGet(StateKey("g_r10RecoveryStartEquity"));g_r10RecoveryWorstEquity=GlobalVariableGet(StateKey("g_r10RecoveryWorstEquity"));}}g_r1LastDecision="DISABLED";g_r1LastReason="";g_r1LastDecisionTime=0;R13ResetObserverState(g_r13Observer);R9SeedExistingPositions();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_RealizationCascadeUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(true);Print(EA_NAME," v0.106 initialized. R1 Admission Gate=",EnableR1AdmissionGate,"; R1 Broker=",EnableR1BrokerGuard," Lot=",EnableR1LotGuard," Margin=",EnableR1MarginGuard," TradePermission=",EnableR1TradePermissionGuard,"; R12 telemetry active; R13 observer/trading active=",EnableR13,"/",EnableR13Trading," auto=",EnableR13AutoActivation,"; event-driven Global Variables; R11 dynamic recovery step multiplier active=",EnableRecoveryStepMultiplier," multiplier=",DoubleToString(RecoveryStepMultiplier,2)," max=",DoubleToString(RecoveryStepMax,1),"; GLOBAL STOP TRAILING; ENGINE ACTION MARKERS active=",EnableEngineActionMarkers,".");CreateFirstOrdersIfFlat();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_RealizationCascadeUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(true);return(INIT_SUCCEEDED);}
void OnDeinit(const int reason){
   PersistAllState(true);
   bool chartChange=(reason==REASON_CHARTCHANGE);
   if(!chartChange)PersistConfigState();
   bool restore=(reason==REASON_CLOSE||reason==REASON_CHARTCLOSE||reason==REASON_RECOMPILE);
   GlobalVariableSet(ConfigKey("RELOAD_ON_REINIT"),restore?1.0:0.0);
   GlobalVariablesFlush();
   EAGOLD_RealizationCascadeDelete();
   EAGOLD_ChartBasketGuidesDelete();
   EAGOLD_ModPanelDelete();
}
void OnTick(){R10RecoveryUpdateState();Rule9DetectActivatedOrders();BuyMachine();SellMachine();CreateFirstOrdersIfFlat();TrailAllStopOrders();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_RealizationCascadeUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(false);}
