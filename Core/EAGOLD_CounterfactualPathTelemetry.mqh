#ifndef EAGOLD_COUNTERFACTUAL_PATH_TELEMETRY_MQH
#define EAGOLD_COUNTERFACTUAL_PATH_TELEMETRY_MQH

// EAGOLD COUNTERFACTUAL PATH TELEMETRY v1.2
// Observer-only, ticket-level, path-preserving telemetry for future
// counterfactual Partial / BE / Runner / Basket-Trailing research.
// MUST NOT submit, modify or close orders.
// v1.2 reduces tester I/O by sampling the path at a configurable interval,
// forcing writes on structural state changes, keeping the file handle open,
// and flushing periodically instead of on every tick.

long g_cfPathSequence=0;
long g_cfPathRowsWritten=0;
bool g_cfPathFileDiagnosticLogged=false;
int g_cfPathFileHandle=INVALID_HANDLE;
datetime g_cfPathLastWriteTime=0;
long g_cfPathLastEngineActionSequence=-1;
long g_cfPathLastEventSequence=-1;
int g_cfPathLastBuyCount=-1;
int g_cfPathLastSellCount=-1;
double g_cfPathLastBuyLots=-1.0;
double g_cfPathLastSellLots=-1.0;
int g_cfPathLastRegime=-1;
int g_cfPathWritesSinceFlush=0;

void EAGOLD_CounterfactualPathHeader(int handle)
{
   if(FileSize(handle)>0)return;
   FileWrite(handle,
      "PATH_SEQ","TIMESTAMP","PHASE","CYCLE_ID","CYCLE_ACTIVE",
      "EVENT_SEQ","ENGINE_ACTION_SEQ",
      "TICKET","TYPE","LOTS","OPEN_PRICE","CURRENT_PRICE",
      "STOP_LOSS","TAKE_PROFIT","TICKET_FLOATING_PL","TICKET_SWAP","TICKET_COMMISSION",
      "BASKET_FLOATING_PL","BUY_FLOATING_PL","SELL_FLOATING_PL",
      "BUY_LOTS","SELL_LOTS","GROSS_LOTS","NET_LOTS",
      "REALIZED_CYCLE_PL","REALIZED_TOTAL_PL",
      "CYCLE_MFE","CYCLE_MAE","CYCLE_PEAK_FLOATING_PL",
      "INTERVAL_MFE","INTERVAL_MAE","INTERVAL_PEAK_FLOATING_PL",
      "R12_VALID","R12_REGIME","R12_PREVIOUS_REGIME",
      "R12_REGIME_CHANGE","R12_REGIME_DURATION_SEC","R12_TIME_SINCE_REGIME_CHANGE_SEC",
      "R12_TRANSITIONS","R12_SEQUENCE_COUNT","R12_REGIME_SEQUENCE",
      "R12_EVENT_TRANSITIONS","R12_EVENT_SEQUENCE_COUNT","R12_EVENT_START_TIME",
      "R12_EVENT_LAST_CHANGE_TIME","R12_EVENT_DURATION_SEC","R12_EVENT_REGIME_SEQUENCE",
      "BID","ASK");
}

int EAGOLD_CounterfactualPathOpenFile()
{
   if(g_cfPathFileHandle!=INVALID_HANDLE)return(g_cfPathFileHandle);

   ResetLastError();
   g_cfPathFileHandle=FileOpen("EAGOLD_COUNTERFACTUAL_PATH.csv",FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,';');
   int error=GetLastError();
   if(g_cfPathFileHandle==INVALID_HANDLE)
   {
      Print("EAGOLD CF PATH: FileOpen FAILED error=",error,
            " tester=",(IsTesting()?"1":"0"),
            " data_path=",TerminalInfoString(TERMINAL_DATA_PATH),
            " common_path=",TerminalInfoString(TERMINAL_COMMONDATA_PATH));
      return(INVALID_HANDLE);
   }

   FileSeek(g_cfPathFileHandle,0,SEEK_END);
   EAGOLD_CounterfactualPathHeader(g_cfPathFileHandle);

   if(!g_cfPathFileDiagnosticLogged)
   {
      g_cfPathFileDiagnosticLogged=true;
      Print("EAGOLD CF PATH: FileOpen OK file=EAGOLD_COUNTERFACTUAL_PATH.csv",
            " tester=",(IsTesting()?"1":"0"),
            " data_path=",TerminalInfoString(TERMINAL_DATA_PATH),
            " common_path=",TerminalInfoString(TERMINAL_COMMONDATA_PATH),
            " size_bytes=",FileSize(g_cfPathFileHandle),
            " rows_written=",g_cfPathRowsWritten,
            " sample_seconds=",CounterfactualPathSampleSeconds);
   }
   return(g_cfPathFileHandle);
}

