#ifndef EAGOLD_ACTION_CONTRACT_MQH
#define EAGOLD_ACTION_CONTRACT_MQH

// Transaction outcome for economic engine actions.
enum EAGOLD_ActionResult
{
   EAGOLD_ACTION_NONE      = 0,
   EAGOLD_ACTION_BLOCKED   = 1,
   EAGOLD_ACTION_COMPLETED = 2,
   EAGOLD_ACTION_PARTIAL   = 3,
   EAGOLD_ACTION_FAILED    = 4
};

// Policy for the remainder of the current tick.
enum EAGOLD_TickPolicy
{
   EAGOLD_TICK_CONTINUE                 = 0,
   EAGOLD_TICK_CONSUME                  = 1,
   EAGOLD_TICK_HALT_FOR_RECONCILIATION  = 2
};

EAGOLD_TickPolicy EAGOLD_PolicyForResult(EAGOLD_ActionResult result)
{
   if(result==EAGOLD_ACTION_PARTIAL)
      return(EAGOLD_TICK_HALT_FOR_RECONCILIATION);
   if(result==EAGOLD_ACTION_COMPLETED)
      return(EAGOLD_TICK_CONSUME);
   return(EAGOLD_TICK_CONTINUE);
}

string EAGOLD_ActionResultName(EAGOLD_ActionResult result)
{
   if(result==EAGOLD_ACTION_BLOCKED)   return("BLOCKED");
   if(result==EAGOLD_ACTION_COMPLETED) return("COMPLETED");
   if(result==EAGOLD_ACTION_PARTIAL)   return("PARTIAL");
   if(result==EAGOLD_ACTION_FAILED)    return("FAILED");
   return("NONE");
}

string EAGOLD_TickPolicyName(EAGOLD_TickPolicy policy)
{
   if(policy==EAGOLD_TICK_CONSUME) return("CONSUME");
   if(policy==EAGOLD_TICK_HALT_FOR_RECONCILIATION) return("HALT_FOR_RECONCILIATION");
   return("CONTINUE");
}

#endif
