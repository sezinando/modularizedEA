#ifndef R10_CORE_MQH
#define R10_CORE_MQH

struct R10_Candidate
{
   string actionType;
   int heavyTicket;
   int lightTicket;
   int heavyType;
   int lightType;
   double reduceLots;
   double beforeExposure;
   double beforeGross;
   double afterExposure;
   double afterGross;
   bool hardConstraintsPass;
};

string R10_ActionId()
{
   return StringFormat("R10-%d-%d",(int)TimeCurrent(),GetTickCount());
}

bool R10_SimulatePair(const EAGOLD_Context &ctx,const EAGOLD_BasketState &before,
                      int heavyTicket,int lightTicket,int heavyType,int lightType,
                      double reduceLots,R10_Candidate &c)
{
   c.actionType="R10_PAIR";
   c.heavyTicket=heavyTicket; c.lightTicket=lightTicket;
   c.heavyType=heavyType; c.lightType=lightType;
   c.reduceLots=EAGOLD_NormalizeLot(ctx,reduceLots);
   c.beforeExposure=before.exposure; c.beforeGross=before.gross;
   c.afterExposure=before.exposure;
   c.afterGross=before.gross-(2.0*c.reduceLots);
   c.hardConstraintsPass=false;
   if(c.reduceLots<=0.0) return false;
   if(c.afterGross>c.beforeGross+0.0000001) return false;
   if(c.afterExposure>c.beforeExposure+0.0000001) return false;
   if(c.afterGross< -0.0000001) return false;
   c.hardConstraintsPass=true;
   return true;
}

bool R10_BuildPairCandidate(const EAGOLD_Context &ctx,const EAGOLD_BasketState &before,R10_Candidate &c)
{
   int heavyType=-1,lightType=-1;
   double lightLots=0.0;
   if(before.buyLots>before.sellLots) { heavyType=OP_BUY; lightType=OP_SELL; lightLots=before.sellLots; }
   else if(before.sellLots>before.buyLots) { heavyType=OP_SELL; lightType=OP_BUY; lightLots=before.buyLots; }
   else return false;
   if(before.exposure<ctx.minExposureLots || lightLots<=0.0) return false;

   int heavyTicket=-1,lightTicket=-1;
   double heavyTicketLots=0.0,lightTicketLots=0.0;
   if(!EAGOLD_FindLargestTicket(ctx,heavyType,heavyTicket,heavyTicketLots)) return false;
   if(!EAGOLD_FindLargestTicket(ctx,lightType,lightTicket,lightTicketLots)) return false;

   double reduceLots=MathMin(before.exposure,lightLots);
   reduceLots=MathMin(reduceLots,lightTicketLots);
   reduceLots=MathMin(reduceLots,heavyTicketLots);
   if(ctx.pairMaxLots>0.0) reduceLots=MathMin(reduceLots,ctx.pairMaxLots);
   reduceLots=EAGOLD_NormalizeLot(ctx,reduceLots);
   if(reduceLots<ctx.minExposureLots) return false;
   return R10_SimulatePair(ctx,before,heavyTicket,lightTicket,heavyType,lightType,reduceLots,c);
}

bool R10_ExecutePair(const EAGOLD_Context &ctx,const R10_Candidate &c,EAGOLD_BasketState &after,EAGOLD_R10Event &event)
{
   EAGOLD_EventReset(event);
   event.actionId=R10_ActionId(); event.timestamp=TimeCurrent(); event.actionType=c.actionType;
   event.ticketA=c.heavyTicket; event.ticketB=c.lightTicket;
   event.lotsA=c.reduceLots; event.lotsB=c.reduceLots;
   event.netBefore=c.beforeExposure; event.grossBefore=c.beforeGross;

   double realizedA=0.0,realizedB=0.0;
   int errorCode=0;
   if(!EAGOLD_CloseLots(ctx,c.heavyTicket,c.reduceLots,realizedA,errorCode))
   { event.errorCode=errorCode; EAGOLD_MeasureBasket(ctx,after); return false; }

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

   EAGOLD_MeasureBasket(ctx,after);
   event.buyAfter=after.buyLots; event.sellAfter=after.sellLots;
   event.netAfter=after.exposure; event.grossAfter=after.gross;
   event.realizedNet=realizedA+realizedB;
   event.success=(after.gross<=c.beforeGross+0.0000001 && after.exposure<=c.beforeExposure+0.0000001);
   if(!event.success) event.errorCode=1;
   return event.success;
}

bool R10_Run(const EAGOLD_Context &ctx,EAGOLD_BasketState &state,datetime &lastAction,EAGOLD_R10Event &event)
{
   EAGOLD_EventReset(event);
   if(!ctx.enableR10) return false;
   if(ctx.pairCooldownSeconds>0 && lastAction>0 && TimeCurrent()-lastAction<ctx.pairCooldownSeconds) return false;

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
      lastAction=TimeCurrent(); state=after;
      Print("EAGOLD R10: action=",event.actionId,
            " gross ",DoubleToString(event.grossBefore,ctx.lotDigits)," -> ",DoubleToString(event.grossAfter,ctx.lotDigits),
            " exposure ",DoubleToString(event.netBefore,ctx.lotDigits)," -> ",DoubleToString(event.netAfter,ctx.lotDigits));
      return true;
   }
   state=after;
   return false;
}

#endif
