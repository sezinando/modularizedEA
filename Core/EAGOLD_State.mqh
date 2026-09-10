#ifndef EAGOLD_STATE_MQH
#define EAGOLD_STATE_MQH

struct EAGOLD_BasketState
{
   double buyLots;
   double sellLots;
   double netSigned;
   double exposure;
   double gross;
   double buyProfit;
   double sellProfit;
   double balance;
   double equity;
   double margin;
   double freeMargin;
   double marginLevel;
};

void EAGOLD_BasketReset(EAGOLD_BasketState &s)
{
   s.buyLots=0.0; s.sellLots=0.0; s.netSigned=0.0; s.exposure=0.0; s.gross=0.0;
   s.buyProfit=0.0; s.sellProfit=0.0;
   s.balance=0.0; s.equity=0.0; s.margin=0.0; s.freeMargin=0.0; s.marginLevel=0.0;
}

#endif
