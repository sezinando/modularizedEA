#ifndef EAGOLD_TRADING_GUARDS_MQH
#define EAGOLD_TRADING_GUARDS_MQH

// Central admission policy for NEW broker orders.
// Existing positions remain manageable: closing, deleting and modifying
// existing orders are intentionally NOT blocked by these entry guards.

bool EAGOLD_TradingWindowOpen()
{
   if(!EnableTradingTimeWindow)
      return(true);

   int start=(TradeStartHour*60)+TradeStartMinute;
   int end=(TradeEndHour*60)+TradeEndMinute;
   int now=(TimeHour(TimeCurrent())*60)+TimeMinute(TimeCurrent());

   // Equal start/end means full-day operation.
   if(start==end)
      return(true);

   if(start<end)
      return(now>=start && now<end);

   // Overnight window, e.g. 22:00 -> 05:00.
   return(now>=start || now<end);
}

bool EAGOLD_SpreadAllowed()
{
   // Existing SpreadLimit is the canonical EAGOLD spread control.
   // <= 0 means no spread restriction.
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

#endif
