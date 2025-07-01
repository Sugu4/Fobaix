//+------------------------------------------------------------------+
//| Forex Trading Bot für EUR/USD auf MetaTrader 5                     |
//+------------------------------------------------------------------+
#property copyright "Trading Bot MT5"
#property version   "1.00"

#include <Trade/Trade.mqh>
CTrade trade;

// Globale Variablen und Input Parameter
input double ProfitPerTrade = 0.024;    // 2,4% Ziel pro Trade
input double BreakEvenAt = 0.45;        // Break Even bei 45% vom Ziel
input double DailyLossLimit = -0.0066;  // -0,66% Tages-Drawdown
input int MaxTradesPerDay = 3;          // Maximal 3 Trades pro Tag
input int StopLossPips = 30;            // Stop Loss in Pips
input ENUM_TIMEFRAMES TrendTimeframe_H4 = PERIOD_H4;    // 4H Timeframe
input ENUM_TIMEFRAMES TrendTimeframe_H1 = PERIOD_H1;    // 1H Timeframe
input ENUM_TIMEFRAMES TrendTimeframe_M15 = PERIOD_M15;  // 15M Timeframe
input ENUM_TIMEFRAMES EntryTimeframe = PERIOD_M1;       // 1M Timeframe für Entries

// Deklaration der globalen Variablen
double StartBalance = 0;
double DailyPnL = 0;
int CurrentTrades = 0;
datetime LastResetDay = 0;
double upper_bb, lower_bb;

