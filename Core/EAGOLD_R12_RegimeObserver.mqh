#ifndef EAGOLD_R12_REGIME_OBSERVER_MQH
#define EAGOLD_R12_REGIME_OBSERVER_MQH

//==================================================================
// EAGOLD R12 REGIME OBSERVER v1.2
// Observer-only market regime classification for telemetry.
// Event-boundary history is accumulated between realization events.
//
// CONTRACT
// - MUST NOT submit, modify or close orders.
// - MUST NOT change lot sizing, TP, BRX, R9, R10, R11 or R13 behavior.
// - Primary timeframe: M5.
// - Classification is based only on closed candles (shift 1+).
// - Persistence/history fields are telemetry only.
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
   int eventBoundaryTransitionCount;
   int eventBoundarySequenceCount;
   datetime eventBoundaryStartTime;
   datetime eventBoundaryLastChangeTime;
   string eventBoundaryRegimeSequence;
   double eventBoundaryDurationSec;
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
EAGOLD_R12_Regime g_r12PreviousRegime=EAGOLD_R12_UNKNOWN;
datetime g_r12RegimeStartTime=0;
datetime g_r12LastRegimeChangeTime=0;
int g_r12TransitionCount=0;
int g_r12SequenceCount=0;
string g_r12RegimeSequence="";

// Event-boundary history. Updated only when a new closed M5 candle is observed.
datetime g_r12LastObservedCandleTime=0;
datetime g_r12EventBoundaryStartTime=0;
datetime g_r12EventBoundaryLastChangeTime=0;
int g_r12EventBoundaryTransitionCount=0;
int g_r12EventBoundarySequenceCount=0;
string g_r12EventBoundaryRegimeSequence="";

void EAGOLD_R12Reset(EAGOLD_R12_State &s)
{
   s.time=0;s.regime=EAGOLD_R12_UNKNOWN;s.previousRegime=EAGOLD_R12_UNKNOWN;
   s.regimeStartTime=0;s.previousRegimeChangeTime=0;s.regimeTransitionCount=0;s.regimeSequenceCount=0;s.regimeSequence="";
   s.regimeDurationSec=0.0;s.timeSinceRegimeChangeSec=0.0;s.regimeChange=false;
   s.eventBoundaryTransitionCount=0;s.eventBoundarySequenceCount=0;s.eventBoundaryStartTime=0;s.eventBoundaryLastChangeTime=0;s.eventBoundaryRegimeSequence="";s.eventBoundaryDurationSec=0.0;
   s.close=0.0;s.atr=0.0;s.atrRatio=0.0;s.drift=0.0;s.slopeFast=0.0;s.slopeSlow=0.0;s.rangeRatio=0.0;s.bodyRatio=0.0;s.valid=false;
}

double EAGOLD_R12SMA(int period,int shift){return(iMA(Symbol(),PERIOD_M5,period,0,MODE_SMA,PRICE_CLOSE,shift));}
double EAGOLD_R12ATR(int period,int shift){return(iATR(Symbol(),PERIOD_M5,period,shift));}

