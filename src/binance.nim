import std/[times, httpclient, httpcore, json, strutils, math, strformat, os], binance/binance_sha256


type
  Binance* = object  ## Binance API Client.
    apiKey*, apiSecret*: string  ## Get API Key and API Secret at https://www.binance.com/en/my/settings/api-management
    recvWindow*: 5_000..60_000   ## "Tolerance" for requests timeouts, Binance is very strict about "Timestamp" diff.
    client: HttpClient

  HistoricalKlinesType* = enum
    SPOT    = 1
    FUTURES = 2

  FuturesType* = enum
    USD_M  = 1
    COIN_M = 2

  Side* = enum
    SIDE_BUY  = "BUY"
    SIDE_SELL = "SELL"

  ContractType* = enum
    PERPETUAL       = "perpetual"
    CURRENT_QUARTER = "current_quarter"
    NEXT_QUARTER    = "next_quarter"

  TimeInForce* = enum
    TIME_IN_FORCE_GTC = "GTC"  # Good Till Cancelled
    TIME_IN_FORCE_IOC = "IOC"  # Immediate Or Cancel
    TIME_IN_FORCE_FOK = "FOK"  # Fill Or Kill
    TIME_IN_FORCE_GTX = "GTX"  # Post Only

  OrderStatus* = enum
    ORDER_STATUS_NEW              = "NEW"
    ORDER_STATUS_PARTIALLY_FILLED = "PARTIALLY_FILLED"
    ORDER_STATUS_FILLED           = "FILLED"
    ORDER_STATUS_CANCELED         = "CANCELED"
    ORDER_STATUS_PENDING_CANCEL   = "PENDING_CANCEL"
    ORDER_STATUS_REJECTED         = "REJECTED"
    ORDER_STATUS_EXPIRED          = "EXPIRED"

  Interval* = enum
    KLINE_INTERVAL_1MINUTE  = "1m"
    KLINE_INTERVAL_3MINUTE  = "3m"
    KLINE_INTERVAL_5MINUTE  = "5m"
    KLINE_INTERVAL_15MINUTE = "15m"
    KLINE_INTERVAL_30MINUTE = "30m"
    KLINE_INTERVAL_1HOUR    = "1h"
    KLINE_INTERVAL_2HOUR    = "2h"
    KLINE_INTERVAL_4HOUR    = "4h"
    KLINE_INTERVAL_6HOUR    = "6h"
    KLINE_INTERVAL_8HOUR    = "8h"
    KLINE_INTERVAL_12HOUR   = "12h"
    KLINE_INTERVAL_1DAY     = "1d"
    KLINE_INTERVAL_3DAY     = "3d"
    KLINE_INTERVAL_1WEEK    = "1w"
    KLINE_INTERVAL_1MONTH   = "1M"

  OrderType* = enum
    ORDER_TYPE_LIMIT             = "LIMIT"
    ORDER_TYPE_MARKET            = "MARKET"
    ORDER_TYPE_STOP_LOSS         = "STOP_LOSS"
    ORDER_TYPE_STOP_LOSS_LIMIT   = "STOP_LOSS_LIMIT"
    ORDER_TYPE_TAKE_PROFIT       = "TAKE_PROFIT"
    ORDER_TYPE_TAKE_PROFIT_LIMIT = "TAKE_PROFIT_LIMIT"
    ORDER_TYPE_LIMIT_MAKER       = "LIMIT_MAKER"

  FutureOrderType* = enum
    FUTURE_ORDER_TYPE_LIMIT              = "LIMIT"
    FUTURE_ORDER_TYPE_MARKET             = "MARKET"
    FUTURE_ORDER_TYPE_STOP               = "STOP"
    FUTURE_ORDER_TYPE_STOP_MARKET        = "STOP_MARKET"
    FUTURE_ORDER_TYPE_TAKE_PROFIT        = "TAKE_PROFIT"
    FUTURE_ORDER_TYPE_TAKE_PROFIT_MARKET = "TAKE_PROFIT_MARKET"
    FUTURE_ORDER_TYPE_LIMIT_MAKER        = "LIMIT_MAKER"

  ResponseType* = enum
    ORDER_RESP_TYPE_ACK    = "ACK"
    ORDER_RESP_TYPE_RESULT = "RESULT"
    ORDER_RESP_TYPE_FULL   = "FULL"

  WebSocketDepth* = enum
    WEBSOCKET_DEPTH_5  = "5"
    WEBSOCKET_DEPTH_10 = "10"
    WEBSOCKET_DEPTH_20 = "20"

  AggregateTrades* = enum  ## For accessing the data returned by Client.aggregate_trades().
    AGG_BEST_MATCH     = 'M'
    AGG_TIME           = 'T'
    AGG_ID             = 'a'
    AGG_FIRST_TRADE_ID = 'f'
    AGG_LAST_TRADE_ID  = 'l'
    AGG_BUYER_MAKES    = 'm'
    AGG_PRICE          = 'p'
    AGG_QUANTITY       = 'q'

  AssetTransfer* = enum    ## New asset transfer API Enum.
    SPOT_TO_FIAT                = "MAIN_C2C"
    SPOT_TO_USDT_FUTURE         = "MAIN_UMFUTURE"
    SPOT_TO_COIN_FUTURE         = "MAIN_CMFUTURE"
    SPOT_TO_MARGIN_CROSS        = "MAIN_MARGIN"
    SPOT_TO_MINING              = "MAIN_MINING"
    FIAT_TO_SPOT                = "C2C_MAIN"
    FIAT_TO_USDT_FUTURE         = "C2C_UMFUTURE"
    FIAT_TO_MINING              = "C2C_MINING"
    USDT_FUTURE_TO_SPOT         = "UMFUTURE_MAIN"
    USDT_FUTURE_TO_FIAT         = "UMFUTURE_C2C"
    USDT_FUTURE_TO_MARGIN_CROSS = "UMFUTURE_MARGIN"
    COIN_FUTURE_TO_SPOT         = "CMFUTURE_MAIN"
    MARGIN_CROSS_TO_SPOT        = "MARGIN_MAIN"
    MARGIN_CROSS_TO_USDT_FUTURE = "MARGIN_UMFUTURE"
    MINING_TO_SPOT              = "MINING_MAIN"
    MINING_TO_USDT_FUTURE       = "MINING_UMFUTURE"
    MINING_TO_FIAT              = "MINING_C2C"

  RateLimitTypes* = enum
    RLRequests = "REQUESTS"
    RLOrders   = "ORDERS"

  RateLimitIntervals* = enum
    RLISecond = "SECOND"
    RLIMinute = "MINUTE"
    RLIDay    = "DAY"

  SymbolStatus* {.pure.} = enum
    PreTrading   = "PRE_TRADING"
    Trading      = "TRADING"
    PostTrading  = "POST_TRADING"
    EndOfDay     = "END_OF_DAY"
    Halt         = "HALT"
    AuctionMatch = "AUCTION_MATCH"
    Break        = "BREAK"


