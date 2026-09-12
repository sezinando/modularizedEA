#ifndef EAGOLD_EXCURSION_TRACKER_MQH
#define EAGOLD_EXCURSION_TRACKER_MQH

//==================================================================
// EAGOLD EXCURSION TRACKER v1.0
// Observer-only telemetry for adaptive profit-management research.
//
// CONTRACT
// - MUST NOT submit, modify or close orders.
// - MUST NOT change lot sizing, TP, BRX, R9, R10, R11 or R13 behavior.
// - Tracks one EAGOLD master cycle from first order until the master
//   universe becomes completely flat (positions AND pending orders).
// - MFE/MAE are measured from aggregate floating P/L of EAGOLD
//   positions, including swap/commission.
// - Final realized P/L is calculated from the broker history delta
//   between cycle start and cycle end.
//==================================================================

bool     g_excursionActive=false;
datetime g_excursionStartTime=0;
string   g_excursionCycleId="";
double   g_excursionStartRealized=0.0;
double   g_excursionMFE=0.0;
double   g_excursionMAE=0.0;
double   g_excursionPeakFloatingPL=0.0;
double   g_excursionLastFloatingPL=0.0;
double   g_excursionMaxBuyLots=0.0;
double   g_excursionMaxSellLots=0.0;
double   g_excursionMaxGrossLots=0.0;
double   g_excursionMaxNetLots=0.0;
string   g_excursionDirection="";
string   g_excursionRealizationEngine="";
string   g_excursionRealizationType="";
int      g_excursionSequence=0;

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

void EAGOLD_ExcursionTrackerReset()
{
   g_excursionActive=false;
   g_excursionStartTime=0;
   g_excursionCycleId="";
   g_excursionStartRealized=0.0;
   g_excursionMFE=0.0;
   g_excursionMAE=0.0;
   g_excursionPeakFloatingPL=0.0;
   g_excursionLastFloatingPL=0.0;
   g_excursionMaxBuyLots=0.0;
   g_excursionMaxSellLots=0.0;
   g_excursionMaxGrossLots=0.0;
   g_excursionMaxNetLots=0.0;
   g_excursionDirection="";
   g_excursionRealizationEngine="";
   g_excursionRealizationType="";
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
   g_excursionMFE=floatingPL;
   g_excursionMAE=floatingPL;
   g_excursionPeakFloatingPL=floatingPL;
   g_excursionLastFloatingPL=floatingPL;
   g_excursionMaxBuyLots=buyLots;
   g_excursionMaxSellLots=sellLots;
   g_excursionMaxGrossLots=buyLots+sellLots;
   g_excursionMaxNetLots=MathAbs(buyLots-sellLots);
   g_excursionDirection=EAGOLD_ExcursionDirection(buyLots,sellLots);
   g_excursionRealizationEngine="";
   g_excursionRealizationType="";
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
}

void EAGOLD_ExcursionTrackerNoteRealization(string engine,string action,EAGOLD_ActionResult result)
{
   if(!g_excursionActive)return;
   if(result!=EAGOLD_ACTION_COMPLETED && result!=EAGOLD_ACTION_PARTIAL)return;
   g_excursionRealizationEngine=engine;
   g_excursionRealizationType=action;
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
