#ifndef EAGOLD_EVENTS_MQH
#define EAGOLD_EVENTS_MQH

struct EAGOLD_R10Event
{
   string actionId;
   datetime timestamp;
   string actionType;
   int ticketA;
   int ticketB;
   double lotsA;
   double lotsB;
   double buyBefore;
   double sellBefore;
   double netBefore;
   double grossBefore;
   double buyAfter;
   double sellAfter;
   double netAfter;
   double grossAfter;
   double realizedNet;
   bool success;
   int errorCode;
};

void EAGOLD_EventReset(EAGOLD_R10Event &e)
{
   e.actionId=""; e.timestamp=0; e.actionType=""; e.ticketA=-1; e.ticketB=-1;
   e.lotsA=0.0; e.lotsB=0.0; e.buyBefore=0.0; e.sellBefore=0.0; e.netBefore=0.0;
   e.grossBefore=0.0; e.buyAfter=0.0; e.sellAfter=0.0; e.netAfter=0.0; e.grossAfter=0.0;
   e.realizedNet=0.0; e.success=false; e.errorCode=0;
}

#endif