const binanceAPIUrl* {.strdefine.} = "https://api.binance.com"  ## `-d:binanceAPIUrl="https://testnet.binance.vision"` for Testnet.


template checkFloat*(floaty: float; lowest: static[float] = NaN; highest: static[float] = NaN) =
  ## Utility template to check if a float is valid, because float sux.
  assert not floaty.isNaN, "Value must not be  NaN"
  assert floaty != +Inf,   "Value must not be +Inf"
  assert floaty != -Inf,   "Value must not be -Inf"
  when not lowest.isNaN:  assert floaty >= lowest,  "Value must be >= " & $lowest
  when not highest.isNaN: assert floaty <= highest, "Value must be <= " & $highest


func truncate*(self: Binance; number: float, digits: uint): float =
  ## Utility function to truncate a float to a certain number of digits.
  checkFloat(number)
  doAssert digits > 1, "digits must not be Zero"
  var
    resp = ""
    startCounting = false
    countDigit: uint = 0
  if number < 1.0:
    var numberStr = fmt"{number:>.20f}"
    for i in 0 ..< numberStr.len:
      if numberStr[0] != '0' and numberStr[i] != ',' and numberStr[i] != '.':
        startCounting = true
      if startCounting:
        inc countDigit
      resp.add numberStr[i]

      if countDigit == digits:
        break
    result = parseFloat(resp[0..2])
  else:
    result = round(number)


