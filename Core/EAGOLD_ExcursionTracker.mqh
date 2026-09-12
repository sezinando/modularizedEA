#ifndef EAGOLD_EXCURSION_TRACKER_MQH
#define EAGOLD_EXCURSION_TRACKER_MQH

// EAGOLD EXCURSION TRACKER v1.5
// Observer-only cycle/inter-event telemetry with R12 M5 context.
// R12 event-boundary history captures the regime path since the prior realization.
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

void EAGOLD_ExcursionEnsureFileHeader(int handle){if(FileSize(handle)>0)return;FileWrite(handle,"CYCLE_ID","START_TIME","END_TIME","DIRECTION","BUY_LOTS_MAX","SELL_LOTS_MAX","GROSS_LOTS_MAX","NET_LOTS_MAX","MFE","MAE","PEAK_FLOATING_PL","FINAL_REALIZED_PL","GIVEBACK","DURATION_SEC","REALIZATION_ENGINE","REALIZATION_TYPE");}

void EAGOLD_ExcursionEnsureEventFileHeader(int handle){
   if(FileSize(handle)>0)return;
   FileWrite(handle,
      "EVENT_ID","CYCLE_ID","EVENT_TIME","EVENT_SEQ","ENGINE","ACTION","RESULT",
      "REALIZED_DELTA","REALIZED_CUMULATIVE","PRE_ACTION_FLOATING_PL","POST_ACTION_FLOATING_PL",
      "INTERVAL_START_FLOATING_PL","INTERVAL_MFE","INTERVAL_MAE","INTERVAL_PEAK_FLOATING_PL","INTERVAL_GIVEBACK","INTERVAL_DURATION_SEC",
      "MFE_AT_ACTION","MAE_AT_ACTION","PEAK_FLOATING_PL_AT_ACTION","PEAK_TO_ACTION_GIVEBACK",
      "BUY_LOTS","SELL_LOTS","GROSS_LOTS","NET_LOTS","BUY_LOTS_MAX","SELL_LOTS_MAX","GROSS_LOTS_MAX","NET_LOTS_MAX",
      "INTERVAL_BUY_LOTS_MAX","INTERVAL_SELL_LOTS_MAX","INTERVAL_GROSS_LOTS_MAX","INTERVAL_NET_LOTS_MAX",
      "R12_VALID","R12_REGIME","R12_PREVIOUS_REGIME","R12_REGIME_CHANGE","R12_REGIME_DURATION_SEC","R12_TIME_SINCE_REGIME_CHANGE_SEC","R12_TRANSITION_COUNT","R12_SEQUENCE_COUNT","R12_REGIME_SEQUENCE",
      "R12_EVENT_TRANSITIONS","R12_EVENT_SEQUENCE_COUNT","R12_EVENT_START_TIME","R12_EVENT_LAST_CHANGE_TIME","R12_EVENT_DURATION_SEC","R12_EVENT_REGIME_SEQUENCE",
      "R12_TIME","R12_CLOSE","R12_ATR","R12_ATR_RATIO","R12_DRIFT","R12_SLOPE_FAST","R12_SLOPE_SLOW","R12_RANGE_RATIO","R12_BODY_RATIO");
}

