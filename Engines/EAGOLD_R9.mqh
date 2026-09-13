#ifndef EAGOLD_R9_MQH
#define EAGOLD_R9_MQH

//==================================================================
// STAGE 4 — R9 EXPOSURE CONTROLLER
// Business behavior extracted from EAGOLD v0.106 without redesign.
// Economic hedge actions now participate in the global tick transaction
// contract so a successful R9 hedge consumes the current tick and a
// failed/partial state cannot be followed by another economic action.
//==================================================================

bool IntArrayContains(int &arr[],int ticket){for(int i=0;i<ArraySize(arr);i++)if(arr[i]==ticket)return(true);return(false);}

void IntArrayAdd(int &arr[],int ticket){if(ticket<0||IntArrayContains(arr,ticket))return;int n=ArraySize(arr);ArrayResize(arr,n+1);arr[n]=ticket;}

bool R9Processed(int ticket){return(IntArrayContains(g_r9ProcessedTickets,ticket));}

void R9MarkProcessed(int ticket){IntArrayAdd(g_r9ProcessedTickets,ticket);}

void R9SeedExistingPositions(){for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder())continue;int type=OrderType();if(type==OP_BUY||type==OP_SELL)R9MarkProcessed(OrderTicket());}}

bool R9GetNewExposureState(int &lightDirection,double &exposure,double &lightLots,double &heavyLots){double b=DirectionLots(OP_BUY),s=DirectionLots(OP_SELL);exposure=MathAbs(b-s);lightDirection=-1;lightLots=MathMin(b,s);heavyLots=MathMax(b,s);if(exposure<R9ExposureTriggerLots)return(false);if(b<s)lightDirection=OP_BUY;else if(s<b)lightDirection=OP_SELL;else return(false);return(true);}

EAGOLD_ActionResult R9HedgeFromActivatedTicketTransactional(int ticket,double &hedgeLots,int &hedgeTicket)
{
   hedgeLots=0.0;hedgeTicket=-1;
   if(!EnableR9Hedge)return(EAGOLD_ACTION_BLOCKED);
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))return(EAGOLD_ACTION_BLOCKED);
   if(!IsEAGOLDOrder())return(EAGOLD_ACTION_BLOCKED);
   int type=OrderType();
   if(type!=OP_BUY&&type!=OP_SELL)return(EAGOLD_ACTION_BLOCKED);
   double triggerLot=OrderLots();
   int light=-1;double exposure=0.0,lightLots=0.0,heavyLots=0.0;
   if(!R9GetNewExposureState(light,exposure,lightLots,heavyLots)){g_r9HedgeActive=false;return(EAGOLD_ACTION_BLOCKED);}
   int heavy=HeavyDirection();
   if(type!=heavy)return(EAGOLD_ACTION_BLOCKED);
   double requestedHedge=NormalizeLot(triggerLot*R9HedgeFraction);
   double maxHedge=NormalizeLot(exposure*R9BalanceCap);
   if(maxHedge<Lot)return(EAGOLD_ACTION_BLOCKED);
   if(requestedHedge>maxHedge)requestedHedge=maxHedge;
   requestedHedge=NormalizeLot(requestedHedge);
   if(requestedHedge<=0.0)return(EAGOLD_ACTION_BLOCKED);
   hedgeLots=requestedHedge;
   hedgeTicket=SendMarket(light,requestedHedge,StringFormat("EAGOLD R9 HEDGE FROM #%d",ticket));
   if(hedgeTicket>0)
   {
      R9MarkProcessed(hedgeTicket);
      g_r9HedgeActive=true;
      Print(EA_NAME," RULE 9 HEDGE: activation=",ticket," triggerLot=",DoubleToString(triggerLot,DigitsLots)," light=",(light==OP_BUY?"BUY":"SELL")," exposure=",DoubleToString(exposure,DigitsLots)," hedgeLot=",DoubleToString(requestedHedge,DigitsLots)," cap=",DoubleToString(R9BalanceCap,2)," newTicket=",hedgeTicket);
      CreateEngineActionMarker("R9","HEDGE",light,requestedHedge);
      return(EAGOLD_ACTION_COMPLETED);
   }
   return(EAGOLD_ACTION_FAILED);
}

// Compatibility wrapper for callers that only need a boolean result.
bool R9HedgeFromActivatedTicket(int ticket)
{
   double hedgeLots=0.0;int hedgeTicket=-1;
   return(R9HedgeFromActivatedTicketTransactional(ticket,hedgeLots,hedgeTicket)==EAGOLD_ACTION_COMPLETED);
}

EAGOLD_ActionResult Rule9DetectActivatedOrdersTransactional()
{
   if(!EnableR9Hedge)return(EAGOLD_ACTION_BLOCKED);
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder())continue;
      int type=OrderType();
      if(type!=OP_BUY&&type!=OP_SELL)continue;
      int ticket=OrderTicket();
      if(R9Processed(ticket))continue;
      double hedgeLots=0.0;int hedgeTicket=-1;
      EAGOLD_ActionResult result=R9HedgeFromActivatedTicketTransactional(ticket,hedgeLots,hedgeTicket);
      R9MarkProcessed(ticket);
      if(result==EAGOLD_ACTION_COMPLETED)return(result);
   }
   double exposure=ExposureLots();
   if(exposure<R9ExposureTriggerLots)g_r9HedgeActive=false;
   return(EAGOLD_ACTION_BLOCKED);
}

void Rule9DetectActivatedOrders(){Rule9DetectActivatedOrdersTransactional();}

#endif
