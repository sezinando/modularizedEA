#ifndef EAGOLD_EXECUTION_MQH
#define EAGOLD_EXECUTION_MQH

// Stage 2: Core execution layer extracted from the proven EAGOLD v0.106 baseline.
// Behavioral logic is intentionally preserved; orchestration remains in EA/EAGOLD.mq4.

int SendPending(int type,double price,double lots,string comment)
{
   if(!EAGOLD_TradingAllowed()){Print(EA_NAME," ORDER BLOCKED: test validity expired on 30/12/2026.");return(-1);}
   RefreshRates();double stopLevel=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point;price=NormalizePrice(price);lots=NormalizeLot(lots);if(type==OP_BUYSTOP&&price<=Ask+stopLevel)return(-1);if(type==OP_SELLSTOP&&price>=Bid-stopLevel)return(-1);ResetLastError();int ticket=OrderSend(Symbol(),type,lots,price,0,0,0,comment,MagicNumber,0,clrNONE);if(ticket<0)Print(EA_NAME," OrderSend failed. type=",type," error=",GetLastError()," comment=",comment);else Print(EA_NAME," pending created. ticket=",ticket," type=",type," price=",DoubleToString(price,Digits)," lot=",DoubleToString(lots,DigitsLots)," comment=",comment);return(ticket);
}

int SendMarket(int type,double lots,string comment)
{
   if(!EAGOLD_TradingAllowed()){Print(EA_NAME," ORDER BLOCKED: test validity expired on 30/12/2026.");return(-1);}
   RefreshRates();lots=NormalizeLot(lots);double price=(type==OP_BUY?Ask:Bid);ResetLastError();int ticket=OrderSend(Symbol(),type,lots,NormalizePrice(price),0,0,0,comment,MagicNumber,0,clrNONE);if(ticket<0)Print(EA_NAME," market send failed. type=",type," error=",GetLastError()," comment=",comment);else Print(EA_NAME," market created. ticket=",ticket," type=",type," lot=",DoubleToString(lots,DigitsLots)," comment=",comment);return(ticket);
}

bool CloseMarketOrder(int ticket){if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))return(false);if(!IsEAGOLDOrder())return(false);int type=OrderType();if(type!=OP_BUY&&type!=OP_SELL)return(false);RefreshRates();double price=(type==OP_BUY?Bid:Ask);ResetLastError();if(!OrderClose(ticket,OrderLots(),NormalizePrice(price),0,clrNONE)){Print(EA_NAME," market close failed. ticket=",ticket," error=",GetLastError());return(false);}return(true);}
bool CloseMarketOrderLots(int ticket,double lots,double &realized){realized=0.0;if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))return(false);if(!IsEAGOLDOrder())return(false);int type=OrderType();if(type!=OP_BUY&&type!=OP_SELL)return(false);double available=OrderLots();double closeLots=NormalizeDouble(MathMin(lots,available),DigitsLots);if(closeLots<Lot)return(false);RefreshRates();double price=(type==OP_BUY?Bid:Ask);ResetLastError();if(!OrderClose(ticket,closeLots,NormalizePrice(price),0,clrNONE)){Print(EA_NAME," partial close failed. ticket=",ticket," lots=",DoubleToString(closeLots,DigitsLots)," error=",GetLastError());return(false);}if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_HISTORY))realized=OrderProfit()+OrderSwap()+OrderCommission();return(true);}
bool DeletePendingOrder(int ticket){if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))return(false);if(!IsEAGOLDOrder())return(false);int type=OrderType();if(type!=OP_BUYSTOP&&type!=OP_SELLSTOP)return(false);ResetLastError();if(!OrderDelete(ticket)){Print(EA_NAME," pending delete failed. ticket=",ticket," error=",GetLastError());return(false);}return(true);}

bool CloseAllDirectionPending(int direction)
{
   int type=(direction==OP_BUY?OP_BUYSTOP:OP_SELLSTOP);
   bool allDeleted=true;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=type)continue;
      if(!DeletePendingOrder(OrderTicket()))
         allDeleted=false;
   }
   if(CountDirectionPending(direction)>0)
      allDeleted=false;
   return(allDeleted);
}

#endif
