#ifndef EAGOLD_LIFECYCLE_MQH
#define EAGOLD_LIFECYCLE_MQH

//==================================================================
// STAGE 7 — LIFECYCLE / R4 / R5 / R7
// Business behavior extracted from EAGOLD v0.106 without redesign.
//==================================================================

int g_globalTrailTickets[];
datetime g_globalTrailLastModifyTime[];
double g_globalTrailLastMarketPrice[];

int GlobalTrailStateIndex(int ticket){for(int i=0;i<ArraySize(g_globalTrailTickets);i++)if(g_globalTrailTickets[i]==ticket)return(i);return(-1);}

int GlobalTrailEnsureState(int ticket){int idx=GlobalTrailStateIndex(ticket);if(idx>=0)return(idx);int n=ArraySize(g_globalTrailTickets);ArrayResize(g_globalTrailTickets,n+1);ArrayResize(g_globalTrailLastModifyTime,n+1);ArrayResize(g_globalTrailLastMarketPrice,n+1);g_globalTrailTickets[n]=ticket;g_globalTrailLastModifyTime[n]=0;g_globalTrailLastMarketPrice[n]=0.0;return(n);}

void GlobalTrailRecordModify(int ticket,datetime modifyTime,double marketPrice){int idx=GlobalTrailEnsureState(ticket);g_globalTrailLastModifyTime[idx]=modifyTime;g_globalTrailLastMarketPrice[idx]=marketPrice;}

void EnsureDirectionMachineAlive(int direction){if(CountDirectionPositions(direction)>0)return;if(CountDirectionPending(direction)>0)return;RefreshRates();int ticket=-1;if(direction==OP_BUY)ticket=SendPending(OP_BUYSTOP,Ask+PointsToPrice(BasketRestartStep),Lot,"EAGOLD R7 RESTART BUY");else ticket=SendPending(OP_SELLSTOP,Bid-PointsToPrice(BasketRestartStep),Lot,"EAGOLD R7 RESTART SELL");if(ticket>0)Print(EA_NAME," KEEP-ALIVE: ",(direction==OP_BUY?"BUY":"SELL")," machine recreated. STOP ticket=",ticket);}

void CreateFirstOrdersIfFlat(){if(CountEAGOLDOrders()==0){RefreshRates();double buyPrice=NormalizePrice(Ask+PointsToPrice(FirstStep));double sellPrice=NormalizePrice(Bid-PointsToPrice(FirstStep));if(EnableR1AdmissionGate){string buyReason="PASS",sellReason="PASS";bool buyAllowed=R1AdmissionAllowed(OP_BUY,Lot,buyPrice,buyReason);bool sellAllowed=R1AdmissionAllowed(OP_SELL,Lot,sellPrice,sellReason);if(!buyAllowed||!sellAllowed){string reason=(!buyAllowed?"BUY_":"SELL_");reason+=(!buyAllowed?buyReason:sellReason);R1Decision("BLOCK",reason);Print(EA_NAME," RULE 1: FIRST cycle blocked atomically. BUY=",buyReason," SELL=",sellReason);CreateEngineActionMarker("R1.1","BLOCK",OP_BUY,Lot);CreateEngineActionMarker("R1.1","BLOCK",OP_SELL,Lot);return;}}int b=SendPending(OP_BUYSTOP,buyPrice,Lot,"EAGOLD R1 FIRST BUY");int s=SendPending(OP_SELLSTOP,sellPrice,Lot,"EAGOLD R1 FIRST SELL");if(b>0||s>0){Print(EA_NAME," RULE 1: initial seeds created. BUY=",b," SELL=",s);CreateEngineActionMarker("R1","SEED",OP_BUY,Lot);CreateEngineActionMarker("R1","SEED",OP_SELL,Lot);}return;}EnsureDirectionMachineAlive(OP_BUY);EnsureDirectionMachineAlive(OP_SELL);}

bool CanCloseLightBasket(int direction){double b=DirectionLots(OP_BUY),s=DirectionLots(OP_SELL);if(b==s)return(true);if(direction==OP_BUY&&b<s&&s>0.0)return(false);if(direction==OP_SELL&&s<b&&b>0.0)return(false);return(true);}

bool CloseDirectionPositionsRobust(int direction){int type=(direction==OP_BUY?OP_BUY:OP_SELL);int tickets[];ArrayResize(tickets,0);for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;int n=ArraySize(tickets);ArrayResize(tickets,n+1);tickets[n]=OrderTicket();}bool ok=true;for(int j=0;j<ArraySize(tickets);j++){if(!CloseMarketOrder(tickets[j]))ok=false;}return(ok&&CountDirectionPositions(direction)==0);}

