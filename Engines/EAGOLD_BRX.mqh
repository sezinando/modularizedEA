#ifndef EAGOLD_BRX_MQH
#define EAGOLD_BRX_MQH

//==================================================================
// BRX v1.4 — TRANSACTIONAL BASKET REALIZATION ENGINE
// Realization is classified explicitly as BLOCKED / COMPLETED / PARTIAL / FAILED.
// A realization is COMPLETED only when the requested market positions are fully
// closed AND directional pending cleanup has been verified.
//
// ORCHESTRATION / FULL REALIZATION FIX v1.4:
// When the BIDIRECTIONAL basket reaches its protected floor, BRX now executes
// a heavy-first FULL BASKET realization path. The light-side protection rule
// remains active for ordinary directional realization, but it is not allowed
// to prevent a protected full-basket liquidation from closing the remaining
// light side. The broker state is re-read after the heavy leg before the light
// leg is authorized. PARTIAL/COMPLETED remain terminal for the current tick
// through the transaction contract. Economic thresholds are unchanged.
//==================================================================

double BRX_DirectionalProfit(int direction){return(DirectionBasketProfit(direction));}
double BRX_BasketProfit(){return(DirectionBasketProfit(OP_BUY)+DirectionBasketProfit(OP_SELL));}
double BRX_RealizationBuffer(){double b=BRXRealizationSafetyBuffer;if(b<0.0)b=0.0;return(b);}
double BRX_DirectionalFloor(){return(MathMax(0.0,BRXDirectionalMinProfit));}
double BRX_BidirectionalFloor(){return(MathMax(0.0,BRXBidirectionalMinProfit));}

double BRX_WeightedBreakeven(int direction){int type=(direction==OP_BUY?OP_BUY:OP_SELL);double weighted=0.0,lots=0.0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;weighted+=OrderOpenPrice()*OrderLots();lots+=OrderLots();}if(lots<=0.0)return(0.0);return(weighted/lots);}

bool BRX_BEDirectionValid(int direction){if(!BRXRequireWeightedBE||BRXWeightedBEBufferPoints<=0.0)return(true);double be=BRX_WeightedBreakeven(direction);if(be<=0.0)return(false);RefreshRates();double buffer=PointsToPrice(BRXWeightedBEBufferPoints);if(direction==OP_BUY)return(Ask>=be+buffer);return(Bid<=be-buffer);}

bool BRX_RecoveryAllowed(int direction){return(R10RecoveryAllowBasketClose(direction));}

double BRX_RealizedTickets(int &tickets[]){double total=0.0;for(int i=0;i<ArraySize(tickets);i++){if(!OrderSelect(tickets[i],SELECT_BY_TICKET,MODE_HISTORY))continue;int type=OrderType();if(type!=OP_BUY&&type!=OP_SELL)continue;total+=OrderProfit()+OrderSwap()+OrderCommission();}return(total);}

void BRX_CaptureDirectionTickets(int direction,int &tickets[]){ArrayResize(tickets,0);int type=(direction==OP_BUY?OP_BUY:OP_SELL);for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;int n=ArraySize(tickets);ArrayResize(tickets,n+1);tickets[n]=OrderTicket();}}

EAGOLD_ActionResult BRX_CloseDirectionTransactional(int direction,int &requestedCount,int &completedCount,double &requestedLots,double &completedLots,double &realized)
{
   requestedCount=0;completedCount=0;requestedLots=0.0;completedLots=0.0;realized=0.0;
   if(CountDirectionPositions(direction)<=0)return(EAGOLD_ACTION_BLOCKED);
   if(!CanCloseLightBasket(direction))return(EAGOLD_ACTION_BLOCKED);
   if(!BRX_RecoveryAllowed(direction))return(EAGOLD_ACTION_BLOCKED);
   double before=BRX_DirectionalProfit(direction);double required=BRX_DirectionalFloor()+BRX_RealizationBuffer();
   if(before<required){Print(EA_NAME," BRX HOLD: directional floor not protected. direction=",(direction==OP_BUY?"BUY":"SELL")," profit=",DoubleToString(before,2)," required=",DoubleToString(required,2));return(EAGOLD_ACTION_BLOCKED);}
   if(!BRX_BEDirectionValid(direction))return(EAGOLD_ACTION_BLOCKED);
   int tickets[];BRX_CaptureDirectionTickets(direction,tickets);
   EAGOLD_ActionResult result=CloseDirectionPositionsTransactional(direction,requestedCount,completedCount,requestedLots,completedLots);
   if(result!=EAGOLD_ACTION_COMPLETED){
      if(result==EAGOLD_ACTION_PARTIAL)EAGOLD_R10RequestReconciliation();
      return(result);
   }
   realized=BRX_RealizedTickets(tickets);
   if(!CloseAllDirectionPending(direction)){
      EAGOLD_R10RequestReconciliation();
      Print(EA_NAME," BRX TRANSACTION PARTIAL: market close completed but pending cleanup failed. direction=",(direction==OP_BUY?"BUY":"SELL"));
      return(EAGOLD_ACTION_PARTIAL);
   }
   return(EAGOLD_ACTION_COMPLETED);
}

