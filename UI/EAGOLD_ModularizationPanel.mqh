#ifndef EAGOLD_MODULARIZATION_PANEL_MQH
#define EAGOLD_MODULARIZATION_PANEL_MQH

string EAGOLD_MOD_PANEL_PREFIX="EAGOLD_MOD_";
double g_modPanelMinProfit=0.0;
double g_modPanelMaxLots=0.0;
bool g_modPanelInitialized=false;

string EAGOLD_ModPanelMoney(double value){return(DoubleToString(value,2));}
string EAGOLD_ModPanelLots(double value){return(DoubleToString(value,2));}
string EAGOLD_ModPanelBool(bool value){return(value?"ON":"OFF");}

string EAGOLD_ModPanelBRXMode()
{
   if(!EnableBasketRealization)return("OFF");
   if(BRXRealizationMode==0)return("LEGACY");
   if(BRXRealizationMode==1)return("DIRECTIONAL");
   if(BRXRealizationMode==2)return("BIDIRECTIONAL");
   return("HYBRID");
}

void EAGOLD_ModPanelLabel(string id,string text,int row,color clr)
{
   string name=EAGOLD_MOD_PANEL_PREFIX+id;
   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))
      {
         Print("EAGOLD MOD PANEL: ObjectCreate failed id=",id," error=",GetLastError());
         return;
      }
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_ZORDER,1000);
   }
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,14);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,10+row*17);
}

void EAGOLD_ModPanelBackground(bool visible,int height)
{
   string name=EAGOLD_MOD_PANEL_PREFIX+"BG";
   if(!visible)
   {
      if(ObjectFind(0,name)>=0)ObjectDelete(0,name);
      return;
   }
   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0))
      {
         Print("EAGOLD MOD PANEL: background create failed error=",GetLastError());
         return;
      }
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrBlack);
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrDimGray);
      ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_ZORDER,999);
   }
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,6);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,4);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,PanelBackgroundWidth);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
}

double EAGOLD_ModPanelWeightedBE(int direction)
{
   double lots=0.0,weighted=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder())continue;
      if(OrderType()!=direction)continue;
      lots+=OrderLots();
      weighted+=OrderOpenPrice()*OrderLots();
   }
   if(lots<=0.0)return(0.0);
   return(NormalizePrice(weighted/lots));
}

double EAGOLD_ModPanelNextOrderPrice(int direction)
{
   int pendingType=(direction==OP_BUY?OP_BUYSTOP:OP_SELLSTOP);
   double selected=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=pendingType)continue;
      double price=OrderOpenPrice();
      if(selected<=0.0)selected=price;
      else if(direction==OP_BUY && price<selected)selected=price;
      else if(direction==OP_SELL && price>selected)selected=price;
   }
   return(selected>0.0?NormalizePrice(selected):0.0);
}

double EAGOLD_ModPanelNextTakePrice(int direction,double basketLots,double basketBE)
{
   if(basketLots<=0.0||basketBE<=0.0)return(0.0);
   double targetMoney=(EnableBasketRealization&&BRXRealizationMode!=0)?BRXDirectionalMinProfit:TakeProfit;
   if(targetMoney<=0.0)return(0.0);
   double tickValue=MarketInfo(Symbol(),MODE_TICKVALUE);
   double tickSize=MarketInfo(Symbol(),MODE_TICKSIZE);
   if(tickValue<=0.0||tickSize<=0.0)return(0.0);
   double priceDistance=(targetMoney/(basketLots*tickValue))*tickSize;
   if(direction==OP_BUY)return(NormalizePrice(basketBE+priceDistance));
   return(NormalizePrice(basketBE-priceDistance));
}

