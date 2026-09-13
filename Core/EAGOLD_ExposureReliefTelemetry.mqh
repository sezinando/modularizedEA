#ifndef EAGOLD_EXPOSURE_RELIEF_TELEMETRY_MQH
#define EAGOLD_EXPOSURE_RELIEF_TELEMETRY_MQH

//==================================================================
// EAGOLD EXPOSURE RELIEF TELEMETRY v1.0
// Observer-only telemetry for the R13 -> R10 economic path.
// MUST NOT submit, modify or close orders.
//
// Primary question:
//   Does R13 recovery capital actually dismantle the Master basket,
//   or does it merely move realized money between operations?
//
// Key outputs:
//   - R13 capital generated / consumed
//   - gross and net exposure before/after
//   - target-direction lots before/after
//   - weighted average entry before/after
//   - weighted-average improvement in points
//   - realized loss consumed by the relief action
//   - exposure-relief efficiency
//==================================================================

datetime g_erTelemetryLastWrite=0;
long g_erTelemetryRows=0;
int g_erTelemetryHandle=INVALID_HANDLE;
bool g_erTelemetryDiagnosticLogged=false;
int g_erTelemetryWritesSinceFlush=0;

string EAGOLD_ExposureReliefDirectionName(int direction)
{
   if(direction==OP_BUY)return("BUY");
   if(direction==OP_SELL)return("SELL");
   return("NONE");
}

string EAGOLD_ExposureReliefResultName(EAGOLD_ActionResult result)
{
   return(EAGOLD_ActionResultName(result));
}

double EAGOLD_ExposureReliefDirectionLots(int direction)
{
   return(DirectionLots(direction));
}

double EAGOLD_ExposureReliefWeightedAverage(int direction)
{
   int type=(direction==OP_BUY?OP_BUY:OP_SELL);
   double weighted=0.0;
   double lots=0.0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=type)continue;
      double orderLots=OrderLots();
      if(orderLots<=0.0)continue;
      weighted+=OrderOpenPrice()*orderLots;
      lots+=orderLots;
   }

   if(lots<=0.0)return(0.0);
   return(weighted/lots);
}

double EAGOLD_ExposureReliefDirectionFloatingProfit(int direction)
{
   int type=(direction==OP_BUY?OP_BUY:OP_SELL);
   double total=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=type)continue;
      total+=OrderProfit()+OrderSwap()+OrderCommission();
   }
   return(total);
}

int EAGOLD_ExposureReliefOpenCount(int direction)
{
   int type=(direction==OP_BUY?OP_BUY:OP_SELL);
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=type)continue;
      count++;
   }
   return(count);
}

void EAGOLD_ExposureReliefHeader(int handle)
{
   if(FileSize(handle)>0)return;

   FileWrite(handle,
      "SEQ","TIMESTAMP","EVENT_TYPE","RESULT","DIRECTION",
      "CAPITAL_BEFORE","CAPITAL_ADDED","CAPITAL_USED","CAPITAL_AFTER",
      "REDUCED_LOTS","REALIZED_LOSS",
      "EXPOSURE_BEFORE","EXPOSURE_AFTER","EXPOSURE_REDUCTION",
      "GROSS_BEFORE","GROSS_AFTER","GROSS_REDUCTION",
      "NET_BEFORE","NET_AFTER","NET_CHANGE",
      "TARGET_LOTS_BEFORE","TARGET_LOTS_AFTER",
      "AVG_ENTRY_BEFORE","AVG_ENTRY_AFTER","AVG_IMPROVEMENT_POINTS",
      "AVG_DISTANCE_TO_MARKET_BEFORE","AVG_DISTANCE_TO_MARKET_AFTER",
      "TARGET_FLOATING_PL_BEFORE","TARGET_FLOATING_PL_AFTER",
      "TARGET_COUNT_BEFORE","TARGET_COUNT_AFTER",
      "RELIEF_EFFICIENCY_LOTS_PER_DOLLAR",
      "AVG_IMPROVEMENT_POINTS_PER_DOLLAR",
      "BID","ASK");
}

int EAGOLD_ExposureReliefOpenFile()
{
   if(g_erTelemetryHandle!=INVALID_HANDLE)return(g_erTelemetryHandle);

   ResetLastError();
   g_erTelemetryHandle=FileOpen(
      "EAGOLD_EXPOSURE_RELIEF_TELEMETRY.csv",
      FILE_CSV|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE,
      ';');
   int error=GetLastError();

   if(g_erTelemetryHandle==INVALID_HANDLE)
   {
      Print(EA_NAME," EXPOSURE RELIEF TELEMETRY: FileOpen FAILED error=",error,
            " tester=",(IsTesting()?"1":"0"),
            " data_path=",TerminalInfoString(TERMINAL_DATA_PATH));
      return(INVALID_HANDLE);
   }

   FileSeek(g_erTelemetryHandle,0,SEEK_END);
   EAGOLD_ExposureReliefHeader(g_erTelemetryHandle);

   if(!g_erTelemetryDiagnosticLogged)
   {
      g_erTelemetryDiagnosticLogged=true;
      Print(EA_NAME," EXPOSURE RELIEF TELEMETRY: FileOpen OK file=EAGOLD_EXPOSURE_RELIEF_TELEMETRY.csv");
   }

   return(g_erTelemetryHandle);
}

