#ifndef EAGOLD_ADAPTIVE_PROFIT_GUARD_MQH
#define EAGOLD_ADAPTIVE_PROFIT_GUARD_MQH

// EAGOLD ADAPTIVE PROFIT GUARD v0.1
// Conservative observer-only decision layer for causal backtest.
// Execution remains blocked until a transactional adapter is validated.

long g_apgDecisionSequence=0;
datetime g_apgLastDecisionTime=0;
string g_apgLastDecision="NONE";
string g_apgLastReason="";
int g_apgCandidateTicket=-1;
double g_apgCandidateLots=0.0;
double g_apgEquityPeak=0.0;
bool g_apgTriggerLatched=false;

string EAGOLD_AdaptiveProfitGuardExposureLabel()
{
   double buyLots=DirectionLots(OP_BUY),sellLots=DirectionLots(OP_SELL);
   if(buyLots>sellLots)return("BUY");
   if(sellLots>buyLots)return("SELL");
   return("NEUTRAL");
}

double EAGOLD_AdaptiveProfitGuardEquity()
{
   double realizedCycle=EAGOLDAccumulatedProfit()-g_excursionStartRealized;
   return(realizedCycle+g_excursionLastFloatingPL);
}

double EAGOLD_AdaptiveProfitGuardGivebackPercent()
{
   double equity=EAGOLD_AdaptiveProfitGuardEquity();
   if(g_apgEquityPeak<=0.0)return(0.0);
   double giveback=g_apgEquityPeak-equity;
   if(giveback<=0.0)return(0.0);
   return((giveback/g_apgEquityPeak)*100.0);
}

bool EAGOLD_AdaptiveProfitGuardCooldownOK()
{
   if(g_apgLastDecisionTime<=0)return(true);
   return((TimeCurrent()-g_apgLastDecisionTime)>=AdaptiveProfitGuardCooldownSeconds);
}

bool EAGOLD_AdaptiveProfitGuardCandidate(int &ticket,double &lots)
{
   ticket=-1; lots=0.0; double bestProfit=-DBL_MAX;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder())continue;
      int type=OrderType(); if(type!=OP_BUY&&type!=OP_SELL)continue;
      double orderLots=OrderLots();
      if(orderLots<MathMax(AdaptiveProfitGuardReduceLots,0.01))continue;
      double profit=OrderProfit()+OrderSwap()+OrderCommission();
      if(profit<=0.0||profit<=bestProfit)continue;
      bestProfit=profit; ticket=OrderTicket(); lots=MathMin(AdaptiveProfitGuardReduceLots,orderLots);
   }
   return(ticket>0&&lots>0.0);
}

void EAGOLD_AdaptiveProfitGuardLog(string decision,string reason,int ticket,double lots)
{
   g_apgDecisionSequence++; g_apgLastDecision=decision; g_apgLastReason=reason;
   g_apgCandidateTicket=ticket; g_apgCandidateLots=lots;
   Print("EAGOLD APG: seq=",g_apgDecisionSequence," decision=",decision," reason=",reason,
         " ticket=",ticket," reduce_lots=",DoubleToString(lots,2),
         " equity=",DoubleToString(EAGOLD_AdaptiveProfitGuardEquity(),2),
         " equity_peak=",DoubleToString(g_apgEquityPeak,2),
         " giveback=",DoubleToString(EAGOLD_AdaptiveProfitGuardGivebackPercent(),2),
         " gross=",DoubleToString(DirectionLots(OP_BUY)+DirectionLots(OP_SELL),2),
         " exposure=",EAGOLD_AdaptiveProfitGuardExposureLabel()," r12=",g_r12State.regime);
}

void EAGOLD_AdaptiveProfitGuardObserve()
{
   if(!EnableAdaptiveProfitGuard)
   {
      g_apgLastDecision="DISABLED"; g_apgLastReason="GUARD_DISABLED"; g_apgCandidateTicket=-1; g_apgCandidateLots=0.0; return;
   }

   double gross=DirectionLots(OP_BUY)+DirectionLots(OP_SELL);
   if(gross<=0.0)
   {
      g_apgEquityPeak=0.0; g_apgTriggerLatched=false; g_apgLastDecision="HOLD"; g_apgLastReason="FLAT"; g_apgCandidateTicket=-1; g_apgCandidateLots=0.0; return;
   }

   double equity=EAGOLD_AdaptiveProfitGuardEquity();
   if(equity>g_apgEquityPeak)g_apgEquityPeak=equity;
   double giveback=EAGOLD_AdaptiveProfitGuardGivebackPercent();

   g_apgLastDecision="HOLD"; g_apgLastReason="NO_TRIGGER"; g_apgCandidateTicket=-1; g_apgCandidateLots=0.0;

   if(giveback<AdaptiveProfitGuardMinGivebackPercent)g_apgTriggerLatched=false;
   if(gross<AdaptiveProfitGuardMinGrossLots){g_apgLastReason="GROSS_BELOW_MIN";return;}
   if(equity<AdaptiveProfitGuardMinEquity){g_apgLastReason="EQUITY_BELOW_MIN";return;}
   if(giveback<AdaptiveProfitGuardMinGivebackPercent){g_apgLastReason="GIVEBACK_BELOW_MIN";return;}
   if(g_apgTriggerLatched){g_apgLastReason="TRIGGER_LATCHED";return;}
   if(!EAGOLD_AdaptiveProfitGuardCooldownOK()){g_apgLastReason="COOLDOWN";return;}

   int ticket=-1; double lots=0.0;
   if(!EAGOLD_AdaptiveProfitGuardCandidate(ticket,lots)){g_apgLastReason="NO_PROFITABLE_TICKET";return;}
   g_apgLastDecisionTime=TimeCurrent();
   g_apgTriggerLatched=true;
   EAGOLD_AdaptiveProfitGuardLog("REDUCE_CANDIDATE","CAUSAL_GIVEBACK_TRIGGER",ticket,lots);
}

void EAGOLD_AdaptiveProfitGuardReset()
{
   g_apgDecisionSequence=0; g_apgLastDecisionTime=0; g_apgLastDecision="NONE"; g_apgLastReason="";
   g_apgCandidateTicket=-1; g_apgCandidateLots=0.0; g_apgEquityPeak=0.0; g_apgTriggerLatched=false;
}

#endif
