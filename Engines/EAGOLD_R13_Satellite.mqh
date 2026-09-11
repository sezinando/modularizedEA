#ifndef EAGOLD_R13_SATELLITE_MQH
#define EAGOLD_R13_SATELLITE_MQH

//==================================================================
// R13 RECOVERY SATELLITE
// Initial operating contract:
//   1) work in parallel with the Master;
//   2) take only the complementary direction while Master is exposed;
//   3) realize Satellite profit independently;
//   4) realized positive R13 profit may fund an R10 average adjustment;
//   5) when Master exposure goes to zero, R13 must leave the market.
//
// This stage intentionally does NOT attempt the later range-entry,
// persistence, capital-reserve or advanced recovery policies.
//==================================================================

#define R13_REGIME_OFF       0
#define R13_REGIME_RANGE     1
#define R13_REGIME_TREND     2
#define R13_REGIME_HIGH_VOL  3
#define R13_REGIME_EXTREME   4

struct R13ObserverState{
   bool configValid;
   bool enabled;
   bool tradingEnabled;
   bool eligible;
   int regime;
   int masterDirection;
   int satelliteDirection;
   double atrPoints;
   double rangePoints;
   double relativeVolatility;
   double driftPoints;
   double masterExposureLots;
   double masterDrawdown;
   double satelliteLots;
   double satelliteProfit;
   double recoveryCapital;
   double recoveryCapitalUsed;
   int satellitePositions;
   string reason;
};

datetime g_r13LastEntry=0;
double g_r13RecoveryCapitalAvailable=0.0;
double g_r13RecoveryCapitalUsed=0.0;

double R13TodayClosedNetProfit(){
   datetime now=TimeCurrent();
   datetime dayStart=StringToTime(TimeToString(now,TIME_DATE));
   double total=0.0;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))continue;
      if(!IsR13Order())continue;
      int type=OrderType();
      if(type!=OP_BUY&&type!=OP_SELL)continue;
      if(OrderCloseTime()<dayStart)continue;
      total+=OrderProfit()+OrderSwap()+OrderCommission();
   }
   return(total);
}

void R13ResetObserverState(R13ObserverState &state){
   state.configValid=false;
   state.enabled=false;
   state.tradingEnabled=false;
   state.eligible=false;
   state.regime=R13_REGIME_OFF;
   state.masterDirection=-1;
   state.satelliteDirection=-1;
   state.atrPoints=0.0;
   state.rangePoints=0.0;
   state.relativeVolatility=0.0;
   state.driftPoints=0.0;
   state.masterExposureLots=0.0;
   state.masterDrawdown=0.0;
   state.satelliteLots=0.0;
   state.satelliteProfit=0.0;
   state.recoveryCapital=g_r13RecoveryCapitalAvailable;
   state.recoveryCapitalUsed=g_r13RecoveryCapitalUsed;
   state.satellitePositions=0;
   state.reason="OFF";
}

int R13CountOwnPositions(){
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsR13Order())continue;
      int type=OrderType();
      if(type==OP_BUY||type==OP_SELL)count++;
   }
   return(count);
}

double R13OwnLots(){
   double lots=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsR13Order())continue;
      int type=OrderType();
      if(type==OP_BUY||type==OP_SELL)lots+=OrderLots();
   }
   return(lots);
}

int R13OwnDirection(){
   double buy=0.0,sell=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsR13Order())continue;
      if(OrderType()==OP_BUY)buy+=OrderLots();
      else if(OrderType()==OP_SELL)sell+=OrderLots();
   }
   if(buy>sell)return(OP_BUY);
   if(sell>buy)return(OP_SELL);
   return(-1);
}

double R13OwnProfit(){
   double profit=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsR13Order())continue;
      int type=OrderType();
      if(type==OP_BUY||type==OP_SELL)profit+=OrderProfit()+OrderSwap()+OrderCommission();
   }
   return(profit);
}