void BuySingleTakeProfit(){if(CountDirectionPositions(OP_BUY)!=1)return;if(!CanCloseLightBasket(OP_BUY))return;if(!R10RecoveryAllowBasketClose(OP_BUY))return;if(DirectionBasketProfit(OP_BUY)<TakeProfit)return;int ticket=-1;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(IsEAGOLDOrder()&&OrderType()==OP_BUY){ticket=OrderTicket();break;}}if(ticket>0&&CloseMarketOrder(ticket)){CloseAllDirectionPending(OP_BUY);SendPending(OP_BUYSTOP,Ask+PointsToPrice(MiniGrid1),Lot,"EAGOLD R4 BUY NEXT");Print(EA_NAME," RULE 4 BUY TP REENTRY. closed=",ticket);CreateEngineActionMarker("R4","REALIZE",OP_BUY,Lot);}}

void SellSingleTakeProfit(){if(CountDirectionPositions(OP_SELL)!=1)return;if(!CanCloseLightBasket(OP_SELL))return;if(!R10RecoveryAllowBasketClose(OP_SELL))return;if(DirectionBasketProfit(OP_SELL)<TakeProfit)return;int ticket=-1;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(IsEAGOLDOrder()&&OrderType()==OP_SELL){ticket=OrderTicket();break;}}if(ticket>0&&CloseMarketOrder(ticket)){CloseAllDirectionPending(OP_SELL);SendPending(OP_SELLSTOP,Bid-PointsToPrice(MiniGrid2),Lot,"EAGOLD R4 SELL NEXT");Print(EA_NAME," RULE 4 SELL TP REENTRY. closed=",ticket);CreateEngineActionMarker("R4","REALIZE",OP_SELL,Lot);}}

bool BuyBasketTargetReached(){int count=CountDirectionPositions(OP_BUY);if(count<=1||TakeProfit<=0.0)return(false);return(DirectionBasketProfit(OP_BUY)>=count*TakeProfit);}

bool SellBasketTargetReached(){int count=CountDirectionPositions(OP_SELL);if(count<=1||TakeProfit<=0.0)return(false);return(DirectionBasketProfit(OP_SELL)>=count*TakeProfit);}

bool BuyBasketClose(){int count=CountDirectionPositions(OP_BUY);if(count<=1||TakeProfit<=0.0)return(false);if(!CanCloseLightBasket(OP_BUY))return(false);if(!R10RecoveryAllowBasketClose(OP_BUY))return(false);double target=count*TakeProfit,profit=DirectionBasketProfit(OP_BUY);if(profit<target)return(false);Print(EA_NAME," RULE 5 BUY TARGET. count=",count," profit=",DoubleToString(profit,2)," target=",DoubleToString(target,2));bool closed=CloseDirectionPositionsRobust(OP_BUY);if(closed){CloseAllDirectionPending(OP_BUY);Print(EA_NAME," RULE 5 BUY CLOSED ALL. count=",count);CreateEngineActionMarker("R5","BALANCE",OP_BUY,DirectionLots(OP_BUY));return(true);}Print(EA_NAME," RULE 5 BUY PARTIAL/FAILED. remaining=",CountDirectionPositions(OP_BUY));return(false);}

bool SellBasketClose(){int count=CountDirectionPositions(OP_SELL);if(count<=1||TakeProfit<=0.0)return(false);if(!CanCloseLightBasket(OP_SELL))return(false);if(!R10RecoveryAllowBasketClose(OP_SELL))return(false);double target=count*TakeProfit,profit=DirectionBasketProfit(OP_SELL);if(profit<target)return(false);Print(EA_NAME," RULE 5 SELL TARGET. count=",count," profit=",DoubleToString(profit,2)," target=",DoubleToString(target,2));bool closed=CloseDirectionPositionsRobust(OP_SELL);if(closed){CloseAllDirectionPending(OP_SELL);Print(EA_NAME," RULE 5 SELL CLOSED ALL. count=",count);CreateEngineActionMarker("R5","BALANCE",OP_SELL,DirectionLots(OP_SELL));return(true);}Print(EA_NAME," RULE 5 SELL PARTIAL/FAILED. remaining=",CountDirectionPositions(OP_SELL));return(false);}

