#ifndef EAGOLD_R13_SATELLITE_MQH
#define EAGOLD_R13_SATELLITE_MQH

// R13 Recovery Satellite — Stage 1: Observer only.
// Contract: measure/classify eligibility without OrderSend/OrderClose.
// This module deliberately produces telemetry only; no trading action is authorized.

#define R13_REGIME_OFF       0
#define R13_REGIME_RANGE     1
#define R13_REGIME_TREND     2
#define R13_REGIME_HIGH_VOL  3
#define R13_REGIME_EXTREME   4

struct R13ObserverState{
   bool configValid;
   bool enabled;
   bool eligible;
   int regime;
   double atrPoints;
   double rangePoints;
   double relativeVolatility;
   double driftPoints;
   double masterExposureLots;
   double masterDrawdown;
   double satelliteLots;
   double satelliteProfit;
   int satellitePositions;
   string reason;
};

void R13ResetObserverState(R13ObserverState &state){
   state.configValid=false;
   state.enabled=false;
   state.eligible=false;
   state.regime=R13_REGIME_OFF;
   state.atrPoints=0.0;
   state.rangePoints=0.0;
   state.relativeVolatility=0.0;
   state.driftPoints=0.0;
   state.masterExposureLots=0.0;
   state.masterDrawdown=0.0;
   state.satelliteLots=0.0;
   state.satelliteProfit=0.0;
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
   for(int shift=1;shift<=count;shift++){
      double high=iHigh(Symbol(),Period(),shift);
      double low=iLow(Symbol(),Period(),shift);
      double prevClose=iClose(Symbol(),Period(),shift+1);
      if(high<=0.0||low<=0.0||prevClose<=0.0)continue;
      double tr=MathMax(high-low,MathMax(MathAbs(high-prevClose),MathAbs(low-prevClose)));
      sum+=tr/Point;
   }
   return(sum/count);
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

   // Conservative observer thresholds. They are classification heuristics only.
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

void R13Observe(R13ObserverState &state){
   R13ResetObserverState(state);
   state.configValid=IsR13OwnershipConfigurationValid();
   state.enabled=EnableR13;
   state.masterExposureLots=ExposureLots();
   state.satelliteLots=R13OwnLots();
   state.satelliteProfit=R13OwnProfit();
   state.satellitePositions=R13CountOwnPositions();

   if(!state.configValid){state.reason="INVALID_OWNERSHIP_CONFIG";return;}
   if(!state.enabled){state.reason="DISABLED";return;}

   int period=14;
   state.atrPoints=R13AverageTrueRangePoints(period);
   state.rangePoints=R13WindowRangePoints(period);
   state.driftPoints=R13WindowDriftPoints(period);
   state.relativeVolatility=(state.atrPoints>0.0?state.rangePoints/state.atrPoints:0.0);
   state.regime=R13ClassifyRegime(state.atrPoints,state.rangePoints,state.driftPoints);

   // First observer contract: R13 is eligible only in RANGE and only while
   // the Master is meaningfully unbalanced. No execution is performed here.
   state.eligible=(state.regime==R13_REGIME_RANGE &&
                   state.masterExposureLots>=R13MinDirectionalImbalance &&
                   state.satellitePositions<R13MaxPositions);
   state.reason=state.eligible?"ELIGIBLE_RANGE":"REGIME_OR_MASTER_GATE";
}

#endif
