#ifndef EAGOLD_REALIZATION_CASCADE_MQH
#define EAGOLD_REALIZATION_CASCADE_MQH

//==================================================================
// REALIZATION CASCADE
// Visual FIFO history of realized profit values only.
// New realizations enter at the top and push older values downward.
// Maximum history: 30 values.
//==================================================================

#define EAGOLD_REALIZATION_CASCADE_MAX 30

string g_realizationCascadePrefix="EAGOLD_REALIZATION_CASCADE_";
double g_realizationCascadeValues[EAGOLD_REALIZATION_CASCADE_MAX];
int g_realizationCascadeCount=0;

string EAGOLD_RealizationCascadeValue(double value)
{
   return(DoubleToString(value,2));
}

void EAGOLD_RealizationCascadeRender()
{
   string bgName=g_realizationCascadePrefix+"BG";
   int rowHeight=16;
   int panelWidth=78;
   int panelHeight=EAGOLD_REALIZATION_CASCADE_MAX*rowHeight+8;

   if(ObjectFind(0,bgName)<0)
   {
      if(!ObjectCreate(0,bgName,OBJ_RECTANGLE_LABEL,0,0,0))return;
      ObjectSetInteger(0,bgName,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,bgName,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
      ObjectSetInteger(0,bgName,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,bgName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,bgName,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,bgName,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,bgName,OBJPROP_BACK,false);
      ObjectSetInteger(0,bgName,OBJPROP_BGCOLOR,clrBlack);
      ObjectSetInteger(0,bgName,OBJPROP_COLOR,clrBlack);
      ObjectSetInteger(0,bgName,OBJPROP_XSIZE,panelWidth);
      ObjectSetInteger(0,bgName,OBJPROP_YSIZE,panelHeight);
      ObjectSetInteger(0,bgName,OBJPROP_ZORDER,900);
   }

   ObjectSetInteger(0,bgName,OBJPROP_XDISTANCE,8);
   ObjectSetInteger(0,bgName,OBJPROP_YDISTANCE,8);
   ObjectSetInteger(0,bgName,OBJPROP_XSIZE,panelWidth);
   ObjectSetInteger(0,bgName,OBJPROP_YSIZE,panelHeight);

   for(int i=0;i<EAGOLD_REALIZATION_CASCADE_MAX;i++)
   {
      string name=g_realizationCascadePrefix+"V_"+IntegerToString(i);
      if(ObjectFind(0,name)<0)
      {
         if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))continue;
         ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
         ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
         ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
         ObjectSetInteger(0,name,OBJPROP_BACK,false);
         ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
         ObjectSetString(0,name,OBJPROP_FONT,"Impact");
         ObjectSetInteger(0,name,OBJPROP_COLOR,clrYellow);
         ObjectSetInteger(0,name,OBJPROP_ZORDER,901);
      }

      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,14);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,11+i*rowHeight);
      if(i<g_realizationCascadeCount)
         ObjectSetString(0,name,OBJPROP_TEXT,EAGOLD_RealizationCascadeValue(g_realizationCascadeValues[i]));
      else
         ObjectSetString(0,name,OBJPROP_TEXT,"");
   }

   ChartRedraw(0);
}

void EAGOLD_RealizationCascadeAdd(double realizedProfit)
{
   // Record actual realized monetary values only. Zero/near-zero events are
   // intentionally ignored so the cascade remains a realization history.
   if(MathAbs(realizedProfit)<0.000001)return;

   int limit=MathMin(g_realizationCascadeCount,EAGOLD_REALIZATION_CASCADE_MAX-1);
   for(int i=limit;i>=1;i--)
      g_realizationCascadeValues[i]=g_realizationCascadeValues[i-1];

   g_realizationCascadeValues[0]=realizedProfit;
   if(g_realizationCascadeCount<EAGOLD_REALIZATION_CASCADE_MAX)
      g_realizationCascadeCount++;

   EAGOLD_RealizationCascadeRender();
}

void EAGOLD_RealizationCascadeUpdate()
{
   if(!EnableModularizationPanel)
   {
      EAGOLD_RealizationCascadeDelete();
      return;
   }
   if(g_realizationCascadeCount>0)
      EAGOLD_RealizationCascadeRender();
}

void EAGOLD_RealizationCascadeDelete()
{
   string bgName=g_realizationCascadePrefix+"BG";
   if(ObjectFind(0,bgName)>=0)ObjectDelete(0,bgName);
   for(int i=0;i<EAGOLD_REALIZATION_CASCADE_MAX;i++)
   {
      string name=g_realizationCascadePrefix+"V_"+IntegerToString(i);
      if(ObjectFind(0,name)>=0)ObjectDelete(0,name);
   }
}

#endif
