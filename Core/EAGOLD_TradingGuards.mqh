#ifndef EAGOLD_TRADING_GUARDS_MQH
#define EAGOLD_TRADING_GUARDS_MQH

// Central admission policy for NEW broker orders.
// Closing, deleting and modifying existing orders remain allowed so an active
// basket can finish even when the entry window has ended or spread is high.

bool EAGOLD_TradingWindowOpen()
{
   if(!EnableTradingTimeWindow)
      return(true);

   int start=(TradeStartHour*60)+TradeStartMinute;
   int end=(TradeEndHour*60)+TradeEndMinute;
   int now=(TimeHour(TimeCurrent())*60)+TimeMinute(TimeCurrent());

   // Equal start/end means a full-day window. This avoids an accidental
   // zero-minute window when both inputs are left at 00:00.
   if(start==end)
      return(true);

   // Normal intraday window, e.g. 09:00 -> 17:00.
   if(start<end)
      return(now>=start && now<end);

   // Overnight window, e.g. 22:00 -> 05:00.
   return(now>=start || now<end);
}

bool EAGOLD_SpreadAllowed()
{
   if(!EnableSpreadFilter)
      return(true);

   RefreshRates();
   double spreadPoints=(Ask-Bid)/Point;
   if(spreadPoints<=MaxSpreadPoints)
      return(true);

   Print(EA_NAME,
         " ENTRY BLOCKED: spread=",DoubleToString(spreadPoints,1),
         " points > MaxSpreadPoints=",DoubleToString(MaxSpreadPoints,1));
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
