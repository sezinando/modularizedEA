#property strict
#property version   "0.106"
#property description "EAGOLD - BUY/SELL independent machines - Rules 1 to 10 + R10.2 Recovery Realization + Dynamic Recovery Step Multiplier + Persistent Global Variables + Isolated R1 Admission Control"

//==================================================================
// EAGOLD MAIN EXECUTION UNIT
// Configuration and business engines are loaded from modules.
//==================================================================
#include "../Core/EAGOLD_Config.mqh"
#include "../Core/EAGOLD_Orders.mqh"
#include "../Core/EAGOLD_Execution.mqh"
#include "../Core/EAGOLD_Persistence.mqh"
#include "../UI/EAGOLD_ModularizationPanel.mqh"

string EA_NAME="EAGOLD";
string PANEL_PREFIX="EAGOLD_BT_";
string R10_MARKER_PREFIX="EAGOLD_R10_MARKER_";
string ENGINE_MARKER_PREFIX="EAGOLD_ENGINE_";
string TELEMETRY_PREFIX="EAGOLD_TELEM_";
string STATE_PREFIX="EAGOLD_STATE_";
double g_panelMinProfit=0.0;
double g_panelMaxLots=0.0;
bool g_panelInitialized=false;
bool g_r9HedgeActive=false;
int g_r9ProcessedTickets[];
datetime g_r10LastAction=0;
string g_r1LastDecision="DISABLED";
string g_r1LastReason="";
datetime g_r1LastDecisionTime=0;
bool g_r10RecoveryCycleActive=false;
double g_r10RecoveryStartEquity=0.0;
double g_r10RecoveryWorstEquity=0.0;

double PointsToPrice(double points){return(points*Point);}
double NormalizePrice(double price){return(NormalizeDouble(price,Digits));}
double NormalizeLot(double lot){if(lot<Lot)lot=Lot;if(MaxOpenLot>0.0&&lot>MaxOpenLot)lot=MaxOpenLot;return(NormalizeDouble(lot,DigitsLots));}

#include "../Engines/EAGOLD_R9.mqh"
#include "../Engines/EAGOLD_R10.mqh"
#include "../Engines/EAGOLD_Recovery.mqh"
#include "../Engines/EAGOLD_Lifecycle.mqh"
#include "../Engines/EAGOLD_R1_Admission.mqh"

