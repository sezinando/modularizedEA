#ifndef EAGOLD_EXCURSION_TRACKER_MQH
#define EAGOLD_EXCURSION_TRACKER_MQH

//==================================================================
// EAGOLD EXCURSION TRACKER v1.1
// Observer-only telemetry for adaptive profit-management research.
//
// CONTRACT
// - MUST NOT submit, modify or close orders.
// - MUST NOT change lot sizing, TP, BRX, R9, R10, R11 or R13 behavior.
// - Tracks one EAGOLD master cycle from first position until the
//   master universe becomes completely flat (positions AND pending).
// - MFE/MAE are measured from aggregate floating P/L of EAGOLD
//   positions, including swap/commission.
// - Final realized P/L is calculated from the broker history delta
//   between cycle start and cycle end.
// - v1.1 additionally records every completed/partial realization as
//   an event, preserving the pre-action excursion state and the
//   realized delta observed after the action.
//==================================================================

bool     g_excursionActive=false;
datetime g_excursionStartTime=0;
string   g_excursionCycleId="";
double   g_excursionStartRealized=0.0;
double   g_excursionLastRealized=0.0;
double   g_excursionMFE=0.0;
double   g_excursionMAE=0.0;
double   g_excursionPeakFloatingPL=0.0;
double   g_excursionLastFloatingPL=0.0;
double   g_excursionLastObservedFloatingPL=0.0;
double   g_excursionMaxBuyLots=0.0;
double   g_excursionMaxSellLots=0.0;
double   g_excursionMaxGrossLots=0.0;
double   g_excursionMaxNetLots=0.0;
string   g_excursionDirection="";
string   g_excursionRealizationEngine="";
string   g_excursionRealizationType="";
int      g_excursionSequence=0;
int      g_excursionRealizationSequence=0;

string EAGOLD_ExcursionDirection(double buyLots,double sellLots)
{
   if(buyLots>0.0 && sellLots>0.0)return("BIDIR");
   if(buyLots>0.0)return("BUY");
   if(sellLots>0.0)return("SELL");
   return("FLAT");
}

void EAGOLD_ExcursionEnsureFileHeader(int handle)
{
   if(FileSize(handle)>0)return;
   FileWrite(handle,
      "CYCLE_ID","START_TIME","END_TIME","DIRECTION",
      "BUY_LOTS_MAX","SELL_LOTS_MAX","GROSS_LOTS_MAX","NET_LOTS_MAX",
      "MFE","MAE","PEAK_FLOATING_PL","FINAL_REALIZED_PL","GIVEBACK",
      "DURATION_SEC","REALIZATION_ENGINE","REALIZATION_TYPE");
}

void EAGOLD_ExcursionEnsureEventFileHeader(int handle)
{
   if(FileSize(handle)>0)return;
   FileWrite(handle,
      "EVENT_ID","CYCLE_ID","EVENT_TIME","ENGINE","ACTION","RESULT",
      "REALIZED_DELTA","REALIZED_CUMULATIVE","PRE_ACTION_FLOATING_PL",
      "POST_ACTION_FLOATING_PL","MFE_AT_ACTION","MAE_AT_ACTION",
      "PEAK_FLOATING_PL_AT_ACTION","PEAK_TO_ACTION_GIVEBACK",
      "BUY_LOTS","SELL_LOTS","GROSS_LOTS","NET_LOTS",
      "BUY_LOTS_MAX","SELL_LOTS_MAX","GROSS_LOTS_MAX","NET_LOTS_MAX");
}

