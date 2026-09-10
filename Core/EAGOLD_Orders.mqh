#ifndef EAGOLD_ORDERS_MQH
#define EAGOLD_ORDERS_MQH

void EAGOLD_MeasureBasket(const EAGOLD_Context &ctx,EAGOLD_BasketState &s)
{
   EAGOLD_BasketReset(s);
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!EAGOLD_IsOwnedOrder(ctx)) continue;
      int type=OrderType();
      if(type==OP_BUY)
      {
         s.buyLots+=OrderLots();
         s.buyProfit+=OrderProfit()+OrderSwap()+OrderCommission();
      }
      else if(type==OP_SELL)
      {
         s.sellLots+=OrderLots();
         s.sellProfit+=OrderProfit()+OrderSwap()+OrderCommission();
      }
   }
   s.netSigned=s.buyLots-s.sellLots;
   s.exposure=MathAbs(s.netSigned);
   s.gross=s.buyLots+s.sellLots;
   s.balance=AccountBalance();
   s.equity=AccountEquity();
   s.margin=AccountMargin();
   s.freeMargin=AccountFreeMargin();
   s.marginLevel=(s.margin>0.0 ? (s.equity/s.margin)*100.0 : 0.0);
}

int EAGOLD_CountDirection(const EAGOLD_Context &ctx,int type)
{
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!EAGOLD_IsOwnedOrder(ctx)) continue;
      if(OrderType()==type) count++;
   }
   return count;
}

bool EAGOLD_FindLargestTicket(const EAGOLD_Context &ctx,int type,int &ticket,double &lots)
{
   ticket=-1; lots=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(!EAGOLD_IsOwnedOrder(ctx) || OrderType()!=type) continue;
      if(OrderLots()>lots || (MathAbs(OrderLots()-lots)<0.0000001 && OrderTicket()<ticket))
      {
         ticket=OrderTicket(); lots=OrderLots();
      }
   }
   return(ticket>0 && lots>0.0);
}

#endif
