#ifndef R10_CORE_MQH
#define R10_CORE_MQH

// R10 is a reduction-only engine. It may close existing exposure but must
// never create a new position or mutate R10.2/R11 state.
struct R10_Candidate
{
   string actionType;
   int heavyTicket;
   int lightTicket;
   int heavyType;
   int lightType;
   double reduceLots;
   double beforeBuyLots;
   double beforeSellLots;
   double beforeExposure;
   double beforeGross;
   double pairProfit;
   double afterBuyLots;
   double afterSellLots;
   double afterExposure;
   double afterGross;
   bool hardConstraintsPass;
};

string R10_ActionId()
{
   return StringFormat("R10-%d-%d",(int)TimeCurrent(),GetTickCount());
}

bool R10_IsBrokerValidLots(const EAGOLD_Context &ctx,double lots)
{
   double minLot=MarketInfo(ctx.symbol,MODE_MINLOT);
   double maxLot=MarketInfo(ctx.symbol,MODE_MAXLOT);
   double step=MarketInfo(ctx.symbol,MODE_LOTSTEP);
   if(lots<=0.0) return false;
   if(minLot>0.0 && lots<minLot-0.0000001) return false;
   if(maxLot>0.0 && lots>maxLot+0.0000001) return false;
   if(step>0.0)
   {
      double units=lots/step;
      if(MathAbs(units-MathRound(units))>0.0000001) return false;
   }
   return true;
}

bool R10_ReadTicketProfit(const EAGOLD_Context &ctx,int ticket,double &profit,double &lots)
{
   profit=0.0; lots=0.0;
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES)) return false;
   if(!EAGOLD_IsOwnedOrder(ctx)) return false;
   if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) return false;
   lots=OrderLots();
   profit=OrderProfit()+OrderSwap()+OrderCommission();
   return(lots>0.0);
}

bool R10_SimulatePair(const EAGOLD_Context &ctx,const EAGOLD_BasketState &before,
                      int heavyTicket,int lightTicket,int heavyType,int lightType,
                      double reduceLots,R10_Candidate &c)
{
   c.actionType="R10_PAIR";
   c.heavyTicket=heavyTicket; c.lightTicket=lightTicket;
   c.heavyType=heavyType; c.lightType=lightType;
   c.reduceLots=EAGOLD_NormalizeLot(ctx,reduceLots);
   c.beforeBuyLots=before.buyLots;
   c.beforeSellLots=before.sellLots;
   c.beforeExposure=before.exposure;
   c.beforeGross=before.gross;
   c.pairProfit=0.0;
   c.afterBuyLots=before.buyLots;
   c.afterSellLots=before.sellLots;
   c.afterExposure=before.exposure;
   c.afterGross=before.gross;
   c.hardConstraintsPass=false;

   double heavyProfit=0.0,heavyLots=0.0;
   double lightProfit=0.0,lightLots=0.0;
   if(!R10_ReadTicketProfit(ctx,heavyTicket,heavyProfit,heavyLots)) return false;
   if(!R10_ReadTicketProfit(ctx,lightTicket,lightProfit,lightLots)) return false;
   if(heavyType==lightType) return false;
   if(heavyType!=OP_BUY && heavyType!=OP_SELL) return false;
   if(lightType!=OP_BUY && lightType!=OP_SELL) return false;

   if(c.reduceLots<=0.0) return false;
   if(c.reduceLots>heavyLots+0.0000001 || c.reduceLots>lightLots+0.0000001) return false;
   if(!R10_IsBrokerValidLots(ctx,c.reduceLots)) return false;
   if(ctx.pairMaxLots>0.0 && c.reduceLots>ctx.pairMaxLots+0.0000001) return false;

   c.pairProfit=heavyProfit+lightProfit;
   if(ctx.pairMinProfit>0.0 && c.pairProfit<ctx.pairMinProfit-0.0000001) return false;

   // Formal balanced-pair simulation: both legs are reduced by the same
   // amount. Exposure is the absolute difference between remaining sides.
   if(heavyType==OP_BUY)
   {
      c.afterBuyLots=before.buyLots-c.reduceLots;
      c.afterSellLots=before.sellLots-c.reduceLots;
   }
   else
   {
      c.afterBuyLots=before.buyLots-c.reduceLots;
      c.afterSellLots=before.sellLots-c.reduceLots;
   }

   if(c.afterBuyLots< -0.0000001 || c.afterSellLots< -0.0000001) return false;
   c.afterBuyLots=MathMax(0.0,c.afterBuyLots);
   c.afterSellLots=MathMax(0.0,c.afterSellLots);
   c.afterExposure=MathAbs(c.afterBuyLots-c.afterSellLots);
   c.afterGross=c.afterBuyLots+c.afterSellLots;

   // Hard constraints: reduction only, no gross increase, no exposure increase,
   // and the action must produce a strictly smaller exposure.
   if(c.afterGross>c.beforeGross+0.0000001) return false;
   if(c.afterExposure>c.beforeExposure+0.0000001) return false;
   if(c.afterExposure>=c.beforeExposure-0.0000001) return false;
   if(c.afterGross>=c.beforeGross-0.0000001) return false;

   c.hardConstraintsPass=true;
   return true;
}