converter interval_to_milliseconds(interval: Interval): int =
  ## Get numeric part of Interval.
  ($interval)[0..^2].parseInt * (
    case ($interval)[^1]:
    of 'm': 60
    of 'h': 60 * 60
    of 'd': 24 * 60 * 60
    of 'w': 7  * 24 * 60 * 60
    else: 1
  ) * 1_000


converter date_to_milliseconds(d: Duration): int64 =
  ## Date to milliseconds.
  var epoch = initDuration(seconds = now().utc.toTime.toUnix)
  epoch -= d
  epoch.inMilliseconds


template getContent*(self: Binance, url: string): string = self.client.getContent(url)
template close*(self: Binance) = self.client.close()


proc newBinance*(apiKey, apiSecret: string): Binance =
  ## Constructor for Binance client.
  assert apiKey.len > 0 and apiSecret.len > 0, "apiKey and apiSecret must not be empty string."
  var client = newHttpClient()
  client.headers.add "X-MBX-APIKEY", apiKey
  Binance(apiKey: apiKey, apiSecret: apiSecret, recvWindow: 10_000, client: client)


template signQueryString(self: Binance; endpoint: static[string]) =
  ## Sign the query string for Binance API, reusing the same string.
  result.add "&recvWindow="
  result.addInt self.recvWindow
  result.add "&timestamp="
  result.addInt now().utc.toTime.toUnix * 1_000  # UTC Timestamp.
  let signature: string = sha256.hmac(self.apiSecret, result)
  result.add "&signature="
  result.add signature
  result = static(binanceAPIUrl & "/api/v3/" & endpoint & '?') & result


# Generic endpoints.


proc ping*(self: Binance): string =
  ## Test connectivity to Binance, just a ping.
  result = binanceAPIUrl & "/api/v3/ping"


proc time*(self: Binance): string =
  ## Get current Binance API server time.
  result = binanceAPIUrl & "/api/v3/time"


proc exchangeInfo*(self: Binance): string =
  ## Exchange information, info about Binance.
  result = binanceAPIUrl & "/api/v3/exchangeInfo"


# Market Data Endpoints


proc orderBook*(self: Binance; symbol: string; limit: 5..1000 = 100): string =
  ## Order book depth.
  doAssert limit in {5, 10, 20, 50, 100, 500, 1_000}, "limit value must be an integer in the set of {5, 10, 20, 50, 100, 500, 1000}"
  result = static(binanceAPIUrl & "/api/v3/depth?symbol=")
  result.add symbol
  result.add "&limit="
  result.addInt limit


proc recentTrades*(self: Binance; symbol: string; limit: 1..500 = 500): string =
  ## Get a list of recent Trades.
  result = static(binanceAPIUrl & "/api/v3/trades?symbol=")
  result.add symbol
  result.add "&limit="
  result.addInt limit


proc olderTrades*(self: Binance; symbol: string; limit: 1..500 = 500; fromId: Positive): string =
  ## Old historical Trades.
  result = static(binanceAPIUrl & "/api/v3/historicalTrades?symbol=")
  result.add symbol
  result.add "&limit="
  result.addInt limit
  result.add "&fromId="
  result.addInt fromId


proc olderTrades*(self: Binance; symbol: string; limit: 1..500 = 500): string =
  ## Old historical Trades.
  result = static(binanceAPIUrl & "/api/v3/historicalTrades?symbol=")
  result.add symbol
  result.add "&limit="
  result.addInt limit


proc aggrTrades*(self: Binance; symbol: string; fromId, startTime, endTime: Positive; limit: 1..500 = 500): string =
  ## Aggregated Trades list.
  assert endTime - startTime < 24 * 36000000, "startTime/endTime must be 2 integers representing a time interval smaller than 24 hours."
  result = static(binanceAPIUrl & "/api/v3/aggTrades?symbol=")
  result.add symbol
  result.add "&fromId="
  result.addInt fromId
  result.add "&startTime="
  result.addInt startTime
  result.add "&endTime="
  result.addInt endTime
  result.add "&limit="
  result.addInt limit