void EAGOLD_ExcursionWriteRecord(datetime endTime){
   int handle=FileOpen("EAGOLD_EXCURSION_CYCLES.csv",FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(handle==INVALID_HANDLE){Print("EAGOLD EXCURSION: FileOpen failed error=",GetLastError());return;}
   FileSeek(handle,0,SEEK_END);EAGOLD_ExcursionEnsureFileHeader(handle);
   double finalRealized=EAGOLDAccumulatedProfit()-g_excursionStartRealized,giveback=g_excursionMFE-g_excursionLastFloatingPL;if(giveback<0.0)giveback=0.0;
   long duration=(long)(endTime-g_excursionStartTime);if(duration<0)duration=0;
   FileWrite(handle,g_excursionCycleId,TimeToString(g_excursionStartTime,TIME_DATE|TIME_SECONDS),TimeToString(endTime,TIME_DATE|TIME_SECONDS),g_excursionDirection,
      DoubleToString(g_excursionMaxBuyLots,DigitsLots),DoubleToString(g_excursionMaxSellLots,DigitsLots),DoubleToString(g_excursionMaxGrossLots,DigitsLots),DoubleToString(g_excursionMaxNetLots,DigitsLots),DoubleToString(g_excursionMFE,2),DoubleToString(g_excursionMAE,2),DoubleToString(g_excursionPeakFloatingPL,2),DoubleToString(finalRealized,2),DoubleToString(giveback,2),IntegerToString((int)duration),g_excursionRealizationEngine,g_excursionRealizationType);
   FileFlush(handle);FileClose(handle);
}

void EAGOLD_ExcursionWriteRealizationEvent(string engine,string action,EAGOLD_ActionResult result){
   int handle=FileOpen("EAGOLD_EXCURSION_EVENTS.csv",FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   if(handle==INVALID_HANDLE){Print("EAGOLD EXCURSION EVENT: FileOpen failed error=",GetLastError());return;}
   FileSeek(handle,0,SEEK_END);EAGOLD_ExcursionEnsureEventFileHeader(handle);g_excursionRealizationSequence++;
   double currentRealized=EAGOLDAccumulatedProfit(),realizedDelta=currentRealized-g_excursionLastRealized,realizedCumulative=currentRealized-g_excursionStartRealized;
   double buyLots=DirectionLots(OP_BUY),sellLots=DirectionLots(OP_SELL),grossLots=buyLots+sellLots,netLots=MathAbs(buyLots-sellLots),postActionFloatingPL=DirectionBasketProfit(OP_BUY)+DirectionBasketProfit(OP_SELL);
   double intervalGiveback=g_excursionIntervalPeakFloatingPL-g_excursionIntervalLastFloatingPL;if(intervalGiveback<0.0)intervalGiveback=0.0;
   long intervalDuration=(long)(TimeCurrent()-g_excursionIntervalStartTime);if(intervalDuration<0)intervalDuration=0;
   double cycleGiveback=g_excursionPeakFloatingPL-g_excursionLastObservedFloatingPL;if(cycleGiveback<0.0)cycleGiveback=0.0;
   string eventId=g_excursionCycleId+"_R"+IntegerToString(g_excursionRealizationSequence);
   string r12Valid=(g_r12State.valid?"1":"0"),r12Time=(g_r12State.valid?TimeToString(g_r12State.time,TIME_DATE|TIME_SECONDS):""),r12Regime=(g_r12State.valid?EAGOLD_R12_RegimeName(g_r12State.regime):"UNKNOWN"),r12Previous=(g_r12State.valid?EAGOLD_R12_RegimeName(g_r12State.previousRegime):"UNKNOWN"),r12Change=(g_r12State.valid&&g_r12State.regimeChange?"1":"0"),r12Sequence=(g_r12State.valid?g_r12State.regimeSequence:""),r12EventSequence=(g_r12State.valid?g_r12State.eventBoundaryRegimeSequence:"");

   FileWrite(handle,eventId,g_excursionCycleId,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),IntegerToString(g_excursionRealizationSequence),engine,action,EAGOLD_ActionResultName(result),
      DoubleToString(realizedDelta,2),DoubleToString(realizedCumulative,2),DoubleToString(g_excursionLastObservedFloatingPL,2),DoubleToString(postActionFloatingPL,2),
      DoubleToString(g_excursionIntervalStartFloatingPL,2),DoubleToString(g_excursionIntervalMFE,2),DoubleToString(g_excursionIntervalMAE,2),DoubleToString(g_excursionIntervalPeakFloatingPL,2),DoubleToString(intervalGiveback,2),IntegerToString((int)intervalDuration),
      DoubleToString(g_excursionMFE,2),DoubleToString(g_excursionMAE,2),DoubleToString(g_excursionPeakFloatingPL,2),DoubleToString(cycleGiveback,2),
      DoubleToString(buyLots,DigitsLots),DoubleToString(sellLots,DigitsLots),DoubleToString(grossLots,DigitsLots),DoubleToString(netLots,DigitsLots),DoubleToString(g_excursionMaxBuyLots,DigitsLots),DoubleToString(g_excursionMaxSellLots,DigitsLots),DoubleToString(g_excursionMaxGrossLots,DigitsLots),DoubleToString(g_excursionMaxNetLots,DigitsLots),
      DoubleToString(g_excursionIntervalMaxBuyLots,DigitsLots),DoubleToString(g_excursionIntervalMaxSellLots,DigitsLots),DoubleToString(g_excursionIntervalMaxGrossLots,DigitsLots),DoubleToString(g_excursionIntervalMaxNetLots,DigitsLots),
      r12Valid,r12Regime,r12Previous,r12Change,DoubleToString(g_r12State.regimeDurationSec,0),DoubleToString(g_r12State.timeSinceRegimeChangeSec,0),IntegerToString(g_r12State.regimeTransitionCount),IntegerToString(g_r12State.regimeSequenceCount),r12Sequence,
      IntegerToString(g_r12State.eventBoundaryTransitionCount),IntegerToString(g_r12State.eventBoundarySequenceCount),TimeToString(g_r12State.eventBoundaryStartTime,TIME_DATE|TIME_SECONDS),TimeToString(g_r12State.eventBoundaryLastChangeTime,TIME_DATE|TIME_SECONDS),DoubleToString(g_r12State.eventBoundaryDurationSec,0),r12EventSequence,
      r12Time,DoubleToString(g_r12State.close,Digits),DoubleToString(g_r12State.atr,Digits),DoubleToString(g_r12State.atrRatio,4),DoubleToString(g_r12State.drift,4),DoubleToString(g_r12State.slopeFast,4),DoubleToString(g_r12State.slopeSlow,4),DoubleToString(g_r12State.rangeRatio,4),DoubleToString(g_r12State.bodyRatio,4));
   FileFlush(handle);FileClose(handle);g_excursionLastRealized=currentRealized;
   g_excursionIntervalStartTime=TimeCurrent();g_excursionIntervalStartFloatingPL=postActionFloatingPL;g_excursionIntervalMFE=postActionFloatingPL;g_excursionIntervalMAE=postActionFloatingPL;g_excursionIntervalPeakFloatingPL=postActionFloatingPL;g_excursionIntervalLastFloatingPL=postActionFloatingPL;
   g_excursionIntervalMaxBuyLots=buyLots;g_excursionIntervalMaxSellLots=sellLots;g_excursionIntervalMaxGrossLots=grossLots;g_excursionIntervalMaxNetLots=netLots;
   EAGOLD_R12ResetEventBoundary();
}

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

void EAGOLD_ExcursionTrackerNoteRealization(string engine,string action,EAGOLD_ActionResult result){if(!g_excursionActive)return;if(result!=EAGOLD_ACTION_COMPLETED&&result!=EAGOLD_ACTION_PARTIAL)return;g_excursionRealizationEngine=engine;g_excursionRealizationType=action;EAGOLD_ExcursionWriteRealizationEvent(engine,action,result);}

void EAGOLD_ExcursionTrackerFinalize(){if(!g_excursionActive)return;datetime endTime=TimeCurrent();EAGOLD_ExcursionWriteRecord(endTime);double finalRealized=EAGOLDAccumulatedProfit()-g_excursionStartRealized;Print("EAGOLD EXCURSION END cycle=",g_excursionCycleId," mfe=",DoubleToString(g_excursionMFE,2)," mae=",DoubleToString(g_excursionMAE,2)," peak=",DoubleToString(g_excursionPeakFloatingPL,2)," realized=",DoubleToString(finalRealized,2)," giveback=",DoubleToString(MathMax(0.0,g_excursionMFE-g_excursionLastFloatingPL),2));EAGOLD_ExcursionTrackerReset();}

#endif
