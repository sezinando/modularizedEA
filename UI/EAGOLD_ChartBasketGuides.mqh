#ifndef EAGOLD_CHART_BASKET_GUIDES_MQH
#define EAGOLD_CHART_BASKET_GUIDES_MQH

//==================================================================
// CHART BASKET GUIDES
// Discreet operational information anchored near the latest bar.
// Display only: no execution logic is performed here.
//==================================================================

string EAGOLD_CHART_GUIDE_PREFIX="EAGOLD_CHART_GUIDE_";

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

void EAGOLD_ChartGuideSet(string id,datetime when,double price,string text,color clr)
{
   if(price<=0.0)return;
   string name=EAGOLD_CHART_GUIDE_PREFIX+id;
   if(ObjectFind(0,name)<0)
   {
      if(!ObjectCreate(0,name,OBJ_TEXT,0,when,price))return;
      ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,true);
      ObjectSetInteger(0,name,OBJPROP_ZORDER,1);
   }
   ObjectMove(0,name,0,when,price);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
}

void EAGOLD_ChartBasketGuidesUpdate()
{
   if(!EnableChartBasketGuides)
   {
      EAGOLD_ChartBasketGuidesDelete();
      return;
   }

   RefreshRates();
   datetime anchorTime=Time[0]+PeriodSeconds()*ChartBasketGuideOffsetBars;
   if(PeriodSeconds()<=0)anchorTime=Time[0]+60*ChartBasketGuideOffsetBars;

   double buyBE=EAGOLD_ModPanelWeightedBE(OP_BUY);
   double sellBE=EAGOLD_ModPanelWeightedBE(OP_SELL);
   double buyNext=0.0,sellNext=0.0;
   int buyPending=EAGOLD_ChartGuideNextPending(OP_BUY,buyNext);
   int sellPending=EAGOLD_ChartGuideNextPending(OP_SELL,sellNext);
   double buyTake=EAGOLD_ChartGuideNextTake(OP_BUY);
   double sellTake=EAGOLD_ChartGuideNextTake(OP_SELL);

   if(buyBE>0.0)
      EAGOLD_ChartGuideSet("BUY_AVG",anchorTime,buyBE,"BUY AVG  "+EAGOLD_ChartGuidePrice(buyBE),clrSilver);
   else
      ObjectDelete(0,EAGOLD_CHART_GUIDE_PREFIX+"BUY_AVG");

   if(buyPending>0)
      EAGOLD_ChartGuideSet("BUY_NEXT",anchorTime,buyNext,"BUY NEXT "+EAGOLD_ChartGuidePrice(buyNext),clrDimGray);
   else
      ObjectDelete(0,EAGOLD_CHART_GUIDE_PREFIX+"BUY_NEXT");

   if(buyTake>0.0)
      EAGOLD_ChartGuideSet("BUY_TAKE",anchorTime,buyTake,"BUY TAKE "+EAGOLD_ChartGuidePrice(buyTake),clrAqua);
   else
      ObjectDelete(0,EAGOLD_CHART_GUIDE_PREFIX+"BUY_TAKE");

   if(sellBE>0.0)
      EAGOLD_ChartGuideSet("SELL_AVG",anchorTime,sellBE,"SELL AVG "+EAGOLD_ChartGuidePrice(sellBE),clrSilver);
   else
      ObjectDelete(0,EAGOLD_CHART_GUIDE_PREFIX+"SELL_AVG");

   if(sellPending>0)
      EAGOLD_ChartGuideSet("SELL_NEXT",anchorTime,sellNext,"SELL NEXT "+EAGOLD_ChartGuidePrice(sellNext),clrDimGray);
   else
      ObjectDelete(0,EAGOLD_CHART_GUIDE_PREFIX+"SELL_NEXT");

   if(sellTake>0.0)
      EAGOLD_ChartGuideSet("SELL_TAKE",anchorTime,sellTake,"SELL TAKE "+EAGOLD_ChartGuidePrice(sellTake),clrAqua);
   else
      ObjectDelete(0,EAGOLD_CHART_GUIDE_PREFIX+"SELL_TAKE");

   ChartRedraw(0);
}

void EAGOLD_ChartBasketGuidesDelete()
{
   string ids[]={"BUY_AVG","BUY_NEXT","BUY_TAKE","SELL_AVG","SELL_NEXT","SELL_TAKE"};
   for(int i=0;i<ArraySize(ids);i++)
   {
      string name=EAGOLD_CHART_GUIDE_PREFIX+ids[i];
      if(ObjectFind(0,name)>=0)ObjectDelete(0,name);
   }
}

#endif