proc aggrTrades*(self: Binance; symbol: string; fromId: Positive; limit: 1..500 = 500): string =
  ## Aggregated Trades list.
  result = static(binanceAPIUrl & "/api/v3/aggTrades?symbol=")
  result.add symbol
  result.add "&fromId="
  result.addInt fromId
  result.add "&limit="
  result.addInt limit


proc aggrTrades*(self: Binance; symbol: string): string =
  ## Aggregated Trades list.
  result = static(binanceAPIUrl & "/api/v3/aggTrades?symbol=")
  result.add symbol


proc klines*(self: Binance; symbol: string; interval: Interval, startTime, endTime: int64; limit: 1..500 = 500): string =
  ## Klines data, AKA Candlestick data.
  result = static(binanceAPIUrl & "/api/v3/klines?symbol=")
  result.add symbol
  result.add "&startTime="
  result.addInt startTime
  result.add "&endTime="
  result.addInt endTime
  result.add "&interval="
  result.add $interval
  result.add "&limit="
  result.addInt limit


proc klines*(self: Binance; symbol: string; interval: Interval; limit: 1..500 = 500): string =
  ## Klines data, AKA Candlestick data.
  result = static(binanceAPIUrl & "/api/v3/klines?symbol=")
  result.add symbol
  result.add "&interval="
  result.add $interval
  result.add "&limit="
  result.addInt limit


proc getHistoricalKlines*(self: Binance, symbol: string, interval: Interval, start_str: Duration, end_str: Duration = initDuration(seconds = 0), kline_type: HistoricalKlinesType = SPOT, limit: int = 500): JsonNode =
  var
    output_data = newJArray()
    timeframe: int = interval  #invoke interval_to_milliseconds
    start_ts: int64 = start_str
    idx = 0
    url: string
    temp_data: JsonNode

  while true:
    url = self.klines(symbol = symbol, interval = interval, limit = limit, startTime = start_str, endTime = end_str)
    temp_data = parseJson(self.getContent(url))
    output_data.add temp_data

    # set our start timestamp using the last value in the array
    start_ts = temp_data[^1][0].getBiggestInt
    inc idx

    if temp_data.len < limit:
      break

    start_ts += timeframe

    if idx %% 3 == 0:
      sleep 1_000

  output_data


proc ticker24h*(self: Binance; symbol: string): string =
  ## Price changes in the last 24 hours.
  result = static(binanceAPIUrl & "/api/v3/ticker/24hr?symbol=")
  result.add symbol


proc ticker24h*(self: Binance): string =
  ## Price changes in the last 24 hours.
  result = static(binanceAPIUrl & "/api/v3/ticker/24hr")


proc tickerPrice*(self: Binance; symbol: string): string =
  ## Symbol price.
  result = static(binanceAPIUrl & "/api/v3/ticker/price?symbol=")
  result.add symbol


proc tickerPrice*(self: Binance): string =
  ## Symbol price.
  result = static(binanceAPIUrl & "/api/v3/ticker/price")


proc orderBookTicker*(self: Binance; symbol: string): string =
  ## Symbol order book.
  result = static(binanceAPIUrl & "/api/v3/ticker/bookTicker?symbol=")
  result.add symbol


proc orderBookTicker*(self: Binance): string =
  ## Symbol order book.
  result = static(binanceAPIUrl & "/api/v3/ticker/bookTicker")


# Account Trade

#GET /api/v3/order
#Check an order's status
proc getOrder*(self: Binance, symbol: string, orderId = 1.Positive, origClientOrderId = 1.Positive): string =
  result = "symbol="
  result.add symbol
  result.add "&orderId="
  result.addInt orderId
  result.add "&origClientOrderId="
  result.addInt origClientOrderId
  self.signQueryString"order"