double R13AverageTrueRangePoints(int period){
   if(period<=0)return(0.0);
   int available=Bars-1;
   if(available<=0)return(0.0);
   int count=MathMin(period,available);
   double sum=0.0;
   int valid=0;
   for(int shift=1;shift<=count;shift++){
      double high=iHigh(Symbol(),Period(),shift);
      double low=iLow(Symbol(),Period(),shift);
      double prevClose=iClose(Symbol(),Period(),shift+1);
      if(high<=0.0||low<=0.0||prevClose<=0.0)continue;
      double tr=MathMax(high-low,MathMax(MathAbs(high-prevClose),MathAbs(low-prevClose)));
      sum+=tr/Point;
      valid++;
   }
   return(valid>0?sum/valid:0.0);
}

double R13WindowRangePoints(int period){
   if(period<=0||Bars<=period)return(0.0);
   int highest=iHighest(Symbol(),Period(),MODE_HIGH,period,1);
   int lowest=iLowest(Symbol(),Period(),MODE_LOW,period,1);
   if(highest<0||lowest<0)return(0.0);
   return((iHigh(Symbol(),Period(),highest)-iLow(Symbol(),Period(),lowest))/Point);
}

double R13WindowDriftPoints(int period){
   if(period<=0||Bars<=period)return(0.0);
   double first=iClose(Symbol(),Period(),period);
   double last=iClose(Symbol(),Period(),1);
   if(first<=0.0||last<=0.0)return(0.0);
   return((last-first)/Point);
}

int R13ClassifyRegime(double atrPoints,double rangePoints,double driftPoints){
   if(atrPoints<=0.0||rangePoints<=0.0)return(R13_REGIME_OFF);
   double driftAbs=MathAbs(driftPoints);
   double driftRatio=driftAbs/rangePoints;
   double rangeToAtr=rangePoints/atrPoints;
   if(rangeToAtr>=4.0&&driftRatio<0.35)return(R13_REGIME_HIGH_VOL);
   if(rangeToAtr>=5.5||driftRatio>=0.75)return(R13_REGIME_EXTREME);
   if(driftRatio>=0.55)return(R13_REGIME_TREND);
   if(rangeToAtr>=1.5)return(R13_REGIME_RANGE);
   return(R13_REGIME_OFF);
}

string R13RegimeName(int regime){
   if(regime==R13_REGIME_RANGE)return("RANGE");
   if(regime==R13_REGIME_TREND)return("TREND");
   if(regime==R13_REGIME_HIGH_VOL)return("HIGH_VOL");
   if(regime==R13_REGIME_EXTREME)return("EXTREME");
   return("OFF");
}

int R13ComplementaryDirection(int masterDirection){
   if(masterDirection==OP_BUY)return(OP_SELL);
   if(masterDirection==OP_SELL)return(OP_BUY);
   return(-1);
}

bool R13WithinSchedule(){
   int hour=TimeHour(TimeCurrent());
   if(R13StartHour<=R13EndHour)return(hour>=R13StartHour&&hour<=R13EndHour);
   return(hour>=R13StartHour||hour<=R13EndHour);
}

bool R13RiskGate(int direction,double lots){
   if(!IsTradeAllowed())return(false);
   if(MarketInfo(Symbol(),MODE_TRADEALLOWED)<=0.0)return(false);
   double spread=MarketInfo(Symbol(),MODE_SPREAD);
   if(R13MaxSpread>0.0&&spread>R13MaxSpread)return(false);
   if(!R13WithinSchedule())return(false);
   double ownProfit=R13OwnProfit();
   if(R13MaxDrawdown>0.0&&ownProfit<=-R13MaxDrawdown)return(false);
   double today=R13TodayClosedNetProfit();
   if(R13MaxDailyLoss>0.0&&today<=-R13MaxDailyLoss)return(false);
   ResetLastError();
   double freeAfter=AccountFreeMarginCheck(Symbol(),direction,lots);
   if(freeAfter<=0.0||GetLastError()==134)return(false);
   return(true);
}

