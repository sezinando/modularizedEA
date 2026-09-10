#ifndef EAGOLD_MODULARIZATION_PANEL_MQH
#define EAGOLD_MODULARIZATION_PANEL_MQH

string EAGOLD_MOD_PANEL_PREFIX="EAGOLD_MOD_";

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
   ObjectSetInteger(0,name,OBJPROP_XSIZE,390);
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
   double spreadPoints=(Ask-Bid)/Point;
   bool spreadAlert=(SpreadLimit>0 && spreadPoints>SpreadLimit);
   double balance=AccountBalance();
   double equity=AccountEquity();
   double currentDD=MathMax(0.0,balance-equity);
   double ddPct=equity>0.0?(currentDD/equity)*100.0:0.0;
   int recoveryLevel=MathMax(RecoveryLevel(OP_BUY),RecoveryLevel(OP_SELL));
   double buyBE=EAGOLD_ModPanelWeightedBE(OP_BUY);
   double sellBE=EAGOLD_ModPanelWeightedBE(OP_SELL);
   double recoveryDebt=R10RecoveryDebt();
   double recoveryRemaining=R10RecoveryRemainingDebt();

   int row=0;
   EAGOLD_ModPanelBackground(true,EnableModularizationDebug?430:310);

   EAGOLD_ModPanelLabel("TITLE","EAGOLD  |  OPERATIONAL MONITOR",row++,clrWhite);
   EAGOLD_ModPanelLabel("SEP1","------------------------------------------",row++,clrDimGray);
   EAGOLD_ModPanelLabel("IDENT","SYMBOL  "+Symbol()+"    MAGIC  "+IntegerToString(MagicNumber),row++,clrAqua);

   color spreadColor=spreadAlert?clrTomato:clrLime;
   EAGOLD_ModPanelLabel("MARKET",StringFormat("BID %8s  ASK %8s",DoubleToString(Bid,Digits),DoubleToString(Ask,Digits)),row++,clrWhite);
   EAGOLD_ModPanelLabel("SPREAD",StringFormat("SPREAD %6.1f pts / LIMIT %d",spreadPoints,SpreadLimit),row++,spreadColor);
   EAGOLD_ModPanelLabel("SPREADSTAT",spreadAlert?"*** SPREAD ABOVE LIMIT ***":"SPREAD WITHIN LIMIT",row++,spreadColor);

   EAGOLD_ModPanelLabel("SEP2","------------------------------------------",row++,clrDimGray);
   EAGOLD_ModPanelLabel("BUY",StringFormat("BUY   %3d pos  %6s lot  P/L %9s",buyCount,EAGOLD_ModPanelLots(buyLots),EAGOLD_ModPanelMoney(buyProfit)),row++,buyProfit>=0.0?clrLime:clrTomato);
   EAGOLD_ModPanelLabel("SELL",StringFormat("SELL  %3d pos  %6s lot  P/L %9s",sellCount,EAGOLD_ModPanelLots(sellLots),EAGOLD_ModPanelMoney(sellProfit)),row++,sellProfit>=0.0?clrLime:clrTomato);
   EAGOLD_ModPanelLabel("EXPOS",StringFormat("GROSS %6s   NET %6s",EAGOLD_ModPanelLots(grossLots),EAGOLD_ModPanelLots(netLots)),row++,clrWhite);
   EAGOLD_ModPanelLabel("PENDING",StringFormat("PENDING  BUY %3d  SELL %3d",buyPending,sellPending),row++,clrSilver);

   EAGOLD_ModPanelLabel("SEP3","------------------------------------------",row++,clrDimGray);
   EAGOLD_ModPanelLabel("FLOAT",StringFormat("FLOATING P/L %12s",EAGOLD_ModPanelMoney(totalProfit)),row++,totalProfit>=0.0?clrLime:clrTomato);
   EAGOLD_ModPanelLabel("EQUITY",StringFormat("EQUITY      %12s",EAGOLD_ModPanelMoney(equity)),row++,clrAqua);
   EAGOLD_ModPanelLabel("DD",StringFormat("DD          %12s  %.2f%%",EAGOLD_ModPanelMoney(currentDD),ddPct),row++,currentDD>0.0?clrYellow:clrLime);
   EAGOLD_ModPanelLabel("BE","BE BUY "+(buyBE>0.0?DoubleToString(buyBE,Digits):"-")+"   SELL "+(sellBE>0.0?DoubleToString(sellBE,Digits):"-"),row++,clrSilver);

   EAGOLD_ModPanelLabel("SEP4","------------------------------------------",row++,clrDimGray);
   EAGOLD_ModPanelLabel("BRX",StringFormat("BRX %s   DIR MIN %s  BI MIN %s",EAGOLD_ModPanelBRXMode(),EAGOLD_ModPanelMoney(BRXDirectionalMinProfit),EAGOLD_ModPanelMoney(BRXBidirectionalMinProfit)),row++,clrAqua);
   EAGOLD_ModPanelLabel("BRXBE",StringFormat("BRX WEIGHTED BE %s  BUFFER %.1f",EAGOLD_ModPanelBool(BRXRequireWeightedBE),BRXWeightedBEBufferPoints),row++,BRXRequireWeightedBE?clrYellow:clrSilver);
   EAGOLD_ModPanelLabel("REC",StringFormat("RECOVERY L%d  DEBT %s  REM %s",recoveryLevel,EAGOLD_ModPanelMoney(recoveryDebt),EAGOLD_ModPanelMoney(recoveryRemaining)),row++,recoveryRemaining>0.0?clrYellow:clrLime);
   EAGOLD_ModPanelLabel("R9",StringFormat("R9 HEDGE %s   R10 %s",EAGOLD_ModPanelBool(g_r9HedgeActive),EAGOLD_ModPanelBool(EnableR10Reduce)),row++,g_r9HedgeActive?clrYellow:clrSilver);
   EAGOLD_ModPanelLabel("TRAIL",StringFormat("GLOBAL TRAIL %s  CD %.1fs  STEP %.1f",EAGOLD_ModPanelBool(EnableGlobalStopTrail),GlobalStopTrailCooldownSeconds,GlobalStopTrailMinStepPoints),row++,EnableGlobalStopTrail?clrAqua:clrSilver);

   if(EnableModularizationDebug)
   {
      EAGOLD_ModPanelLabel("SEP5","============= DEBUG =============",row++,clrDimGray);
      EAGOLD_ModPanelLabel("DBG1","MODULE STATUS: RUNNING",row++,clrLime);
      EAGOLD_ModPanelLabel("DBG2","S1-S9: COMPLETE  | BASELINE v0.106",row++,clrSilver);
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
   string ids[]={"BG","TITLE","SEP1","IDENT","MARKET","SPREAD","SPREADSTAT","SEP2","BUY","SELL","EXPOS","PENDING","SEP3","FLOAT","EQUITY","DD","BE","SEP4","BRX","BRXBE","REC","R9","TRAIL","SEP5","DBG1","DBG2","DBG3","DBG4","DBG5","DBG6","DBG7","DBG8"};
   for(int i=0;i<ArraySize(ids);i++)
   {
      string name=EAGOLD_MOD_PANEL_PREFIX+ids[i];
      if(ObjectFind(0,name)>=0)ObjectDelete(0,name);
   }
}

#endif
