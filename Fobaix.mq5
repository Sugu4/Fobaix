// AI Trading Bot Framework

// Strukturen
struct NeuralNetwork {
    int inputNodes;
    int hiddenNodes;
    int outputNodes;
    double weights[];
    double bias[];
};

struct PatternData {
    double priceData[];
    double volumeData[];
    int patternType;
    bool isValid;
};

struct RiskParameters {
    double baseRisk;
    double adaptiveRisk;
    double maxDrawdown;
    double confidenceScore;
};

struct PatternSignal {
    bool pattern_found;
    bool is_buy;
};

struct LearningParameters {
    double weights[];
    double previousResults[];
    double learningRate;
    double adaptationRate;
    int trainingCycles;
    double performanceScore;
    double trainingData[];
};


// Globale Variablen
double trainingData[];
double predictions[];
int dataSize = 1000;
int atr_handle;
double atr_buffer[];
static LearningParameters learning;

double CalculatePerformance()
{
    double totalProfit = 0;
    HistorySelect(0, TimeCurrent());
    for(int i = 0; i < HistoryDealsTotal(); i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        totalProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
    }
    return totalProfit;
}

void UpdateTrainingData()
{
    ArrayResize(learning.trainingData, 1000);
    for(int i = 0; i < 1000; i++)
    {
        learning.trainingData[i] = iClose(_Symbol, PERIOD_M5, i);
    }
}

int OnInit()
{
    atr_handle = iATR(_Symbol, PERIOD_M5, 14);
    if(atr_handle == INVALID_HANDLE)
    {
        Print("Error creating ATR indicator");
        return(INIT_FAILED);
    }
    
    ArraySetAsSeries(atr_buffer, true);
    ArrayResize(atr_buffer, 10);
    
    learning.learningRate = 0.01;
    learning.adaptationRate = 0.05;
    learning.trainingCycles = 0;
    ArrayResize(learning.previousResults, 100);
    ArrayResize(learning.trainingData, 1000);
    ArrayResize(learning.weights, 5);
    for(int i = 0; i < 5; i++)
    {
        learning.weights[i] = 0.2;
    }
    return(INIT_SUCCEEDED);
}

double GetATRValue()
{
    double atr_values[];
    ArraySetAsSeries(atr_values, true);
    CopyBuffer(atr_handle, 0, 0, 1, atr_values);
    return atr_values[0];
}

void InitializeLearning()
{
    learning.learningRate = 0.01;
    learning.adaptationRate = 0.05;
    learning.trainingCycles = 0;
    ArrayResize(learning.weights, 5);
    ArrayResize(learning.previousResults, 100);
}

void UpdateWeights(double profit)
{
    double old_weights[5];
    ArrayCopy(old_weights, learning.weights);
    double old_rate = learning.learningRate;
    
    double adaptation_rate = 0.05;  // Erhöhte Adaptionsrate
    
    if(profit > 0)
    {
        for(int i = 0; i < ArraySize(learning.weights); i++)
        {
            learning.weights[i] *= (1 + adaptation_rate * profit);
        }
        learning.learningRate *= 1.2;
    }
    else
    {
        for(int i = 0; i < ArraySize(learning.weights); i++)
        {
            learning.weights[i] *= (1 - adaptation_rate * MathAbs(profit));
        }
        learning.learningRate *= 0.8;
    }
    
    Print("=== Learning Update ===");
    Print("Profit from trade: ", profit);
    Print("Old weights: ", old_weights[0], ", ", old_weights[1], ", ", old_weights[2]);
    Print("New weights: ", learning.weights[0], ", ", learning.weights[1], ", ", learning.weights[2]);
    Print("Learning rate changed from: ", old_rate, " to: ", learning.learningRate);
    Print("Performance Score: ", learning.performanceScore);
    Print("=====================");
}

void OptimizeParameters()
{
    double performance = CalculatePerformance();
    
    if(performance > learning.performanceScore)
    {
        learning.adaptationRate *= 1.1;
        UpdateTrainingData();
    }
    else
    {
        learning.adaptationRate *= 0.9;
    }
    
    learning.performanceScore = performance;
}