void TrailAllStopOrders(){if(!EnableGlobalStopTrail||PendingStepTrail<=0.0)return;double stopLevel=MarketInfo(Symbol(),MODE_STOPLEVEL)*Point;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder())continue;int type=OrderType();if(type!=OP_BUYSTOP&&type!=OP_SELLSTOP)continue;string c=OrderComment();double resetPoints=0.0,triggerPoints=PendingStepTrail;string family="GLOBAL";if(StringFind(c,"EAGOLD R1 FIRST",0)>=0){resetPoints=FirstStep;triggerPoints=FirstStep+PendingStepTrail;family="R1 FIRST";}else if(StringFind(c,"EAGOLD BUY RECOVERY",0)>=0||StringFind(c,"EAGOLD SELL RECOVERY",0)>=0){resetPoints=RecoveryMinDistance;family="RECOVERY";}else if(StringFind(c,"EAGOLD R4 BUY NEXT",0)>=0){resetPoints=MiniGrid1;family="R4 BUY";}else if(StringFind(c,"EAGOLD R4 SELL NEXT",0)>=0){resetPoints=MiniGrid2;family="R4 SELL";}else if(StringFind(c,"EAGOLD R7 RESTART",0)>=0){resetPoints=BasketRestartStep;family="R7 RESTART";}else{double marketDistance=(type==OP_BUYSTOP?OrderOpenPrice()-Ask:Bid-OrderOpenPrice());if(marketDistance<=0.0)continue;resetPoints=marketDistance/Point;family="GLOBAL UNKNOWN";}if(resetPoints<=0.0||triggerPoints<=0.0)continue;double trigger=PointsToPrice(triggerPoints),resetDistance=PointsToPrice(resetPoints);RefreshRates();double current=OrderOpenPrice(),desired=current,adverseDistance=0.0;int ticket=OrderTicket();double marketPrice=(type==OP_BUYSTOP?Ask:Bid);

      // Per-ticket throttling. Zero keeps the legacy behavior unchanged.
      int trailState=GlobalTrailEnsureState(ticket);
      if(GlobalStopTrailCooldownSeconds>0.0&&g_globalTrailLastModifyTime[trailState]>0){double elapsed=(double)(TimeCurrent()-g_globalTrailLastModifyTime[trailState]);if(elapsed<GlobalStopTrailCooldownSeconds)continue;}
      if(GlobalStopTrailMinStepPoints>0.0&&g_globalTrailLastMarketPrice[trailState]>0.0){double displacement=MathAbs(marketPrice-g_globalTrailLastMarketPrice[trailState])/Point;if(displacement<GlobalStopTrailMinStepPoints)continue;}

      if(type==OP_BUYSTOP){adverseDistance=current-Ask;if(adverseDistance<trigger)continue;desired=NormalizePrice(Ask+resetDistance);if(desired>=current||desired<=Ask+stopLevel)continue;}else{adverseDistance=Bid-current;if(adverseDistance<trigger)continue;desired=NormalizePrice(Bid-resetDistance);if(desired<=current||desired>=Bid-stopLevel)continue;}ResetLastError();if(!OrderModify(ticket,desired,0,0,0,clrNONE))Print(EA_NAME," GLOBAL STOP TRAIL FAILED ticket=",ticket," family=",family," error=",GetLastError());else{GlobalTrailRecordModify(ticket,TimeCurrent(),marketPrice);Print(EA_NAME," GLOBAL STOP TRAIL ticket=",ticket," family=",family," old=",DoubleToString(current,Digits)," new=",DoubleToString(desired,Digits)," adverse=",DoubleToString(adverseDistance/Point,1)," trigger=",DoubleToString(triggerPoints,1)," reset=",DoubleToString(resetPoints,1));}}}

void RestartEmptyBasket(int direction){if(BasketRestartStep<=0.0)return;if(CountDirectionPositions(direction)!=0||CountDirectionPending(direction)!=0)return;RefreshRates();if(direction==OP_BUY){int r7ticket=SendPending(OP_BUYSTOP,Ask+PointsToPrice(BasketRestartStep),Lot,"EAGOLD R7 RESTART BUY");if(r7ticket>0)CreateEngineActionMarker("R7","RESTART",OP_BUY,Lot);}else{int r7ticket=SendPending(OP_SELLSTOP,Bid-PointsToPrice(BasketRestartStep),Lot,"EAGOLD R7 RESTART SELL");if(r7ticket>0)CreateEngineActionMarker("R7","RESTART",OP_SELL,Lot);}}

void BuyMachine(){if(BuyBasketTargetReached()&&DirectionLots(OP_BUY)>DirectionLots(OP_SELL))Rule10Reduce(OP_BUY);bool basketClosed=BuyBasketClose();if(basketClosed)RestartEmptyBasket(OP_BUY);BuySingleTakeProfit();BuyRecovery();}

void SellMachine(){if(SellBasketTargetReached()&&DirectionLots(OP_SELL)>DirectionLots(OP_BUY))Rule10Reduce(OP_SELL);bool basketClosed=SellBasketClose();if(basketClosed)RestartEmptyBasket(OP_SELL);SellSingleTakeProfit();SellRecovery();}

#endif
