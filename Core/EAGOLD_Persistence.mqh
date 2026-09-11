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

void PersistPanelExtrema(double currentProfit,double currentLots)
{
   // In Strategy Tester, panel extrema belong to the current test run only.
   if(!EAGOLD_PersistenceEnabled())return;

   string minKey=StateKey("PANEL_MIN_PROFIT");
   string maxKey=StateKey("MAX_ACCUM_LOTS");
   double persistedMin=PersistMonotonicMin(minKey,currentProfit);
   double persistedMax=PersistMonotonicMax(maxKey,currentLots);
   if(!GlobalVariableCheck(minKey)||MathAbs(GlobalVariableGet(minKey)-persistedMin)>0.0000001)
      GlobalVariableSet(minKey,persistedMin);
   if(!GlobalVariableCheck(maxKey)||MathAbs(GlobalVariableGet(maxKey)-persistedMax)>0.0000001)
      GlobalVariableSet(maxKey,persistedMax);
   // Deliberately no GlobalVariablesFlush() here. The terminal manages the
   // persistence of terminal-global variables; explicit disk flush is reserved
   // for forced live lifecycle checkpoints.
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
   if(GlobalVariableCheck(StateKey("MAX_ACCUM_LOTS")))g_panelMaxLots=GlobalVariableGet(StateKey("MAX_ACCUM_LOTS"));
}

void PersistStrategicState(bool force=false)
{
   // Backtests are intentionally stateless with respect to terminal GVs.
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

   // Important state transitions are persisted immediately. Worst-equity
   // telemetry is checkpointed only after the configured material movement.
   bool changed=force||!initialized||cycleChanged||startChanged||actionChanged||hedgeChanged||worstSignificant;
   if(!changed)return;

   GlobalVariableSet(StateKey("g_r10RecoveryCycleActive"),cycle);
   GlobalVariableSet(StateKey("g_r10RecoveryStartEquity"),g_r10RecoveryStartEquity);
   GlobalVariableSet(StateKey("g_r10RecoveryWorstEquity"),g_r10RecoveryWorstEquity);
   GlobalVariableSet(StateKey("g_r10LastAction"),(double)g_r10LastAction);
   GlobalVariableSet(StateKey("g_r9HedgeActive"),hedge);

   initialized=true;
   lastCycle=cycle;
   lastStart=g_r10RecoveryStartEquity;
   lastWorstPersisted=g_r10RecoveryWorstEquity;
   lastAction=(double)g_r10LastAction;
   lastHedge=hedge;

   // Only forced live lifecycle checkpoints hit disk synchronously.
   if(force)GlobalVariablesFlush();
}

void PersistAllState(bool force=false)
{
   PersistStrategicState(force);
}

#endif
