#ifndef EAGOLD_BRX_MQH
#define EAGOLD_BRX_MQH

//==================================================================
// BRX v1.1 — BASKET REALIZATION ENGINE
// Replaces the legacy count * TakeProfit basket target when enabled.
// Modes: 0 legacy, 1 directional, 2 bidirectional, 3 hybrid.
// A realization is authorized only when the projected net result remains
// above the configured profit floor plus the execution safety buffer.
//==================================================================

double BRX_DirectionalProfit(int direction){return(DirectionBasketProfit(direction));}
double BRX_BasketProfit(){return(DirectionBasketProfit(OP_BUY)+DirectionBasketProfit(OP_SELL));}
double BRX_RealizationBuffer(){double b=BRXRealizationSafetyBuffer;if(b<0.0)b=0.0;return(b);}
double BRX_DirectionalFloor(){return(MathMax(0.0,BRXDirectionalMinProfit));}
double BRX_BidirectionalFloor(){return(MathMax(0.0,BRXBidirectionalMinProfit));}

double BRX_WeightedBreakeven(int direction){int type=(direction==OP_BUY?OP_BUY:OP_SELL);double weighted=0.0,lots=0.0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;weighted+=OrderOpenPrice()*OrderLots();lots+=OrderLots();}if(lots<=0.0)return(0.0);return(weighted/lots);}

bool BRX_BEDirectionValid(int direction){if(!BRXRequireWeightedBE||BRXWeightedBEBufferPoints<=0.0)return(true);double be=BRX_WeightedBreakeven(direction);if(be<=0.0)return(false);RefreshRates();double buffer=PointsToPrice(BRXWeightedBEBufferPoints);if(direction==OP_BUY)return(Ask>=be+buffer);return(Bid<=be-buffer);}

bool BRX_RecoveryAllowed(int direction){return(R10RecoveryAllowBasketClose(direction));}

// Return the realized net result for a known set of tickets after execution.
double BRX_RealizedTickets(int &tickets[]){
   double total=0.0;
   for(int i=0;i<ArraySize(tickets);i++){
      if(!OrderSelect(tickets[i],SELECT_BY_TICKET,MODE_HISTORY))continue;
      int type=OrderType();
      if(type!=OP_BUY&&type!=OP_SELL)continue;
      total+=OrderProfit()+OrderSwap()+OrderCommission();
   }
   return(total);
}

void BRX_CaptureDirectionTickets(int direction,int &tickets[]){
   ArrayResize(tickets,0);
   int type=(direction==OP_BUY?OP_BUY:OP_SELL);
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=type)continue;
      int n=ArraySize(tickets);
      ArrayResize(tickets,n+1);
      tickets[n]=OrderTicket();
   }
}

bool BRX_CloseDirection(int direction){
   if(CountDirectionPositions(direction)<=0)return(false);
   if(!CanCloseLightBasket(direction))return(false);
   if(!BRX_RecoveryAllowed(direction))return(false);
   double before=BRX_DirectionalProfit(direction);
   double required=BRX_DirectionalFloor()+BRX_RealizationBuffer();
   if(before<required){Print(EA_NAME," BRX HOLD: directional floor not protected. direction=",(direction==OP_BUY?"BUY":"SELL")," profit=",DoubleToString(before,2)," required=",DoubleToString(required,2));return(false);}
   int tickets[];
   BRX_CaptureDirectionTickets(direction,tickets);
   bool closed=CloseDirectionPositionsRobust(direction);
   if(closed){
      double realized=BRX_RealizedTickets(tickets);
      CloseAllDirectionPending(direction);
      Print(EA_NAME," BRX DIRECTIONAL CLOSE: direction=",(direction==OP_BUY?"BUY":"SELL")," profitBefore=",DoubleToString(before,2)," realized=",DoubleToString(realized,2)," floor=",DoubleToString(BRX_DirectionalFloor(),2));
      CreateEngineActionMarker("BRX","DIRECTIONAL",direction,0.0);
   }else{
      Print(EA_NAME," BRX DIRECTIONAL CLOSE PARTIAL/FAILED: direction=",(direction==OP_BUY?"BUY":"SELL")," remaining=",CountDirectionPositions(direction));
   }
   return(closed);
}

