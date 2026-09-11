#ifndef EAGOLD_CHART_BASKET_GUIDES_MQH
#define EAGOLD_CHART_BASKET_GUIDES_MQH

//==================================================================
// CHART BASKET GUIDES
// Compact operational guides anchored near the latest bar.
// Display only: no execution logic is performed here.
// Only BUY and SELL weighted-average prices are displayed.
// Direction is identified exclusively by line/text color.
//==================================================================

string EAGOLD_CHART_GUIDE_PREFIX="EAGOLD_CHART_GUIDE_";
string EAGOLD_CHART_GUIDE_FONT="Segoe UI Semibold";
int EAGOLD_CHART_GUIDE_FONT_SIZE=9;

string EAGOLD_ChartGuidePrice(double price)
{
   if(price<=0.0)return("-");
   return(DoubleToString(NormalizePrice(price),Digits));
}

double EAGOLD_ChartGuideAverage(int direction)
{
   double lots=0.0,weighted=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;
      if(!IsEAGOLDOrder()||OrderType()!=direction)continue;
      lots+=OrderLots();
      weighted+=OrderOpenPrice()*OrderLots();
   }
   if(lots<=0.0)return(0.0);
   return(NormalizePrice(weighted/lots));
}

void EAGOLD_ChartGuideLineSet(string id,datetime startTime,datetime endTime,double price,string text,color clr)
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
      ObjectSetInteger(0,textName,OBJPROP_ANCHOR,ANCHOR_CENTER);
      ObjectSetInteger(0,textName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,textName,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,textName,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,textName,OBJPROP_BACK,false);
      ObjectSetInteger(0,textName,OBJPROP_ZORDER,2);
   }
   ObjectMove(0,textName,0,endTime,price);
   ObjectSetString(0,textName,OBJPROP_TEXT,text);
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

   double buyBE=EAGOLD_ChartGuideAverage(OP_BUY);
   double sellBE=EAGOLD_ChartGuideAverage(OP_SELL);

   // Direction is intentionally communicated by color only.
   // No BUY/SELL legend is placed on the chart.
   if(buyBE>0.0)
      EAGOLD_ChartGuideLineSet("BUY_AVG",lineStart,labelTime,buyBE,EAGOLD_ChartGuidePrice(buyBE),clrLime);
   else
      EAGOLD_ChartGuideDelete("BUY_AVG");

   if(sellBE>0.0)
      EAGOLD_ChartGuideLineSet("SELL_AVG",lineStart,labelTime,sellBE,EAGOLD_ChartGuidePrice(sellBE),clrTomato);
   else
      EAGOLD_ChartGuideDelete("SELL_AVG");

   // Remove obsolete NEXT/TAKE guide objects left by previous versions.
   EAGOLD_ChartGuideDelete("BUY_NEXT");
   EAGOLD_ChartGuideDelete("BUY_TAKE");
   EAGOLD_ChartGuideDelete("SELL_NEXT");
   EAGOLD_ChartGuideDelete("SELL_TAKE");

   ChartRedraw(0);
}

void EAGOLD_ChartBasketGuidesDelete()
{
   string ids[]={"BUY_AVG","SELL_AVG","BUY_NEXT","BUY_TAKE","SELL_NEXT","SELL_TAKE"};
   for(int i=0;i<ArraySize(ids);i++)EAGOLD_ChartGuideDelete(ids[i]);
}

#endif
