#ifndef EAGOLD_R1_ADMISSION_MQH
#define EAGOLD_R1_ADMISSION_MQH

//==================================================================
// STAGE 8 — R1.1 FIRST ADMISSION CONTROL
// Business behavior extracted from EAGOLD v0.106 without redesign.
//==================================================================

void R1Decision(string decision,string reason){g_r1LastDecision=decision;g_r1LastReason=reason;g_r1LastDecisionTime=TimeCurrent();if(EnableR1DecisionLog)Print(EA_NAME," R1 ADMISSION: ",decision," reason=",reason);}

bool R1ValidateLot(double lots,string &reason){double minLot=MarketInfo(Symbol(),MODE_MINLOT);double maxLot=MarketInfo(Symbol(),MODE_MAXLOT);double lotStep=MarketInfo(Symbol(),MODE_LOTSTEP);double eps=0.0000001;if(minLot>0.0&&lots<minLot-eps){reason="BROKER_MIN_LOT";return(false);}if(maxLot>0.0&&lots>maxLot+eps){reason="BROKER_MAX_LOT";return(false);}if(lotStep>0.0){double steps=(lots-minLot)/lotStep;double nearest=MathRound(steps);if(MathAbs(steps-nearest)>0.000001){reason="BROKER_LOT_STEP";return(false);}}reason="PASS";return(true);}

bool R1BrokerGuard(int direction,double price,string &reason){double stopLevel=MarketInfo(Symbol(),MODE_STOPLEVEL);if(stopLevel<0.0)stopLevel=0.0;double requiredDistance=stopLevel+MathMax(0.0,R1BrokerSafetyBufferPoints);RefreshRates();double actualDistance=(direction==OP_BUY?(price-Ask):(Bid-price))/Point;if(actualDistance+0.000001<requiredDistance){reason="BROKER_STOPLEVEL";return(false);}reason="PASS";return(true);}

bool R1TradePermissionGuard(string &reason){double allowed=MarketInfo(Symbol(),MODE_TRADEALLOWED);if(allowed<0.5){reason="TRADE_NOT_ALLOWED";return(false);}reason="PASS";return(true);}

bool R1MarginGuard(int direction,double lots,string &reason){int marketType=(direction==OP_BUY?OP_BUY:OP_SELL);ResetLastError();double remaining=AccountFreeMarginCheck(Symbol(),marketType,lots);int err=GetLastError();if(remaining<=0.0||err==134){reason="INSUFFICIENT_MARGIN";return(false);}if(R1MinFreeMarginAfterOrder>0.0&&remaining<R1MinFreeMarginAfterOrder){reason="MIN_FREE_MARGIN";return(false);}reason="PASS";return(true);}

bool R1AdmissionAllowed(int direction,double lots,double price,string &reason){reason="PASS";if(!EnableR1AdmissionGate){R1Decision("DISABLED","MASTER_OFF");return(true);}string localReason="PASS";if(EnableR1TradePermissionGuard){if(!R1TradePermissionGuard(localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}if(EnableR1BrokerGuard){if(!R1BrokerGuard(direction,price,localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}if(EnableR1LotGuard){if(!R1ValidateLot(lots,localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}if(EnableR1MarginGuard){if(!R1MarginGuard(direction,lots,localReason)){reason=localReason;R1Decision("BLOCK",reason);return(false);}}R1Decision("ALLOW","ALL_ENABLED_GATES_PASS");return(true);}

#endif
