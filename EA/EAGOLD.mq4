#property strict
#property version "0.102"
#property description "EAGOLD Modular — migration baseline with legacy input contract"

// ============================================================
// GENERAL / IDENTITY
// ============================================================
input string INPUT_GROUP_GENERAL="=== GENERAL / IDENTITY ===";
extern int MagicNumber=3001;

// ============================================================
// CORE MONEY / LOT PROGRESSION
// ============================================================
input string INPUT_GROUP_MONEY="=== CORE MONEY / LOT PROGRESSION ===";
extern double Lot=0.01;
extern double Multiplier=1.10;
extern int DigitsLots=2;
extern double LotIncrement=0.02;
extern double MaxOpenLot=3.00;
extern double TakeProfit=5.00;
extern double SellProfit=30.00;
extern double BasketLoss=100.00;
extern int SpreadLimit=100;
extern int WaitSeconds=0;

// ============================================================
// R1 FIRST ENGINE / CORE
// ============================================================
input string INPUT_GROUP_R1_CORE="=== R1 FIRST ENGINE / CORE ===";
extern double FirstStep=160.0;

// ============================================================
// R1.1 FIRST ADMISSION CONTROL
// ============================================================
input string INPUT_GROUP_R1_ADMISSION="=== R1.1 FIRST ADMISSION CONTROL ===";
extern bool EnableR1AdmissionGate=false;
extern bool EnableR1BrokerGuard=false;
extern bool EnableR1LotGuard=false;
extern bool EnableR1MarginGuard=false;
extern bool EnableR1TradePermissionGuard=false;
extern double R1BrokerSafetyBufferPoints=0.0;
extern double R1MinFreeMarginAfterOrder=0.0;
extern bool EnableR1DecisionLog=true;

// ============================================================
// R4 / R5 / R7 LIFECYCLE
// ============================================================
input string INPUT_GROUP_LIFECYCLE="=== R4 / R5 / R7 LIFECYCLE ===";
extern double MiniGrid1=320.0;
extern double SmartGrid1=280.0;
extern double RecoveryMinDistance=340.0;
extern double MiniGrid2=80.0;
extern double SmartGrid2=60.0;
extern double PendingStepTrail=50.0;
extern double BasketRestartStep=160.0;
extern int MaxTrades=2000;
extern bool EnableCloseBy=true;
extern double BuyProgressionTolerance=10.0;

// ============================================================
// R9 EXPOSURE CONTROLLER
// ============================================================
input string INPUT_GROUP_R9="=== R9 EXPOSURE CONTROLLER ===";
extern bool EnableR9Hedge=true;
extern double R9ExposureTriggerLots=1.00;
extern double R9TriggerLotMinimum=0.00;
extern double R9HedgeFraction=0.6666666667;
extern double R9BalanceCap=0.50;

// ============================================================
// R10 EXPOSURE REDUCTION
// ============================================================
input string INPUT_GROUP_R10="=== R10 EXPOSURE REDUCTION ===";
extern bool EnableR10Reduce=true;
extern double R10MinExposureLots=0.01;
extern bool EnableR10PairReduction=true;
extern double R10PairMinProfit=5.00;
extern double R10PairMaxLots=1.00;
extern int R10PairCooldownSeconds=30;
extern bool EnableR10VisualMarker=true;
extern string R10MarkerFont="Arial Bold";
extern int R10MarkerFontSize=9;
extern color R10BuyMarkerColor=clrLime;
extern color R10SellMarkerColor=clrTomato;
extern double R10MarkerOffsetPoints=25.0;
extern bool EnableEngineActionMarkers=true;
extern int EngineActionMarkerFontSize=8;
extern double EngineActionMarkerOffsetPoints=18.0;

// ============================================================
// R10.2 RECOVERY REALIZATION
// ============================================================
input string INPUT_GROUP_R102="=== R10.2 RECOVERY REALIZATION ===";
extern bool EnableR10RecoveryRealization=false;
extern double R10RecoveryMinDebt=100.0;
extern double R10RecoveryProfitTarget=50.0;
extern double R10RecoveryDebtTargetPercent=0.0;
extern bool R10RecoveryRequireDebtRepaid=true;

// ============================================================
// R11 RECOVERY STEP CONTROL
// ============================================================
input string INPUT_GROUP_R11="=== R11 RECOVERY STEP CONTROL ===";
extern bool EnableRecoveryStepMultiplier=true;
extern double RecoveryStepMultiplier=1.15;
extern double RecoveryStepMax=500.0;

// ============================================================
// UI / PANEL
// ============================================================
input string INPUT_GROUP_UI="=== UI / PANEL ===";
extern int PanelBackgroundX=260;
extern int PanelBackgroundY=8;
extern int PanelBackgroundHeight=450;
extern int PanelBottomY=8;
extern int PanelBottomX1=15;
extern int PanelBottomX2=190;
extern int PanelBottomX3=520;
extern int PanelBottomX4=850;

// ============================================================
// MODULAR MIGRATION / RUNTIME
// ============================================================
input string INPUT_GROUP_MODULAR="=== MODULAR MIGRATION / RUNTIME ===";
extern bool EnableModularR10=false;

#include "../Core/EAGOLD_Context.mqh"
#include "../Core/EAGOLD_State.mqh"
#include "../Core/EAGOLD_Orders.mqh"
#include "../Core/EAGOLD_Execution.mqh"
#include "../Core/EAGOLD_Events.mqh"
#include "../Core/EAGOLD_Telemetry.mqh"
#include "../Core/EAGOLD_BootDiagnostics.mqh"
#include "../Persistence/EAGOLD_GlobalState.mqh"
#include "../UI/EAGOLD_Clock.mqh"
#include "../UI/EAGOLD_Panel.mqh"
#include "../Engines/R10/R10_Core.mqh"

EAGOLD_Context     g_ctx;
EAGOLD_BasketState g_state;
datetime           g_r10LastAction=0;

int OnInit()
{
   EAGOLD_ContextInit(g_ctx,Symbol(),MagicNumber,Lot,DigitsLots,
                      R10MinExposureLots,R10PairMaxLots,R10PairMinProfit,
                      R10PairCooldownSeconds,EnableModularR10,EnableR10PairReduction);
   g_r10LastAction=EAGOLD_LoadR10LastAction(Symbol(),MagicNumber);
   EAGOLD_MeasureBasket(g_ctx,g_state);

   EAGOLD_BootDiagnostic(g_ctx);
   EAGOLD_PanelUpdate(g_ctx,g_state);

   Print("EAGOLD MODULAR: initialized. Legacy input contract restored.");
   Print("EAGOLD MODULAR: Modular R10 runtime = ",
         (EnableModularR10?"ENABLED":"DISABLED"));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EAGOLD_PanelDelete();
}

void OnTick()
{
   EAGOLD_MeasureBasket(g_ctx,g_state);

   if(EnableModularR10)
   {
      EAGOLD_R10Event event;
      if(R10_Run(g_ctx,g_state,g_r10LastAction,event))
      {
         EAGOLD_SaveR10LastAction(Symbol(),MagicNumber,g_r10LastAction);
         EAGOLD_LogR10Event(event);
      }
   }

   EAGOLD_PanelUpdate(g_ctx,g_state);
}