int R13SendMarket(int type,double lots){
   RefreshRates();
   lots=NormalizeDouble(lots,DigitsLots);
   if(lots<Lot)return(-1);
   double minLot=MarketInfo(Symbol(),MODE_MINLOT);
   double maxLot=MarketInfo(Symbol(),MODE_MAXLOT);
   if(lots<minLot)return(-1);
   if(maxLot>0.0&&lots>maxLot)lots=maxLot;
   double price=(type==OP_BUY?Ask:Bid);
   ResetLastError();
   int ticket=OrderSend(Symbol(),type,lots,NormalizePrice(price),0,0,0,R13OrderComment,R13MagicNumber,0,clrNONE);
   if(ticket<0)Print(EA_NAME," R13 OrderSend failed. type=",type," error=",GetLastError());
   else Print(EA_NAME," R13 ENTRY: ticket=",ticket," side=",(type==OP_BUY?"BUY":"SELL")," lots=",DoubleToString(lots,DigitsLots)," masterExposure=",DoubleToString(ExposureLots(),DigitsLots));
   return(ticket);
}

bool R13CloseTicket(int ticket,double &realized){
   realized=0.0;
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))return(false);
   if(!IsR13Order())return(false);
   int type=OrderType();
   if(type!=OP_BUY&&type!=OP_SELL)return(false);
   double lots=OrderLots();
   RefreshRates();
   double price=(type==OP_BUY?Bid:Ask);
   ResetLastError();
   if(!OrderClose(ticket,lots,NormalizePrice(price),0,clrNONE)){
      Print(EA_NAME," R13 close failed. ticket=",ticket," error=",GetLastError());
      return(false);
   }
   if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_HISTORY))realized=OrderProfit()+OrderSwap()+OrderCommission();
   return(true);
}

bool R13CloseAll(string reason,double &realizedTotal){
   realizedTotal=0.0;
   bool changed=false;
   for(int i=OrdersTotal()-1;i>=0;i--){
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsR13Order())continue;
      int type=OrderType();
      if(type!=OP_BUY&&type!=OP_SELL)continue;
      int ticket=OrderTicket();
      double realized=0.0;
      if(R13CloseTicket(ticket,realized)){realizedTotal+=realized;changed=true;}
   }
   if(changed)Print(EA_NAME," R13 EXIT: reason=",reason," realized=$",DoubleToString(realizedTotal,2));
   return(changed);
}

void R13AddRecoveryCapital(double realized){
   if(realized<=0.0||R13RecoveryCapitalFraction<=0.0)return;
   double added=realized*R13RecoveryCapitalFraction;
   g_r13RecoveryCapitalAvailable+=added;
   Print(EA_NAME," R13 RECOVERY CAPITAL: realized=$",DoubleToString(realized,2)," added=$",DoubleToString(added,2)," available=$",DoubleToString(g_r13RecoveryCapitalAvailable,2));
}

void R13TryFundMasterAdjustment(){
   if(!EnableR13MasterAdjustment||g_r13RecoveryCapitalAvailable<=0.0)return;
   double exposure=ExposureLots();
   if(exposure<R13MinDirectionalImbalance)return;
   int masterDirection=HeavyDirection();
   if(masterDirection<0)return;
   double used=0.0,reduced=0.0,loss=0.0;
   if(R10ProfitFundedAverageAdjustment(masterDirection,g_r13RecoveryCapitalAvailable,R13MasterAdjustmentMaxLots,used,reduced,loss)){
      g_r13RecoveryCapitalAvailable=MathMax(0.0,g_r13RecoveryCapitalAvailable-used);
      g_r13RecoveryCapitalUsed+=used;
      Print(EA_NAME," R13 -> R10 CAPITAL CONSUMED: side=",(masterDirection==OP_BUY?"BUY":"SELL")," reduced=",DoubleToString(reduced,DigitsLots)," loss=$",DoubleToString(MathAbs(loss),2)," used=$",DoubleToString(used,2)," remaining=$",DoubleToString(g_r13RecoveryCapitalAvailable,2));
   }
}

