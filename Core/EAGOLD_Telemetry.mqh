#ifndef EAGOLD_TELEMETRY_MQH
#define EAGOLD_TELEMETRY_MQH

void EAGOLD_LogR10Event(const EAGOLD_R10Event &e)
{
   if(e.actionId=="") return;
   Print("EAGOLD R10 EVENT action=",e.actionId,
         " type=",e.actionType,
         " success=",(e.success?"1":"0"),
         " error=",e.errorCode,
         " gross=",DoubleToString(e.grossBefore,2),"->",DoubleToString(e.grossAfter,2),
         " exposure=",DoubleToString(e.netBefore,2),"->",DoubleToString(e.netAfter,2),
         " realized=",DoubleToString(e.realizedNet,2));
}

#endif
