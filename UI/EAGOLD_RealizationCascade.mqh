#ifndef EAGOLD_REALIZATION_CASCADE_MQH
#define EAGOLD_REALIZATION_CASCADE_MQH

#define EAGOLD_REALIZATION_CASCADE_MAX 30
string g_realizationCascadePrefix="EAGOLD_REALIZATION_CASCADE_";
double g_realizationCascadeValues[EAGOLD_REALIZATION_CASCADE_MAX];
color g_realizationCascadeColors[EAGOLD_REALIZATION_CASCADE_MAX];
int g_realizationCascadeCount=0;
bool g_realizationCascadeColorPending=false;

string g_actionCascadePrefix="EAGOLD_ACTION_CASCADE_";
string g_actionCascadeEngine[EAGOLD_REALIZATION_CASCADE_MAX];
datetime g_actionCascadeTime[EAGOLD_REALIZATION_CASCADE_MAX];
color g_actionCascadeColors[EAGOLD_REALIZATION_CASCADE_MAX];
int g_actionCascadeCount=0;

color CascadeEngineColor(string engine){if(engine=="R1")return(clrYellow);if(engine=="R1.1")return(clrBlue);if(engine=="R4")return(clrRed);if(engine=="R5")return(clrMagenta);if(engine=="BRX")return(clrAqua);if(engine=="R7")return(clrOrange);if(engine=="R10")return(clrViolet);if(engine=="R13")return(clrLime);return(clrWhite);}

void EAGOLD_ActionCascadeAdd(string engine)
{
   if(engine=="")return;
   color c=CascadeEngineColor(engine);
   int limit=MathMin(g_actionCascadeCount,EAGOLD_REALIZATION_CASCADE_MAX-1);
   for(int i=limit;i>=1;i--){g_actionCascadeEngine[i]=g_actionCascadeEngine[i-1];g_actionCascadeTime[i]=g_actionCascadeTime[i-1];g_actionCascadeColors[i]=g_actionCascadeColors[i-1];}
   g_actionCascadeEngine[0]=engine;g_actionCascadeTime[0]=TimeCurrent();g_actionCascadeColors[0]=c;
   if(g_actionCascadeCount<EAGOLD_REALIZATION_CASCADE_MAX)g_actionCascadeCount++;
   if(g_realizationCascadeColorPending&&g_realizationCascadeCount>0){g_realizationCascadeColors[0]=c;g_realizationCascadeColorPending=false;}
}

void EAGOLD_RealizationCascadeAdd(double realizedProfit,color engineColor=clrYellow)
{
   if(MathAbs(realizedProfit)<0.000001)return;
   int limit=MathMin(g_realizationCascadeCount,EAGOLD_REALIZATION_CASCADE_MAX-1);
   for(int i=limit;i>=1;i--){g_realizationCascadeValues[i]=g_realizationCascadeValues[i-1];g_realizationCascadeColors[i]=g_realizationCascadeColors[i-1];}
   g_realizationCascadeValues[0]=realizedProfit;g_realizationCascadeColors[0]=engineColor;
   if(g_realizationCascadeCount<EAGOLD_REALIZATION_CASCADE_MAX)g_realizationCascadeCount++;
   g_realizationCascadeColorPending=true;
}

void EAGOLD_RealizationCascadeDelete(){ObjectsDeleteAll(0,g_realizationCascadePrefix);ObjectsDeleteAll(0,g_actionCascadePrefix);}

