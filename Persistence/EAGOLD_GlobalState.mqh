#ifndef EAGOLD_GLOBAL_STATE_MQH
#define EAGOLD_GLOBAL_STATE_MQH

string EAGOLD_StateKey(string symbol,int magic,string metric)
{
   return StringFormat("EAGOLD_MOD_%s_%d_%s",symbol,magic,metric);
}

void EAGOLD_SaveR10LastAction(string symbol,int magic,datetime value)
{
   GlobalVariableSet(EAGOLD_StateKey(symbol,magic,"R10_LAST_ACTION"),(double)value);
}

datetime EAGOLD_LoadR10LastAction(string symbol,int magic)
{
   string key=EAGOLD_StateKey(symbol,magic,"R10_LAST_ACTION");
   if(!GlobalVariableCheck(key)) return 0;
   return (datetime)GlobalVariableGet(key);
}

#endif