// Trend Detection Funktionen
double CalculateTrendPrediction()
{
    double trend = 0;
    double prices[];
    ArraySetAsSeries(prices, true);
    
    if(!CopyClose(_Symbol, PERIOD_M5, 0, 20, prices))
        return 0;
        
    double sma20 = 0;
    for(int i = 0; i < 20; i++)
    {
        sma20 += prices[i];
    }
    sma20 /= 20;
    
    // Verstärkte Trend-Berechnung
    trend = MathAbs((prices[0] - sma20) / sma20) * 100;
    
    return trend;
}

double calculateTrendStrength(double& prices[])
{
    double strength = 0;
    int count_up = 0;
    int count_down = 0;
    
    for(int i = 1; i < ArraySize(prices); i++)
    {
        if(prices[i-1] > prices[i]) count_up++;
        if(prices[i-1] < prices[i]) count_down++;
    }
    
    strength = (double)count_up / (count_up + count_down);
    return strength;
}

// Pattern Recognition Funktionen
bool RecognizePattern(bool& is_buy)
{
    double prices[];
    double highs[];
    double lows[];
    
    ArraySetAsSeries(prices, true);
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    
    if(!CopyClose(_Symbol, PERIOD_M5, 0, 50, prices)) return false;
    if(!CopyHigh(_Symbol, PERIOD_M5, 0, 50, highs)) return false;
    if(!CopyLow(_Symbol, PERIOD_M5, 0, 50, lows)) return false;
    
    bool topPattern = checkDoubleTop(highs, 50);
    bool bottomPattern = checkDoubleBottom(lows, 50);
    
    Print("Top Pattern: ", topPattern, " Bottom Pattern: ", bottomPattern);
    
    if(bottomPattern)  // Prüfe zuerst Bottom Pattern für Buy
    {
        is_buy = true;
        Print("Buy Signal gefunden");
        return true;
    }
    if(topPattern)  // Dann Top Pattern für Sell
    {
        is_buy = false;
        Print("Sell Signal gefunden");
        return true;
    }
    
    return false;
}

bool checkDoubleTop(double& highs[], int period)
{
    double firstPeak = 0;
    double secondPeak = 0;
    int firstPeakIndex = 0;
    
    for(int i = 5; i < period-5; i++)
    {
        if(highs[i] > highs[i-1] && highs[i] > highs[i+1])
        {
            if(firstPeak == 0) 
            {
                firstPeak = highs[i];
                firstPeakIndex = i;
            }
            else secondPeak = highs[i];
            
            if(firstPeak > 0 && secondPeak > 0)
            {
                // Mindestabstand zwischen Peaks
                if(MathAbs(i - firstPeakIndex) > 3 && 
                   MathAbs(firstPeak - secondPeak) < 0.0010)
                {
                    Print("Double Top gefunden - Peaks: ", firstPeak, " und ", secondPeak);
                    return true;
                }
            }
        }
    }
    return false;
}

bool checkDoubleBottom(double& lows[], int period)
{
    double firstBottom = 0;
    double secondBottom = 0;
    int firstBottomIndex = 0;
    
    for(int i = 5; i < period-5; i++)
    {
        if(lows[i] < lows[i-1] && lows[i] < lows[i+1])
        {
            if(firstBottom == 0)
            {
                firstBottom = lows[i];
                firstBottomIndex = i;
            }
            else secondBottom = lows[i];
            
            if(firstBottom > 0 && secondBottom > 0)
            {
                // Mindestabstand zwischen Bottoms
                if(MathAbs(i - firstBottomIndex) > 3 &&
                   MathAbs(firstBottom - secondBottom) < 0.0010)
                {
                    Print("Double Bottom gefunden - Bottoms: ", firstBottom, " und ", secondBottom);
                    return true;
                }
            }
        }
    }
    return false;
}

