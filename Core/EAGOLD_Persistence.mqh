#ifndef EAGOLD_PERSISTENCE_MQH
#define EAGOLD_PERSISTENCE_MQH

//==================================================================
// PERSISTENCE POLICY
// - Inputs are NOT persisted. They remain the EA configuration contract.
// - Only non-reconstructible operational state and historical extrema are kept.
// - Runtime telemetry is calculated in memory/on demand.
// - Live operation may use terminal Global Variables for continuity.
// - Strategy Tester deliberately does NOT read or write terminal Global Variables.
// - GlobalVariablesFlush is reserved for forced live lifecycle checkpoints.
//
// Rationale: MQL4 documents that terminal Global Variables are shared with
// Strategy Tester and can therefore contaminate tests with previous state.
// Backtests must start from a clean in-memory state for every run.
//==================================================================

bool EAGOLD_PersistenceEnabled(){return(!IsTesting());}

string StateKey(string metric){return(STATE_PREFIX+Symbol()+"_"+IntegerToString(MagicNumber)+"_"+metric);}

double PersistMonotonicMin(string key,double currentValue){if(!GlobalVariableCheck(key))return(currentValue);double stored=GlobalVariableGet(key);return(currentValue<stored?currentValue:stored);}
double PersistMonotonicMax(string key,double currentValue){if(!GlobalVariableCheck(key))return(currentValue);double stored=GlobalVariableGet(key);return(currentValue>stored?currentValue:stored);}

// R13 capital is persisted as a two-slot snapshot. The inactive slot is
// written completely before the committed slot is switched. This prevents a
// restart from accepting a half-written capital state.
int R13PersistenceCommittedSlot(){
   string key=StateKey("R13_CAP_COMMIT_SLOT");
   if(!GlobalVariableCheck(key))return(-1);
   double stored=GlobalVariableGet(key);
   if(stored<0.0||stored>1.0)return(-1);
   return((int)MathRound(stored));
}

void LoadPersistedR13State(){
   if(!EAGOLD_PersistenceEnabled())return;
   int slot=R13PersistenceCommittedSlot();
   if(slot<0){
      Print(EA_NAME," R13 persistence: no committed snapshot; capital starts at zero.");
      return;
   }
   string versionKey=StateKey("R13_CAP_VERSION_"+IntegerToString(slot));
   if(!GlobalVariableCheck(versionKey)||MathAbs(GlobalVariableGet(versionKey)-1.0)>0.0000001){
      Print(EA_NAME," R13 persistence: invalid snapshot version; capital starts at zero.");
      return;
   }
   string availableKey=StateKey("R13_CAP_AVAILABLE_"+IntegerToString(slot));
   string usedKey=StateKey("R13_CAP_USED_"+IntegerToString(slot));
   string entryKey=StateKey("R13_LAST_ENTRY_"+IntegerToString(slot));
   if(!GlobalVariableCheck(availableKey)||!GlobalVariableCheck(usedKey)||!GlobalVariableCheck(entryKey)){
      Print(EA_NAME," R13 persistence: incomplete snapshot; capital starts at zero.");
      return;
   }
   double available=GlobalVariableGet(availableKey);
   double used=GlobalVariableGet(usedKey);
   datetime lastEntry=(datetime)GlobalVariableGet(entryKey);
   if(available<0.0||used<0.0){
      Print(EA_NAME," R13 persistence: invalid capital values; capital starts at zero.");
      return;
   }
   g_r13RecoveryCapitalAvailable=available;
   g_r13RecoveryCapitalUsed=used;
   g_r13LastEntry=lastEntry;
   Print(EA_NAME," R13 persistence restored: slot=",slot," available=$",DoubleToString(available,2)," used=$",DoubleToString(used,2)," lastEntry=",TimeToString(lastEntry,TIME_DATE|TIME_SECONDS));
}