void EAGOLD_ExposureReliefTelemetryClose()
{
   if(g_erTelemetryHandle==INVALID_HANDLE)return;
   FileFlush(g_erTelemetryHandle);
   FileClose(g_erTelemetryHandle);
   g_erTelemetryHandle=INVALID_HANDLE;
}

void EAGOLD_ExposureReliefTelemetryWriteAdjustment(
   EAGOLD_ActionResult result,
   int direction,
   double capitalBefore,
   double capitalUsed,
   double reducedLots,
   double realizedLoss,
   double exposureBefore,
   double grossBefore,
   double avgBefore)
{
   int handle=EAGOLD_ExposureReliefOpenFile();
   if(handle==INVALID_HANDLE)return;

   RefreshRates();

   double capitalAfter=MathMax(0.0,capitalBefore-capitalUsed);
   double exposureAfter=ExposureLots();
   double grossAfter=DirectionLots(OP_BUY)+DirectionLots(OP_SELL);
   double netBefore=exposureBefore;
   double netAfter=exposureAfter;
   double targetLotsBefore=EAGOLD_ExposureReliefDirectionLots(direction)+MathMax(0.0,reducedLots);
   double targetLotsAfter=EAGOLD_ExposureReliefDirectionLots(direction);
   double avgAfter=EAGOLD_ExposureReliefWeightedAverage(direction);
   double targetFloatingBefore=EAGOLD_ExposureReliefDirectionFloatingProfit(direction);
   double targetFloatingAfter=EAGOLD_ExposureReliefDirectionFloatingProfit(direction);
   double targetCountBefore=EAGOLD_ExposureReliefOpenCount(direction)+(reducedLots>=Lot?1.0:0.0);
   double targetCountAfter=EAGOLD_ExposureReliefOpenCount(direction);
   double avgImprovementPoints=0.0;

   // For BUY, a higher average entry is an improvement for removing the
   // most adverse losing ticket. For SELL, a lower average entry is better.
   if(avgBefore>0.0&&avgAfter>0.0)
   {
      if(direction==OP_BUY)avgImprovementPoints=(avgAfter-avgBefore)/Point;
      else if(direction==OP_SELL)avgImprovementPoints=(avgBefore-avgAfter)/Point;
   }

   double market=(direction==OP_BUY?Bid:Ask);
   double avgDistanceBefore=0.0;
   double avgDistanceAfter=0.0;
   if(avgBefore>0.0)avgDistanceBefore=MathAbs(market-avgBefore)/Point;
   if(avgAfter>0.0)avgDistanceAfter=MathAbs(market-avgAfter)/Point;

   double exposureReduction=MathMax(0.0,exposureBefore-exposureAfter);
   double grossReduction=MathMax(0.0,grossBefore-grossAfter);
   double netChange=netBefore-netAfter;
   double reliefEfficiency=(capitalUsed>0.0?exposureReduction/capitalUsed:0.0);
   double avgImprovementPerDollar=(capitalUsed>0.0?avgImprovementPoints/capitalUsed:0.0);

   g_erTelemetryRows++;
   FileWrite(handle,
      IntegerToString((int)g_erTelemetryRows),
      TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
      "R13_R10_ADJUSTMENT",
      EAGOLD_ExposureReliefResultName(result),
      EAGOLD_ExposureReliefDirectionName(direction),
      DoubleToString(capitalBefore,2),
      "0.00",
      DoubleToString(capitalUsed,2),
      DoubleToString(capitalAfter,2),
      DoubleToString(reducedLots,DigitsLots),
      DoubleToString(realizedLoss,2),
      DoubleToString(exposureBefore,DigitsLots),
      DoubleToString(exposureAfter,DigitsLots),
      DoubleToString(exposureReduction,DigitsLots),
      DoubleToString(grossBefore,DigitsLots),
      DoubleToString(grossAfter,DigitsLots),
      DoubleToString(grossReduction,DigitsLots),
      DoubleToString(netBefore,DigitsLots),
      DoubleToString(netAfter,DigitsLots),
      DoubleToString(netChange,DigitsLots),
      DoubleToString(targetLotsBefore,DigitsLots),
      DoubleToString(targetLotsAfter,DigitsLots),
      DoubleToString(avgBefore,Digits),
      DoubleToString(avgAfter,Digits),
      DoubleToString(avgImprovementPoints,2),
      DoubleToString(avgDistanceBefore,2),
      DoubleToString(avgDistanceAfter,2),
      DoubleToString(targetFloatingBefore,2),
      DoubleToString(targetFloatingAfter,2),
      IntegerToString((int)targetCountBefore),
      IntegerToString((int)targetCountAfter),
      DoubleToString(reliefEfficiency,6),
      DoubleToString(avgImprovementPerDollar,6),
      DoubleToString(Bid,Digits),
      DoubleToString(Ask,Digits));

   g_erTelemetryWritesSinceFlush++;
   if(g_erTelemetryWritesSinceFlush>=20)
   {
      FileFlush(handle);
      g_erTelemetryWritesSinceFlush=0;
   }

   Print(EA_NAME," EXPOSURE RELIEF TELEMETRY: result=",EAGOLD_ExposureReliefResultName(result),
         " side=",EAGOLD_ExposureReliefDirectionName(direction),
         " capital=",DoubleToString(capitalBefore,2)," used=",DoubleToString(capitalUsed,2),
         " reduced=",DoubleToString(reducedLots,DigitsLots),
         " exposure=",DoubleToString(exposureBefore,DigitsLots)," -> ",DoubleToString(exposureAfter,DigitsLots),
         " gross=",DoubleToString(grossBefore,DigitsLots)," -> ",DoubleToString(grossAfter,DigitsLots),
         " avgImprovementPts=",DoubleToString(avgImprovementPoints,2),
         " reliefEff=",DoubleToString(reliefEfficiency,6));
}

