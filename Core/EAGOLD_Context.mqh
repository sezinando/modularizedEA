#ifndef EAGOLD_CONTEXT_MQH
#define EAGOLD_CONTEXT_MQH

struct EAGOLD_Context
{
   string symbol;
   int    magic;
   double lot;
   int    lotDigits;
   double minExposureLots;
   double pairMaxLots;
   double pairMinProfit;
   int    pairCooldownSeconds;
   bool   enableR10;
   bool   enableR10Pair;
};

void EAGOLD_ContextInit(EAGOLD_Context &ctx,
                        string symbol,
                        int magic,
                        double lot,
                        int lotDigits,
                        double minExposureLots,
                        double pairMaxLots,
                        double pairMinProfit,
                        int pairCooldownSeconds,
                        bool enableR10,
                        bool enableR10Pair)
{
   ctx.symbol=symbol;
   ctx.magic=magic;
   ctx.lot=lot;
   ctx.lotDigits=lotDigits;
   ctx.minExposureLots=minExposureLots;
   ctx.pairMaxLots=pairMaxLots;
   ctx.pairMinProfit=pairMinProfit;
   ctx.pairCooldownSeconds=pairCooldownSeconds;
   ctx.enableR10=enableR10;
   ctx.enableR10Pair=enableR10Pair;
}

double EAGOLD_NormalizeLot(const EAGOLD_Context &ctx,double lots)
{
   double minLot=MarketInfo(ctx.symbol,MODE_MINLOT);
   double maxLot=MarketInfo(ctx.symbol,MODE_MAXLOT);
   double step=MarketInfo(ctx.symbol,MODE_LOTSTEP);
   if(step>0.0)
      lots=minLot+MathFloor((lots-minLot)/step+0.0000001)*step;
   if(minLot>0.0 && lots<minLot) lots=minLot;
   if(maxLot>0.0 && lots>maxLot) lots=maxLot;
   return NormalizeDouble(lots,ctx.lotDigits);
}

bool EAGOLD_IsOwnedOrder(const EAGOLD_Context &ctx)
{
   return(OrderSymbol()==ctx.symbol && OrderMagicNumber()==ctx.magic);
}

#endif