bool IsValidTradingSession()
{
    static bool last_status = false;
    static datetime last_check = 0;
    static int london_trades = 0;
    static int ny_trades = 0;
    static int last_day = 0;
    
    datetime current_time = TimeCurrent();
    
    if(current_time == last_check) 
        return last_status;
        
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);
    
    // Reset bei neuem Tag
    if(time_struct.day != last_day)
    {
        london_trades = 0;
        ny_trades = 0;
        last_day = time_struct.day;
        Print("New trading day - Reset session counters");
    }
    
    bool is_trading_time = false;
    
    if(time_struct.day_of_week == 6 || time_struct.day_of_week == 0)
    {
        if(last_status) Print("Weekend - no trading");
        is_trading_time = false;
    }
    else if(time_struct.day_of_week == 5 && time_struct.hour >= 21)
    {
        if(last_status) Print("Friday after NY session - no trading");
        is_trading_time = false;
    }
    else if(time_struct.hour >= 11 && time_struct.hour < 13)
    {
        if(last_status) Print("Lunch break - no trading");
        is_trading_time = false;
    }
    else
    {
        bool london_session = (time_struct.hour >= 8 && time_struct.hour < 14);
        bool ny_session = (time_struct.hour >= 15 && time_struct.hour < 21);
        
        if(london_session && london_trades >= 3)
        {
            if(last_status) Print("London session trade limit reached");
            is_trading_time = false;
        }
        else if(ny_session && ny_trades >= 3)
        {
            if(last_status) Print("NY session trade limit reached");
            is_trading_time = false;
        }
        else
        {
            is_trading_time = london_session || ny_session;
            if(london_session && is_trading_time) london_trades++;
            if(ny_session && is_trading_time) ny_trades++;
        }
    }
    
    if(is_trading_time != last_status)
    {
        if(is_trading_time)
            Print("Trading session started");
        else
            Print("Outside trading session - no trading");
    }
    
    last_status = is_trading_time;
    last_check = current_time;
    return is_trading_time;
}

bool CanOpenNewTrade()
{
    static int daily_trades = 0;
    static int last_day = 0;
    static bool limit_message_shown = false;
    
    MqlDateTime time_struct;
    TimeToStruct(TimeCurrent(), time_struct);
    int current_day = time_struct.day;
    
    if(current_day != last_day)
    {
        daily_trades = 0;
        last_day = current_day;
        limit_message_shown = false;
        Print("New trading day - Reset trade counter");
    }
    
    if(daily_trades >= 6)
    {
        if(!limit_message_shown)
        {
            Print("Daily trade limit (6) reached - No more trades today");
            limit_message_shown = true;
        }
        return false;
    }
    
    daily_trades++;
    return true;
}

// Neural Network für Preisprognosen
double PredictNextPrice()
{
    double inputs[];
    double weights_ih[];
    double weights_ho[];
    double hidden[];
    double output;
    
    ArrayResize(inputs, 10);
    ArrayResize(weights_ih, 10);
    ArrayResize(weights_ho, 5);
    ArrayResize(hidden, 5);
    
    double prices[];
    ArraySetAsSeries(prices, true);
    CopyClose(_Symbol, PERIOD_M5, 0, 10, prices);
    
    // Dynamische Gewichte basierend auf Trend
    double trend = CalculateTrendPrediction();
    double weight_modifier = trend / 100.0;
    
    // Input Layer mit dynamischen Gewichten
    for(int i = 0; i < 10; i++)
    {
        inputs[i] = NormalizePrice(prices[i]);
        weights_ih[i] = 0.2 + (weight_modifier * (i % 2 ? 0.1 : -0.1));
    }
    
    // Hidden Layer mit verbesserten Gewichten
    for(int i = 0; i < 5; i++)
    {
        hidden[i] = 0;
        for(int j = 0; j < 10; j++)
        {
            hidden[i] += inputs[j] * weights_ih[j];
        }
        hidden[i] = Activation(hidden[i]);
        weights_ho[i] = 0.2 + (weight_modifier * (i % 2 ? 0.15 : -0.15));
    }
    
    // Output Layer
    output = 0;
    for(int i = 0; i < 5; i++)
    {
        output += hidden[i] * weights_ho[i];
    }
    output = Activation(output);
    
    return DenormalizePrice(output);
}

double Activation(double x)
{
    return 1.0 / (1.0 + MathExp(-x));  // Sigmoid Funktion
}

double NormalizePrice(double price)
{
    double min = iLow(_Symbol, PERIOD_M5, 1);
    double max = iHigh(_Symbol, PERIOD_M5, 1);
    return (price - min) / (max - min);
}