void EAGOLD_ModPanelUpdate()
{
   if(!EnableModularizationPanel)
   {
      EAGOLD_ModPanelDelete();
      return;
   }

   RefreshRates();

   int buyCount=0,sellCount=0,buyPending=0,sellPending=0;
   double buyLots=0.0,sellLots=0.0,buyProfit=0.0,sellProfit=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder())continue;
      int type=OrderType();
      if(type==OP_BUY)
      {
         buyCount++;
         buyLots+=OrderLots();
         buyProfit+=OrderProfit()+OrderSwap()+OrderCommission();
      }
      else if(type==OP_SELL)
      {
         sellCount++;
         sellLots+=OrderLots();
         sellProfit+=OrderProfit()+OrderSwap()+OrderCommission();
      }
      else if(type==OP_BUYSTOP)buyPending++;
      else if(type==OP_SELLSTOP)sellPending++;
   }

   double totalProfit=buyProfit+sellProfit;
   double grossLots=buyLots+sellLots;
   double netLots=MathAbs(buyLots-sellLots);
   double accumulated=EAGOLDAccumulatedProfit();
   double balance=AccountBalance();
   double equity=AccountEquity();
   double currentDD=MathMax(0.0,balance-equity);
   double ddPct=equity>0.0?(currentDD/equity)*100.0:0.0;
   double spreadPoints=(Ask-Bid)/Point;
   bool spreadAlert=(SpreadLimit>0 && spreadPoints>SpreadLimit);
   int recoveryLevel=MathMax(RecoveryLevel(OP_BUY),RecoveryLevel(OP_SELL));
   int displayDirection=HeavyDirection();
   if(displayDirection<0)displayDirection=OP_BUY;
   int displayLevel=RecoveryLevel(displayDirection);
   double recoveryDebt=R10RecoveryDebt();
   double recoveryRemaining=R10RecoveryRemainingDebt();
   double buyBE=EAGOLD_ModPanelWeightedBE(OP_BUY);
   double sellBE=EAGOLD_ModPanelWeightedBE(OP_SELL);
   double buyNext=EAGOLD_ModPanelNextOrderPrice(OP_BUY);
   double sellNext=EAGOLD_ModPanelNextOrderPrice(OP_SELL);
   double buyTake=EAGOLD_ModPanelNextTakePrice(OP_BUY,buyLots,buyBE);
   double sellTake=EAGOLD_ModPanelNextTakePrice(OP_SELL,sellLots,sellBE);

   if(!g_modPanelInitialized)
   {
      g_modPanelMinProfit=totalProfit;
      g_modPanelMaxLots=grossLots;
      g_modPanelInitialized=true;
   }
   else
   {
      if(totalProfit<g_modPanelMinProfit)g_modPanelMinProfit=totalProfit;
      if(grossLots>g_modPanelMaxLots)g_modPanelMaxLots=grossLots;
   }

   int row=0;
   EAGOLD_ModPanelBackground(true,EnableModularizationDebug?670:550);

   EAGOLD_ModPanelLabel("TITLE",StringFormat("EAGOLD v%s | OPERATIONAL PANEL",EAGOLD_VERSION),row++,clrWhite);
   EAGOLD_ModPanelLabel("SEP1","----------------------------------------------",row++,clrDimGray);
   if(MagicNumber==-1)
      EAGOLD_ModPanelLabel("IDENT",StringFormat("SYMBOL %-8s   MAGIC %4d   | TODOS",Symbol(),MagicNumber),row++,clrYellow);
   else
      EAGOLD_ModPanelLabel("IDENT",StringFormat("SYMBOL %-8s   MAGIC %4d",Symbol(),MagicNumber),row++,clrAqua);
   EAGOLD_ModPanelLabel("MARKET",StringFormat("BID %10s   ASK %10s",DoubleToString(Bid,Digits),DoubleToString(Ask,Digits)),row++,clrWhite);
   color spreadColor=spreadAlert?clrTomato:clrLime;
   EAGOLD_ModPanelLabel("SPREAD",StringFormat("SPREAD %6.1f pts   LIMIT %3d",spreadPoints,SpreadLimit),row++,spreadColor);

   EAGOLD_ModPanelLabel("SEP2","----------------------------------------------",row++,clrDimGray);
   EAGOLD_ModPanelLabel("BUY",StringFormat("BUY  %3d pos   %6s lot   P/L %10s",buyCount,EAGOLD_ModPanelLots(buyLots),EAGOLD_ModPanelMoney(buyProfit)),row++,buyProfit>=0.0?clrLime:clrTomato);
   EAGOLD_ModPanelLabel("SELL",StringFormat("SELL %3d pos   %6s lot   P/L %10s",sellCount,EAGOLD_ModPanelLots(sellLots),EAGOLD_ModPanelMoney(sellProfit)),row++,sellProfit>=0.0?clrLime:clrTomato);
   EAGOLD_ModPanelLabel("EXPOS",StringFormat("GROSS %6s   NET %6s",EAGOLD_ModPanelLots(grossLots),EAGOLD_ModPanelLots(netLots)),row++,clrWhite);
   EAGOLD_ModPanelLabel("PENDING",StringFormat("PENDING  BUY %3d   SELL %3d",buyPending,sellPending),row++,clrSilver);

   EAGOLD_ModPanelLabel("SEP3","----------------------------------------------",row++,clrDimGray);
   EAGOLD_ModPanelLabel("TOTAL",StringFormat("TOTAL P/L %14s",EAGOLD_ModPanelMoney(totalProfit)),row++,totalProfit>=0.0?clrLime:clrTomato);
   EAGOLD_ModPanelLabel("EQUITY",StringFormat("EQUITY    %14s",EAGOLD_ModPanelMoney(equity)),row++,clrAqua);
   EAGOLD_ModPanelLabel("ACCUM",StringFormat("LUCRO ACUM. %10s",EAGOLD_ModPanelMoney(accumulated)),row++,accumulated>=0.0?clrLime:clrTomato);
   EAGOLD_ModPanelLabel("MIN",StringFormat("MENOR P/L   %11s",EAGOLD_ModPanelMoney(g_modPanelMinProfit)),row++,clrYellow);
   EAGOLD_ModPanelLabel("LOTS",StringFormat("LOTES ATUAIS %9s",EAGOLD_ModPanelLots(grossLots)),row++,clrWhite);
   EAGOLD_ModPanelLabel("MAXLOTS",StringFormat("MAIOR ACUM. %9s",EAGOLD_ModPanelLots(g_modPanelMaxLots)),row++,clrYellow);
   EAGOLD_ModPanelLabel("DD",StringFormat("DD %11s  %6.2f%%",EAGOLD_ModPanelMoney(currentDD),ddPct),row++,currentDD>0.0?clrYellow:clrLime);

   EAGOLD_ModPanelLabel("SEP4","----------------------------------------------",row++,clrDimGray);
   EAGOLD_ModPanelLabel("BE",StringFormat("AVG BUY  %10s   AVG SELL %10s",buyBE>0.0?DoubleToString(buyBE,Digits):"-",sellBE>0.0?DoubleToString(sellBE,Digits):"-"),row++,clrSilver);
   EAGOLD_ModPanelLabel("NEXT",StringFormat("NEXT BUY %10s   TAKE BUY %10s",buyNext>0.0?DoubleToString(buyNext,Digits):"-",buyTake>0.0?DoubleToString(buyTake,Digits):"-"),row++,clrSilver);
   EAGOLD_ModPanelLabel("NEXTS",StringFormat("NEXT SELL %10s   TAKE SELL %10s",sellNext>0.0?DoubleToString(sellNext,Digits):"-",sellTake>0.0?DoubleToString(sellTake,Digits):"-"),row++,clrSilver);
   EAGOLD_ModPanelLabel("HEDGE",StringFormat("HEDGE     %s",g_r9HedgeActive?"ATIVO":"INATIVO"),row++,g_r9HedgeActive?clrYellow:clrSilver);
   EAGOLD_ModPanelLabel("R11",StringFormat("R11 STEP x %4.2f   L%-2d = %s",EnableRecoveryStepMultiplier?RecoveryStepMultiplier:1.00,displayLevel,EAGOLD_ModPanelLots(RecoveryStepForLevel(displayLevel))),row++,EnableRecoveryStepMultiplier?clrAqua:clrSilver);
   EAGOLD_ModPanelLabel("REC",StringFormat("RECOVERY  B%-2d S%-2d L%-2d",RecoveryLevel(OP_BUY),RecoveryLevel(OP_SELL),recoveryLevel),row++,recoveryRemaining>0.0?clrYellow:clrLime);
   EAGOLD_ModPanelLabel("RECD",StringFormat("DEBT %10s   REM %10s",EAGOLD_ModPanelMoney(recoveryDebt),EAGOLD_ModPanelMoney(recoveryRemaining)),row++,recoveryRemaining>0.0?clrYellow:clrSilver);

   EAGOLD_ModPanelLabel("SEP5","----------------------------------------------",row++,clrDimGray);
   EAGOLD_ModPanelLabel("BRX",StringFormat("BRX %-11s   DIR %6s   BI %6s",EAGOLD_ModPanelBRXMode(),EAGOLD_ModPanelMoney(BRXDirectionalMinProfit),EAGOLD_ModPanelMoney(BRXBidirectionalMinProfit)),row++,clrAqua);
   EAGOLD_ModPanelLabel("TRAIL",StringFormat("TRAIL %-3s   CD %5.1fs   STEP %5.1f",EAGOLD_ModPanelBool(EnableGlobalStopTrail),GlobalStopTrailCooldownSeconds,GlobalStopTrailMinStepPoints),row++,EnableGlobalStopTrail?clrAqua:clrSilver);
   EAGOLD_ModPanelLabel("TIME",StringFormat("TIME      %s",TimeToString(TimeCurrent(),TIME_SECONDS)),row++,clrSilver);

   if(EnableModularizationDebug)
   {
      EAGOLD_ModPanelLabel("SEP6","============= DEBUG =============",row++,clrDimGray);
      EAGOLD_ModPanelLabel("DBG1","MODULE STATUS: RUNNING",row++,clrLime);
      EAGOLD_ModPanelLabel("DBG2",StringFormat("S1-S9: COMPLETE  | BASELINE v%s",EAGOLD_VERSION),row++,clrSilver);
      EAGOLD_ModPanelLabel("DBG3","R1 DECISION: "+g_r1LastDecision,row++,clrWhite);
      EAGOLD_ModPanelLabel("DBG4","R1 REASON: "+g_r1LastReason,row++,clrSilver);
      EAGOLD_ModPanelLabel("DBG5","R1 TIME: "+(g_r1LastDecisionTime>0?TimeToString(g_r1LastDecisionTime,TIME_SECONDS):"-"),row++,clrSilver);
      EAGOLD_ModPanelLabel("DBG6","R10 LAST ACTION: "+(g_r10LastAction>0?TimeToString(g_r10LastAction,TIME_SECONDS):"-"),row++,clrSilver);
      EAGOLD_ModPanelLabel("DBG7","ORDERS TOTAL: "+IntegerToString(CountEAGOLDOrders()),row++,clrSilver);
      EAGOLD_ModPanelLabel("DBG8","HEARTBEAT: "+TimeToString(TimeCurrent(),TIME_SECONDS),row++,clrWhite);
   }

   ChartRedraw(0);
}

void EAGOLD_ModPanelDelete()
{
   string ids[]={"BG","TITLE","SEP1","IDENT","MARKET","SPREAD","SEP2","BUY","SELL","EXPOS","PENDING","SEP3","TOTAL","EQUITY","ACCUM","MIN","LOTS","MAXLOTS","DD","SEP4","BE","NEXT","NEXTS","HEDGE","R11","REC","RECD","SEP5","BRX","TRAIL","TIME","SEP6","DBG1","DBG2","DBG3","DBG4","DBG5","DBG6","DBG7","DBG8"};
   for(int i=0;i<ArraySize(ids);i++)
   {
      string name=EAGOLD_MOD_PANEL_PREFIX+ids[i];
      if(ObjectFind(0,name)>=0)ObjectDelete(0,name);
   }
   for(int j=ObjectsTotal()-1;j>=0;j--)
   {
      string objectName=ObjectName(0,j);
      if(StringFind(objectName,ENGINE_MARKER_PREFIX,0)==0||StringFind(objectName,R10_MARKER_PREFIX,0)==0)ObjectDelete(0,objectName);
   }
   g_modPanelInitialized=false;
   g_modPanelMinProfit=0.0;
   g_modPanelMaxLots=0.0;
}

#endif
