#ifndef EAGOLD_PANEL_MQH
#define EAGOLD_PANEL_MQH

void EAGOLD_PanelUpdate(const EAGOLD_BasketState &s)
{
   Comment("EAGOLD MODULAR v0.1\n",
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
