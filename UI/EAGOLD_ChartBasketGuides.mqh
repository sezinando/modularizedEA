#ifndef EAGOLD_CHART_BASKET_GUIDES_MQH
#define EAGOLD_CHART_BASKET_GUIDES_MQH

//==================================================================
// CHART BASKET GUIDES
// Compact operational guides anchored near the latest bar.
// Display only: no execution logic is performed here.
// AVG / NEXT / TAKE are represented by horizontal guide lines with
// a compact legend at the right edge instead of long text labels.
//==================================================================

string EAGOLD_CHART_GUIDE_PREFIX="EAGOLD_CHART_GUIDE_";
string EAGOLD_CHART_GUIDE_FONT="Segoe UI Semibold";
int EAGOLD_CHART_GUIDE_FONT_SIZE=8;

string EAGOLD_ChartGuidePrice(double price)
{
   if(price<=0.0)return("-");
   return(DoubleToString(NormalizePrice(price),Digits));
}

int EAGOLD_ChartGuideNextPending(int direction,double &price)
{
   price=0.0;
   bool found=false;
   double best=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder())continue;
      int type=OrderType();
      if(direction==OP_BUY && type!=OP_BUYSTOP)continue;
      if(direction==OP_SELL && type!=OP_SELLSTOP)continue;
      double p=OrderOpenPrice();
      if(!found || (direction==OP_BUY ? p<best : p>best))
      {
         best=p;
         found=true;
      }
   }
   if(found)price=NormalizePrice(best);
   return(found?1:0);
}

double EAGOLD_ChartGuideBasketTargetMoney(int direction,int count)
{
   if(count<=0)return(0.0);
   if(count==1)return(TakeProfit>0.0?TakeProfit:0.0);
   if(EnableBasketRealization && BRXRealizationMode!=0)
      return(BRXDirectionalMinProfit>0.0?BRXDirectionalMinProfit:0.0);
   return(TakeProfit>0.0?count*TakeProfit:0.0);
}

double EAGOLD_ChartGuideNextTake(int direction)
{
   int type=(direction==OP_BUY?OP_BUY:OP_SELL);
   int count=0;
   double lots=0.0;
   double currentProfit=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=type)continue;
      count++;
      lots+=OrderLots();
      currentProfit+=OrderProfit()+OrderSwap()+OrderCommission();
   }
   if(count<=0||lots<=0.0)return(0.0);

   double target=EAGOLD_ChartGuideBasketTargetMoney(direction,count);
   if(target<=0.0)return(0.0);

   double remaining=target-currentProfit;
   RefreshRates();
   double marketPrice=(direction==OP_BUY?Bid:Ask);
   if(remaining<=0.0)return(NormalizePrice(marketPrice));

   double tickValue=MarketInfo(Symbol(),MODE_TICKVALUE);
   double tickSize=MarketInfo(Symbol(),MODE_TICKSIZE);
   if(tickValue<=0.0||tickSize<=0.0)return(0.0);

   double valuePerPriceUnit=(tickValue/tickSize)*lots;
   if(valuePerPriceUnit<=0.0)return(0.0);

   double distance=remaining/valuePerPriceUnit;
   double targetPrice=(direction==OP_BUY?marketPrice+distance:marketPrice-distance);
   return(NormalizePrice(targetPrice));
}

void EAGOLD_ChartGuideLineSet(string id,datetime startTime,datetime endTime,double price,string legend,color clr)
{
   if(price<=0.0)return;
   string lineName=EAGOLD_CHART_GUIDE_PREFIX+id+"_LINE";
   string textName=EAGOLD_CHART_GUIDE_PREFIX+id+"_TEXT";
   if(ObjectFind(0,lineName)<0)
   {
      if(!ObjectCreate(0,lineName,OBJ_TREND,0,startTime,price,endTime,price))return;
      ObjectSetInteger(0,lineName,OBJPROP_RAY_RIGHT,true);
      ObjectSetInteger(0,lineName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,lineName,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,lineName,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,lineName,OBJPROP_BACK,true);
      ObjectSetInteger(0,lineName,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,lineName,OBJPROP_STYLE,STYLE_DOT);
   }
   ObjectMove(0,lineName,0,startTime,price);
   ObjectMove(0,lineName,1,endTime,price);
   ObjectSetInteger(0,lineName,OBJPROP_COLOR,clr);

   if(ObjectFind(0,textName)<0)
   {
      if(!ObjectCreate(0,textName,OBJ_TEXT,0,endTime,price))return;
      ObjectSetString(0,textName,OBJPROP_FONT,EAGOLD_CHART_GUIDE_FONT);
      ObjectSetInteger(0,textName,OBJPROP_FONTSIZE,EAGOLD_CHART_GUIDE_FONT_SIZE);
      ObjectSetInteger(0,textName,OBJPROP_ANCHOR,ANCHOR_LEFT);
      ObjectSetInteger(0,textName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,textName,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,textName,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,textName,OBJPROP_BACK,false);
      ObjectSetInteger(0,textName,OBJPROP_ZORDER,2);
   }
   ObjectMove(0,textName,0,endTime,price);
   ObjectSetString(0,textName,OBJPROP_TEXT,legend);
   ObjectSetInteger(0,textName,OBJPROP_COLOR,clr);
}