void PersistR13State(bool force=false){
   if(!EAGOLD_PersistenceEnabled())return;
   static bool initialized=false;
   static double lastAvailable=-1.0,lastUsed=-1.0,lastEntry=0.0;
   if(!force&&initialized&&MathAbs(lastAvailable-g_r13RecoveryCapitalAvailable)<0.0000001&&MathAbs(lastUsed-g_r13RecoveryCapitalUsed)<0.0000001&&lastEntry==(double)g_r13LastEntry)return;

   int committed=R13PersistenceCommittedSlot();
   int target=(committed==0?1:0);
   string suffix=IntegerToString(target);
   GlobalVariableSet(StateKey("R13_CAP_VERSION_"+suffix),1.0);
   GlobalVariableSet(StateKey("R13_CAP_AVAILABLE_"+suffix),MathMax(0.0,g_r13RecoveryCapitalAvailable));
   GlobalVariableSet(StateKey("R13_CAP_USED_"+suffix),MathMax(0.0,g_r13RecoveryCapitalUsed));
   GlobalVariableSet(StateKey("R13_LAST_ENTRY_"+suffix),(double)g_r13LastEntry);
   // Commit is written last. A crash before this point leaves the previous
   // committed slot authoritative.
   GlobalVariableSet(StateKey("R13_CAP_COMMIT_SLOT"),(double)target);
   initialized=true;
   lastAvailable=g_r13RecoveryCapitalAvailable;
   lastUsed=g_r13RecoveryCapitalUsed;
   lastEntry=(double)g_r13LastEntry;
   if(force)GlobalVariablesFlush();
}

void PersistPanelExtrema(double currentProfit,double currentLots,double currentMaxProfit)
{
   // In Strategy Tester, panel extrema belong to the current test run only.
   if(!EAGOLD_PersistenceEnabled())return;

   string minKey=StateKey("PANEL_MIN_PROFIT");
   string maxProfitKey=StateKey("PANEL_MAX_PROFIT");
   string maxLotsKey=StateKey("MAX_ACCUM_LOTS");
   double persistedMin=PersistMonotonicMin(minKey,currentProfit);
   double persistedMaxProfit=PersistMonotonicMax(maxProfitKey,currentMaxProfit);
   double persistedMaxLots=PersistMonotonicMax(maxLotsKey,currentLots);
   if(!GlobalVariableCheck(minKey)||MathAbs(GlobalVariableGet(minKey)-persistedMin)>0.0000001)
      GlobalVariableSet(minKey,persistedMin);
   if(!GlobalVariableCheck(maxProfitKey)||MathAbs(GlobalVariableGet(maxProfitKey)-persistedMaxProfit)>0.0000001)
      GlobalVariableSet(maxProfitKey,persistedMaxProfit);
   if(!GlobalVariableCheck(maxLotsKey)||MathAbs(GlobalVariableGet(maxLotsKey)-persistedMaxLots)>0.0000001)
      GlobalVariableSet(maxLotsKey,persistedMaxLots);
}

void LoadPersistedStrategicState()
{
   if(!EAGOLD_PersistenceEnabled())return;

   if(GlobalVariableCheck(StateKey("g_r10RecoveryCycleActive")))g_r10RecoveryCycleActive=(GlobalVariableGet(StateKey("g_r10RecoveryCycleActive"))>0.5);
   if(GlobalVariableCheck(StateKey("g_r10RecoveryStartEquity")))g_r10RecoveryStartEquity=GlobalVariableGet(StateKey("g_r10RecoveryStartEquity"));
   if(GlobalVariableCheck(StateKey("g_r10RecoveryWorstEquity")))g_r10RecoveryWorstEquity=GlobalVariableGet(StateKey("g_r10RecoveryWorstEquity"));
   if(GlobalVariableCheck(StateKey("g_r10LastAction")))g_r10LastAction=(datetime)GlobalVariableGet(StateKey("g_r10LastAction"));
   if(GlobalVariableCheck(StateKey("g_r9HedgeActive")))g_r9HedgeActive=(GlobalVariableGet(StateKey("g_r9HedgeActive"))>0.5);
   if(GlobalVariableCheck(StateKey("PANEL_MIN_PROFIT")))g_panelMinProfit=GlobalVariableGet(StateKey("PANEL_MIN_PROFIT"));
   if(GlobalVariableCheck(StateKey("PANEL_MAX_PROFIT")))g_panelMaxProfit=GlobalVariableGet(StateKey("PANEL_MAX_PROFIT"));
   if(GlobalVariableCheck(StateKey("MAX_ACCUM_LOTS")))g_panelMaxLots=GlobalVariableGet(StateKey("MAX_ACCUM_LOTS"));
   LoadPersistedR13State();
}

