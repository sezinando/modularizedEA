#ifndef EAGOLD_R12_REGIME_OBSERVER_MQH
#define EAGOLD_R12_REGIME_OBSERVER_MQH

//==================================================================
// EAGOLD R12 REGIME OBSERVER v1.0
// Observer-only market regime classification for telemetry.
//
// CONTRACT
// - MUST NOT submit, modify or close orders.
// - MUST NOT change lot sizing, TP, BRX, R9, R10, R11 or R13 behavior.
// - Primary timeframe: M5.
// - Classification is based only on closed candles (shift 1+).
// - This is a deterministic first observer, not an adaptive trading gate.
//==================================================================

enum EAGOLD_R12_Regime
{
   EAGOLD_R12_UNKNOWN=0,
   EAGOLD_R12_BULLISH_TREND=1,
   EAGOLD_R12_BEARISH_TREND=2,
   EAGOLD_R12_BULLISH_PULLBACK=3,
   EAGOLD_R12_BEARISH_PULLBACK=4,
   EAGOLD_R12_HIGH_VOLATILITY=5,
   EAGOLD_R12_LOW_VOLATILITY=6,
   EAGOLD_R12_TRANSITION_BULLISH=7,
   EAGOLD_R12_TRANSITION_BEARISH=8,
   EAGOLD_R12_EXHAUSTION=9,
   EAGOLD_R12_CONFLICT=10
};

string EAGOLD_R12_RegimeName(EAGOLD_R12_Regime r)
{
   if(r==EAGOLD_R12_BULLISH_TREND)return("BULLISH_TREND");
   if(r==EAGOLD_R12_BEARISH_TREND)return("BEARISH_TREND");
   if(r==EAGOLD_R12_BULLISH_PULLBACK)return("BULLISH_PULLBACK");
   if(r==EAGOLD_R12_BEARISH_PULLBACK)return("BEARISH_PULLBACK");
   if(r==EAGOLD_R12_HIGH_VOLATILITY)return("HIGH_VOLATILITY");
   if(r==EAGOLD_R12_LOW_VOLATILITY)return("LOW_VOLATILITY");
   if(r==EAGOLD_R12_TRANSITION_BULLISH)return("TRANSITION_BULLISH");
   if(r==EAGOLD_R12_TRANSITION_BEARISH)return("TRANSITION_BEARISH");
   if(r==EAGOLD_R12_EXHAUSTION)return("EXHAUSTION");
   if(r==EAGOLD_R12_CONFLICT)return("CONFLICT");
   return("UNKNOWN");
}

struct EAGOLD_R12_State
{
   datetime time;
   EAGOLD_R12_Regime regime;
   double close;
   double atr;
   double atrRatio;
   double drift;
   double slopeFast;
   double slopeSlow;
   double rangeRatio;
   double bodyRatio;
   bool valid;
};

EAGOLD_R12_State g_r12State;

void EAGOLD_R12Reset(EAGOLD_R12_State &s)
{
   s.time=0;
   s.regime=EAGOLD_R12_UNKNOWN;
   s.close=0.0;
   s.atr=0.0;
   s.atrRatio=0.0;
   s.drift=0.0;
   s.slopeFast=0.0;
   s.slopeSlow=0.0;
   s.rangeRatio=0.0;
   s.bodyRatio=0.0;
   s.valid=false;
}

double EAGOLD_R12SMA(int period,int shift)
{
   return(iMA(Symbol(),PERIOD_M5,period,0,MODE_SMA,PRICE_CLOSE,shift));
}

double EAGOLD_R12ATR(int period,int shift)
{
   return(iATR(Symbol(),PERIOD_M5,period,shift));
}

bool EAGOLD_R12Update(EAGOLD_R12_State &s)
{
   EAGOLD_R12Reset(s);
   if(iBars(Symbol(),PERIOD_M5)<40)return(false);

   int sh=1;
   double close=iClose(Symbol(),PERIOD_M5,sh);
   double atr=EAGOLD_R12ATR(14,sh);
   double atrPrev=EAGOLD_R12ATR(14,sh+5);
   double fast=EAGOLD_R12SMA(9,sh);
   double fastPrev=EAGOLD_R12SMA(9,sh+3);
   double slow=EAGOLD_R12SMA(21,sh);
   double slowPrev=EAGOLD_R12SMA(21,sh+3);
   double olderClose=iClose(Symbol(),PERIOD_M5,sh+6);
   double range=iHigh(Symbol(),PERIOD_M5,sh)-iLow(Symbol(),PERIOD_M5,sh);
   double body=MathAbs(iClose(Symbol(),PERIOD_M5,sh)-iOpen(Symbol(),PERIOD_M5,sh));

   if(atr<=0.0 || atrPrev<=0.0 || close<=0.0 || olderClose<=0.0)return(false);

   double atrRatio=atr/atrPrev;
   double drift=(close-olderClose)/atr;
   double slopeFast=(fast-fastPrev)/atr;
   double slopeSlow=(slow-slowPrev)/atr;
   double rangeRatio=range/atr;
   double bodyRatio=(range>0.0?body/range:0.0);

   bool highVol=(atrRatio>=1.50 || rangeRatio>=2.00);
   bool lowVol=(atrRatio<=0.70 && rangeRatio<=1.00);
   bool bullStructure=(fast>slow && slopeFast>0.10 && slopeSlow>0.03 && drift>0.35);
   bool bearStructure=(fast<slow && slopeFast<-0.10 && slopeSlow<-0.03 && drift<-0.35);
   bool bullPullback=(fast>slow && drift<=0.35 && close<fast && slopeSlow>=0.0);
   bool bearPullback=(fast<slow && drift>=-0.35 && close>fast && slopeSlow<=0.0);
   bool bullTransition=(fast>slow && slopeFast>0.0 && slopeSlow<=0.03 && drift>0.0);
   bool bearTransition=(fast<slow && slopeFast<0.0 && slopeSlow>=-0.03 && drift<0.0);
   bool exhaustion=(MathAbs(drift)>=2.00 && bodyRatio>=0.70);

   s.time=iTime(Symbol(),PERIOD_M5,sh);
   s.close=close;
   s.atr=atr;
   s.atrRatio=atrRatio;
   s.drift=drift;
   s.slopeFast=slopeFast;
   s.slopeSlow=slopeSlow;
   s.rangeRatio=rangeRatio;
   s.bodyRatio=bodyRatio;
   s.valid=true;

   // Priority intentionally puts exceptional volatility first, then
   // directional structure, then pullback/transition/consolidation.
   if(highVol)s.regime=EAGOLD_R12_HIGH_VOLATILITY;
   else if(exhaustion)s.regime=EAGOLD_R12_EXHAUSTION;
   else if(bullStructure)s.regime=EAGOLD_R12_BULLISH_TREND;
   else if(bearStructure)s.regime=EAGOLD_R12_BEARISH_TREND;
   else if(bullPullback)s.regime=EAGOLD_R12_BULLISH_PULLBACK;
   else if(bearPullback)s.regime=EAGOLD_R12_BEARISH_PULLBACK;
   else if(bullTransition)s.regime=EAGOLD_R12_TRANSITION_BULLISH;
   else if(bearTransition)s.regime=EAGOLD_R12_TRANSITION_BEARISH;
   else if(lowVol)s.regime=EAGOLD_R12_LOW_VOLATILITY;
   else s.regime=EAGOLD_R12_CONFLICT;

   return(true);
}

#endif
