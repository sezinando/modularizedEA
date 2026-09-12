#ifndef EAGOLD_BRX_MQH
#define EAGOLD_BRX_MQH

//==================================================================
// BRX v1.2 — TRANSACTIONAL BASKET REALIZATION ENGINE
// Realization is classified explicitly as BLOCKED / COMPLETED / PARTIAL / FAILED.
// A realization is COMPLETED only when the requested market positions are fully
// closed AND directional pending cleanup has been verified.
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

EAGOLD_ActionResult BRX_CloseBasketTransactional(int &requestedCount,int &completedCount,double &requestedLots,double &completedLots,double &realized)
{
   requestedCount=0;completedCount=0;requestedLots=0.0;completedLots=0.0;realized=0.0;
   int buyCount=CountDirectionPositions(OP_BUY),sellCount=CountDirectionPositions(OP_SELL);
   if(buyCount<=0&&sellCount<=0)return(EAGOLD_ACTION_BLOCKED);
   if(!R10RecoveryAllowBasketClose(OP_BUY)||!R10RecoveryAllowBasketClose(OP_SELL))return(EAGOLD_ACTION_BLOCKED);
   double floor=BRX_BidirectionalFloor();double required=floor+BRX_RealizationBuffer();double before=BRX_BasketProfit();
   if(before<required){Print(EA_NAME," BRX HOLD: basket floor not protected. profit=",DoubleToString(before,2)," required=",DoubleToString(required,2));return(EAGOLD_ACTION_BLOCKED);}

   if(buyCount>0){
      int buyReq=0,buyDone=0;double buyReqLots=0.0,buyDoneLots=0.0,buyRealized=0.0;
      EAGOLD_ActionResult buyResult=BRX_CloseDirectionTransactional(OP_BUY,buyReq,buyDone,buyReqLots,buyDoneLots,buyRealized);
      requestedCount+=buyReq;completedCount+=buyDone;requestedLots+=buyReqLots;completedLots+=buyDoneLots;realized+=buyRealized;
      if(buyResult!=EAGOLD_ACTION_COMPLETED)return(buyResult);
   }

   if(sellCount>0){
      if(realized<floor){Print(EA_NAME," BRX HOLD SELL LEG: actual realized first leg below floor. realized=",DoubleToString(realized,2)," floor=",DoubleToString(floor,2));EAGOLD_R10RequestReconciliation();return(EAGOLD_ACTION_PARTIAL);}
      double sellBefore=BRX_DirectionalProfit(OP_SELL);
      if(realized+sellBefore<floor){Print(EA_NAME," BRX HOLD SELL LEG: projected basket result below floor. realized=",DoubleToString(realized,2)," sell=",DoubleToString(sellBefore,2)," floor=",DoubleToString(floor,2));EAGOLD_R10RequestReconciliation();return(EAGOLD_ACTION_PARTIAL);}
      int sellReq=0,sellDone=0;double sellReqLots=0.0,sellDoneLots=0.0,sellRealized=0.0;
      EAGOLD_ActionResult sellResult=BRX_CloseDirectionTransactional(OP_SELL,sellReq,sellDone,sellReqLots,sellDoneLots,sellRealized);
      requestedCount+=sellReq;completedCount+=sellDone;requestedLots+=sellReqLots;completedLots+=sellDoneLots;realized+=sellRealized;
      if(sellResult!=EAGOLD_ACTION_COMPLETED)return(sellResult);
   }
   return(EAGOLD_ACTION_COMPLETED);
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
         if(result==EAGOLD_ACTION_COMPLETED){EAGOLD_RealizationCascadeAdd(realized,CascadeEngineColor("BRX"));CreateEngineActionMarker("BRX","BIDIRECTIONAL",HeavyDirection(),0.0);Print(EA_NAME," BRX BIDIRECTIONAL COMPLETE: realized=",DoubleToString(realized,2));}
         return(true);
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