void EAGOLD_ExposureReliefTelemetryWriteCapitalCredit(
   double realizedProfit,
   double capitalAdded,
   double capitalBefore,
   double capitalAfter,
   int sourceDirection)
{
   int handle=EAGOLD_ExposureReliefOpenFile();
   if(handle==INVALID_HANDLE)return;

   RefreshRates();
   double exposure=ExposureLots();
   double gross=DirectionLots(OP_BUY)+DirectionLots(OP_SELL);
   double net=exposure;
   double targetLots=EAGOLD_ExposureReliefDirectionLots(sourceDirection);
   double avg=EAGOLD_ExposureReliefWeightedAverage(sourceDirection);
   double market=(sourceDirection==OP_BUY?Bid:Ask);
   double distance=(avg>0.0?MathAbs(market-avg)/Point:0.0);

   g_erTelemetryRows++;
   FileWrite(handle,
      IntegerToString((int)g_erTelemetryRows),
      TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
      "R13_CAPITAL_CREDIT",
      "COMPLETED",
      EAGOLD_ExposureReliefDirectionName(sourceDirection),
      DoubleToString(capitalBefore,2),
      DoubleToString(capitalAdded,2),
      "0.00",
      DoubleToString(capitalAfter,2),
      "0.00",
      DoubleToString(realizedProfit,2),
      DoubleToString(exposure,DigitsLots),
      DoubleToString(exposure,DigitsLots),
      "0.00",
      DoubleToString(gross,DigitsLots),
      DoubleToString(gross,DigitsLots),
      "0.00",
      DoubleToString(net,DigitsLots),
      DoubleToString(net,DigitsLots),
      "0.00",
      DoubleToString(targetLots,DigitsLots),
      DoubleToString(targetLots,DigitsLots),
      DoubleToString(avg,Digits),
      DoubleToString(avg,Digits),
      "0.00",
      DoubleToString(distance,2),
      DoubleToString(distance,2),
      DoubleToString(EAGOLD_ExposureReliefDirectionFloatingProfit(sourceDirection),2),
      DoubleToString(EAGOLD_ExposureReliefDirectionFloatingProfit(sourceDirection),2),
      IntegerToString(EAGOLD_ExposureReliefOpenCount(sourceDirection)),
      IntegerToString(EAGOLD_ExposureReliefOpenCount(sourceDirection)),
      "0.000000",
      "0.000000",
      DoubleToString(Bid,Digits),
      DoubleToString(Ask,Digits));

   g_erTelemetryWritesSinceFlush++;
   if(g_erTelemetryWritesSinceFlush>=20)
   {
      FileFlush(handle);
      g_erTelemetryWritesSinceFlush=0;
   }
}

void EAGOLD_ExposureReliefTelemetryReset()
{
   EAGOLD_ExposureReliefTelemetryClose();
   g_erTelemetryLastWrite=0;
   g_erTelemetryRows=0;
   g_erTelemetryHandle=INVALID_HANDLE;
   g_erTelemetryDiagnosticLogged=false;
   g_erTelemetryWritesSinceFlush=0;
}

#endif
