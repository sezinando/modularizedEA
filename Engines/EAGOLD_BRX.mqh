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

double BRX_WeightedBreakeven(int direction){
   int type=(direction==OP_BUY?OP_BUY:OP_SELL);
   double weighted=0.0,lots=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=type)continue;
      weighted+=OrderOpenPrice()*OrderLots();
      lots+=OrderLots();
   }
   if(lots<=0.0)return(0.0);
   return(weighted/lots);
}

bool BRX_BEDirectionValid(int direction){
   if(!BRXRequireWeightedBE||BRXWeightedBEBufferPoints<=0.0)return(true);
   double be=BRX_WeightedBreakeven(direction);
   if(be<=0.0)return(false);
   RefreshRates();
   double buffer=PointsToPrice(BRXWeightedBEBufferPoints);
   if(direction==OP_BUY)return(Ask>=be+buffer);
   return(Bid<=be-buffer);
}

bool BRX_RecoveryAllowed(int direction){return(R10RecoveryAllowBasketClose(direction));}

bool BRX_CloseDirection(int direction){
   if(CountDirectionPositions(direction)<=0)return(false);
   if(!CanCloseLightBasket(direction))return(false);
   if(!BRX_RecoveryAllowed(direction))return(false);
   double before=BRX_DirectionalProfit(direction);
   double required=BRX_DirectionalFloor()+BRX_RealizationBuffer();
   if(before<required){
      Print(EA_NAME," BRX HOLD: directional floor not protected. direction=",(direction==OP_BUY?"BUY":"SELL")," profit=",DoubleToString(before,2)," required=",DoubleToString(required,2));
      return(false);
   }
   bool closed=CloseDirectionPositionsRobust(direction);
   if(closed){
      CloseAllDirectionPending(direction);
      Print(EA_NAME," BRX DIRECTIONAL CLOSE: direction=",(direction==OP_BUY?"BUY":"SELL")," profitBefore=",DoubleToString(before,2)," floor=",DoubleToString(BRX_DirectionalFloor(),2));
      CreateEngineActionMarker("BRX","DIRECTIONAL",direction,0.0);
   }else Print(EA_NAME," BRX DIRECTIONAL CLOSE FAILED: direction=",(direction==OP_BUY?"BUY":"SELL")," remaining=",CountDirectionPositions(direction));
   return(closed);
}

bool BRX_CloseBasket(){
   int buyCount=CountDirectionPositions(OP_BUY),sellCount=CountDirectionPositions(OP_SELL);
   if(buyCount<=0&&sellCount<=0)return(false);
   if(!R10RecoveryAllowBasketClose(OP_BUY)||!R10RecoveryAllowBasketClose(OP_SELL))return(false);
   double floor=BRX_BidirectionalFloor();
   double required=floor+BRX_RealizationBuffer();
   double before=BRX_BasketProfit();
   if(before<required){
      Print(EA_NAME," BRX HOLD: basket floor not protected. profit=",DoubleToString(before,2)," required=",DoubleToString(required,2));
      return(false);
   }

   // Close legs sequentially, but carry the already realized result into the
   // projected basket result. The second leg is never closed if doing so would
   // take the projected final basket below the configured profit floor.
   double realized=0.0;
   bool buyOk=true,sellOk=true;
   if(buyCount>0){
      double buyBefore=BRX_DirectionalProfit(OP_BUY);
      RefreshRates();
      if(realized+buyBefore<floor){
         Print(EA_NAME," BRX HOLD BUY LEG: projected basket result below floor. realized=",DoubleToString(realized,2)," buy=",DoubleToString(buyBefore,2)," floor=",DoubleToString(floor,2));
         return(false);
      }
      buyOk=CloseDirectionPositionsRobust(OP_BUY);
      if(!buyOk){
         Print(EA_NAME," BRX BIDIRECTIONAL CLOSE FAILED on BUY: remaining=",CountDirectionPositions(OP_BUY));
         return(false);
      }
      realized+=buyBefore;
      CloseAllDirectionPending(OP_BUY);
   }
   if(sellCount>0){
      double sellBefore=BRX_DirectionalProfit(OP_SELL);
      RefreshRates();
      if(realized+sellBefore<floor){
         Print(EAGOLD," BRX HOLD SELL LEG: projected basket result below floor. realized=",DoubleToString(realized,2)," sell=",DoubleToString(sellBefore,2)," floor=",DoubleToString(floor,2));
         return(false);
      }
      sellOk=CloseDirectionPositionsRobust(OP_SELL);
      if(!sellOk){
         Print(EA_NAME," BRX BIDIRECTIONAL CLOSE FAILED on SELL: remaining=",CountDirectionPositions(OP_SELL));
         return(false);
      }
      realized+=sellBefore;
      CloseAllDirectionPending(OP_SELL);
   }
   if(buyOk&&sellOk){
      Print(EA_NAME," BRX BIDIRECTIONAL CLOSE: basketProfitBefore=",DoubleToString(before,2)," realizedProjected=",DoubleToString(realized,2)," floor=",DoubleToString(floor,2));
      CreateEngineActionMarker("BRX","BIDIRECTIONAL",HeavyDirection(),0.0);
      return(true);
   }
   return(false);
}

bool BRX_DirectionalTargetReached(int direction){
   int count=CountDirectionPositions(direction);
   if(count<=1)return(false);
   double profit=BRX_DirectionalProfit(direction);
   if(profit<BRX_DirectionalFloor()+BRX_RealizationBuffer())return(false);
   return(BRX_BEDirectionValid(direction));
}

bool BRX_BidirectionalTargetReached(){
   int total=CountDirectionPositions(OP_BUY)+CountDirectionPositions(OP_SELL);
   if(total<2)return(false);
   double profit=BRX_BasketProfit();
   if(profit<BRX_BidirectionalFloor()+BRX_RealizationBuffer())return(false);
   return(true);
}

bool BRX_Run(){
   if(!EnableBasketRealization)return(false);
   if(BRXRealizationMode==0)return(false);

   if(BRXRealizationMode==2||BRXRealizationMode==3){
      if(BRX_BidirectionalTargetReached())return(BRX_CloseBasket());
   }

   if(BRXRealizationMode==1||BRXRealizationMode==3){
      double buy=BRX_DirectionalProfit(OP_BUY),sell=BRX_DirectionalProfit(OP_SELL);
      int direction=-1;
      if(DirectionLots(OP_BUY)>DirectionLots(OP_SELL))direction=OP_BUY;
      else if(DirectionLots(OP_SELL)>DirectionLots(OP_BUY))direction=OP_SELL;
      else if(buy>sell)direction=OP_BUY;
      else if(sell>buy)direction=OP_SELL;
      if(direction>=0&&BRX_DirectionalTargetReached(direction))return(BRX_CloseDirection(direction));
   }
   return(false);
}

#endif