void EAGOLD_R12AppendEventBoundary(EAGOLD_R12_Regime regime,datetime candleTime)
{
   string name=EAGOLD_R12_RegimeName(regime);
   if(g_r12EventBoundaryStartTime<=0)
   {
      g_r12EventBoundaryStartTime=candleTime;
      g_r12EventBoundaryLastChangeTime=candleTime;
      g_r12EventBoundaryTransitionCount=0;
      g_r12EventBoundarySequenceCount=1;
      g_r12EventBoundaryRegimeSequence=name;
      return;
   }
   if(g_r12EventBoundarySequenceCount<=0)
   {
      g_r12EventBoundarySequenceCount=1;
      g_r12EventBoundaryRegimeSequence=name;
      g_r12EventBoundaryStartTime=candleTime;
      g_r12EventBoundaryLastChangeTime=candleTime;
      return;
   }
   string lastName="";
   int pos=StringFind(g_r12EventBoundaryRegimeSequence,">");
   if(pos<0)lastName=g_r12EventBoundaryRegimeSequence;
   else
   {
      int scan=pos;
      while(scan>=0)
      {
         int next=StringFind(g_r12EventBoundaryRegimeSequence,">",scan+1);
         if(next<0){lastName=StringSubstr(g_r12EventBoundaryRegimeSequence,scan+1);break;}
         scan=next;
      }
   }
   if(name!=lastName)
   {
      g_r12EventBoundaryTransitionCount++;
      g_r12EventBoundarySequenceCount++;
      g_r12EventBoundaryLastChangeTime=candleTime;
      if(g_r12EventBoundaryRegimeSequence=="")g_r12EventBoundaryRegimeSequence=name;
      else g_r12EventBoundaryRegimeSequence=g_r12EventBoundaryRegimeSequence+">"+name;
      if(StringLen(g_r12EventBoundaryRegimeSequence)>900)
      {
         int cut=StringFind(g_r12EventBoundaryRegimeSequence,">");
         if(cut>=0)g_r12EventBoundaryRegimeSequence=StringSubstr(g_r12EventBoundaryRegimeSequence,cut+1);
      }
   }
}

void EAGOLD_R12ResetEventBoundary()
{
   if(!g_r12State.valid)return;
   g_r12EventBoundaryStartTime=g_r12State.time;
   g_r12EventBoundaryLastChangeTime=g_r12State.time;
   g_r12EventBoundaryTransitionCount=0;
   g_r12EventBoundarySequenceCount=1;
   g_r12EventBoundaryRegimeSequence=EAGOLD_R12_RegimeName(g_r12State.regime);
}

