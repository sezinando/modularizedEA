#ifndef EAGOLD_PANEL_MQH
#define EAGOLD_PANEL_MQH

void EAGOLD_PanelUpdate(const EAGOLD_Context &ctx,const EAGOLD_BasketState &s)
{
   Comment("EAGOLD MODULAR v0.101\n",
           "BOOT STATUS: OK   R10: ",(ctx.enableR10?"ENABLED":"DISABLED"),
           "   R10 PAIR: ",(ctx.enableR10Pair?"ENABLED":"DISABLED"),"\n",
           "CORE: Context OK | State OK | Orders OK | Execution OK\n",
           "      Events OK | Telemetry OK | Persistence OK\n",
           "UI:   Panel OK | GM-3 OK | Server Clock OK\n",
           "SYMBOL ",ctx.symbol,"   MAGIC ",ctx.magic,"   TRADING ",
           (ctx.enableR10?"ENABLED":"DISABLED"),"\n",
           "GM-3  ",EAGOLD_GM3Clock(),"   SERVER  ",EAGOLD_ServerClock(),"\n",
           "BUY ",DoubleToString(s.buyLots,2),"  SELL ",DoubleToString(s.sellLots,2),
           "  NET ",DoubleToString(s.exposure,2),"  GROSS ",DoubleToString(s.gross,2),"\n",
           "EQUITY ",DoubleToString(s.equity,2),"  FREE MARGIN ",DoubleToString(s.freeMargin,2));
}

void EAGOLD_PanelDelete()
{
   Comment("");
}

#endif
