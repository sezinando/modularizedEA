#ifndef EAGOLD_ORDERS_MQH
#define EAGOLD_ORDERS_MQH

// EAGOLD order ownership and exposure measurement.
// Master ownership is Symbol + dedicated MagicNumber.
// Legacy MagicNumber == -1 can be explicitly reattached for the current
// symbol only when EnableLegacyReattach=true. It is never an account-wide
// ownership mode.
// R13 owns a reserved Magic namespace and is never part of the Master universe.
// Comment is observational only and never establishes ownership.

bool IsR13Order(){
   if(OrderSymbol()!=Symbol())return(false);
   return(OrderMagicNumber()==R13MagicNumber);
}

bool IsR13OwnershipConfigurationValid(){
   if(R13MagicNumber<=0)return(false);
   if(MagicNumber<=0)return(false);
   if(R13MagicNumber==MagicNumber)return(false);
   return(true);
}

int CountLegacyMagicOrders(){
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(OrderSymbol()!=Symbol())continue;
      if(OrderMagicNumber()==-1)count++;
   }
   return(count);
}

bool EAGOLDLegacyReattachAllowed(){
   return(EnableLegacyReattach);
}

bool EAGOLDValidateOwnershipConfiguration(){
   if(MagicNumber<=0){
      Print(EA_NAME," OWNERSHIP BLOCKED: Master MagicNumber must be > 0. Current=",MagicNumber);
      return(false);
   }
   if(R13MagicNumber<=0){
      Print(EA_NAME," OWNERSHIP BLOCKED: R13 MagicNumber must be > 0. Current=",R13MagicNumber);
      return(false);
   }
   if(MagicNumber==R13MagicNumber){
      Print(EA_NAME," OWNERSHIP BLOCKED: Master MagicNumber collides with R13 MagicNumber. Magic=",MagicNumber);
      return(false);
   }
   if(RequireCleanLegacyOwnership && !EAGOLDLegacyReattachAllowed()){
      int legacy=CountLegacyMagicOrders();
      if(legacy>0){
         Print(EA_NAME," OWNERSHIP BLOCKED: ",legacy," open order(s) on ",Symbol()," still use legacy MagicNumber=-1. Enable EnableLegacyReattach only for an intentional legacy recovery session.");
         return(false);
      }
   }
   if(EAGOLDLegacyReattachAllowed()){
      int legacyReattach=CountLegacyMagicOrders();
      if(legacyReattach>0)
         Print(EA_NAME," LEGACY REATTACH ENABLED: ",legacyReattach," order(s) with MagicNumber=-1 on ",Symbol()," will be included in the EAGOLD Master view for this chart only.");
   }
   return(true);
}

bool IsEAGOLDOrder(){
   if(OrderSymbol()!=Symbol())return(false);
   // R13 uses a reserved Magic and is never part of the Master universe.
   if(OrderMagicNumber()==R13MagicNumber)return(false);
   // Strict dedicated ownership is the default.
   if(MagicNumber<=0)return(false);
   if(OrderMagicNumber()==MagicNumber)return(true);
   // Explicit legacy reattach: -1 is accepted only for the current symbol
   // and only while the operator has deliberately enabled the reattach mode.
   if(EAGOLDLegacyReattachAllowed() && OrderMagicNumber()==-1)return(true);
   return(false);
}

int CountOrdersByType(int type){int count=0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder())continue;if(OrderType()==type)count++;}return(count);}

int CountDirectionPositions(int direction){return(CountOrdersByType(direction==OP_BUY?OP_BUY:OP_SELL));}

int CountDirectionPending(int direction){return(CountOrdersByType(direction==OP_BUY?OP_BUYSTOP:OP_SELLSTOP));}

int CountEAGOLDOrders(){int count=0;for(int i=OrdersTotal()-1;i>=0;i--){if(!IsEAGOLDOrder())continue;count++;}return(count);}

double DirectionBasketProfit(int direction){int type=(direction==OP_BUY?OP_BUY:OP_SELL);double total=0.0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;total+=OrderProfit()+OrderSwap()+OrderCommission();}return(total);}

double DirectionLots(int direction){int type=(direction==OP_BUY?OP_BUY:OP_SELL);double total=0.0;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;total+=OrderLots();}return(total);}

double ExposureLots(){return(MathAbs(DirectionLots(OP_BUY)-DirectionLots(OP_SELL)));}

int HeavyDirection(){double b=DirectionLots(OP_BUY),s=DirectionLots(OP_SELL);if(b>s)return(OP_BUY);if(s>b)return(OP_SELL);return(-1);}

double EAGOLDAccumulatedProfit(){double total=0.0;for(int i=OrdersHistoryTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))continue;if(!IsEAGOLDOrder())continue;int type=OrderType();if(type==OP_BUY||type==OP_SELL)total+=OrderProfit()+OrderSwap()+OrderCommission();}return(total);}

// Closed EAGOLD result for the current broker/server day only.
double EAGOLDTodayProfit(){
   double total=0.0;
   datetime dayStart=StringToTime(TimeToString(TimeCurrent(),TIME_DATE));
   datetime now=TimeCurrent();
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))continue;
      if(!IsEAGOLDOrder())continue;
      int type=OrderType();
      if(type!=OP_BUY&&type!=OP_SELL)continue;
      datetime closeTime=OrderCloseTime();
      if(closeTime<dayStart||closeTime>now)continue;
      total+=OrderProfit()+OrderSwap()+OrderCommission();
   }
   return(total);
}

#endif
