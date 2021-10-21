#property description "Easy Ultimate Capital. Slide Crypto Exchange Wave. High-Leverage, No-Commission, No-Spread."
#property copyright "MaxiPrimo 2021"
#property link      "http://www.linkedin.com/in/ms84"
#property version   "1.0"

input double INPUT_TradeLotSize = 0.9; // Trade Capital Usage
input double INPUT_MaxTradeVolume = 47.5; // Maximum Trade Volume
input int INPUT_MaxCapital = 100*1000*1000; // Maximum Capital In Currency
input int INPUT_MaxRunMinutes = 1440*7; // Maximal Minutes To Run
input double INPUT_CapitalFallback = 0.35; // Maximal Capital Lost Fallback

int max_error = 5;
int error_count = 0;

bool CheckError(bool NoError){
   if(!NoError){
      error_count++;
      if(error_count >= max_error){
         ExpertRemove();
         return NoError;
      }
   }else{
      error_count = 0;
   }
   return NoError;
}

#include <Object.mqh>
class TickObject : public CObject
{
public:
   int time;
   double avg;
   TickObject(int time, double avg){
      this.time = time;
      this.avg = avg;
   }
};


#include <Arrays\List.mqh>
CList list;
int ma = 100;
double mean = 0;
double GetMean(){
   double sum = 0;
   for(int i=0; i<list.Total(); i++){
      sum += ((TickObject*)list.GetNodeAtIndex(i)).avg;
   }
   return sum/list.Total();
}


double LotSize(ENUM_ORDER_TYPE OrderType, double Ask, double Percent)
{
   double required_margin = 0;
   if(OrderCalcMargin(OrderType,Symbol(),1.0,Ask,required_margin))
   {
     if(NormalizeDouble(AccountInfoDouble(ACCOUNT_FREEMARGIN)/required_margin,2))
     {
       double trade_volume=NormalizeDouble((AccountInfoDouble(ACCOUNT_FREEMARGIN)/required_margin)*Percent,2);
       return trade_volume;
     }
   }
   return -1;
}

#include <Trade\Trade.mqh>
CTrade m_trade;

bool OpenOrder(ENUM_ORDER_TYPE OrderType, double Price, double Lot)
{
   bool NoError = m_trade.PositionOpen(Symbol(), OrderType, Lot, Price, 0, 0, NULL);
   return NoError;
}

bool ClosePosition()
{
   bool NoError = true;
   for(int i=PositionsTotal()-1; i>=0; i--){
      if(!m_trade.PositionClose(PositionGetTicket(i))){
         NoError = false;
      }
   }
   return NoError;
}

int file=0;
int OnInit()
{
   ClosePosition();
   file = FileOpen("market.txt", FILE_WRITE, "", CP_UTF8);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ClosePosition();
   FileFlush(file);
   FileClose(file);
}

int dir = 0;
bool active = false;
double last = 0;
int start = 0;
double capital = 0;
void OnTick()
{
   int time = (int)TimeCurrent();
   if(start == 0){
      start = time;
   }
   if(time >= start + (INPUT_MaxRunMinutes*60)){
      ClosePosition();
      ExpertRemove();
   }
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double avg = ((ask-bid)/2)+bid;
   FileWriteString(file, time+"|"+bid+"|"+ask+"\n");
   FileFlush(file);
   if(last==0){
      last = avg;
      return;
   }
   list.Add(new TickObject(time, avg));
   if(list.Total()<=ma)
      return;
   list.Delete(0);
   double curr = GetMean();
   if(mean == 0){
      mean = curr;
      return;
   }
   bool buy = curr > mean && curr - mean > 0.1;
   bool sell = curr < mean && mean - curr > 0.1;
   mean = curr;
   bool finish = true;
   if(buy && dir <= 0)
      dir = 1;
   else if(sell && dir >= 0)
      dir = -1;
   else
      finish = false;
   if(active && finish){
      if(CheckError(ClosePosition()))
         active = false;
   }
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance >= INPUT_MaxCapital)
      ExpertRemove();
   if(capital == 0)
      capital = balance;
   if(balance <= capital * INPUT_CapitalFallback)
      ExpertRemove();
   if(!active && (buy || sell)){
      ENUM_ORDER_TYPE type = (buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
      double price = (buy?ask:bid);
      double lot = LotSize(type, price, INPUT_TradeLotSize);
      if(lot>INPUT_MaxTradeVolume)
         lot = INPUT_MaxTradeVolume;
      if(CheckError(OpenOrder(type, price, lot)))
         active = true;
   }
   last = avg;
}
