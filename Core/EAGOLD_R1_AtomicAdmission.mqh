#ifndef EAGOLD_R1_ATOMIC_ADMISSION_MQH
#define EAGOLD_R1_ATOMIC_ADMISSION_MQH

// R1 atomic first-seed transaction.
// A flat EAGOLD basket must end the admission attempt with either BOTH
// directional seed pendings present or NONE. A one-sided seed is never
// accepted as a successful first cycle.

EAGOLD_ActionResult EAGOLD_CreateFirstOrdersAtomic()
{
   if(CountEAGOLDOrders()>0)
      return(EAGOLD_ACTION_BLOCKED);

   RefreshRates();
   double buyPrice=NormalizePrice(Ask+PointsToPrice(FirstStep));
   double sellPrice=NormalizePrice(Bid-PointsToPrice(FirstStep));

   if(EnableR1AdmissionGate)
   {
      string buyReason="PASS",sellReason="PASS";
      bool buyAllowed=R1AdmissionAllowed(OP_BUY,Lot,buyPrice,buyReason);
      bool sellAllowed=R1AdmissionAllowed(OP_SELL,Lot,sellPrice,sellReason);
      if(!buyAllowed||!sellAllowed)
      {
         string reason=(!buyAllowed?"BUY_":"SELL_");
         reason+=(!buyAllowed?buyReason:sellReason);
         R1Decision("BLOCK",reason);
         Print(EA_NAME," RULE 1: FIRST cycle blocked atomically. BUY=",buyReason," SELL=",sellReason);
         CreateEngineActionMarker("R1.1","BLOCK",OP_BUY,Lot);
         CreateEngineActionMarker("R1.1","BLOCK",OP_SELL,Lot);
         return(EAGOLD_ACTION_BLOCKED);
      }
   }

   int buyTicket=SendPending(OP_BUYSTOP,buyPrice,Lot,"EAGOLD R1 FIRST BUY");
   if(buyTicket<=0)
   {
      Print(EA_NAME," RULE 1 ATOMIC: BUY seed failed. First cycle remains flat.");
      return(EAGOLD_ACTION_FAILED);
   }

   int sellTicket=SendPending(OP_SELLSTOP,sellPrice,Lot,"EAGOLD R1 FIRST SELL");
   if(sellTicket<=0)
   {
      bool rollbackOk=DeletePendingOrder(buyTicket);
      Print(EA_NAME," RULE 1 ATOMIC: SELL seed failed. BUY rollback=",(rollbackOk?"OK":"FAILED"));
      if(rollbackOk&&CountDirectionPending(OP_BUY)==0&&CountDirectionPending(OP_SELL)==0)
         return(EAGOLD_ACTION_FAILED);
      EAGOLD_R10RequestReconciliation();
      return(EAGOLD_ACTION_PARTIAL);
   }

   bool bothPresent=(CountDirectionPending(OP_BUY)>0&&CountDirectionPending(OP_SELL)>0);
   if(!bothPresent)
   {
      bool buyRollback=(CountDirectionPending(OP_BUY)==0);
      bool sellRollback=(CountDirectionPending(OP_SELL)==0);
      if(!buyRollback)
      {
         if(OrderSelect(buyTicket,SELECT_BY_TICKET,MODE_TRADES))
            buyRollback=DeletePendingOrder(buyTicket);
      }
      if(!sellRollback)
      {
         if(OrderSelect(sellTicket,SELECT_BY_TICKET,MODE_TRADES))
            sellRollback=DeletePendingOrder(sellTicket);
      }
      Print(EA_NAME," RULE 1 ATOMIC: post-send verification failed. rollback BUY=",(buyRollback?"OK":"FAILED")," SELL=",(sellRollback?"OK":"FAILED"));
      if(CountDirectionPending(OP_BUY)==0&&CountDirectionPending(OP_SELL)==0)
         return(EAGOLD_ACTION_FAILED);
      EAGOLD_R10RequestReconciliation();
      return(EAGOLD_ACTION_PARTIAL);
   }

   Print(EA_NAME," RULE 1 ATOMIC: initial seeds created. BUY=",buyTicket," SELL=",sellTicket);
   CreateEngineActionMarker("R1","SEED",OP_BUY,Lot);
   CreateEngineActionMarker("R1","SEED",OP_SELL,Lot);
   return(EAGOLD_ACTION_COMPLETED);
}

#endif
