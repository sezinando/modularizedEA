#ifndef EAGOLD_EXCURSION_TRACKER_MQH
#define EAGOLD_EXCURSION_TRACKER_MQH

// EAGOLD EXCURSION TRACKER v1.6
// Observer-only cycle/inter-event state used by Counterfactual Path Telemetry.
// Research file output was intentionally removed: the canonical research dataset
// is now EAGOLD_COUNTERFACTUAL_PATH.csv only.
// No order, sizing, TP, BRX, R9, R10, R11 or R13 behavior is changed.

bool g_excursionActive=false;
datetime g_excursionStartTime=0; string g_excursionCycleId="";
double g_excursionStartRealized=0.0,g_excursionLastRealized=0.0,g_excursionMFE=0.0,g_excursionMAE=0.0,g_excursionPeakFloatingPL=0.0,g_excursionLastFloatingPL=0.0,g_excursionLastObservedFloatingPL=0.0;
double g_excursionMaxBuyLots=0.0,g_excursionMaxSellLots=0.0,g_excursionMaxGrossLots=0.0,g_excursionMaxNetLots=0.0;
string g_excursionDirection="",g_excursionRealizationEngine="",g_excursionRealizationType="";
int g_excursionSequence=0,g_excursionRealizationSequence=0;
datetime g_excursionIntervalStartTime=0;
double g_excursionIntervalStartFloatingPL=0.0,g_excursionIntervalMFE=0.0,g_excursionIntervalMAE=0.0,g_excursionIntervalPeakFloatingPL=0.0,g_excursionIntervalLastFloatingPL=0.0;
double g_excursionIntervalMaxBuyLots=0.0,g_excursionIntervalMaxSellLots=0.0,g_excursionIntervalMaxGrossLots=0.0,g_excursionIntervalMaxNetLots=0.0;

string EAGOLD_ExcursionDirection(double buyLots,double sellLots){if(buyLots>0.0&&sellLots>0.0)return("BIDIR");if(buyLots>0.0)return("BUY");if(sellLots>0.0)return("SELL");return("FLAT");}

void EAGOLD_ExcursionTrackerReset(){
   g_excursionActive=false;g_excursionStartTime=0;g_excursionCycleId="";g_excursionStartRealized=0.0;g_excursionLastRealized=0.0;g_excursionMFE=0.0;g_excursionMAE=0.0;g_excursionPeakFloatingPL=0.0;g_excursionLastFloatingPL=0.0;g_excursionLastObservedFloatingPL=0.0;
   g_excursionMaxBuyLots=0.0;g_excursionMaxSellLots=0.0;g_excursionMaxGrossLots=0.0;g_excursionMaxNetLots=0.0;g_excursionDirection="";g_excursionRealizationEngine="";g_excursionRealizationType="";g_excursionRealizationSequence=0;
   g_excursionIntervalStartTime=0;g_excursionIntervalStartFloatingPL=0.0;g_excursionIntervalMFE=0.0;g_excursionIntervalMAE=0.0;g_excursionIntervalPeakFloatingPL=0.0;g_excursionIntervalLastFloatingPL=0.0;g_excursionIntervalMaxBuyLots=0.0;g_excursionIntervalMaxSellLots=0.0;g_excursionIntervalMaxGrossLots=0.0;g_excursionIntervalMaxNetLots=0.0;
}

void EAGOLD_ExcursionTrackerStart(datetime now,double buyLots,double sellLots,double floatingPL){
   g_excursionSequence++;g_excursionActive=true;g_excursionStartTime=now;g_excursionCycleId=TimeToString(now,TIME_DATE|TIME_SECONDS)+"_"+IntegerToString(g_excursionSequence);StringReplace(g_excursionCycleId,".","");StringReplace(g_excursionCycleId,":","");StringReplace(g_excursionCycleId," ","_");
   g_excursionStartRealized=EAGOLDAccumulatedProfit();g_excursionLastRealized=g_excursionStartRealized;g_excursionMFE=floatingPL;g_excursionMAE=floatingPL;g_excursionPeakFloatingPL=floatingPL;g_excursionLastFloatingPL=floatingPL;g_excursionLastObservedFloatingPL=floatingPL;
   g_excursionMaxBuyLots=buyLots;g_excursionMaxSellLots=sellLots;g_excursionMaxGrossLots=buyLots+sellLots;g_excursionMaxNetLots=MathAbs(buyLots-sellLots);g_excursionDirection=EAGOLD_ExcursionDirection(buyLots,sellLots);g_excursionRealizationEngine="";g_excursionRealizationType="";g_excursionRealizationSequence=0;
   g_excursionIntervalStartTime=now;g_excursionIntervalStartFloatingPL=floatingPL;g_excursionIntervalMFE=floatingPL;g_excursionIntervalMAE=floatingPL;g_excursionIntervalPeakFloatingPL=floatingPL;g_excursionIntervalLastFloatingPL=floatingPL;g_excursionIntervalMaxBuyLots=buyLots;g_excursionIntervalMaxSellLots=sellLots;g_excursionIntervalMaxGrossLots=buyLots+sellLots;g_excursionIntervalMaxNetLots=MathAbs(buyLots-sellLots);
   EAGOLD_R12ResetEventBoundary();
   Print("EAGOLD EXCURSION START cycle=",g_excursionCycleId," direction=",g_excursionDirection," floating=",DoubleToString(floatingPL,2));
}

