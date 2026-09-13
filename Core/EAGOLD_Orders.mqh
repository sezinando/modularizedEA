#ifndef EAGOLD_ORDERS_MQH
#define EAGOLD_ORDERS_MQH

// EAGOLD order recognition supports two explicit modes:
// 1) Magic mode: manage only orders matching MagicNumber on this symbol.
// 2) Symbol/PAR mode: manage all orders on this symbol regardless of Magic,
//    except the reserved R13 Magic namespace.
// This preserves strict Magic ownership by default while allowing an operator
// to deliberately reattach an existing PAR/basket with mixed Magic numbers.
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

bool EAGOLDAllSymbolRecognitionAllowed(){
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

   if(EAGOLDAllSymbolRecognitionAllowed())
   {
      int symbolOrders=0;
      for(int i=OrdersTotal()-1;i>=0;i--)
      {
         if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
         if(OrderSymbol()!=Symbol())continue;
         if(OrderMagicNumber()==R13MagicNumber)continue;
         symbolOrders++;
      }
      Print(EA_NAME," PAR REATTACH MODE ENABLED: ",symbolOrders," open order(s) on ",Symbol()," will be recognized regardless of MagicNumber. R13 Magic=",R13MagicNumber," remains isolated.");
      return(true);
   }

   if(RequireCleanLegacyOwnership){
      int legacy=CountLegacyMagicOrders();
      if(legacy>0){
         Print(EA_NAME," OWNERSHIP BLOCKED: ",legacy," open order(s) on ",Symbol()," still use legacy MagicNumber=-1. Use PAR reattach mode only when this entire symbol basket is intended for EAGOLD.");
         return(false);
      }
   }

   Print(EA_NAME," MAGIC OWNERSHIP MODE: recognizing only MagicNumber=",MagicNumber," on ",Symbol(),". R13 Magic=",R13MagicNumber," remains isolated.");
   return(true);
}

bool IsEAGOLDOrder(){
   if(OrderSymbol()!=Symbol())return(false);
   // R13 uses a reserved Magic and is never part of the Master universe.
   if(OrderMagicNumber()==R13MagicNumber)return(false);
   if(MagicNumber<=0)return(false);

   // Explicit PAR/Symbol mode: every open order on the current symbol is
   // recognized, independent of MagicNumber, except R13 above.
   if(EAGOLDAllSymbolRecognitionAllowed())return(true);

   // Default Magic mode: only the configured EAGOLD Magic is recognized.
   return(OrderMagicNumber()==MagicNumber);
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
