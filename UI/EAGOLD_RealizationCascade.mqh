#ifndef EAGOLD_REALIZATION_CASCADE_MQH
#define EAGOLD_REALIZATION_CASCADE_MQH

//==================================================================
// REALIZATION CASCADE
// FIFO history of realized values. Each realization carries the color
// of the engine that produced it. No legend is shown: color is the key.
//==================================================================
#define EAGOLD_REALIZATION_CASCADE_MAX 30

string g_realizationCascadePrefix="EAGOLD_REALIZATION_CASCADE_";
double g_realizationCascadeValues[EAGOLD_REALIZATION_CASCADE_MAX];
color g_realizationCascadeColors[EAGOLD_REALIZATION_CASCADE_MAX];
int g_realizationCascadeCount=0;

string EAGOLD_RealizationCascadeValue(double value){return(DoubleToString(value,2));}

void EAGOLD_RealizationCascadeRender()
{
   string bgName=g_realizationCascadePrefix+"BG";
   int rowHeight=16,panelWidth=78,panelHeight=EAGOLD_REALIZATION_CASCADE_MAX*rowHeight+8;
   if(ObjectFind(0,bgName)<0)
   {
      if(!ObjectCreate(0,bgName,OBJ_RECTANGLE_LABEL,0,0,0))return;
      ObjectSetInteger(0,bgName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
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
   int baseX=PanelBackgroundX+PanelBackgroundWidth+12;
   int baseY=PanelBackgroundY;
   ObjectSetInteger(0,bgName,OBJPROP_XDISTANCE,baseX);
   ObjectSetInteger(0,bgName,OBJPROP_YDISTANCE,baseY);
   ObjectSetInteger(0,bgName,OBJPROP_XSIZE,panelWidth);
   ObjectSetInteger(0,bgName,OBJPROP_YSIZE,panelHeight);

   for(int i=0;i<EAGOLD_REALIZATION_CASCADE_MAX;i++)
   {
      string valueName=g_realizationCascadePrefix+"V_"+IntegerToString(i);
      string dotName=g_realizationCascadePrefix+"D_"+IntegerToString(i);
      if(i<g_realizationCascadeCount)
      {
         int y=baseY+5+i*rowHeight;
         if(ObjectFind(0,valueName)<0)ObjectCreate(0,valueName,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,valueName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(0,valueName,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,valueName,OBJPROP_SELECTED,false);
         ObjectSetInteger(0,valueName,OBJPROP_HIDDEN,true);
         ObjectSetInteger(0,valueName,OBJPROP_BACK,false);
         ObjectSetInteger(0,valueName,OBJPROP_XDISTANCE,baseX+32);
         ObjectSetInteger(0,valueName,OBJPROP_YDISTANCE,y);
         ObjectSetInteger(0,valueName,OBJPROP_FONTSIZE,9);
         ObjectSetString(0,valueName,OBJPROP_FONT,"Impact");
         ObjectSetInteger(0,valueName,OBJPROP_COLOR,g_realizationCascadeColors[i]);
         ObjectSetInteger(0,valueName,OBJPROP_ZORDER,901);
         ObjectSetString(0,valueName,OBJPROP_TEXT,EAGOLD_RealizationCascadeValue(g_realizationCascadeValues[i]));

         if(ObjectFind(0,dotName)<0)ObjectCreate(0,dotName,OBJ_LABEL,0,0,0);
         ObjectSetInteger(0,dotName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
         ObjectSetInteger(0,dotName,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,dotName,OBJPROP_SELECTED,false);
         ObjectSetInteger(0,dotName,OBJPROP_HIDDEN,true);
         ObjectSetInteger(0,dotName,OBJPROP_BACK,false);
         ObjectSetInteger(0,dotName,OBJPROP_XDISTANCE,baseX+8);
         ObjectSetInteger(0,dotName,OBJPROP_YDISTANCE,y-1);
         ObjectSetInteger(0,dotName,OBJPROP_FONTSIZE,9);
         ObjectSetString(0,dotName,OBJPROP_FONT,"Arial");
         ObjectSetInteger(0,dotName,OBJPROP_COLOR,g_realizationCascadeColors[i]);
         ObjectSetInteger(0,dotName,OBJPROP_ZORDER,902);
         ObjectSetString(0,dotName,OBJPROP_TEXT,"●");
      }
      else
      {
         ObjectDelete(0,valueName);
         ObjectDelete(0,dotName);
      }
   }
   ChartRedraw(0);
}

void EAGOLD_RealizationCascadeAdd(double realizedProfit,color engineColor=clrYellow)
{
   if(MathAbs(realizedProfit)<0.000001)return;
   int limit=MathMin(g_realizationCascadeCount,EAGOLD_REALIZATION_CASCADE_MAX-1);
   for(int i=limit;i>=1;i--)
   {
      g_realizationCascadeValues[i]=g_realizationCascadeValues[i-1];
      g_realizationCascadeColors[i]=g_realizationCascadeColors[i-1];
   }
   g_realizationCascadeValues[0]=realizedProfit;
   g_realizationCascadeColors[0]=engineColor;
   if(g_realizationCascadeCount<EAGOLD_REALIZATION_CASCADE_MAX)g_realizationCascadeCount++;
   EAGOLD_RealizationCascadeRender();
}

void EAGOLD_RealizationCascadeUpdate(){if(!EnableModularizationPanel){EAGOLD_RealizationCascadeDelete();return;}if(g_realizationCascadeCount>0)EAGOLD_RealizationCascadeRender();}

void EAGOLD_RealizationCascadeDelete()
{
   string bgName=g_realizationCascadePrefix+"BG";
   ObjectDelete(0,bgName);
   for(int i=0;i<EAGOLD_REALIZATION_CASCADE_MAX;i++){ObjectDelete(0,g_realizationCascadePrefix+"V_"+IntegerToString(i));ObjectDelete(0,g_realizationCascadePrefix+"D_"+IntegerToString(i));}
}

#endif