// Full-basket path used only after the bidirectional protected floor is reached.
// It deliberately does not call CanCloseLightBasket(): that guard protects
// directional exposure management, whereas this transaction is explicitly a
// protected liquidation of both sides. Heavy side is closed first so its
// realized result can finance/protect the remaining light side.
EAGOLD_ActionResult BRX_CloseFullBasketTransactional(int &requestedCount,int &completedCount,double &requestedLots,double &completedLots,double &realized)
{
   requestedCount=0;completedCount=0;requestedLots=0.0;completedLots=0.0;realized=0.0;
   int buyCount=CountDirectionPositions(OP_BUY),sellCount=CountDirectionPositions(OP_SELL);
   if(buyCount<=0&&sellCount<=0)return(EAGOLD_ACTION_BLOCKED);
   if(!R10RecoveryAllowBasketClose(OP_BUY)||!R10RecoveryAllowBasketClose(OP_SELL))return(EAGOLD_ACTION_BLOCKED);

   double floor=BRX_BidirectionalFloor();
   double required=floor+BRX_RealizationBuffer();
   double before=BRX_BasketProfit();
   if(before<required){
      Print(EA_NAME," BRX FULL HOLD: basket floor not protected. profit=",DoubleToString(before,2)," required=",DoubleToString(required,2));
      return(EAGOLD_ACTION_BLOCKED);
   }

   int heavyDirection=-1,lightDirection=-1;
   double buyLots=DirectionLots(OP_BUY),sellLots=DirectionLots(OP_SELL);
   double buyProfit=BRX_DirectionalProfit(OP_BUY),sellProfit=BRX_DirectionalProfit(OP_SELL);
   if(buyCount>0&&sellCount<=0)heavyDirection=OP_BUY;
   else if(sellCount>0&&buyCount<=0)heavyDirection=OP_SELL;
   else if(buyLots>sellLots){heavyDirection=OP_BUY;lightDirection=OP_SELL;}
   else if(sellLots>buyLots){heavyDirection=OP_SELL;lightDirection=OP_BUY;}
   else if(buyProfit>sellProfit){heavyDirection=OP_BUY;lightDirection=OP_SELL;}
   else if(sellProfit>buyProfit){heavyDirection=OP_SELL;lightDirection=OP_BUY;}
   else if(buyCount>0){heavyDirection=OP_BUY;lightDirection=OP_SELL;}
   else {heavyDirection=OP_SELL;lightDirection=OP_BUY;}

   // One-sided basket: this is still a full liquidation, but use the normal
   // directional transaction so its ordinary protection remains intact.
   if(lightDirection<0){
      return(BRX_CloseDirectionTransactional(heavyDirection,requestedCount,completedCount,requestedLots,completedLots,realized));
   }

   int heavyReq=0,heavyDone=0;double heavyReqLots=0.0,heavyDoneLots=0.0,heavyRealized=0.0;
   int heavyTickets[];BRX_CaptureDirectionTickets(heavyDirection,heavyTickets);

   // Weighted BE remains a hard directional safety condition when configured.
   if(!BRX_BEDirectionValid(heavyDirection))return(EAGOLD_ACTION_BLOCKED);

   EAGOLD_ActionResult heavyResult=CloseDirectionPositionsTransactional(heavyDirection,heavyReq,heavyDone,heavyReqLots,heavyDoneLots);
   requestedCount+=heavyReq;completedCount+=heavyDone;requestedLots+=heavyReqLots;completedLots+=heavyDoneLots;
   if(heavyResult!=EAGOLD_ACTION_COMPLETED){
      if(heavyResult==EAGOLD_ACTION_PARTIAL)EAGOLD_R10RequestReconciliation();
      return(heavyResult);
   }
   heavyRealized=BRX_RealizedTickets(heavyTickets);
   realized+=heavyRealized;
   if(!CloseAllDirectionPending(heavyDirection)){
      EAGOLD_R10RequestReconciliation();
      Print(EA_NAME," BRX FULL PARTIAL: heavy market close completed but pending cleanup failed. direction=",(heavyDirection==OP_BUY?"BUY":"SELL"));
      return(EAGOLD_ACTION_PARTIAL);
   }

   // Broker state is authoritative. Recalculate the remaining side after the
   // heavy leg instead of trusting the pre-trade simulation.
   double remainingProfit=BRX_DirectionalProfit(lightDirection);
   double projected=realized+remainingProfit;
   if(projected<floor){
      EAGOLD_R10RequestReconciliation();
      Print(EA_NAME," BRX FULL PARTIAL: heavy leg realized but light leg not protected. realized=",DoubleToString(realized,2)," remaining=",DoubleToString(remainingProfit,2)," floor=",DoubleToString(floor,2));
      return(EAGOLD_ACTION_PARTIAL);
   }

   int lightReq=0,lightDone=0;double lightReqLots=0.0,lightDoneLots=0.0,lightRealized=0.0;
   int lightTickets[];BRX_CaptureDirectionTickets(lightDirection,lightTickets);
   if(!BRX_BEDirectionValid(lightDirection)){
      EAGOLD_R10RequestReconciliation();
      Print(EA_NAME," BRX FULL PARTIAL: light weighted BE condition failed after heavy realization. direction=",(lightDirection==OP_BUY?"BUY":"SELL"));
      return(EAGOLD_ACTION_PARTIAL);
   }

   EAGOLD_ActionResult lightResult=CloseDirectionPositionsTransactional(lightDirection,lightReq,lightDone,lightReqLots,lightDoneLots);
   requestedCount+=lightReq;completedCount+=lightDone;requestedLots+=lightReqLots;completedLots+=lightDoneLots;
   if(lightResult!=EAGOLD_ACTION_COMPLETED){
      if(lightResult==EAGOLD_ACTION_PARTIAL)EAGOLD_R10RequestReconciliation();
      else if(lightResult==EAGOLD_ACTION_FAILED)EAGOLD_R10RequestReconciliation();
      return(lightResult==EAGOLD_ACTION_FAILED?EAGOLD_ACTION_PARTIAL:lightResult);
   }
   lightRealized=BRX_RealizedTickets(lightTickets);
   realized+=lightRealized;
   if(!CloseAllDirectionPending(lightDirection)){
      EAGOLD_R10RequestReconciliation();
      Print(EA_NAME," BRX FULL PARTIAL: light market close completed but pending cleanup failed. direction=",(lightDirection==OP_BUY?"BUY":"SELL"));
      return(EAGOLD_ACTION_PARTIAL);
   }

   if(CountDirectionPositions(OP_BUY)>0||CountDirectionPositions(OP_SELL)>0||CountDirectionPending(OP_BUY)>0||CountDirectionPending(OP_SELL)>0){
      EAGOLD_R10RequestReconciliation();
      Print(EA_NAME," BRX FULL PARTIAL: liquidation postcondition failed. BUY positions=",CountDirectionPositions(OP_BUY)," SELL positions=",CountDirectionPositions(OP_SELL)," BUY pending=",CountDirectionPending(OP_BUY)," SELL pending=",CountDirectionPending(OP_SELL));
      return(EAGOLD_ACTION_PARTIAL);
   }

   return(EAGOLD_ACTION_COMPLETED);
}

