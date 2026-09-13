#ifndef EAGOLD_TRADING_GUARDS_MQH
#define EAGOLD_TRADING_GUARDS_MQH

// Central admission policy for NEW broker orders.
// Existing market positions remain manageable. Pending orders are removed when
// entry conditions are closed, because a pending order can otherwise be
// activated by the broker without a new OrderSend() from the EA.

bool EAGOLD_TradingWindowOpen()
{
   if(!EnableTradingTimeWindow)
      return(true);

   int start=(TradeStartHour*60)+TradeStartMinute;
   int end=(TradeEndHour*60)+TradeEndMinute;
   int now=(TimeHour(TimeCurrent())*60)+TimeMinute(TimeCurrent());

   if(start==end)
      return(true);

   if(start<end)
      return(now>=start && now<end);

   return(now>=start || now<end);
}

bool EAGOLD_SpreadAllowed()
{
   if(SpreadLimit<=0)
      return(true);

   RefreshRates();
   double spreadPoints=(Ask-Bid)/Point;
   if(spreadPoints<=SpreadLimit)
      return(true);

   Print(EA_NAME,
         " ENTRY BLOCKED: spread=",DoubleToString(spreadPoints,1),
         " points > SpreadLimit=",IntegerToString(SpreadLimit));
   return(false);
}

bool EAGOLD_NewOrderAdmissionAllowed()
{
   if(!EAGOLD_TradingAllowed())
      return(false);

   if(!EAGOLD_TradingWindowOpen())
   {
      Print(EA_NAME,
            " ENTRY BLOCKED: outside trading window. Start=",
            IntegerToString(TradeStartHour),":",
            StringFormat("%02d",TradeStartMinute),
            " End=",IntegerToString(TradeEndHour),":",
            StringFormat("%02d",TradeEndMinute));
      return(false);
   }

   return(EAGOLD_SpreadAllowed());
}

// A pending order is a broker-side future entry. If the spread or trading
// window becomes invalid after the pending was created, leaving it alive can
// still create a NEW market position. Remove only EAGOLD-recognized pending
// orders; market positions are never touched here.
int EAGOLD_SuspendInvalidPendingEntries()
{
   bool windowOpen=EAGOLD_TradingWindowOpen();
   bool spreadOpen=EAGOLD_SpreadAllowed();
   if(windowOpen && spreadOpen)
      return(0);

   int deleted=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder())continue;
      int type=OrderType();
      if(type!=OP_BUYSTOP&&type!=OP_SELLSTOP)continue;
      int ticket=OrderTicket();
      ResetLastError();
      if(OrderDelete(ticket))
      {
         deleted++;
         Print(EA_NAME," ENTRY SUSPENDED: pending ticket=",ticket,
               " removed because entry conditions are closed.");
      }
      else
      {
         Print(EA_NAME," ENTRY SUSPEND FAILED: pending ticket=",ticket,
               " error=",GetLastError());
      }
   }
   return(deleted);
}

#endif