void EAGOLD_RealizationCascadeUpdate()
{
   if(!EnableModularizationPanel){EAGOLD_RealizationCascadeDelete();return;}
   if(g_realizationCascadeCount<1&&g_actionCascadeCount<1)return;

   int rowHeight=16,headerHeight=20,gap=8,right=8;
   int actionWidth=118,realWidth=78;
   int panelHeight=headerHeight+EAGOLD_REALIZATION_CASCADE_MAX*rowHeight+8;
   int panelY=8;

   // Two independent FIFO panels, side-by-side, anchored to the upper-right.
   // REALIZATIONS occupies the rightmost column; ACTIONS sits immediately
   // to its left. Both therefore remain horizontally aligned at all times.
   int realRight=right;
   int actionRight=right+realWidth+gap;

   // ACTIONS
   string actionBg=g_actionCascadePrefix+"BG";
   if(ObjectFind(0,actionBg)<0)ObjectCreate(0,actionBg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,actionBg,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(0,actionBg,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);ObjectSetInteger(0,actionBg,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,actionBg,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,actionBg,OBJPROP_HIDDEN,true);ObjectSetInteger(0,actionBg,OBJPROP_BACK,false);ObjectSetInteger(0,actionBg,OBJPROP_BGCOLOR,clrBlack);ObjectSetInteger(0,actionBg,OBJPROP_COLOR,clrBlack);ObjectSetInteger(0,actionBg,OBJPROP_XDISTANCE,actionRight);ObjectSetInteger(0,actionBg,OBJPROP_YDISTANCE,panelY);ObjectSetInteger(0,actionBg,OBJPROP_XSIZE,actionWidth);ObjectSetInteger(0,actionBg,OBJPROP_YSIZE,panelHeight);ObjectSetInteger(0,actionBg,OBJPROP_ZORDER,900);

   string actionTitle=g_actionCascadePrefix+"TITLE";
   if(ObjectFind(0,actionTitle)<0)ObjectCreate(0,actionTitle,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,actionTitle,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(0,actionTitle,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);ObjectSetInteger(0,actionTitle,OBJPROP_XDISTANCE,actionRight+7);ObjectSetInteger(0,actionTitle,OBJPROP_YDISTANCE,panelY+8);ObjectSetInteger(0,actionTitle,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,actionTitle,OBJPROP_HIDDEN,true);ObjectSetString(0,actionTitle,OBJPROP_FONT,"Arial Bold");ObjectSetInteger(0,actionTitle,OBJPROP_FONTSIZE,9);ObjectSetInteger(0,actionTitle,OBJPROP_COLOR,clrWhite);ObjectSetString(0,actionTitle,OBJPROP_TEXT,"ACOES DO EA (FIFO - 30)");

   for(int a=0;a<EAGOLD_REALIZATION_CASCADE_MAX;a++){string an=g_actionCascadePrefix+IntegerToString(a);if(a<g_actionCascadeCount){if(ObjectFind(0,an)<0)ObjectCreate(0,an,OBJ_LABEL,0,0,0);int ay=panelY+headerHeight+a*rowHeight;ObjectSetInteger(0,an,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(0,an,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);ObjectSetInteger(0,an,OBJPROP_XDISTANCE,actionRight+7);ObjectSetInteger(0,an,OBJPROP_YDISTANCE,ay);ObjectSetInteger(0,an,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,an,OBJPROP_HIDDEN,true);ObjectSetInteger(0,an,OBJPROP_FONTSIZE,8);ObjectSetString(0,an,OBJPROP_FONT,"Arial");ObjectSetInteger(0,an,OBJPROP_COLOR,g_actionCascadeColors[a]);ObjectSetInteger(0,an,OBJPROP_ZORDER,901);ObjectSetString(0,an,OBJPROP_TEXT,TimeToString(g_actionCascadeTime[a],TIME_SECONDS)+"  "+g_actionCascadeEngine[a]);}else ObjectDelete(0,an);}

   // REALIZATIONS — values only; colored dot identifies the originating engine.
   string realBg=g_realizationCascadePrefix+"BG";
   if(ObjectFind(0,realBg)<0)ObjectCreate(0,realBg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,realBg,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(0,realBg,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);ObjectSetInteger(0,realBg,OBJPROP_BORDER_TYPE,BORDER_FLAT);ObjectSetInteger(0,realBg,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,realBg,OBJPROP_HIDDEN,true);ObjectSetInteger(0,realBg,OBJPROP_BACK,false);ObjectSetInteger(0,realBg,OBJPROP_BGCOLOR,clrBlack);ObjectSetInteger(0,realBg,OBJPROP_COLOR,clrBlack);ObjectSetInteger(0,realBg,OBJPROP_XDISTANCE,realRight);ObjectSetInteger(0,realBg,OBJPROP_YDISTANCE,panelY);ObjectSetInteger(0,realBg,OBJPROP_XSIZE,realWidth);ObjectSetInteger(0,realBg,OBJPROP_YSIZE,panelHeight);ObjectSetInteger(0,realBg,OBJPROP_ZORDER,900);

   string realTitle=g_realizationCascadePrefix+"TITLE";
   if(ObjectFind(0,realTitle)<0)ObjectCreate(0,realTitle,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,realTitle,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(0,realTitle,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);ObjectSetInteger(0,realTitle,OBJPROP_XDISTANCE,realRight+7);ObjectSetInteger(0,realTitle,OBJPROP_YDISTANCE,panelY+8);ObjectSetInteger(0,realTitle,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,realTitle,OBJPROP_HIDDEN,true);ObjectSetString(0,realTitle,OBJPROP_FONT,"Arial Bold");ObjectSetInteger(0,realTitle,OBJPROP_FONTSIZE,9);ObjectSetInteger(0,realTitle,OBJPROP_COLOR,clrWhite);ObjectSetString(0,realTitle,OBJPROP_TEXT,"REALIZACOES (FIFO - 30)");

   for(int r=0;r<EAGOLD_REALIZATION_CASCADE_MAX;r++){string vn=g_realizationCascadePrefix+"V_"+IntegerToString(r),dn=g_realizationCascadePrefix+"D_"+IntegerToString(r);if(r<g_realizationCascadeCount){int ry=panelY+headerHeight+r*rowHeight;if(ObjectFind(0,vn)<0)ObjectCreate(0,vn,OBJ_LABEL,0,0,0);ObjectSetInteger(0,vn,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(0,vn,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);ObjectSetInteger(0,vn,OBJPROP_XDISTANCE,realRight+8);ObjectSetInteger(0,vn,OBJPROP_YDISTANCE,ry);ObjectSetInteger(0,vn,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,vn,OBJPROP_HIDDEN,true);ObjectSetString(0,vn,OBJPROP_FONT,"Impact");ObjectSetInteger(0,vn,OBJPROP_FONTSIZE,9);ObjectSetInteger(0,vn,OBJPROP_COLOR,clrYellow);ObjectSetInteger(0,vn,OBJPROP_ZORDER,901);ObjectSetString(0,vn,OBJPROP_TEXT,DoubleToString(g_realizationCascadeValues[r],2));if(ObjectFind(0,dn)<0)ObjectCreate(0,dn,OBJ_LABEL,0,0,0);ObjectSetInteger(0,dn,OBJPROP_CORNER,CORNER_RIGHT_UPPER);ObjectSetInteger(0,dn,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);ObjectSetInteger(0,dn,OBJPROP_XDISTANCE,realRight+58);ObjectSetInteger(0,dn,OBJPROP_YDISTANCE,ry-1);ObjectSetInteger(0,dn,OBJPROP_SELECTABLE,false);ObjectSetInteger(0,dn,OBJPROP_HIDDEN,true);ObjectSetString(0,dn,OBJPROP_FONT,"Arial");ObjectSetInteger(0,dn,OBJPROP_FONTSIZE,9);ObjectSetInteger(0,dn,OBJPROP_COLOR,g_realizationCascadeColors[r]);ObjectSetInteger(0,dn,OBJPROP_ZORDER,902);ObjectSetString(0,dn,OBJPROP_TEXT,"●");}else{ObjectDelete(0,vn);ObjectDelete(0,dn);}}
   ChartRedraw(0);
}

#endif