#POST /api/v3/order
#Send in a new order.
proc postOrder*(self: Binance; side: Side; tipe: OrderType; timeInForce, symbol: string; quantity, price: float): string =
  result = "symbol="
  result.add symbol
  result.add "&side="
  result.add $side
  result.add "&type="
  result.add $tipe
  result.add "&timeInForce="
  result.add timeInForce
  result.add "&quantity="
  result.add $quantity
  result.add "&price="
  result.add $price
  self.signQueryString"order"


proc postOrder*(self: Binance; side: Side; tipe: OrderType; symbol: string; quantity: float): string =
  result = "symbol="
  result.add symbol
  result.add "&side="
  result.add $side
  result.add "&type="
  result.add $tipe
  result.add "&quantity="
  result.add $quantity
  self.signQueryString"order"


#POST /api/v3/order/test
#Test new order creation and signature/recvWindow long.
#Creates and validates a new order but does not send it into the matching engine
proc orderTest*(self: Binance; side: Side; tipe: OrderType; newOrderRespType: ResponseType;
    timeInForce, newClientOrderId, symbol: string; quantity, price: float): string =
  result = "symbol="
  result.add symbol
  result.add "&side="
  result.add $side
  result.add "&type="
  result.add $tipe
  result.add "&timeInForce="
  result.add timeInForce
  result.add "&quantity="
  result.add $quantity
  result.add "&price="
  result.add $price
  result.add "&newClientOrderId="
  result.add newClientOrderId
  result.add "&newOrderRespType="
  result.add $newOrderRespType
  self.signQueryString"order/test"


#GET /api/v3/account
#Get the current account information
proc accountData*(self: Binance): string =
  self.signQueryString"account"


#GET /api/v3/myTrades
#Get trades for a specific account and symbol.
proc myTrades*(self: Binance; symbol: string): string =
  result = "symbol="
  result.add symbol
  self.signQueryString"myTrades"


#GET /api/v3/rateLimit/order
#Displays the user's current order count usage for all intervals.
proc rateLimitOrder*(self: Binance): string =
  self.signQueryString"rateLimit/order"


#GET /api/v3/orderList
#Retrieves all OCO based on provided optional parameters
proc orderList*(self: Binance; orderListId = 1.Positive): string =
  result = "orderListId="
  result.addInt orderListId
  self.signQueryString"orderList"


#GET /api/v3/allOrderList
#Retrieves all OCO based on provided optional parameters
proc allOrderList*(self: Binance): string =
  self.signQueryString"allOrderList"


#GET /api/v3/openOrderList
proc openOrderList*(self: Binance): string =
  self.signQueryString"openOrderList"

#POST /api/v3/order/oco
#Send in a new OCO buy order
proc newOrderOco*(self: Binance, symbol: string, side: Side, quantity, price, stopPrice, stopLimitPrice :float, stopLimitTimeInForce: string):string =
  result = "symbol="
  result.add symbol
  result.add "&price="
  result.add $price
  result.add "&quantity="
  result.add $quantity
  result.add "&stopPrice="
  result.add $stopPrice
  result.add "&stopLimitPrice="
  result.add $stopLimitPrice
  result.add "&stopLimitTimeInForce="
  result.add stopLimitTimeInForce
  result.add "&side="
  result.add $side
  self.signQueryString"order/oco"

#GET /api/v3/openOrders
#Get all open orders on a symbol.
proc openOrders*(self: Binance, symbol: string): string =
  result = "symbol="
  result.add symbol
  self.signQueryString"openOrders"


proc request*(self: Binance, endpoint: string, httpMethod: HttpMethod = HttpGet): string =
  self.client.request(endpoint, httpMethod = httpMethod).body


# User data streams


proc userDataStream*(self: Binance): string =
  ## Start a new user data stream.
  ## * `POST` to Open a new user data stream.
  ## * `DELETE` to Delete an existing user data stream. Auto-closes at 60 minutes idle.
  ## * `GET` to Keep Alive an existing user data stream.
  result = binanceAPIUrl & "/api/v3/userDataStream"


runnableExamples"-d:ssl -d:nimDisableCertificateValidation -r:off":
  let client: Binance = newBinance("YOUR_BINANCE_API_KEY", "YOUR_BINANCE_API_SECRET")
  let preparedEndpoint: string = client.ping()
  echo client.getContent(preparedEndpoint)