double DenormalizePrice(double normalized)
{
    double min = iLow(_Symbol, PERIOD_M5, 1);
    double max = iHigh(_Symbol, PERIOD_M5, 1);
    return normalized * (max - min) + min;
}

// Adaptives Risk Management
double CalculateAdaptiveRisk()
{
    RiskParameters risk;
    risk.baseRisk = 0.01;  // 1% Basis-Risiko
    
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double currentDrawdown = (balance - equity) / balance;
    double dailyProfit = CalculateDailyProfit();
    
    if(currentDrawdown > 0.05)
    {
        risk.adaptiveRisk = risk.baseRisk * 0.5;
        risk.maxDrawdown = 0.05;
    }
    else if(dailyProfit < -0.02)
    {
        risk.adaptiveRisk = risk.baseRisk * 0.6;
    }
    else if(dailyProfit > 0.02)
    {
        risk.adaptiveRisk = risk.baseRisk * 1.3;
    }
    
    double trendStrength = CalculateTrendPrediction();
    if(trendStrength > 0.8) risk.adaptiveRisk *= 1.2;
    if(trendStrength < 0.3) risk.adaptiveRisk *= 0.8;
    
    bool is_pattern_buy = false;
    if(RecognizePattern(is_pattern_buy)) risk.adaptiveRisk *= 1.1;
    
    double prediction = PredictNextPrice();
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if(MathAbs(prediction - currentPrice) < 0.0010)
        risk.adaptiveRisk *= 1.15;
    
    return MathMin(risk.adaptiveRisk, 0.02);
}

double CalculateDailyProfit()
{
    double profit = 0;
    datetime today = TimeCurrent();
    datetime dayStart = StringToTime(TimeToString(today, TIME_DATE));
    
    HistorySelect(dayStart, TimeCurrent());
    for(int i = 0; i < HistoryDealsTotal(); i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
    }
    
    return profit / AccountInfoDouble(ACCOUNT_BALANCE);
}

void OnTick()
{
    static bool last_trading_state = false;
    bool current_trading_state = IsValidTradingSession();
    bool is_buy = false;
    
    if(current_trading_state != last_trading_state)
    {
        if(!current_trading_state)
            Print("Outside trading session - no trading");
        else
            Print("Trading session started");
            
        last_trading_state = current_trading_state;
    }
    
    if(!current_trading_state)
        return;
    
    Print("Tick received - Analyzing market...");
    
    double trend_score = CalculateTrendPrediction() * learning.weights[0];
    bool pattern_found = RecognizePattern(is_buy);
    double next_price = PredictNextPrice() * learning.weights[1];
    double risk = CalculateAdaptiveRisk() * learning.weights[2];
    
    Print("Trend Score: ", trend_score);
    Print("Pattern Found: ", pattern_found);
    Print("Next Price Prediction: ", next_price);
    
    if(trend_score > 0.00003 && pattern_found)  // Reduced threshold
    {
        if(!CanOpenNewTrade())
            return;
            
        double current_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double current_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        
        request.action = TRADE_ACTION_DEAL;
        request.symbol = _Symbol;
        request.volume = CalculateSafeLotSize();
        request.deviation = 3;
        request.magic = 123456;
        
        double points = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double tp_distance = 600 * points;
        double sl_distance = 200 * points;
        
        if(is_buy && next_price > current_ask * 0.9999)  // Looser buy condition
        {
            request.type = ORDER_TYPE_BUY;
            request.price = current_ask;
            request.sl = current_ask - sl_distance;
            request.tp = current_ask + tp_distance;
            
            if(OrderSend(request, result))
            {
                double profit = 0;
                if(HistoryDealSelect(result.deal))
                    profit = HistoryDealGetDouble(result.deal, DEAL_PROFIT);
                UpdateWeights(profit);
                OptimizeParameters();
            }
        }
        else if(!is_buy && next_price < current_bid * 1.0001)  // Looser sell condition
        {
            request.type = ORDER_TYPE_SELL;
            request.price = current_bid;
            request.sl = current_bid + sl_distance;
            request.tp = current_bid - tp_distance;
            
            if(OrderSend(request, result))
            {
                double profit = 0;
                if(HistoryDealSelect(result.deal))
                    profit = HistoryDealGetDouble(result.deal, DEAL_PROFIT);
                UpdateWeights(profit);
                OptimizeParameters();
            }
        }
        
        learning.trainingCycles++;
    }
    
    ManageOpenTrades();
    ManageAccountRisk();
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                      const MqlTradeRequest& request,
                      const MqlTradeResult& result)
{
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
    {
        if(HistoryDealSelect(trans.deal))
        {
            long entry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT)
            {
                double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
                double sl = HistoryDealGetDouble(trans.deal, DEAL_SL);
                double tp = HistoryDealGetDouble(trans.deal, DEAL_TP);
                
                if(profit > 0)
                    Print("Trade closed with profit: ", profit, " (Take Profit hit)");
                else
                    Print("Trade closed with loss: ", profit, " (Stop Loss hit)");
            }
        }
    }
}

