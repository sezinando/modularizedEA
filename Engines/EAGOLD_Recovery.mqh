#ifndef EAGOLD_RECOVERY_MQH
#define EAGOLD_RECOVERY_MQH

//==================================================================
// STAGE 6 — RECOVERY / R5 / R10.2 / R11
// Business behavior extracted from EAGOLD v0.106 without redesign.
//==================================================================

double RecoveryStepForLevel(int level){double step=RecoveryMinDistance;if(level<0)level=0;if(EnableRecoveryStepMultiplier&&RecoveryStepMultiplier>1.0){for(int i=0;i<level;i++){step*=RecoveryStepMultiplier;if(RecoveryStepMax>0.0&&step>=RecoveryStepMax){step=RecoveryStepMax;break;}}}if(RecoveryStepMax>0.0&&step>RecoveryStepMax)step=RecoveryStepMax;return(step);}

int RecoveryLevel(int direction){int count=CountDirectionPositions(direction);if(count<=1)return(0);return(count-1);}

double R10RecoveryDebt(){if(!g_r10RecoveryCycleActive)return(0.0);double debt=g_r10RecoveryStartEquity-g_r10RecoveryWorstEquity;if(debt<0.0)debt=0.0;return(debt);}

double R10RecoveryRemainingDebt(){if(!g_r10RecoveryCycleActive)return(0.0);double remaining=g_r10RecoveryStartEquity-AccountEquity();if(remaining<0.0)remaining=0.0;return(remaining);}

double R10RecoverySurplus(){if(!g_r10RecoveryCycleActive)return(0.0);double surplus=AccountEquity()-g_r10RecoveryStartEquity;if(surplus<0.0)surplus=0.0;return(surplus);}

double R10RecoveryTarget(){double debt=R10RecoveryDebt();double target=MathMax(0.0,R10RecoveryProfitTarget);if(R10RecoveryDebtTargetPercent>0.0)target+=debt*(R10RecoveryDebtTargetPercent/100.0);return(target);}

void R10RecoveryStartCycle(){g_r10RecoveryCycleActive=true;g_r10RecoveryStartEquity=AccountEquity();g_r10RecoveryWorstEquity=g_r10RecoveryStartEquity;Print(EA_NAME," R10.2 CYCLE START: equity=",DoubleToString(g_r10RecoveryStartEquity,2));CreateEngineActionMarker("R10.2","CYCLE",HeavyDirection(),0.0);}

void R10RecoveryResetCycle(){if(g_r10RecoveryCycleActive){Print(EA_NAME," R10.2 CYCLE RESET: debt=",DoubleToString(R10RecoveryDebt(),2)," surplus=",DoubleToString(R10RecoverySurplus(),2));CreateEngineActionMarker("R10.2","REALIZE",HeavyDirection(),0.0);}g_r10RecoveryCycleActive=false;g_r10RecoveryStartEquity=0.0;g_r10RecoveryWorstEquity=0.0;}

void R10RecoveryUpdateState(){if(!EnableR10RecoveryRealization)return;double equity=AccountEquity();if(CountEAGOLDOrders()==0){R10RecoveryResetCycle();return;}if(!g_r10RecoveryCycleActive)R10RecoveryStartCycle();if(equity<g_r10RecoveryWorstEquity)g_r10RecoveryWorstEquity=equity;}

bool R10RecoveryAllowBasketClose(int direction){if(!EnableR10RecoveryRealization)return(true);if(!g_r10RecoveryCycleActive)return(true);double debt=R10RecoveryDebt();if(debt<R10RecoveryMinDebt)return(true);double remaining=R10RecoveryRemainingDebt();double surplus=R10RecoverySurplus();double target=R10RecoveryTarget();if(R10RecoveryRequireDebtRepaid&&remaining>0.01){Print(EA_NAME," R10.2 HOLD: debt not repaid. remaining=",DoubleToString(remaining,2)," debt=",DoubleToString(debt,2));return(false);}if(surplus+0.01<target){Print(EA_NAME," R10.2 HOLD: recovery target not reached. surplus=",DoubleToString(surplus,2)," target=",DoubleToString(target,2));return(false);}return(true);}