void EAGOLD_ChartGuideDelete(string id)
{
   string lineName=EAGOLD_CHART_GUIDE_PREFIX+id+"_LINE";
   string textName=EAGOLD_CHART_GUIDE_PREFIX+id+"_TEXT";
   if(ObjectFind(0,lineName)>=0)ObjectDelete(0,lineName);
   if(ObjectFind(0,textName)>=0)ObjectDelete(0,textName);
}

void EAGOLD_ChartBasketGuidesUpdate()
{
   if(!EnableChartBasketGuides)
   {
      EAGOLD_ChartBasketGuidesDelete();
      return;
   }

   RefreshRates();
   int periodSeconds=PeriodSeconds();
   if(periodSeconds<=0)periodSeconds=60;
   datetime lineStart=Time[0];
   datetime labelTime=Time[0]+periodSeconds*ChartBasketGuideOffsetBars;

   double buyBE=EAGOLD_ModPanelWeightedBE(OP_BUY);
   double sellBE=EAGOLD_ModPanelWeightedBE(OP_SELL);
   double buyNext=0.0,sellNext=0.0;
   int buyPending=EAGOLD_ChartGuideNextPending(OP_BUY,buyNext);
   int sellPending=EAGOLD_ChartGuideNextPending(OP_SELL,sellNext);
   double buyTake=EAGOLD_ChartGuideNextTake(OP_BUY);
   double sellTake=EAGOLD_ChartGuideNextTake(OP_SELL);

   if(buyBE>0.0)
      EAGOLD_ChartGuideLineSet("BUY_AVG",lineStart,labelTime,buyBE,"BUY AVG "+EAGOLD_ChartGuidePrice(buyBE),clrSilver);
   else
      EAGOLD_ChartGuideDelete("BUY_AVG");

   if(buyPending>0)
      EAGOLD_ChartGuideLineSet("BUY_NEXT",lineStart,labelTime,buyNext,"BUY NEXT "+EAGOLD_ChartGuidePrice(buyNext),clrDimGray);
   else
      EAGOLD_ChartGuideDelete("BUY_NEXT");

   if(buyTake>0.0)
      EAGOLD_ChartGuideLineSet("BUY_TAKE",lineStart,labelTime,buyTake,"BUY TAKE "+EAGOLD_ChartGuidePrice(buyTake),clrAqua);
   else
      EAGOLD_ChartGuideDelete("BUY_TAKE");

   if(sellBE>0.0)
      EAGOLD_ChartGuideLineSet("SELL_AVG",lineStart,labelTime,sellBE,"SELL AVG "+EAGOLD_ChartGuidePrice(sellBE),clrSilver);
   else
      EAGOLD_ChartGuideDelete("SELL_AVG");

   if(sellPending>0)
      EAGOLD_ChartGuideLineSet("SELL_NEXT",lineStart,labelTime,sellNext,"SELL NEXT "+EAGOLD_ChartGuidePrice(sellNext),clrDimGray);
   else
      EAGOLD_ChartGuideDelete("SELL_NEXT");

   if(sellTake>0.0)
      EAGOLD_ChartGuideLineSet("SELL_TAKE",lineStart,labelTime,sellTake,"SELL TAKE "+EAGOLD_ChartGuidePrice(sellTake),clrAqua);
   else
      EAGOLD_ChartGuideDelete("SELL_TAKE");

   ChartRedraw(0);
}

void EAGOLD_ChartBasketGuidesDelete()
{
   string ids[]={"BUY_AVG","BUY_NEXT","BUY_TAKE","SELL_AVG","SELL_NEXT","SELL_TAKE"};
   for(int i=0;i<ArraySize(ids);i++)EAGOLD_ChartGuideDelete(ids[i]);
}

#endif