void ManageOpenTrades()
{
    MqlDateTime time_struct;
    TimeToStruct(TimeCurrent(), time_struct);
    
    // Schließe alle Positionen nach NY Session (21:00 GMT)
    if(time_struct.hour >= 21)
    {
        Print("End of NY session - closing all positions");
        CloseAllPositions();
        return;
    }
    
    Print("Checking open trades...");
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionSelectByTicket(ticket))
        {
            double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            Print("Trade #", ticket, " - Entry: ", entry_price, " Current: ", current_price, " Profit: ", profit);
            
            double points = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double tp_distance = 800 * points;
            double sl_distance = 200 * points;
            
            double tp_level = entry_price + tp_distance;
            double sl_level = entry_price - sl_distance;
            
            Print("TP Level: ", tp_level, " SL Level: ", sl_level);
            
            if(current_price >= tp_level)
            {
                Print("Closing trade at profit - Price reached TP");
                ClosePosition(ticket);
            }
            else if(current_price <= sl_level)
            {
                Print("Closing trade at loss - Price reached SL");
                ClosePosition(ticket);
            }
        }
    }
}

void ClosePosition(ulong ticket)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = _Symbol;
    request.volume = PositionGetDouble(POSITION_VOLUME);
    request.type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    OrderSend(request, result);
}

void ManageAccountRisk()
{
    static int last_day = 0;
    static double daily_profit = 0;
    
    MqlDateTime time_struct;
    TimeToStruct(TimeCurrent(), time_struct);
    
    // Reset täglich
    if(time_struct.day != last_day)
    {
        daily_profit = 0;
        last_day = time_struct.day;
        Print("New trading day - Reset profit target");
    }
    
    double total_profit = 0;
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double max_drawdown = account_balance * 0.01;    // 1% max Verlust pro Tag
    double daily_target = account_balance * 0.03;    // 3% Gewinnziel pro Tag
    
    // Berechne aktuellen Profit
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            total_profit += PositionGetDouble(POSITION_PROFIT);
        }
    }
    
    daily_profit += total_profit;
    
    Print("Daily Profit: ", daily_profit, " Target: ", daily_target, " Max Drawdown: ", max_drawdown);
    
    if(daily_profit <= -max_drawdown)  // Strikte Drawdown-Kontrolle
    {
        Print("Daily max drawdown (", max_drawdown, ") reached at: ", daily_profit);
        CloseAllPositions();
        return;
    }
    
    if(daily_profit >= daily_target)
    {
        Print("Daily profit target reached - Closing all positions");
        CloseAllPositions();
        return;
    }
}

double CalculateSafeLotSize()
{
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double daily_risk = account_balance * 0.01;    // 1% tägliches Risiko
    double risk_per_trade = daily_risk / 3;        // Auf 3 Trades verteilt = 0.33% pro Trade
    
    double point_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double sl_points = 200; // Basierend auf Ihrem aktuellen SL
    
    double safe_lot = NormalizeDouble(risk_per_trade / (sl_points * point_value), 2);
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    
    Print("Risk per trade: ", risk_per_trade, " Safe lot size: ", safe_lot);
    
    return MathMax(safe_lot, min_lot);
}

void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        ClosePosition(ticket);
    }
}