#ifndef EAGOLD_MODULARIZATION_PANEL_MQH
#define EAGOLD_MODULARIZATION_PANEL_MQH

string EAGOLD_MOD_PANEL_PREFIX="EAGOLD_MOD_";

void EAGOLD_ModPanelLabel(string id,string text,int row,color clr)
{
   string name=EAGOLD_MOD_PANEL_PREFIX+id;
   if(ObjectFind(0,name)<0)
   {
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,12);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,12+row*16);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
      ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
   }
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
}

void EAGOLD_ModPanelUpdate()
{
   EAGOLD_ModPanelLabel("TITLE","EAGOLD MODULARIZATION",0,clrWhite);
   EAGOLD_ModPanelLabel("SEP","------------------------",1,clrSilver);
   EAGOLD_ModPanelLabel("S1","[DONE] 01 CORE / ORDERS",2,clrLime);
   EAGOLD_ModPanelLabel("S2","[NEXT] 02 CORE / EXECUTION",3,clrYellow);
   EAGOLD_ModPanelLabel("S3","[----] 03 PERSISTENCE",4,clrSilver);
   EAGOLD_ModPanelLabel("S4","[----] 04 R9 EXPOSURE",5,clrSilver);
   EAGOLD_ModPanelLabel("S5","[----] 05 R10 INTEGRATION",6,clrSilver);
   EAGOLD_ModPanelLabel("S6","[----] 06 RECOVERY",7,clrSilver);
   EAGOLD_ModPanelLabel("S7","[----] 07 LIFECYCLE",8,clrSilver);
   EAGOLD_ModPanelLabel("S8","[----] 08 R1 ADMISSION",9,clrSilver);
   EAGOLD_ModPanelLabel("PROG","PROGRESS: 1 / 8  (12.5%)",10,clrAqua);
   EAGOLD_ModPanelLabel("BASE","BASELINE: v0.106",11,clrSilver);
   ChartRedraw(0);
}

void EAGOLD_ModPanelDelete()
{
   string ids[]={"TITLE","SEP","S1","S2","S3","S4","S5","S6","S7","S8","PROG","BASE"};
   for(int i=0;i<ArraySize(ids);i++)
   {
      string name=EAGOLD_MOD_PANEL_PREFIX+ids[i];
      if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
   }
}

#endif
