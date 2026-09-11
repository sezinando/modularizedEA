#ifndef EAGOLD_PERSISTENCE_MQH
#define EAGOLD_PERSISTENCE_MQH

// Persistence policy:
// - Inputs are NOT persisted. They remain the EA configuration contract.
// - Only non-reconstructible operational state and historical extrema are kept.
// - Runtime telemetry is calculated in memory/on demand.
// - GlobalVariablesFlush() is used only after an actual persistence event.

string StateKey(string metric){return(STATE_PREFIX+Symbol()+"_"+IntegerToString(MagicNumber)+"_"+metric);}

double PersistMonotonicMin(string key,double currentValue){if(!GlobalVariableCheck(key))return(currentValue);double stored=GlobalVariableGet(key);return(currentValue<stored?currentValue:stored);}
double PersistMonotonicMax(string key,double currentValue){if(!GlobalVariableCheck(key))return(currentValue);double stored=GlobalVariableGet(key);return(currentValue>stored?currentValue:stored);}

void PersistPanelExtrema(double currentProfit,double currentLots)
{
   string minKey=StateKey("PANEL_MIN_PROFIT");
   string maxKey=StateKey("MAX_ACCUM_LOTS");
   bool changed=false;
   double persistedMin=PersistMonotonicMin(minKey,currentProfit);
   double persistedMax=PersistMonotonicMax(maxKey,currentLots);
   g_panelMinProfit=persistedMin;
   g_panelMaxLots=persistedMax;
   if(!GlobalVariableCheck(minKey)||MathAbs(GlobalVariableGet(minKey)-persistedMin)>0.0000001){GlobalVariableSet(minKey,persistedMin);changed=true;}
   if(!GlobalVariableCheck(maxKey)||MathAbs(GlobalVariableGet(maxKey)-persistedMax)>0.0000001){GlobalVariableSet(maxKey,persistedMax);changed=true;}
   if(changed)GlobalVariablesFlush();
}

void LoadPersistedStrategicState()
{
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
   static bool initialized=false;
   static double lastCycle=0.0,lastStart=0.0,lastWorst=0.0,lastAction=0.0,lastHedge=0.0;
   double cycle=g_r10RecoveryCycleActive?1.0:0.0;
   double hedge=g_r9HedgeActive?1.0:0.0;
   double worstDelta=MathAbs(lastWorst-g_r10RecoveryWorstEquity);
   bool worstSignificant=(worstDelta>=1.0);
   bool changed=force||!initialized||MathAbs(lastCycle-cycle)>0.0000001||MathAbs(lastStart-g_r10RecoveryStartEquity)>0.0000001||worstSignificant||MathAbs(lastAction-(double)g_r10LastAction)>0.0000001||MathAbs(lastHedge-hedge)>0.0000001;
   if(!changed)return;
   GlobalVariableSet(StateKey("g_r10RecoveryCycleActive"),cycle);
   GlobalVariableSet(StateKey("g_r10RecoveryStartEquity"),g_r10RecoveryStartEquity);
   GlobalVariableSet(StateKey("g_r10RecoveryWorstEquity"),g_r10RecoveryWorstEquity);
   GlobalVariableSet(StateKey("g_r10LastAction"),(double)g_r10LastAction);
   GlobalVariableSet(StateKey("g_r9HedgeActive"),hedge);
   GlobalVariablesFlush();
   initialized=true;
   lastCycle=cycle;lastStart=g_r10RecoveryStartEquity;lastWorst=g_r10RecoveryWorstEquity;lastAction=(double)g_r10LastAction;lastHedge=hedge;
}

void PersistAllState(bool force=false)
{
   PersistStrategicState(force);
}

#endif