bool BRX_CloseBasket(){
   int buyCount=CountDirectionPositions(OP_BUY),sellCount=CountDirectionPositions(OP_SELL);
   if(buyCount<=0&&sellCount<=0)return(false);
   if(!R10RecoveryAllowBasketClose(OP_BUY)||!R10RecoveryAllowBasketClose(OP_SELL))return(false);
   double floor=BRX_BidirectionalFloor();
   double required=floor+BRX_RealizationBuffer();
   double before=BRX_BasketProfit();
   if(before<required){Print(EA_NAME," BRX HOLD: basket floor not protected. profit=",DoubleToString(before,2)," required=",DoubleToString(required,2));return(false);}

   // Execution is not transactional in MT4. Each leg is closed separately,
   // and the next leg is authorized from the ACTUAL realized result of the
   // already closed tickets, never from its pre-close floating estimate.
   double realized=0.0;
   if(buyCount>0){
      int buyTickets[];
      BRX_CaptureDirectionTickets(OP_BUY,buyTickets);
      if(!CloseDirectionPositionsRobust(OP_BUY)){
         double buyRealized=BRX_RealizedTickets(buyTickets);
         Print(EA_NAME," BRX BIDIRECTIONAL CLOSE PARTIAL/FAILED on BUY: remaining=",CountDirectionPositions(OP_BUY)," realizedBUY=",DoubleToString(buyRealized,2)," residualSELL=",CountDirectionPositions(OP_SELL));
         return(false);
      }
      double buyRealized=BRX_RealizedTickets(buyTickets);
      realized+=buyRealized;
      CloseAllDirectionPending(OP_BUY);
      Print(EA_NAME," BRX BIDIRECTIONAL BUY LEG CLOSED: realizedBUY=",DoubleToString(buyRealized,2)," cumulative=",DoubleToString(realized,2));
   }
   if(sellCount>0){
      int sellTickets[];
      BRX_CaptureDirectionTickets(OP_SELL,sellTickets);
      // The second leg must preserve the nominal configured floor after the
      // actual result of the first leg is known. Safety buffer remains an
      // authorization reserve on the overall basket, not a post-close profit
      // guarantee against market execution/slippage.
      if(realized<floor){
         Print(EA_NAME," BRX HOLD SELL LEG: actual realized first leg below floor. realized=",DoubleToString(realized,2)," floor=",DoubleToString(floor,2)," remainingSELL=",CountDirectionPositions(OP_SELL));
         return(false);
      }
      double sellBefore=BRX_DirectionalProfit(OP_SELL);
      if(realized+sellBefore<floor){
         Print(EA_NAME," BRX HOLD SELL LEG: projected basket result below floor. realized=",DoubleToString(realized,2)," sell=",DoubleToString(sellBefore,2)," floor=",DoubleToString(floor,2));
         return(false);
      }
      if(!CloseDirectionPositionsRobust(OP_SELL)){
         double sellRealized=BRX_RealizedTickets(sellTickets);
         Print(EA_NAME," BRX BIDIRECTIONAL CLOSE PARTIAL/FAILED on SELL: remaining=",CountDirectionPositions(OP_SELL)," realizedFirstLeg=",DoubleToString(realized,2)," realizedSELL=",DoubleToString(sellRealized,2));
         return(false);
      }
      double sellRealized=BRX_RealizedTickets(sellTickets);
      realized+=sellRealized;
      CloseAllDirectionPending(OP_SELL);
      Print(EA_NAME," BRX BIDIRECTIONAL SELL LEG CLOSED: realizedSELL=",DoubleToString(sellRealized,2)," cumulative=",DoubleToString(realized,2));
   }
   Print(EA_NAME," BRX BIDIRECTIONAL CLOSE COMPLETE: basketProfitBefore=",DoubleToString(before,2)," realizedActual=",DoubleToString(realized,2)," floor=",DoubleToString(floor,2)," requiredAuthorization=",DoubleToString(required,2));
   CreateEngineActionMarker("BRX","BIDIRECTIONAL",HeavyDirection(),0.0);
   return(true);
}

bool BRX_DirectionalTargetReached(int direction){int count=CountDirectionPositions(direction);if(count<=1)return(false);double profit=BRX_DirectionalProfit(direction);if(profit<BRX_DirectionalFloor()+BRX_RealizationBuffer())return(false);return(BRX_BEDirectionValid(direction));}

bool BRX_BidirectionalTargetReached(){int total=CountDirectionPositions(OP_BUY)+CountDirectionPositions(OP_SELL);if(total<2)return(false);double profit=BRX_BasketProfit();if(profit<BRX_BidirectionalFloor()+BRX_RealizationBuffer())return(false);return(true);}

bool BRX_Run(){
   if(!EnableBasketRealization)return(false);
   if(BRXRealizationMode==0)return(false);
   if(BRXRealizationMode==2||BRXRealizationMode==3){if(BRX_BidirectionalTargetReached())return(BRX_CloseBasket());}
   if(BRXRealizationMode==1||BRXRealizationMode==3){double buy=BRX_DirectionalProfit(OP_BUY),sell=BRX_DirectionalProfit(OP_SELL);int direction=-1;if(DirectionLots(OP_BUY)>DirectionLots(OP_SELL))direction=OP_BUY;else if(DirectionLots(OP_SELL)>DirectionLots(OP_BUY))direction=OP_SELL;else if(buy>sell)direction=OP_BUY;else if(sell>buy)direction=OP_SELL;if(direction>=0&&BRX_DirectionalTargetReached(direction))return(BRX_CloseDirection(direction));}
   return(false);
}

#endif