void EAGOLD_ExcursionTrackerObserve(){
   int masterOrders=CountEAGOLDOrders();if(masterOrders<=0){if(g_excursionActive)EAGOLD_ExcursionTrackerFinalize();return;}
   double buyLots=DirectionLots(OP_BUY),sellLots=DirectionLots(OP_SELL),floatingPL=DirectionBasketProfit(OP_BUY)+DirectionBasketProfit(OP_SELL),grossLots=buyLots+sellLots,netLots=MathAbs(buyLots-sellLots);
   if(!g_excursionActive){if(CountDirectionPositions(OP_BUY)+CountDirectionPositions(OP_SELL)>0)EAGOLD_ExcursionTrackerStart(TimeCurrent(),buyLots,sellLots,floatingPL);return;}
   if(buyLots>g_excursionMaxBuyLots)g_excursionMaxBuyLots=buyLots;if(sellLots>g_excursionMaxSellLots)g_excursionMaxSellLots=sellLots;if(grossLots>g_excursionMaxGrossLots)g_excursionMaxGrossLots=grossLots;if(netLots>g_excursionMaxNetLots)g_excursionMaxNetLots=netLots;
   if(buyLots>sellLots)g_excursionDirection="BUY";else if(sellLots>buyLots)g_excursionDirection="SELL";else if(buyLots>0.0)g_excursionDirection="BIDIR";
   if(floatingPL>g_excursionMFE)g_excursionMFE=floatingPL;if(floatingPL<g_excursionMAE)g_excursionMAE=floatingPL;if(floatingPL>g_excursionPeakFloatingPL)g_excursionPeakFloatingPL=floatingPL;g_excursionLastFloatingPL=floatingPL;g_excursionLastObservedFloatingPL=floatingPL;
   if(floatingPL>g_excursionIntervalMFE)g_excursionIntervalMFE=floatingPL;if(floatingPL<g_excursionIntervalMAE)g_excursionIntervalMAE=floatingPL;if(floatingPL>g_excursionIntervalPeakFloatingPL)g_excursionIntervalPeakFloatingPL=floatingPL;g_excursionIntervalLastFloatingPL=floatingPL;
   if(buyLots>g_excursionIntervalMaxBuyLots)g_excursionIntervalMaxBuyLots=buyLots;if(sellLots>g_excursionIntervalMaxSellLots)g_excursionIntervalMaxSellLots=sellLots;if(grossLots>g_excursionIntervalMaxGrossLots)g_excursionIntervalMaxGrossLots=grossLots;if(netLots>g_excursionIntervalMaxNetLots)g_excursionIntervalMaxNetLots=netLots;
}

void EAGOLD_ExcursionTrackerNoteRealization(string engine,string action,EAGOLD_ActionResult result){
   if(!g_excursionActive)return;
   if(result!=EAGOLD_ACTION_COMPLETED&&result!=EAGOLD_ACTION_PARTIAL)return;
   g_excursionRealizationEngine=engine;g_excursionRealizationType=action;g_excursionRealizationSequence++;
   double currentRealized=EAGOLDAccumulatedProfit();
   g_excursionLastRealized=currentRealized;
   double postActionFloatingPL=DirectionBasketProfit(OP_BUY)+DirectionBasketProfit(OP_SELL);
   g_excursionIntervalStartTime=TimeCurrent();g_excursionIntervalStartFloatingPL=postActionFloatingPL;g_excursionIntervalMFE=postActionFloatingPL;g_excursionIntervalMAE=postActionFloatingPL;g_excursionIntervalPeakFloatingPL=postActionFloatingPL;g_excursionIntervalLastFloatingPL=postActionFloatingPL;
   double buyLots=DirectionLots(OP_BUY),sellLots=DirectionLots(OP_SELL),grossLots=buyLots+sellLots,netLots=MathAbs(buyLots-sellLots);
   g_excursionIntervalMaxBuyLots=buyLots;g_excursionIntervalMaxSellLots=sellLots;g_excursionIntervalMaxGrossLots=grossLots;g_excursionIntervalMaxNetLots=netLots;
   EAGOLD_R12ResetEventBoundary();
}

void EAGOLD_ExcursionTrackerFinalize(){
   if(!g_excursionActive)return;
   datetime endTime=TimeCurrent();
   double finalRealized=EAGOLDAccumulatedProfit()-g_excursionStartRealized;
   double giveback=MathMax(0.0,g_excursionMFE-g_excursionLastFloatingPL);
   Print("EAGOLD EXCURSION END cycle=",g_excursionCycleId," mfe=",DoubleToString(g_excursionMFE,2)," mae=",DoubleToString(g_excursionMAE,2)," peak=",DoubleToString(g_excursionPeakFloatingPL,2)," realized=",DoubleToString(finalRealized,2)," giveback=",DoubleToString(giveback,2)," duration=",IntegerToString((int)MathMax(0,endTime-g_excursionStartTime)));
   EAGOLD_ExcursionTrackerReset();
}

#endif
