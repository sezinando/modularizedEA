#ifndef EAGOLD_R10_RECONCILIATION_MQH
#define EAGOLD_R10_RECONCILIATION_MQH

//==================================================================
// R10 RECONCILIATION ENGINE v1.0
//==================================================================
// A PARTIAL broker execution is a state boundary. The next tick must
// first establish a fresh broker-visible census before any new
// economic engine is allowed to act.

string EAGOLD_R10ReconciliationKey()
{
   return("EAGOLD_R10_RECON_"+IntegerToString(AccountNumber())+"_"+Symbol()+"_"+IntegerToString(MagicNumber));
}

bool EAGOLD_R10ReconciliationRequired()
{
   string key=EAGOLD_R10ReconciliationKey();
   if(!GlobalVariableCheck(key))
      return(false);
   return(GlobalVariableGet(key)>0.5);
}

void EAGOLD_R10RequestReconciliation()
{
   string key=EAGOLD_R10ReconciliationKey();
   GlobalVariableSet(key,1.0);
   Print(EA_NAME," R10 RECONCILIATION REQUIRED: broker state must be reconciled before new economic actions.");
}

void EAGOLD_R10ClearReconciliation()
{
   string key=EAGOLD_R10ReconciliationKey();
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

bool EAGOLD_R10BrokerCensusValid()
{
   RefreshRates();

   double buyLots=0.0;
   double sellLots=0.0;
   int buyPositions=0;
   int sellPositions=0;
   int buyPending=0;
   int sellPending=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         return(false);
      if(!IsEAGOLDOrder())
         continue;

      int type=OrderType();
      double lots=OrderLots();
      if(lots<=0.0)
         return(false);

      if(type==OP_BUY)
      {
         buyPositions++;
         buyLots+=lots;
      }
      else if(type==OP_SELL)
      {
         sellPositions++;
         sellLots+=lots;
      }
      else if(type==OP_BUYSTOP)
      {
         buyPending++;
      }
      else if(type==OP_SELLSTOP)
      {
         sellPending++;
      }
   }

   // Re-read the authoritative broker census through the existing order
   // helpers. A mismatch means the account state changed while the census
   // was being built; stay halted and retry on the next tick.
   double helperBuy=DirectionLots(OP_BUY);
   double helperSell=DirectionLots(OP_SELL);

   if(MathAbs(buyLots-helperBuy)>0.00001 || MathAbs(sellLots-helperSell)>0.00001)
      return(false);

   if(buyPositions<0 || sellPositions<0 || buyPending<0 || sellPending<0)
      return(false);

   return(true);
}

bool EAGOLD_R10ReconcileIfRequired()
{
   if(!EAGOLD_R10ReconciliationRequired())
      return(true);

   if(!EAGOLD_R10BrokerCensusValid())
   {
      Print(EA_NAME," R10 RECONCILIATION BLOCKED: broker census invalid/incomplete. Economic engines remain halted.");
      return(false);
   }

   // State is rebuilt from broker-visible orders by the existing order
   // helpers. There is intentionally no synthetic repair of lots or tickets.
   EAGOLD_R10ClearReconciliation();
   Print(EA_NAME," R10 RECONCILIATION COMPLETE: broker state accepted as authoritative. Economic execution released.");
   return(true);
}

#endif