void EAGOLD_CounterfactualPathCloseFile()
{
   if(g_cfPathFileHandle==INVALID_HANDLE)return;
   FileFlush(g_cfPathFileHandle);
   FileClose(g_cfPathFileHandle);
   g_cfPathFileHandle=INVALID_HANDLE;
}

string EAGOLD_CounterfactualPathTypeName(int type)
{
   if(type==OP_BUY)return("BUY");
   if(type==OP_SELL)return("SELL");
   return("OTHER");
}

bool EAGOLD_CounterfactualPathStateChanged(int buyCount,int sellCount,double buyLots,double sellLots,int regime,long eventSeq,long engineActionSeq)
{
   if(g_cfPathLastBuyCount<0)return(true);
   if(buyCount!=g_cfPathLastBuyCount||sellCount!=g_cfPathLastSellCount)return(true);
   if(MathAbs(buyLots-g_cfPathLastBuyLots)>0.0000001||MathAbs(sellLots-g_cfPathLastSellLots)>0.0000001)return(true);
   if(regime!=g_cfPathLastRegime)return(true);
   if(eventSeq!=g_cfPathLastEventSequence)return(true);
   if(engineActionSeq!=g_cfPathLastEngineActionSequence)return(true);
   return(false);
}

bool EAGOLD_CounterfactualPathShouldWrite(string phase,int buyCount,int sellCount,double buyLots,double sellLots,int regime,long eventSeq,long engineActionSeq)
{
   if(phase=="INIT")return(true);
   if(EAGOLD_CounterfactualPathStateChanged(buyCount,sellCount,buyLots,sellLots,regime,eventSeq,engineActionSeq))return(true);

   int sampleSeconds=CounterfactualPathSampleSeconds;
   if(sampleSeconds<1)sampleSeconds=1;
   datetime now=TimeCurrent();
   if(g_cfPathLastWriteTime==0)return(true);
   if((long)(now-g_cfPathLastWriteTime)>=sampleSeconds)return(true);
   return(false);
}