bool EAGOLD_R12Update(EAGOLD_R12_State &s)
{
   EAGOLD_R12Reset(s);
   if(iBars(Symbol(),PERIOD_M5)<40)return(false);
   int sh=1;
   double close=iClose(Symbol(),PERIOD_M5,sh),atr=EAGOLD_R12ATR(14,sh),atrPrev=EAGOLD_R12ATR(14,sh+5);
   double fast=EAGOLD_R12SMA(9,sh),fastPrev=EAGOLD_R12SMA(9,sh+3),slow=EAGOLD_R12SMA(21,sh),slowPrev=EAGOLD_R12SMA(21,sh+3);
   double olderClose=iClose(Symbol(),PERIOD_M5,sh+6),range=iHigh(Symbol(),PERIOD_M5,sh)-iLow(Symbol(),PERIOD_M5,sh),body=MathAbs(iClose(Symbol(),PERIOD_M5,sh)-iOpen(Symbol(),PERIOD_M5,sh));
   if(atr<=0.0||atrPrev<=0.0||close<=0.0||olderClose<=0.0)return(false);

   double atrRatio=atr/atrPrev,drift=(close-olderClose)/atr,slopeFast=(fast-fastPrev)/atr,slopeSlow=(slow-slowPrev)/atr,rangeRatio=range/atr,bodyRatio=(range>0.0?body/range:0.0);
   bool highVol=(atrRatio>=1.50||rangeRatio>=2.00),lowVol=(atrRatio<=0.70&&rangeRatio<=1.00);
   bool bullStructure=(fast>slow&&slopeFast>0.10&&slopeSlow>0.03&&drift>0.35),bearStructure=(fast<slow&&slopeFast<-0.10&&slopeSlow<-0.03&&drift<-0.35);
   bool bullPullback=(fast>slow&&drift<=0.35&&close<fast&&slopeSlow>=0.0),bearPullback=(fast<slow&&drift>=-0.35&&close>fast&&slopeSlow<=0.0);
   bool bullTransition=(fast>slow&&slopeFast>0.0&&slopeSlow<=0.03&&drift>0.0),bearTransition=(fast<slow&&slopeFast<0.0&&slopeSlow>=-0.03&&drift<0.0);
   bool exhaustion=(MathAbs(drift)>=2.00&&bodyRatio>=0.70);

   EAGOLD_R12_Regime current=EAGOLD_R12_CONFLICT;
   if(highVol)current=EAGOLD_R12_HIGH_VOLATILITY;else if(exhaustion)current=EAGOLD_R12_EXHAUSTION;else if(bullStructure)current=EAGOLD_R12_BULLISH_TREND;else if(bearStructure)current=EAGOLD_R12_BEARISH_TREND;else if(bullPullback)current=EAGOLD_R12_BULLISH_PULLBACK;else if(bearPullback)current=EAGOLD_R12_BEARISH_PULLBACK;else if(bullTransition)current=EAGOLD_R12_TRANSITION_BULLISH;else if(bearTransition)current=EAGOLD_R12_TRANSITION_BEARISH;else if(lowVol)current=EAGOLD_R12_LOW_VOLATILITY;

   EAGOLD_R12_Regime previous=g_r12PreviousRegime;datetime currentTime=iTime(Symbol(),PERIOD_M5,sh);bool changed=(previous!=EAGOLD_R12_UNKNOWN&&current!=previous);
   if(previous==EAGOLD_R12_UNKNOWN||g_r12RegimeStartTime<=0){g_r12RegimeStartTime=currentTime;g_r12LastRegimeChangeTime=currentTime;g_r12SequenceCount=1;g_r12RegimeSequence=EAGOLD_R12_RegimeName(current);g_r12TransitionCount=0;changed=false;}
   else if(changed){g_r12TransitionCount++;g_r12SequenceCount++;g_r12RegimeStartTime=currentTime;g_r12LastRegimeChangeTime=currentTime;string nextName=EAGOLD_R12_RegimeName(current);if(g_r12RegimeSequence=="")g_r12RegimeSequence=nextName;else g_r12RegimeSequence=g_r12RegimeSequence+">"+nextName;if(StringLen(g_r12RegimeSequence)>900){int cut=StringFind(g_r12RegimeSequence,">");if(cut>=0)g_r12RegimeSequence=StringSubstr(g_r12RegimeSequence,cut+1);}}

   // Boundary history advances once per newly closed M5 candle, not once per tick.
   if(g_r12LastObservedCandleTime!=currentTime)
   {
      EAGOLD_R12AppendEventBoundary(current,currentTime);
      g_r12LastObservedCandleTime=currentTime;
   }

   s.time=currentTime;s.regime=current;s.previousRegime=previous;s.regimeStartTime=g_r12RegimeStartTime;s.previousRegimeChangeTime=g_r12LastRegimeChangeTime;
   s.regimeTransitionCount=g_r12TransitionCount;s.regimeSequenceCount=g_r12SequenceCount;s.regimeSequence=g_r12RegimeSequence;
   s.regimeDurationSec=(double)MathMax(0,(int)(currentTime-g_r12RegimeStartTime));s.timeSinceRegimeChangeSec=(double)MathMax(0,(int)(currentTime-g_r12LastRegimeChangeTime));s.regimeChange=changed;
   s.eventBoundaryTransitionCount=g_r12EventBoundaryTransitionCount;s.eventBoundarySequenceCount=g_r12EventBoundarySequenceCount;s.eventBoundaryStartTime=g_r12EventBoundaryStartTime;s.eventBoundaryLastChangeTime=g_r12EventBoundaryLastChangeTime;s.eventBoundaryRegimeSequence=g_r12EventBoundaryRegimeSequence;s.eventBoundaryDurationSec=(double)MathMax(0,(int)(currentTime-g_r12EventBoundaryStartTime));
   s.close=close;s.atr=atr;s.atrRatio=atrRatio;s.drift=drift;s.slopeFast=slopeFast;s.slopeSlow=slopeSlow;s.rangeRatio=rangeRatio;s.bodyRatio=bodyRatio;s.valid=true;
   g_r12PreviousRegime=current;
   return(true);
}

#endif
