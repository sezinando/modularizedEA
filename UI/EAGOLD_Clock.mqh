#ifndef EAGOLD_CLOCK_MQH
#define EAGOLD_CLOCK_MQH

string EAGOLD_GM3Clock()
{
   datetime t=TimeGMT()-3*60*60;
   return TimeToString(t,TIME_SECONDS);
}

string EAGOLD_ServerClock()
{
   return TimeToString(TimeCurrent(),TIME_SECONDS);
}

#endif