void EAGOLD_CounterfactualPathWrite(string phase)
{
   if(!EnableCounterfactualPathTelemetry)return;

   int handle=EAGOLD_CounterfactualPathOpenFile();
   if(handle==INVALID_HANDLE)return;

   int buyCount=CountDirectionPositions(OP_BUY);
   int sellCount=CountDirectionPositions(OP_SELL);
   if(buyCount+sellCount<=0)
   {
      // Keep INIT/flat creation lightweight; a terminal flat transition is
      // represented by the last populated POST_ACTION row and event ledger.
      return;
   }

   RefreshRates();
   double buyLots=DirectionLots(OP_BUY),sellLots=DirectionLots(OP_SELL);
   double grossLots=buyLots+sellLots,netLots=MathAbs(buyLots-sellLots);
   double buyPL=DirectionBasketProfit(OP_BUY),sellPL=DirectionBasketProfit(OP_SELL),basketPL=buyPL+sellPL;
   double realizedTotal=EAGOLDAccumulatedProfit();
   double realizedCycle=(g_excursionActive?realizedTotal-g_excursionStartRealized:0.0);
   string cycleId=(g_excursionActive?g_excursionCycleId:"");
   string cycleActive=(g_excursionActive?"1":"0");
   long eventSeq=(g_excursionActive?g_excursionRealizationSequence:0);
   long engineActionSeq=(long)g_excursionSequence;
   int regime=(g_r12State.valid?g_r12State.regime:-1);

   if(!EAGOLD_CounterfactualPathShouldWrite(phase,buyCount,sellCount,buyLots,sellLots,regime,eventSeq,engineActionSeq))
      return;

   string r12Valid=(g_r12State.valid?"1":"0");
   string r12Regime=(g_r12State.valid?EAGOLD_R12_RegimeName(g_r12State.regime):"UNKNOWN");
   string r12Previous=(g_r12State.valid?EAGOLD_R12_RegimeName(g_r12State.previousRegime):"UNKNOWN");
   string r12Change=(g_r12State.valid&&g_r12State.regimeChange?"1":"0");
   string r12Sequence=(g_r12State.valid?g_r12State.regimeSequence:"");
   string r12EventSequence=(g_r12State.valid?g_r12State.eventBoundaryRegimeSequence:"");
   string r12EventStart=(g_r12State.valid?TimeToString(g_r12State.eventBoundaryStartTime,TIME_DATE|TIME_SECONDS):"");
   string r12EventChange=(g_r12State.valid?TimeToString(g_r12State.eventBoundaryLastChangeTime,TIME_DATE|TIME_SECONDS):"");

   int rowsThisWrite=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder())continue;
      int type=OrderType();
      if(type!=OP_BUY&&type!=OP_SELL)continue;

      g_cfPathSequence++;
      double currentPrice=(type==OP_BUY?Bid:Ask);
      double ticketPL=OrderProfit()+OrderSwap()+OrderCommission();
      FileWrite(handle,
         IntegerToString((int)g_cfPathSequence),TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),phase,cycleId,cycleActive,
         IntegerToString((int)eventSeq),IntegerToString((int)engineActionSeq),
         IntegerToString(OrderTicket()),EAGOLD_CounterfactualPathTypeName(type),DoubleToString(OrderLots(),DigitsLots),
         DoubleToString(OrderOpenPrice(),Digits),DoubleToString(currentPrice,Digits),
         DoubleToString(OrderStopLoss(),Digits),DoubleToString(OrderTakeProfit(),Digits),
         DoubleToString(ticketPL,2),DoubleToString(OrderSwap(),2),DoubleToString(OrderCommission(),2),
         DoubleToString(basketPL,2),DoubleToString(buyPL,2),DoubleToString(sellPL,2),
         DoubleToString(buyLots,DigitsLots),DoubleToString(sellLots,DigitsLots),DoubleToString(grossLots,DigitsLots),DoubleToString(netLots,DigitsLots),
         DoubleToString(realizedCycle,2),DoubleToString(realizedTotal,2),
         DoubleToString(g_excursionMFE,2),DoubleToString(g_excursionMAE,2),DoubleToString(g_excursionPeakFloatingPL,2),
         DoubleToString(g_excursionIntervalMFE,2),DoubleToString(g_excursionIntervalMAE,2),DoubleToString(g_excursionIntervalPeakFloatingPL,2),
         r12Valid,r12Regime,r12Previous,r12Change,DoubleToString(g_r12State.regimeDurationSec,0),DoubleToString(g_r12State.timeSinceRegimeChangeSec,0),
         IntegerToString(g_r12State.regimeTransitionCount),IntegerToString(g_r12State.regimeSequenceCount),r12Sequence,
         IntegerToString(g_r12State.eventBoundaryTransitionCount),IntegerToString(g_r12State.eventBoundarySequenceCount),r12EventStart,
         r12EventChange,DoubleToString(g_r12State.eventBoundaryDurationSec,0),r12EventSequence,
         DoubleToString(Bid,Digits),DoubleToString(Ask,Digits));
      g_cfPathRowsWritten++;
      rowsThisWrite++;
   }

   if(rowsThisWrite>0)
   {
      g_cfPathLastWriteTime=TimeCurrent();
      g_cfPathLastEngineActionSequence=engineActionSeq;
      g_cfPathLastEventSequence=eventSeq;
      g_cfPathLastBuyCount=buyCount;
      g_cfPathLastSellCount=sellCount;
      g_cfPathLastBuyLots=buyLots;
      g_cfPathLastSellLots=sellLots;
      g_cfPathLastRegime=regime;
      g_cfPathWritesSinceFlush++;

      if(g_cfPathWritesSinceFlush>=50)
      {
         FileFlush(handle);
         g_cfPathWritesSinceFlush=0;
      }

      if(g_cfPathRowsWritten==rowsThisWrite || (g_cfPathRowsWritten%1000)<rowsThisWrite)
         Print("EAGOLD CF PATH: rows_written=",g_cfPathRowsWritten," size_bytes=",FileSize(handle)," sample_seconds=",CounterfactualPathSampleSeconds);
   }
}

void EAGOLD_CounterfactualPathReset()
{
   EAGOLD_CounterfactualPathCloseFile();
   g_cfPathSequence=0;
   g_cfPathRowsWritten=0;
   g_cfPathFileDiagnosticLogged=false;
   g_cfPathFileHandle=INVALID_HANDLE;
   g_cfPathLastWriteTime=0;
   g_cfPathLastEngineActionSequence=-1;
   g_cfPathLastEventSequence=-1;
   g_cfPathLastBuyCount=-1;
   g_cfPathLastSellCount=-1;
   g_cfPathLastBuyLots=-1.0;
   g_cfPathLastSellLots=-1.0;
   g_cfPathLastRegime=-1;
   g_cfPathWritesSinceFlush=0;
}

#endif