//+------------------------------------------------------------------+
//| Expert initialization function                                      |
//+------------------------------------------------------------------+
int OnInit()
{
    StartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    LastResetDay = TimeCurrent();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Break Even prüfen und setzen                                      |
//+------------------------------------------------------------------+
void checkAndSetBreakEven()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double takeProfit = PositionGetDouble(POSITION_TP);
                double stopLoss = PositionGetDouble(POSITION_SL);
                
                double profitDistance = MathAbs(takeProfit - openPrice);
                double breakEvenLevel = profitDistance * BreakEvenAt;
                
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                {
                    if(currentPrice >= (openPrice + breakEvenLevel) && stopLoss < openPrice)
                    {
                        trade.PositionModify(ticket, openPrice, takeProfit);
                        Print("Break Even gesetzt für Ticket: ", ticket);
                    }
                }
                else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                {
                    if(currentPrice <= (openPrice - breakEvenLevel) && stopLoss > openPrice)
                    {
                        trade.PositionModify(ticket, openPrice, takeProfit);
                        Print("Break Even gesetzt für Ticket: ", ticket);
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
//| Einzelne Timeframe Analyse                                        |
//+------------------------------------------------------------------+
string analyze_timeframe(ENUM_TIMEFRAMES timeframe)
{
    double ema50[], ema200[];
    ArraySetAsSeries(ema50, true);
    ArraySetAsSeries(ema200, true);
    
    int ema50_handle = iMA(_Symbol, timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
    int ema200_handle = iMA(_Symbol, timeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
    
    CopyBuffer(ema50_handle, 0, 0, 3, ema50);
    CopyBuffer(ema200_handle, 0, 0, 3, ema200);
    
    if(ema50[0] > ema200[0] && ema50[1] > ema200[1] && ema50[0] > ema50[1]) 
        return "STRONG_UPTREND";
    if(ema50[0] < ema200[0] && ema50[1] < ema200[1] && ema50[0] < ema50[1]) 
        return "STRONG_DOWNTREND";
    return "RANGE";
}

//+------------------------------------------------------------------+
//| Mehrstufige Trend Analyse                                         |
//+------------------------------------------------------------------+
string analyze_trend()
{
    string trend_h4 = analyze_timeframe(TrendTimeframe_H4);
    string trend_h1 = analyze_timeframe(TrendTimeframe_H1);
    string trend_m15 = analyze_timeframe(TrendTimeframe_M15);
    
    if(trend_h4 == "STRONG_UPTREND" && trend_h1 == "STRONG_UPTREND" && trend_m15 == "STRONG_UPTREND")
        return "STRONG_UPTREND";
    if(trend_h4 == "STRONG_DOWNTREND" && trend_h1 == "STRONG_DOWNTREND" && trend_m15 == "STRONG_DOWNTREND")
        return "STRONG_DOWNTREND";
    return "RANGE";
}

//+------------------------------------------------------------------+
//| Lot Size für Gewinnziel berechnen                                 |
//+------------------------------------------------------------------+
double calculate_position_size(double entry_price, double stop_loss, double target_profit)
{
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double target_amount = account_balance * ProfitPerTrade;
    double pip_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double distance_to_tp = MathAbs(target_profit - entry_price);
    
    double required_lot = target_amount / (distance_to_tp * pip_value);
    
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    required_lot = MathFloor(required_lot / lot_step) * lot_step;
    required_lot = MathMax(min_lot, MathMin(max_lot, required_lot));
    
    return required_lot;
}

//+------------------------------------------------------------------+
//| Handelstage prüfen                                                |
//+------------------------------------------------------------------+
bool is_valid_trading_day()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    if(dt.day_of_week == 0  dt.day_of_week == 1  dt.day_of_week == 6)
        return false;
        
    return true;
}

//+------------------------------------------------------------------+
//| Handelszeiten prüfen                                              |
//+------------------------------------------------------------------+
bool is_trading_session()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    bool morning_session = (dt.hour == 8  dt.hour == 9  (dt.hour == 10 && dt.min <= 50));
    bool afternoon_session = ((dt.hour == 15  dt.hour == 16  dt.hour == 17  dt.hour == 18)  
                            (dt.hour == 19 && dt.min <= 30));
    
    return morning_session || afternoon_session;
}

//+------------------------------------------------------------------+
//| Schlusszeit prüfen                                                |
//+------------------------------------------------------------------+
bool is_closing_time()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return (dt.hour == 22 && dt.min >= 40);
}
//+------------------------------------------------------------------+
//| Alle Positionen schließen                                         |
//+------------------------------------------------------------------+
void close_all_positions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            if(PositionSelectByTicket(ticket))
            {
                if(PositionGetString(POSITION_SYMBOL) == _Symbol)
                {
                    trade.PositionClose(ticket);
                    Print("Position geschlossen um 22:40 - Ticket: ", ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Tageslimits zurücksetzen                                          |
//+------------------------------------------------------------------+
void reset_daily_limits()
{
    MqlDateTime current, last;
    TimeToStruct(TimeCurrent(), current);
    TimeToStruct(LastResetDay, last);
    
    if (current.day != last.day)
    {
        DailyPnL = 0;
        CurrentTrades = 0;
        LastResetDay = TimeCurrent();
        StartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        Print("Neuer Tag - Drawdown & Trade-Limit zurückgesetzt!");
    }
}

//+------------------------------------------------------------------+
//| Indikatoren berechnen                                             |
//+------------------------------------------------------------------+
void calculate_indicators(double &ema50, double &ema200, double &rsi, double &adx, double &upper_bb_local, double &lower_bb_local)
{
    double ema50_buffer[], ema200_buffer[], rsi_buffer[], adx_buffer[], bands_buffer[];
    
    ArraySetAsSeries(ema50_buffer, true);
    ArraySetAsSeries(ema200_buffer, true);
    ArraySetAsSeries(rsi_buffer, true);
    ArraySetAsSeries(adx_buffer, true);
    ArraySetAsSeries(bands_buffer, true);
    
    int ema50_handle = iMA(_Symbol, EntryTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
    int ema200_handle = iMA(_Symbol, EntryTimeframe, 200, 0, MODE_EMA, PRICE_CLOSE);
    int rsi_handle = iRSI(_Symbol, EntryTimeframe, 14, PRICE_CLOSE);
    int adx_handle = iADX(_Symbol, EntryTimeframe, 14);
    int bands_handle = iBands(_Symbol, EntryTimeframe, 20, 2, 0, PRICE_CLOSE);
    
    CopyBuffer(ema50_handle, 0, 0, 1, ema50_buffer);
    CopyBuffer(ema200_handle, 0, 0, 1, ema200_buffer);
    CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer);
    CopyBuffer(adx_handle, 0, 0, 1, adx_buffer);
    CopyBuffer(bands_handle, 1, 0, 1, bands_buffer);
    
    ema50 = ema50_buffer[0];
    ema200 = ema200_buffer[0];
    rsi = rsi_buffer[0];
    adx = adx_buffer[0];
    upper_bb_local = bands_buffer[0];
    
    CopyBuffer(bands_handle, 2, 0, 1, bands_buffer);
    lower_bb_local = bands_buffer[0];
    
    upper_bb = upper_bb_local;
    lower_bb = lower_bb_local;
}

//+------------------------------------------------------------------+
//| Handelslogik                                                       |
//+------------------------------------------------------------------+
string check_trade_signal()
{
    string current_trend = analyze_trend();
    
    double ema50, ema200, rsi, adx, upper_bb_local, lower_bb_local;
    calculate_indicators(ema50, ema200, rsi, adx, upper_bb_local, lower_bb_local);
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    if (adx > 25 && adx < 60)
    {
        if (current_trend == "STRONG_UPTREND" && 
            ema50 > ema200 && 
            rsi < 35 && 
            price > lower_bb_local && 
            price < (lower_bb_local + ((upper_bb_local - lower_bb_local) * 0.3)))
            return "BUY";
            
        if (current_trend == "STRONG_DOWNTREND" && 
            ema50 < ema200 && 
            rsi > 65 && 
            price < upper_bb_local &&
            price > (upper_bb_local - ((upper_bb_local - lower_bb_local) * 0.3)))
            return "SELL";
    }
    return "HOLD";
}
//+------------------------------------------------------------------+
//| Order platzieren                                                   |
//+------------------------------------------------------------------+
void place_order(string order_type)
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = 0, tp = 0;
    
    if (order_type == "BUY")
    {
        sl = price - (StopLossPips * _Point);
        tp = price + ((price * ProfitPerTrade) / 2);
        double volume = calculate_position_size(price, sl, tp);
        
        double bb_range = upper_bb - lower_bb;
        if((tp - price) > bb_range * 0.7) return;
        
        trade.Buy(volume, _Symbol, 0, sl, tp);
    }
    else if (order_type == "SELL")
    {
        sl = price + (StopLossPips * _Point);
        tp = price - ((price * ProfitPerTrade) / 2);
        double volume = calculate_position_size(price, sl, tp);
        
        double bb_range = upper_bb - lower_bb;
        if((price - tp) > bb_range * 0.7) return;
        
        trade.Sell(volume, _Symbol, 0, sl, tp);
    }
    
    Print(order_type, " Order platziert! Zeit: ", TimeToString(TimeCurrent()));
    CurrentTrades++;
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    // ... previous code remains unchanged ...
    
    string signal = check_trade_signal();
    if (signal != "HOLD") place_order(signal);
    
    DailyPnL = (AccountInfoDouble(ACCOUNT_BALANCE) - StartBalance) / StartBalance;
    Print("Tages-PnL: ", NormalizeDouble(DailyPnL * 100, 2), "%", ", Trades heute: ", CurrentTrades, "/", MaxTradesPerDay);
}