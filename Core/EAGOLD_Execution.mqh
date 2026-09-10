#ifndef EAGOLD_EXECUTION_MQH
#define EAGOLD_EXECUTION_MQH

bool EAGOLD_CloseLots(const EAGOLD_Context &ctx,int ticket,double requestedLots,double &realized,int &errorCode)
{
   realized=0.0; errorCode=0;
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) { errorCode=4108; return false; }
   if(!EAGOLD_IsOwnedOrder(ctx)) { errorCode=4108; return false; }
   int type=OrderType();
   if(type!=OP_BUY && type!=OP_SELL) { errorCode=4108; return false; }
   double closeLots=NormalizeDouble(MathMin(requestedLots,OrderLots()),ctx.lotDigits);
   double minLot=MarketInfo(ctx.symbol,MODE_MINLOT);
   if(closeLots<=0.0 || (minLot>0.0 && closeLots<minLot)) { errorCode=131; return false; }
   RefreshRates();
   double price=(type==OP_BUY ? Bid : Ask);
   ResetLastError();
   if(!OrderClose(ticket,closeLots,NormalizeDouble(price,Digits),0,clrNONE))
   {
      errorCode=GetLastError();
      return false;
   }
   realized=OrderProfit()+OrderSwap()+OrderCommission();
   return true;
}

bool EAGOLD_CloseBy(const EAGOLD_Context &ctx,int ticketA,int ticketB,int &errorCode)
{
   errorCode=0;
   if(!OrderSelect(ticketA,SELECT_BY_TICKET,MODE_TRADES)) { errorCode=4108; return false; }
   if(!EAGOLD_IsOwnedOrder(ctx)) { errorCode=4108; return false; }
   int typeA=OrderType();
   if(!OrderSelect(ticketB,SELECT_BY_TICKET,MODE_TRADES)) { errorCode=4108; return false; }
   if(!EAGOLD_IsOwnedOrder(ctx)) { errorCode=4108; return false; }
   int typeB=OrderType();
   if(typeA==typeB || (typeA!=OP_BUY && typeA!=OP_SELL) || (typeB!=OP_BUY && typeB!=OP_SELL)) { errorCode=4108; return false; }
   ResetLastError();
   if(!OrderCloseBy(ticketA,ticketB,clrNONE))
   {
      errorCode=GetLastError();
      return false;
   }
   return true;
}

#endif