bool GetLatestActivatedPosition(int direction,double &latestPrice,double &latestLot,int &latestTicket){int type=(direction==OP_BUY?OP_BUY:OP_SELL);latestPrice=0.0;latestLot=NormalizeLot(Lot);latestTicket=-1;datetime latestTime=0;bool found=false;for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;datetime t=OrderOpenTime();int ticket=OrderTicket();if(!found||t>latestTime||(t==latestTime&&ticket>latestTicket)){found=true;latestTime=t;latestPrice=OrderOpenPrice();latestLot=OrderLots();latestTicket=ticket;}}return(found);}

bool HasRecoveryPending(int direction){string tag=(direction==OP_BUY?"EAGOLD BUY RECOVERY":"EAGOLD SELL RECOVERY");int type=(direction==OP_BUY?OP_BUYSTOP:OP_SELLSTOP);for(int i=OrdersTotal()-1;i>=0;i--){if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue;if(!IsEAGOLDOrder()||OrderType()!=type)continue;if(StringFind(OrderComment(),tag,0)>=0)return(true);}return(false);}

double NextRecoveryLot(double previousLot){if(previousLot<=0.0)return(NormalizeLot(Lot));return(NormalizeLot(previousLot*Multiplier+LotIncrement));}

void BuyRecovery(){if(SmartGrid1<=0.0||RecoveryMinDistance<=0.0)return;if(CountDirectionPositions(OP_BUY)<=0||HasRecoveryPending(OP_BUY))return;double p=0.0,l=Lot;int t=-1;if(!GetLatestActivatedPosition(OP_BUY,p,l,t))return;RefreshRates();if(p-Ask<PointsToPrice(2.0*SmartGrid1))return;int level=RecoveryLevel(OP_BUY)-1;double dynamicStep=RecoveryStepForLevel(level);double stop=NormalizePrice(Ask+PointsToPrice(dynamicStep));if(stop<=Ask+MarketInfo(Symbol(),MODE_STOPLEVEL)*Point)return;Print(EA_NAME," RULE 11 BUY STEP: level=",level," step=",DoubleToString(dynamicStep,1)," multiplier=",DoubleToString(RecoveryStepMultiplier,2));double recoveryLot=NextRecoveryLot(l);int recoveryTicket=SendPending(OP_BUYSTOP,stop,recoveryLot,"EAGOLD BUY RECOVERY");if(recoveryTicket>0){CreateEngineActionMarker("R5","RECOVERY",OP_BUY,recoveryLot);CreateEngineActionMarker("R11","STEP "+DoubleToString(dynamicStep,0),OP_BUY,0.0);}}

void SellRecovery(){if(SmartGrid1<=0.0||RecoveryMinDistance<=0.0)return;if(CountDirectionPositions(OP_SELL)<=0||HasRecoveryPending(OP_SELL))return;double p=0.0,l=Lot;int t=-1;if(!GetLatestActivatedPosition(OP_SELL,p,l,t))return;RefreshRates();if(Bid-p<PointsToPrice(2.0*SmartGrid1))return;int level=RecoveryLevel(OP_SELL)-1;double dynamicStep=RecoveryStepForLevel(level);double stop=NormalizePrice(Bid-PointsToPrice(dynamicStep));if(stop>=Bid-MarketInfo(Symbol(),MODE_STOPLEVEL)*Point)return;Print(EA_NAME," RULE 11 SELL STEP: level=",level," step=",DoubleToString(dynamicStep,1)," multiplier=",DoubleToString(RecoveryStepMultiplier,2));double recoveryLot=NextRecoveryLot(l);int recoveryTicket=SendPending(OP_SELLSTOP,stop,recoveryLot,"EAGOLD SELL RECOVERY");if(recoveryTicket>0){CreateEngineActionMarker("R5","RECOVERY",OP_SELL,recoveryLot);CreateEngineActionMarker("R11","STEP "+DoubleToString(dynamicStep,0),OP_SELL,0.0);}}

#endif
