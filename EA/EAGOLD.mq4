#property strict
#property version "0.101"
#property description "EAGOLD Modular — migration baseline; boot diagnostics enabled"

input int    MagicNumber=3001;
input double Lot=0.01;
input int    DigitsLots=2;

input bool   EnableR10=false;
input bool   EnableR10PairReduction=true;
input double R10MinExposureLots=0.01;
input double R10PairMaxLots=1.00;
input int    R10PairCooldownSeconds=30;

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
                      R10MinExposureLots,R10PairMaxLots,0.0,
                      R10PairCooldownSeconds,EnableR10,EnableR10PairReduction);
   g_r10LastAction=EAGOLD_LoadR10LastAction(Symbol(),MagicNumber);
   EAGOLD_MeasureBasket(g_ctx,g_state);

   EAGOLD_BootDiagnostic(g_ctx);
   EAGOLD_PanelUpdate(g_state);

   Print("EAGOLD MODULAR: initialized. Trading action is ",
         (EnableR10?"ENABLED":"DISABLED"),". Baseline migration stage: R10.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EAGOLD_PanelDelete();
}

void OnTick()
{
   EAGOLD_MeasureBasket(g_ctx,g_state);

   EAGOLD_R10Event event;
   if(R10_Run(g_ctx,g_state,g_r10LastAction,event))
   {
      EAGOLD_SaveR10LastAction(Symbol(),MagicNumber,g_r10LastAction);
      EAGOLD_LogR10Event(event);
   }

   EAGOLD_PanelUpdate(g_state);
}