bool R10_BuildPairCandidate(const EAGOLD_Context &ctx,const EAGOLD_BasketState &before,R10_Candidate &c)
{
   int heavyType=-1,lightType=-1;
   double lightLots=0.0;
   if(before.buyLots>before.sellLots)
   {
      heavyType=OP_BUY; lightType=OP_SELL; lightLots=before.sellLots;
   }
   else if(before.sellLots>before.buyLots)
   {
      heavyType=OP_SELL; lightType=OP_BUY; lightLots=before.buyLots;
   }
   else return false;

   if(before.exposure<ctx.minExposureLots || lightLots<=0.0) return false;

   int heavyTicket=-1,lightTicket=-1;
   double heavyTicketLots=0.0,lightTicketLots=0.0;
   if(!EAGOLD_FindLargestTicket(ctx,heavyType,heavyTicket,heavyTicketLots)) return false;
   if(!EAGOLD_FindLargestTicket(ctx,lightType,lightTicket,lightTicketLots)) return false;

   // A pair reduction is limited by the smaller leg, the selected tickets,
   // the configured cap and the minimum exposure contract.
   double reduceLots=MathMin(heavyTicketLots,lightTicketLots);
   if(ctx.pairMaxLots>0.0) reduceLots=MathMin(reduceLots,ctx.pairMaxLots);
   reduceLots=EAGOLD_NormalizeLot(ctx,reduceLots);
   if(reduceLots<ctx.minExposureLots) return false;

   return R10_SimulatePair(ctx,before,heavyTicket,lightTicket,
                           heavyType,lightType,reduceLots,c);
}

bool R10_ExecutePair(const EAGOLD_Context &ctx,const R10_Candidate &c,
                     EAGOLD_BasketState &after,EAGOLD_R10Event &event)
{
   EAGOLD_EventReset(event);
   event.actionId=R10_ActionId();
   event.timestamp=TimeCurrent();
   event.actionType=c.actionType;
   event.ticketA=c.heavyTicket;
   event.ticketB=c.lightTicket;
   event.lotsA=c.reduceLots;
   event.lotsB=c.reduceLots;
   event.buyBefore=c.beforeBuyLots;
   event.sellBefore=c.beforeSellLots;
   event.netBefore=c.beforeExposure;
   event.grossBefore=c.beforeGross;

   double realizedA=0.0,realizedB=0.0;
   int errorCode=0;
   if(!EAGOLD_CloseLots(ctx,c.heavyTicket,c.reduceLots,realizedA,errorCode))
   {
      event.errorCode=errorCode;
      EAGOLD_MeasureBasket(ctx,after);
      event.buyAfter=after.buyLots; event.sellAfter=after.sellLots;
      event.netAfter=after.exposure; event.grossAfter=after.gross;
      return false;
   }

   int errorB=0;
   if(!EAGOLD_CloseLots(ctx,c.lightTicket,c.reduceLots,realizedB,errorB))
   {
      event.errorCode=errorB;
      EAGOLD_MeasureBasket(ctx,after);
      event.buyAfter=after.buyLots; event.sellAfter=after.sellLots;
      event.netAfter=after.exposure; event.grossAfter=after.gross;
      event.realizedNet=realizedA;
      return false;
   }

   // Verify against actual broker state. Do not trust the simulation after
   // execution; the broker state is authoritative.
   EAGOLD_MeasureBasket(ctx,after);
   event.buyAfter=after.buyLots;
   event.sellAfter=after.sellLots;
   event.netAfter=after.exposure;
   event.grossAfter=after.gross;
   event.realizedNet=realizedA+realizedB;
   event.success=(after.gross<c.beforeGross-0.0000001 &&
                  after.exposure<c.beforeExposure-0.0000001);
   if(!event.success) event.errorCode=1;
   return event.success;
}

bool R10_Run(const EAGOLD_Context &ctx,EAGOLD_BasketState &state,
             datetime &lastAction,EAGOLD_R10Event &event)
{
   EAGOLD_EventReset(event);
   if(!ctx.enableR10) return false;
   if(ctx.pairCooldownSeconds>0 && lastAction>0 &&
      TimeCurrent()-lastAction<ctx.pairCooldownSeconds) return false;

   EAGOLD_BasketState before;
   EAGOLD_MeasureBasket(ctx,before);

   R10_Candidate candidate;
   bool valid=false;
   if(ctx.enableR10Pair)
      valid=R10_BuildPairCandidate(ctx,before,candidate);
   if(!valid || !candidate.hardConstraintsPass) return false;

   EAGOLD_BasketState after;
   if(R10_ExecutePair(ctx,candidate,after,event))
   {
      lastAction=TimeCurrent();
      state=after;
      Print("EAGOLD R10: action=",event.actionId,
            " gross ",DoubleToString(event.grossBefore,ctx.lotDigits)," -> ",
            DoubleToString(event.grossAfter,ctx.lotDigits),
            " exposure ",DoubleToString(event.netBefore,ctx.lotDigits)," -> ",
            DoubleToString(event.netAfter,ctx.lotDigits),
            " realized=",DoubleToString(event.realizedNet,2));
      return true;
   }

   state=after;
   return false;
}

#endif
