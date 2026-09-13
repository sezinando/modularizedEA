#ifndef EAGOLD_ADAPTIVE_PROFIT_GUARD_MQH
#define EAGOLD_ADAPTIVE_PROFIT_GUARD_MQH

//==================================================================
// EAGOLD ADAPTIVE PROFIT GUARD v0.1
// Conservative observer/decision layer for incremental realization.
//
// IMPORTANT:
// - This module NEVER increases exposure.
// - It does not replace BRX/R4/R5/R9/R10/R11.
// - Default is OBSERVER ONLY: execution remains disabled until the
//   user explicitly enables the execution flag after validation.
// - Decision inputs are current/past state only; no future MFE/MAE.
//==================================================================

#ifndef EAGOLD_CONFIG_MQH
#include "EAGOLD_Config.mqh"
#endif

extern bool EnableAdaptiveProfitGuard=false;
extern bool EnableAdaptiveProfitGuardExecution=false;
extern double AdaptiveProfitGuardMinEquity=20.0;
extern double AdaptiveProfitGuardMinGivebackPercent=25.0;
extern double AdaptiveProfitGuardMinGrossLots=0.02;
extern double AdaptiveProfitGuardReduceLots=0.01;
extern int AdaptiveProfitGuardCooldownSeconds=60;
extern double AdaptiveProfitGuardMaxDailyLoss=0.0;
extern double AdaptiveProfitGuardMaxCycleDD=0.0;

long g_apgDecisionSequence=0;
datetime g_apgLastDecisionTime=0;

string EAGOLD_AdaptiveProfitGuardExposureLabel()
{
   double buyLots=DirectionLots(OP_BUY);
   double sellLots=DirectionLots(OP_SELL);
   if(buyLots>sellLots)return("BUY");
   if(sellLots>buyLots)return("SELL");
   return("NEUTRAL");
}

double EAGOLD_AdaptiveProfitGuardEquity()
{
   return(g_excursionLastRealized + g_excursionLastFloatingPL);
}

double EAGOLD_AdaptiveProfitGuardGivebackPercent()
{
   double peak=g_excursionPeakFloatingPL;
   double current=g_excursionLastFloatingPL;
   if(peak<=0.0)return(0.0);
   double giveback=peak-current;
   if(giveback<=0.0)return(0.0);
   return((giveback/peak)*100.0);
}

bool EAGOLD_AdaptiveProfitGuardCooldownOK()
{
   if(g_apgLastDecisionTime<=0)return(true);
   return((TimeCurrent()-g_apgLastDecisionTime)>=AdaptiveProfitGuardCooldownSeconds);
}

bool EAGOLD_AdaptiveProfitGuardCandidate(int &ticket,double &lots)
{
   ticket=-1;
   lots=0.0;
   double bestProfit=-DBL_MAX;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(OrderSymbol()!=Symbol())continue;
      if(MagicNumber>=0 && OrderMagicNumber()!=MagicNumber)continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL)continue;
      double orderLots=OrderLots();
      if(orderLots<MathMax(AdaptiveProfitGuardReduceLots,0.01))continue;
      double profit=OrderProfit()+OrderSwap()+OrderCommission();
      if(profit<=0.0)continue;
      if(profit>bestProfit)
      {
         bestProfit=profit;
         ticket=OrderTicket();
         lots=MathMin(AdaptiveProfitGuardReduceLots,orderLots);
      }
   }
   return(ticket>0 && lots>0.0);
}

void EAGOLD_AdaptiveProfitGuardLog(string decision,string reason,int ticket,double lots)
{
   g_apgDecisionSequence++;
   Print("EAGOLD APG: seq=",g_apgDecisionSequence,
         " decision=",decision,
         " reason=",reason,
         " ticket=",ticket,
         " reduce_lots=",DoubleToString(lots,2),
         " equity=",DoubleToString(EAGOLD_AdaptiveProfitGuardEquity(),2),
         " giveback=",DoubleToString(EAGOLD_AdaptiveProfitGuardGivebackPercent(),2),
         " gross=",DoubleToString(DirectionLots(OP_BUY)+DirectionLots(OP_SELL),2),
         " exposure=",EAGOLD_AdaptiveProfitGuardExposureLabel(),
         " r12=",g_r12State.regime);
}

// Returns true only when a real execution was successfully completed.
bool EAGOLD_AdaptiveProfitGuardReduce()
{
   int ticket=-1;
   double lots=0.0;
   if(!EAGOLD_AdaptiveProfitGuardCandidate(ticket,lots))return(false);

   if(!EnableAdaptiveProfitGuardExecution)
   {
      EAGOLD_AdaptiveProfitGuardLog("REDUCE_CANDIDATE","EXECUTION_DISABLED",ticket,lots);
      return(false);
   }

   // Execution hook intentionally remains isolated. R10's transactional
   // implementation is the authoritative reduction path until the APG
   // action adapter is explicitly integrated and runtime-validated.
   EAGOLD_AdaptiveProfitGuardLog("REDUCE_BLOCKED","NO_TRANSACTION_ADAPTER",ticket,lots);
   return(false);
}

void EAGOLD_AdaptiveProfitGuardObserve()
{
   if(!EnableAdaptiveProfitGuard)return;
   double gross=DirectionLots(OP_BUY)+DirectionLots(OP_SELL);
   double equity=EAGOLD_AdaptiveProfitGuardEquity();
   double giveback=EAGOLD_AdaptiveProfitGuardGivebackPercent();

   if(gross<AdaptiveProfitGuardMinGrossLots)return;
   if(equity<AdaptiveProfitGuardMinEquity)return;
   if(giveback<AdaptiveProfitGuardMinGivebackPercent)return;
   if(!EAGOLD_AdaptiveProfitGuardCooldownOK())return;

   int ticket=-1;
   double lots=0.0;
   if(!EAGOLD_AdaptiveProfitGuardCandidate(ticket,lots))return;

   g_apgLastDecisionTime=TimeCurrent();
   EAGOLD_AdaptiveProfitGuardReduce();
}

void EAGOLD_AdaptiveProfitGuardReset()
{
   g_apgDecisionSequence=0;
   g_apgLastDecisionTime=0;
}

#endif