EAGOLD_ActionResult BRX_CloseBasketTransactional(int &requestedCount,int &completedCount,double &requestedLots,double &completedLots,double &realized)
{
   requestedCount=0;completedCount=0;requestedLots=0.0;completedLots=0.0;realized=0.0;
   int buyCount=CountDirectionPositions(OP_BUY),sellCount=CountDirectionPositions(OP_SELL);
   if(buyCount<=0&&sellCount<=0)return(EAGOLD_ACTION_BLOCKED);
   if(!R10RecoveryAllowBasketClose(OP_BUY)||!R10RecoveryAllowBasketClose(OP_SELL))return(EAGOLD_ACTION_BLOCKED);
   double floor=BRX_BidirectionalFloor();double required=floor+BRX_RealizationBuffer();double before=BRX_BasketProfit();
   if(before<required){Print(EA_NAME," BRX HOLD: basket floor not protected. profit=",DoubleToString(before,2)," required=",DoubleToString(required,2));return(EAGOLD_ACTION_BLOCKED);}

   // v1.4: protected bidirectional target always uses heavy-first full liquidation.
   return(BRX_CloseFullBasketTransactional(requestedCount,completedCount,requestedLots,completedLots,realized));
}

bool BRX_DirectionalTargetReached(int direction){int count=CountDirectionPositions(direction);if(count<=1)return(false);double profit=BRX_DirectionalProfit(direction);if(profit<BRX_DirectionalFloor()+BRX_RealizationBuffer())return(false);return(BRX_BEDirectionValid(direction));}