void PersistStrategicState(bool force=false)
{
   if(!EAGOLD_PersistenceEnabled())return;

   static bool initialized=false;
   static double lastCycle=0.0,lastStart=0.0,lastWorstPersisted=0.0,lastAction=0.0,lastHedge=0.0;

   double cycle=g_r10RecoveryCycleActive?1.0:0.0;
   double hedge=g_r9HedgeActive?1.0:0.0;

   bool cycleChanged=MathAbs(lastCycle-cycle)>0.0000001;
   bool startChanged=MathAbs(lastStart-g_r10RecoveryStartEquity)>0.0000001;
   bool actionChanged=MathAbs(lastAction-(double)g_r10LastAction)>0.0000001;
   bool hedgeChanged=MathAbs(lastHedge-hedge)>0.0000001;

   double worstStep=PersistenceWorstEquityStep;
   if(worstStep<0.0)worstStep=0.0;
   bool worstSignificant=(MathAbs(lastWorstPersisted-g_r10RecoveryWorstEquity)>=worstStep);
   bool r13Changed=force||!initialized||MathAbs(g_r13RecoveryCapitalAvailable-GlobalVariableGet(StateKey("R13_LAST_AVAILABLE_CACHE")))>0.0000001||MathAbs(g_r13RecoveryCapitalUsed-GlobalVariableGet(StateKey("R13_LAST_USED_CACHE")))>0.0000001||MathAbs((double)g_r13LastEntry-GlobalVariableGet(StateKey("R13_LAST_ENTRY_CACHE")))>0.0000001;

   bool changed=force||!initialized||cycleChanged||startChanged||actionChanged||hedgeChanged||worstSignificant||r13Changed;
   if(!changed)return;

   GlobalVariableSet(StateKey("g_r10RecoveryCycleActive"),cycle);
   GlobalVariableSet(StateKey("g_r10RecoveryStartEquity"),g_r10RecoveryStartEquity);
   GlobalVariableSet(StateKey("g_r10RecoveryWorstEquity"),g_r10RecoveryWorstEquity);
   GlobalVariableSet(StateKey("g_r10LastAction"),(double)g_r10LastAction);
   GlobalVariableSet(StateKey("g_r9HedgeActive"),hedge);
   PersistR13State(force);
   GlobalVariableSet(StateKey("R13_LAST_AVAILABLE_CACHE"),g_r13RecoveryCapitalAvailable);
   GlobalVariableSet(StateKey("R13_LAST_USED_CACHE"),g_r13RecoveryCapitalUsed);
   GlobalVariableSet(StateKey("R13_LAST_ENTRY_CACHE"),(double)g_r13LastEntry);

   initialized=true;
   lastCycle=cycle;
   lastStart=g_r10RecoveryStartEquity;
   lastWorstPersisted=g_r10RecoveryWorstEquity;
   lastAction=(double)g_r10LastAction;
   lastHedge=hedge;

   if(force)GlobalVariablesFlush();
}

void PersistAllState(bool force=false)
{
   PersistStrategicState(force);
}

#endif