void R13ManageOpenPositions(int masterDirection,double masterExposure){
   int ownDirection=R13OwnDirection();
   double ownProfit=R13OwnProfit();
   if(R13CountOwnPositions()<=0)return;

   // Never allow the Satellite to remain aligned with the Master after a
   // directional flip. It is a hedge/satellite, not a second Master basket.
   int required=R13ComplementaryDirection(masterDirection);
   if(masterExposure<R13MinDirectionalImbalance){
      double realized=0.0;
      if(R13CloseWhenMasterFlat)R13CloseAll("MASTER_FLAT",realized);
      R13AddRecoveryCapital(realized);
      R13TryFundMasterAdjustment();
      return;
   }
   if(EnableR13DirectionalComplementarity&&required>=0&&ownDirection>=0&&ownDirection!=required){
      double realized=0.0;
      R13CloseAll("MASTER_DIRECTION_CHANGED",realized);
      R13AddRecoveryCapital(realized);
      R13TryFundMasterAdjustment();
      return;
   }
   if(R13ProfitTarget>0.0&&ownProfit>=R13ProfitTarget){
      double realized=0.0;
      R13CloseAll("R13_PROFIT_TARGET",realized);
      R13AddRecoveryCapital(realized);
      R13TryFundMasterAdjustment();
      return;
   }
}

void R13TryOpen(int masterDirection,double masterExposure,int regime){
   if(!EnableR13Trading)return;
   if(masterDirection<0||masterExposure<R13MinDirectionalImbalance)return;
   if(regime!=R13_REGIME_RANGE)return;
   if(R13CountOwnPositions()>0)return;
   if(R13EntryCooldownSeconds>0.0&&g_r13LastEntry>0&&TimeCurrent()-g_r13LastEntry<R13EntryCooldownSeconds)return;

   int direction=R13ComplementaryDirection(masterDirection);
   if(direction<0)return;
   double room=R13MaxLots-R13OwnLots();
   if(room<Lot)return;
   double lot=NormalizeDouble(MathMin(Lot,room),DigitsLots);
   double minLot=MarketInfo(Symbol(),MODE_MINLOT);
   if(lot<minLot||lot<Lot)return;
   if(!R13RiskGate(direction,lot))return;
   int ticket=R13SendMarket(direction,lot);
   if(ticket>0)g_r13LastEntry=TimeCurrent();
}

void R13Observe(R13ObserverState &state){
   R13ResetObserverState(state);
   state.configValid=IsR13OwnershipConfigurationValid();
   state.enabled=EnableR13;
   state.tradingEnabled=(EnableR13&&EnableR13Trading&&EnableR13AutoActivation);
   state.masterExposureLots=ExposureLots();
   state.masterDirection=HeavyDirection();
   state.satelliteDirection=R13OwnDirection();
   state.satelliteLots=R13OwnLots();
   state.satelliteProfit=R13OwnProfit();
   state.satellitePositions=R13CountOwnPositions();
   state.recoveryCapital=g_r13RecoveryCapitalAvailable;
   state.recoveryCapitalUsed=g_r13RecoveryCapitalUsed;

   if(!state.configValid){state.reason="INVALID_OWNERSHIP_CONFIG";return;}
   if(!state.enabled){state.reason="DISABLED";return;}

   int period=14;
   state.atrPoints=R13AverageTrueRangePoints(period);
   state.rangePoints=R13WindowRangePoints(period);
   state.driftPoints=R13WindowDriftPoints(period);
   state.relativeVolatility=(state.atrPoints>0.0?state.rangePoints/state.atrPoints:0.0);
   state.regime=R13ClassifyRegime(state.atrPoints,state.rangePoints,state.driftPoints);

   state.eligible=(state.regime==R13_REGIME_RANGE &&
                   state.masterExposureLots>=R13MinDirectionalImbalance &&
                   state.satellitePositions<R13MaxPositions);
   state.reason=state.eligible?"ELIGIBLE_RANGE":"REGIME_OR_MASTER_GATE";

   if(state.tradingEnabled){
      R13ManageOpenPositions(state.masterDirection,state.masterExposureLots);
      R13TryOpen(state.masterDirection,state.masterExposureLots,state.regime);
      // Refresh the observer values after any R13 action.
      state.masterExposureLots=ExposureLots();
      state.masterDirection=HeavyDirection();
      state.satelliteDirection=R13OwnDirection();
      state.satelliteLots=R13OwnLots();
      state.satelliteProfit=R13OwnProfit();
      state.satellitePositions=R13CountOwnPositions();
      state.recoveryCapital=g_r13RecoveryCapitalAvailable;
      state.recoveryCapitalUsed=g_r13RecoveryCapitalUsed;
   }
}

#endif
