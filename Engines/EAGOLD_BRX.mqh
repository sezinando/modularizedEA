#ifndef EAGOLD_BRX_MQH
#define EAGOLD_BRX_MQH

//==================================================================
// BRX v1.0 — BASKET REALIZATION ENGINE
// Replaces the legacy count * TakeProfit basket target when enabled.
// Modes: 0 legacy, 1 directional, 2 bidirectional, 3 hybrid.
// Uses realized/net floating P/L, exposure and recovery gate.
//==================================================================

double BRX_DirectionalProfit(int direction){return(DirectionBasketProfit(direction));}

double BRX_BasketProfit(){return(DirectionBasketProfit(OP_BUY)+DirectionBasketProfit(OP_SELL));}

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

bool BRX_RecoveryAllowed(int direction){
   return(R10RecoveryAllowBasketClose(direction));
}

bool BRX_CloseDirection(int direction){
   if(CountDirectionPositions(direction)<=0)return(false);
   if(!CanCloseLightBasket(direction))return(false);
   if(!BRX_RecoveryAllowed(direction))return(false);
   double before=BRX_DirectionalProfit(direction);
   bool closed=CloseDirectionPositionsRobust(direction);
   if(closed){
      CloseAllDirectionPending(direction);
      Print(EA_NAME," BRX DIRECTIONAL CLOSE: direction=",(direction==OP_BUY?"BUY":"SELL")," profit=",DoubleToString(before,2));
      CreateEngineActionMarker("BRX","DIRECTIONAL",direction,DirectionLots(direction));
   }else Print(EA_NAME," BRX DIRECTIONAL CLOSE FAILED: direction=",(direction==OP_BUY?"BUY":"SELL")," remaining=",CountDirectionPositions(direction));
   return(closed);
}

bool BRX_CloseBasket(){
   int buyCount=CountDirectionPositions(OP_BUY),sellCount=CountDirectionPositions(OP_SELL);
   if(buyCount<=0&&sellCount<=0)return(false);
   if(!R10RecoveryAllowBasketClose(OP_BUY)||!R10RecoveryAllowBasketClose(OP_SELL))return(false);
   double before=BRX_BasketProfit();
   bool buyOk=true,sellOk=true;
   if(buyCount>0)buyOk=CloseDirectionPositionsRobust(OP_BUY);
   if(sellCount>0)sellOk=CloseDirectionPositionsRobust(OP_SELL);
   if(buyOk&&sellOk){
      CloseAllDirectionPending(OP_BUY);CloseAllDirectionPending(OP_SELL);
      Print(EA_NAME," BRX BIDIRECTIONAL CLOSE: basketProfit=",DoubleToString(before,2)," buy=",buyCount," sell=",sellCount);
      CreateEngineActionMarker("BRX","BIDIRECTIONAL",HeavyDirection(),0.0);
      return(true);
   }
   Print(EA_NAME," BRX BIDIRECTIONAL CLOSE FAILED: buyRemaining=",CountDirectionPositions(OP_BUY)," sellRemaining=",CountDirectionPositions(OP_SELL));
   return(false);
}

bool BRX_DirectionalTargetReached(int direction){
   int count=CountDirectionPositions(direction);
   if(count<=1)return(false);
   double profit=BRX_DirectionalProfit(direction);
   if(profit<BRXDirectionalMinProfit)return(false);
   return(BRX_BEDirectionValid(direction));
}

bool BRX_BidirectionalTargetReached(){
   int total=CountDirectionPositions(OP_BUY)+CountDirectionPositions(OP_SELL);
   if(total<2)return(false);
   double profit=BRX_BasketProfit();
   if(profit<BRXBidirectionalMinProfit)return(false);
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