void EAGOLD_ExcursionWriteRecord(datetime endTime)
{
   int handle=FileOpen("EAGOLD_EXCURSION_CYCLES.csv",
      FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(handle==INVALID_HANDLE)
   {
      Print("EAGOLD EXCURSION: FileOpen failed error=",GetLastError());
      return;
   }

   FileSeek(handle,0,SEEK_END);
   EAGOLD_ExcursionEnsureFileHeader(handle);

   double finalRealized=EAGOLDAccumulatedProfit()-g_excursionStartRealized;
   double giveback=g_excursionMFE-g_excursionLastFloatingPL;
   if(giveback<0.0)giveback=0.0;
   long duration=(long)(endTime-g_excursionStartTime);
   if(duration<0)duration=0;

   FileWrite(handle,
      g_excursionCycleId,
      TimeToString(g_excursionStartTime,TIME_DATE|TIME_SECONDS),
      TimeToString(endTime,TIME_DATE|TIME_SECONDS),
      g_excursionDirection,
      DoubleToString(g_excursionMaxBuyLots,DigitsLots),
      DoubleToString(g_excursionMaxSellLots,DigitsLots),
      DoubleToString(g_excursionMaxGrossLots,DigitsLots),
      DoubleToString(g_excursionMaxNetLots,DigitsLots),
      DoubleToString(g_excursionMFE,2),
      DoubleToString(g_excursionMAE,2),
      DoubleToString(g_excursionPeakFloatingPL,2),
      DoubleToString(finalRealized,2),
      DoubleToString(giveback,2),
      IntegerToString((int)duration),
      g_excursionRealizationEngine,
      g_excursionRealizationType);

   FileFlush(handle);
   FileClose(handle);
}

void EAGOLD_ExcursionWriteRealizationEvent(string engine,string action,EAGOLD_ActionResult result)
{
   int handle=FileOpen("EAGOLD_EXCURSION_EVENTS.csv",
      FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(handle==INVALID_HANDLE)
   {
      Print("EAGOLD EXCURSION EVENT: FileOpen failed error=",GetLastError());
      return;
   }

   FileSeek(handle,0,SEEK_END);
   EAGOLD_ExcursionEnsureEventFileHeader(handle);

   g_excursionRealizationSequence++;
   double currentRealized=EAGOLDAccumulatedProfit();
   double realizedDelta=currentRealized-g_excursionLastRealized;
   double realizedCumulative=currentRealized-g_excursionStartRealized;

   double buyLots=DirectionLots(OP_BUY);
   double sellLots=DirectionLots(OP_SELL);
   double grossLots=buyLots+sellLots;
   double netLots=MathAbs(buyLots-sellLots);
   double giveback=g_excursionPeakFloatingPL-g_excursionLastObservedFloatingPL;
   if(giveback<0.0)giveback=0.0;

   string eventId=g_excursionCycleId+"_R"+IntegerToString(g_excursionRealizationSequence);

   FileWrite(handle,
      eventId,
      g_excursionCycleId,
      TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
      engine,
      action,
      EAGOLD_ActionResultName(result),
      DoubleToString(realizedDelta,2),
      DoubleToString(realizedCumulative,2),
      DoubleToString(g_excursionLastObservedFloatingPL,2),
      DoubleToString(DirectionBasketProfit(OP_BUY)+DirectionBasketProfit(OP_SELL),2),
      DoubleToString(g_excursionMFE,2),
      DoubleToString(g_excursionMAE,2),
      DoubleToString(g_excursionPeakFloatingPL,2),
      DoubleToString(giveback,2),
      DoubleToString(buyLots,DigitsLots),
      DoubleToString(sellLots,DigitsLots),
      DoubleToString(grossLots,DigitsLots),
      DoubleToString(netLots,DigitsLots),
      DoubleToString(g_excursionMaxBuyLots,DigitsLots),
      DoubleToString(g_excursionMaxSellLots,DigitsLots),
      DoubleToString(g_excursionMaxGrossLots,DigitsLots),
      DoubleToString(g_excursionMaxNetLots,DigitsLots));

   FileFlush(handle);
   FileClose(handle);
   g_excursionLastRealized=currentRealized;
}

void EAGOLD_ExcursionTrackerReset()
{
   g_excursionActive=false;
   g_excursionStartTime=0;
   g_excursionCycleId="";
   g_excursionStartRealized=0.0;
   g_excursionLastRealized=0.0;
   g_excursionMFE=0.0;
   g_excursionMAE=0.0;
   g_excursionPeakFloatingPL=0.0;
   g_excursionLastFloatingPL=0.0;
   g_excursionLastObservedFloatingPL=0.0;
   g_excursionMaxBuyLots=0.0;
   g_excursionMaxSellLots=0.0;
   g_excursionMaxGrossLots=0.0;
   g_excursionMaxNetLots=0.0;
   g_excursionDirection="";
   g_excursionRealizationEngine="";
   g_excursionRealizationType="";
   g_excursionRealizationSequence=0;
}

void EAGOLD_ExcursionTrackerStart(datetime now,double buyLots,double sellLots,double floatingPL)
{
   g_excursionSequence++;
   g_excursionActive=true;
   g_excursionStartTime=now;
   g_excursionCycleId=TimeToString(now,TIME_DATE|TIME_SECONDS)+"_"+IntegerToString(g_excursionSequence);
   StringReplace(g_excursionCycleId,".","");
   StringReplace(g_excursionCycleId,":","");
   StringReplace(g_excursionCycleId," ","_");
   g_excursionStartRealized=EAGOLDAccumulatedProfit();
   g_excursionLastRealized=g_excursionStartRealized;
   g_excursionMFE=floatingPL;
   g_excursionMAE=floatingPL;
   g_excursionPeakFloatingPL=floatingPL;
   g_excursionLastFloatingPL=floatingPL;
   g_excursionLastObservedFloatingPL=floatingPL;
   g_excursionMaxBuyLots=buyLots;
   g_excursionMaxSellLots=sellLots;
   g_excursionMaxGrossLots=buyLots+sellLots;
   g_excursionMaxNetLots=MathAbs(buyLots-sellLots);
   g_excursionDirection=EAGOLD_ExcursionDirection(buyLots,sellLots);
   g_excursionRealizationEngine="";
   g_excursionRealizationType="";
   g_excursionRealizationSequence=0;
   Print("EAGOLD EXCURSION START cycle=",g_excursionCycleId,
         " direction=",g_excursionDirection,
         " floating=",DoubleToString(floatingPL,2));
}

void EAGOLD_ExcursionTrackerObserve()
{
   int masterOrders=CountEAGOLDOrders();
   if(masterOrders<=0)
   {
      if(g_excursionActive)EAGOLD_ExcursionTrackerFinalize();
      return;
   }

   double buyLots=DirectionLots(OP_BUY);
   double sellLots=DirectionLots(OP_SELL);
   double floatingPL=DirectionBasketProfit(OP_BUY)+DirectionBasketProfit(OP_SELL);
   double grossLots=buyLots+sellLots;
   double netLots=MathAbs(buyLots-sellLots);

   if(!g_excursionActive)
   {
      if(CountDirectionPositions(OP_BUY)+CountDirectionPositions(OP_SELL)>0)
         EAGOLD_ExcursionTrackerStart(TimeCurrent(),buyLots,sellLots,floatingPL);
      return;
   }

   if(buyLots>g_excursionMaxBuyLots)g_excursionMaxBuyLots=buyLots;
   if(sellLots>g_excursionMaxSellLots)g_excursionMaxSellLots=sellLots;
   if(grossLots>g_excursionMaxGrossLots)g_excursionMaxGrossLots=grossLots;
   if(netLots>g_excursionMaxNetLots)g_excursionMaxNetLots=netLots;

   if(buyLots>sellLots)g_excursionDirection="BUY";
   else if(sellLots>buyLots)g_excursionDirection="SELL";
   else if(buyLots>0.0)g_excursionDirection="BIDIR";

   if(floatingPL>g_excursionMFE)g_excursionMFE=floatingPL;
   if(floatingPL<g_excursionMAE)g_excursionMAE=floatingPL;
   if(floatingPL>g_excursionPeakFloatingPL)g_excursionPeakFloatingPL=floatingPL;
   g_excursionLastFloatingPL=floatingPL;
   g_excursionLastObservedFloatingPL=floatingPL;
}

void EAGOLD_ExcursionTrackerNoteRealization(string engine,string action,EAGOLD_ActionResult result)
{
   if(!g_excursionActive)return;
   if(result!=EAGOLD_ACTION_COMPLETED && result!=EAGOLD_ACTION_PARTIAL)return;
   g_excursionRealizationEngine=engine;
   g_excursionRealizationType=action;
   EAGOLD_ExcursionWriteRealizationEvent(engine,action,result);
}

void EAGOLD_ExcursionTrackerFinalize()
{
   if(!g_excursionActive)return;

   datetime endTime=TimeCurrent();
   EAGOLD_ExcursionWriteRecord(endTime);
   double finalRealized=EAGOLDAccumulatedProfit()-g_excursionStartRealized;
   Print("EAGOLD EXCURSION END cycle=",g_excursionCycleId,
         " mfe=",DoubleToString(g_excursionMFE,2),
         " mae=",DoubleToString(g_excursionMAE,2),
         " peak=",DoubleToString(g_excursionPeakFloatingPL,2),
         " realized=",DoubleToString(finalRealized,2),
         " giveback=",DoubleToString(MathMax(0.0,g_excursionMFE-g_excursionLastFloatingPL),2));
   EAGOLD_ExcursionTrackerReset();
}

#endif
