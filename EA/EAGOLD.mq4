#property strict
#property version   "0.106"
#property description "EAGOLD - BUY/SELL independent machines - Rules 1 to 10 + R10.2 Recovery Realization + Dynamic Recovery Step Multiplier + Persistent Operational State + Isolated R1 Admission Control + R13 Recovery Satellite"
#include "../Core/EAGOLD_Config.mqh"
#include "../Core/EAGOLD_ActionContract.mqh"
#include "../Core/EAGOLD_Orders.mqh"
#include "../Core/EAGOLD_Execution.mqh"
#include "../Core/EAGOLD_Persistence.mqh"
string EA_NAME="EAGOLD";string R10_MARKER_PREFIX="EAGOLD_R10_MARKER_";string ENGINE_MARKER_PREFIX="EAGOLD_ENGINE_";string STATE_PREFIX="EAGOLD_STATE_";bool g_r9HedgeActive=false;int g_r9ProcessedTickets[];datetime g_r10LastAction=0;string g_r1LastDecision="DISABLED";string g_r1LastReason="";datetime g_r1LastDecisionTime=0;bool g_r10RecoveryCycleActive=false;double g_r10RecoveryStartEquity=0.0;double g_r10RecoveryWorstEquity=0.0;EAGOLD_TickPolicy g_eagoldTickPolicy=EAGOLD_TICK_CONTINUE;

double PointsToPrice(double points){return(points*Point);}double NormalizePrice(double price){return(NormalizeDouble(price,Digits));}double NormalizeLot(double lot){if(lot<Lot)lot=Lot;if(MaxOpenLot>0.0&&lot>MaxOpenLot)lot=MaxOpenLot;return(NormalizeDouble(lot,DigitsLots));}

void EAGOLD_ResetTickTransaction(){g_eagoldTickPolicy=EAGOLD_TICK_CONTINUE;}
bool EAGOLD_EconomicExecutionAllowed(){return(g_eagoldTickPolicy!=EAGOLD_TICK_HALT_FOR_RECONCILIATION);}
void EAGOLD_ApplyActionResult(EAGOLD_ActionResult result,string engine,string action,int direction,double lots){EAGOLD_TickPolicy policy=EAGOLD_PolicyForResult(result);Print(EA_NAME," ACTION CONTRACT engine=",engine," action=",action," result=",EAGOLD_ActionResultName(result)," policy=",EAGOLD_TickPolicyName(policy)," direction=",(direction==OP_BUY?"BUY":"SELL")," lots=",DoubleToString(lots,DigitsLots));if(policy==EAGOLD_TICK_HALT_FOR_RECONCILIATION)g_eagoldTickPolicy=EAGOLD_TICK_HALT_FOR_RECONCILIATION;else if(policy==EAGOLD_TICK_CONSUME&&g_eagoldTickPolicy==EAGOLD_TICK_CONTINUE)g_eagoldTickPolicy=EAGOLD_TICK_CONSUME;}

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
double EngineMarkerPipsToPrice(double pips){double pipSize=Point;if(Digits==3||Digits==5)pipSize=Point*10.0;return(pips*pipSize);}
int EngineMarkerStackLevel(string engine){if(engine=="R1")return(0);if(engine=="R1.1")return(1);if(engine=="R4")return(2);if(engine=="R5"||engine=="BRX")return(3);if(engine=="R7")return(4);if(engine=="R10")return(5);if(engine=="R13")return(6);return(7);}
string ResolveEngineMarkerFont(){return("Arial");}
void CreateEngineActionMarker(string engine,string action,int direction,double lots){if(!EnableEngineActionMarkers||Bars<1)return;RefreshRates();datetime stamp=Time[0];double price=NormalizePrice(direction==OP_BUY?Low[0]:High[0]);color markerColor=CascadeEngineColor(engine);string name=ENGINE_MARKER_PREFIX+IntegerToString((int)stamp)+"_"+IntegerToString(GetTickCount())+"_"+IntegerToString(MathRand());if(ObjectCreate(0,name,OBJ_ARROW,0,stamp,price)){ObjectSetInteger(0,name,OBJPROP_ARROWCODE,159);ObjectSetInteger(0,name,OBJPROP_WIDTH,2);ObjectSetInteger(0,name,OBJPROP_COLOR,markerColor);ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,name,OBJPROP_SELECTED,false);ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);ObjectSetInteger(0,name,OBJPROP_BACK,false);ObjectSetInteger(0,name,OBJPROP_ZORDER,5);}EAGOLD_ActionCascadeAdd(engine);ChartRedraw(0);}
int OnInit(){ObjectsDeleteAll(0,ENGINE_MARKER_PREFIX);ObjectsDeleteAll(0,R10_MARKER_PREFIX);ArrayResize(g_r9ProcessedTickets,0);g_r9HedgeActive=false;g_r10LastAction=0;g_r10RecoveryCycleActive=false;g_r10RecoveryStartEquity=0.0;g_r10RecoveryWorstEquity=0.0;g_eagoldTickPolicy=EAGOLD_TICK_CONTINUE;if(EAGOLD_PersistenceEnabled())LoadPersistedStrategicState();else{g_modPanelMinProfit=0.0;g_modPanelMaxLots=0.0;g_modPanelInitialized=true;g_panelMinProfit=0.0;g_panelMaxLots=0.0;g_panelInitialized=true;}g_r1LastDecision="DISABLED";g_r1LastReason="";g_r1LastDecisionTime=0;R13ResetObserverState(g_r13Observer);R9SeedExistingPositions();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_RealizationCascadeUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(true);CreateFirstOrdersIfFlat();R13Observe(g_r13Observer);EAGOLD_ModPanelUpdate();EAGOLD_RealizationCascadeUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(true);return(INIT_SUCCEEDED);}
void OnDeinit(const int reason){if(EAGOLD_PersistenceEnabled())PersistAllState(true);EAGOLD_RealizationCascadeDelete();EAGOLD_ChartBasketGuidesDelete();EAGOLD_ModPanelDelete();}
void OnTick(){EAGOLD_ResetTickTransaction();R10RecoveryUpdateState();Rule9DetectActivatedOrders();if(EAGOLD_EconomicExecutionAllowed())BuyMachine();if(EAGOLD_EconomicExecutionAllowed())SellMachine();if(EAGOLD_EconomicExecutionAllowed())CreateFirstOrdersIfFlat();if(EAGOLD_EconomicExecutionAllowed())TrailAllStopOrders();if(EAGOLD_EconomicExecutionAllowed())R13Observe(g_r13Observer);ObjectsDeleteAll(0,R10_MARKER_PREFIX);EAGOLD_ModPanelUpdate();EAGOLD_RealizationCascadeUpdate();EAGOLD_ChartBasketGuidesUpdate();PersistAllState(false);}