bool BRX_BidirectionalTargetReached(){int total=CountDirectionPositions(OP_BUY)+CountDirectionPositions(OP_SELL);if(total<2)return(false);double profit=BRX_BasketProfit();if(profit<BRX_BidirectionalFloor()+BRX_RealizationBuffer())return(false);return(true);}

bool BRX_Run(){
   if(!EnableBasketRealization)return(false);
   if(BRXRealizationMode==0)return(false);
   if(BRXRealizationMode==2||BRXRealizationMode==3){
      if(BRX_BidirectionalTargetReached()){
         int rc=0,cc=0;double rl=0.0,cl=0.0,realized=0.0;
         EAGOLD_ActionResult result=BRX_CloseBasketTransactional(rc,cc,rl,cl,realized);
         EAGOLD_ApplyActionResult(result,"BRX","BIDIRECTIONAL",HeavyDirection(),cl);
         if(result==EAGOLD_ACTION_COMPLETED){EAGOLD_RealizationCascadeAdd(realized,CascadeEngineColor("BRX"));CreateEngineActionMarker("BRX","BIDIRECTIONAL",HeavyDirection(),0.0);Print(EA_NAME," BRX BIDIRECTIONAL COMPLETE: realized=",DoubleToString(realized,2));return(true);}
         if(result==EAGOLD_ACTION_PARTIAL){return(true);}
         // BLOCKED/FAILED: do not consume BRX. Continue to DIRECTIONAL fallback.
      }
   }
   if(BRXRealizationMode==1||BRXRealizationMode==3){
      double buy=BRX_DirectionalProfit(OP_BUY),sell=BRX_DirectionalProfit(OP_SELL);int direction=-1;
      if(DirectionLots(OP_BUY)>DirectionLots(OP_SELL))direction=OP_BUY;else if(DirectionLots(OP_SELL)>DirectionLots(OP_BUY))direction=OP_SELL;else if(buy>sell)direction=OP_BUY;else if(sell>buy)direction=OP_SELL;
      if(direction>=0&&BRX_DirectionalTargetReached(direction)){
         int rc=0,cc=0;double rl=0.0,cl=0.0,realized=0.0;
         EAGOLD_ActionResult result=BRX_CloseDirectionTransactional(direction,rc,cc,rl,cl,realized);
         EAGOLD_ApplyActionResult(result,"BRX","DIRECTIONAL",direction,cl);
         if(result==EAGOLD_ACTION_COMPLETED){EAGOLD_RealizationCascadeAdd(realized,CascadeEngineColor("BRX"));CreateEngineActionMarker("BRX","DIRECTIONAL",direction,0.0);Print(EA_NAME," BRX DIRECTIONAL COMPLETE: direction=",(direction==OP_BUY?"BUY":"SELL")," realized=",DoubleToString(realized,2));}
         return(true);
      }
   }
   return(false);
}

#endif
