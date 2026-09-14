#ifndef EAGOLD_R7_KEEPALIVE_MQH
#define EAGOLD_R7_KEEPALIVE_MQH

// R7 Keep-Alive Transaction v1.1
//
// Purpose:
//   Protect the economic action budget when one direction machine disappears
//   while the opposite side of the EAGOLD cycle is still alive.
//
// Safety rule:
//   R7 never recreates a direction while the complete EAGOLD basket is flat.
//   Flat admission remains exclusively owned by R1 atomic admission.
//
// Restart authority:
//   Only this transactional R7 path receives explicit broker authorization
//   for an "EAGOLD R7 RESTART" OrderSend. Legacy lifecycle restart functions
//   may remain for compatibility, but Core execution rejects their restart
//   requests. This removes duplicate restart authorities without changing the
//   proven keep-alive decision itself.

EAGOLD_ActionResult EAGOLD_R7EnsureDirectionTransactional(int direction)
{
   if(CountEAGOLDOrders()==0)
      return(EAGOLD_ACTION_BLOCKED);

   if(CountDirectionPositions(direction)>0)
      return(EAGOLD_ACTION_BLOCKED);

   if(CountDirectionPending(direction)>0)
      return(EAGOLD_ACTION_BLOCKED);

   if(EAGOLD_EntrySuspendedThisTick())
      return(EAGOLD_ACTION_BLOCKED);

   RefreshRates();

   int ticket=-1;
   string side=(direction==OP_BUY?"BUY":"SELL");

   EAGOLD_R7BeginRestartAuthorization();
   if(direction==OP_BUY)
      ticket=SendPending(OP_BUYSTOP,Ask+PointsToPrice(BasketRestartStep),Lot,"EAGOLD R7 RESTART BUY");
   else
      ticket=SendPending(OP_SELLSTOP,Bid-PointsToPrice(BasketRestartStep),Lot,"EAGOLD R7 RESTART SELL");
   EAGOLD_R7EndRestartAuthorization();

   if(ticket<=0)
   {
      Print(EA_NAME," R7 TRANSACTION FAILED: unable to recreate ",side," machine.");
      return(EAGOLD_ACTION_FAILED);
   }

   Print(EA_NAME," R7 TRANSACTION COMPLETE: ",side," machine recreated. STOP ticket=",ticket);
   CreateEngineActionMarker("R7","RESTART",direction,Lot);
   return(EAGOLD_ACTION_COMPLETED);
}

EAGOLD_ActionResult EAGOLD_R7EnsureMissingDirectionTransactional()
{
   if(CountEAGOLDOrders()==0)
      return(EAGOLD_ACTION_BLOCKED);

   EAGOLD_ActionResult buyResult=EAGOLD_R7EnsureDirectionTransactional(OP_BUY);
   if(buyResult!=EAGOLD_ACTION_BLOCKED)
      return(buyResult);

   EAGOLD_ActionResult sellResult=EAGOLD_R7EnsureDirectionTransactional(OP_SELL);
   return(sellResult);
}

#endif
