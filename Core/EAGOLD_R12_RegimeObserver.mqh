#ifndef EAGOLD_R12_REGIME_OBSERVER_MQH
#define EAGOLD_R12_REGIME_OBSERVER_MQH

//==================================================================
// EAGOLD R12 REGIME OBSERVER v1.1
// Observer-only market regime classification for telemetry.
//
// CONTRACT
// - MUST NOT submit, modify or close orders.
// - MUST NOT change lot sizing, TP, BRX, R9, R10, R11 or R13 behavior.
// - Primary timeframe: M5.
// - Classification is based only on closed candles (shift 1+).
// - Persistence/transition fields are telemetry only.
// - This is a deterministic observer, not an adaptive trading gate.
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
   EAGOLD_R12_Regime previousRegime;
   datetime regimeStartTime;
   datetime previousRegimeChangeTime;
   int regimeTransitionCount;
   int regimeSequenceCount;
   string regimeSequence;
   double regimeDurationSec;
   double timeSinceRegimeChangeSec;
   bool regimeChange;
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

// History is deliberately kept outside g_r12State because Update() resets
// the output structure on every observation. These variables preserve the
// previous closed-candle classification across updates.
EAGOLD_R12_Regime g_r12PreviousRegime=EAGOLD_R12_UNKNOWN;
datetime g_r12RegimeStartTime=0;
datetime g_r12LastRegimeChangeTime=0;
int g_r12TransitionCount=0;
int g_r12SequenceCount=0;
string g_r12RegimeSequence="";

evoid EAGOLD_R12Reset(EAGOLD_R12_State &s)
{
   s.time=0;
   s.regime=EAGOLD_R12_UNKNOWN;
   s.previousRegime=EAGOLD_R12_UNKNOWN;
   s.regimeStartTime=0;
   s.previousRegimeChangeTime=0;
   s.regimeTransitionCount=0;
   s.regimeSequenceCount=0;
   s.regimeSequence="";
   s.regimeDurationSec=0.0;
   s.timeSinceRegimeChangeSec=0.0;
   s.regimeChange=false;
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

   EAGOLD_R12_Regime current=EAGOLD_R12_CONFLICT;
   if(highVol)current=EAGOLD_R12_HIGH_VOLATILITY;
   else if(exhaustion)current=EAGOLD_R12_EXHAUSTION;
   else if(bullStructure)current=EAGOLD_R12_BULLISH_TREND;
   else if(bearStructure)current=EAGOLD_R12_BEARISH_TREND;
   else if(bullPullback)current=EAGOLD_R12_BULLISH_PULLBACK;
   else if(bearPullback)current=EAGOLD_R12_BEARISH_PULLBACK;
   else if(bullTransition)current=EAGOLD_R12_TRANSITION_BULLISH;
   else if(bearTransition)current=EAGOLD_R12_TRANSITION_BEARISH;
   else if(lowVol)current=EAGOLD_R12_LOW_VOLATILITY;

   EAGOLD_R12_Regime previous=g_r12PreviousRegime;
   datetime currentTime=iTime(Symbol(),PERIOD_M5,sh);
   bool changed=(previous!=EAGOLD_R12_UNKNOWN && current!=previous);

   if(previous==EAGOLD_R12_UNKNOWN || g_r12RegimeStartTime<=0)
   {
      g_r12RegimeStartTime=currentTime;
      g_r12LastRegimeChangeTime=currentTime;
      g_r12SequenceCount=1;
      g_r12RegimeSequence=EAGOLD_R12_RegimeName(current);
      g_r12TransitionCount=0;
      changed=false;
   }
   else if(changed)
   {
      g_r12TransitionCount++;
      g_r12SequenceCount++;
      g_r12RegimeStartTime=currentTime;
      g_r12LastRegimeChangeTime=currentTime;
      string nextName=EAGOLD_R12_RegimeName(current);
      if(g_r12RegimeSequence=="")g_r12RegimeSequence=nextName;
      else g_r12RegimeSequence=g_r12RegimeSequence+">"+nextName;
      // Prevent unbounded telemetry strings during long EA sessions.
      if(StringLen(g_r12RegimeSequence)>900)
      {
         int cut=StringFind(g_r12RegimeSequence,">");
         if(cut>=0)g_r12RegimeSequence=StringSubstr(g_r12RegimeSequence,cut+1);
      }
   }

   s.time=currentTime;
   s.regime=current;
   s.previousRegime=previous;
   s.regimeStartTime=g_r12RegimeStartTime;
   s.previousRegimeChangeTime=g_r12LastRegimeChangeTime;
   s.regimeTransitionCount=g_r12TransitionCount;
   s.regimeSequenceCount=g_r12SequenceCount;
   s.regimeSequence=g_r12RegimeSequence;
   s.regimeDurationSec=(double)MathMax(0,(int)(currentTime-g_r12RegimeStartTime));
   s.timeSinceRegimeChangeSec=(double)MathMax(0,(int)(currentTime-g_r12LastRegimeChangeTime));
   s.regimeChange=changed;
   s.close=close;
   s.atr=atr;
   s.atrRatio=atrRatio;
   s.drift=drift;
   s.slopeFast=slopeFast;
   s.slopeSlow=slopeSlow;
   s.rangeRatio=rangeRatio;
   s.bodyRatio=bodyRatio;
   s.valid=true;

   // Commit history only after the complete observation is valid.
   g_r12PreviousRegime=current;
   return(true);
}

#endif
