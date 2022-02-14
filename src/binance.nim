import std/[uri, times, httpclient, httpcore]
import binance/binance_sha256


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
    SPOT_TO_FIAT = "MAIN_C2C"
    SPOT_TO_USDT_FUTURE = "MAIN_UMFUTURE"
    SPOT_TO_COIN_FUTURE = "MAIN_CMFUTURE"
    SPOT_TO_MARGIN_CROSS = "MAIN_MARGIN"
    SPOT_TO_MINING = "MAIN_MINING"
    FIAT_TO_SPOT = "C2C_MAIN"
    FIAT_TO_USDT_FUTURE = "C2C_UMFUTURE"
    FIAT_TO_MINING = "C2C_MINING"
    USDT_FUTURE_TO_SPOT = "UMFUTURE_MAIN"
    USDT_FUTURE_TO_FIAT = "UMFUTURE_C2C"
    USDT_FUTURE_TO_MARGIN_CROSS = "UMFUTURE_MARGIN"
    COIN_FUTURE_TO_SPOT = "CMFUTURE_MAIN"
    MARGIN_CROSS_TO_SPOT = "MARGIN_MAIN"
    MARGIN_CROSS_TO_USDT_FUTURE = "MARGIN_UMFUTURE"
    MINING_TO_SPOT = "MINING_MAIN"
    MINING_TO_USDT_FUTURE = "MINING_UMFUTURE"
    MINING_TO_FIAT = "MINING_C2C"

const binanceAPIUrl* {.strdefine.} = "https://testnet.binance.vision"  # "https://api.binance.com"   `-d:binanceAPIUrl="https://testnet.binance.vision"` for Testnet.


template genTimestamp(): string = $(now().utc.toTime.toUnix * 1_000)


proc newBinance*(apiKey, apiSecret: string): Binance =
  ## Constructor for Binance client.
  assert apiKey.len > 0 and apiSecret.len > 0, "apiKey and apiSecret must not be empty string."
  var client = newHttpClient()
  client.headers.add "X-MBX-APIKEY", apiKey
  Binance(apiKey: apiKey, apiSecret: apiSecret, recvWindow: 10_000, client: client)

template getContent*(self: Binance, url: string): string = self.client.getContent(url)


proc signQueryString(apiSecret, queryString, endpoint: string): string =
  let signature: string = sha256.hmac(apiSecret, queryString)
  result = static(binanceAPIUrl & "/api/v3/")
  result.add endpoint
  result.add '?'
  result.add queryString
  result.add '&'
  result.add 's'
  result.add 'i'
  result.add 'g'
  result.add 'n'
  result.add 'a'
  result.add 't'
  result.add 'u'
  result.add 'r'
  result.add 'e'
  result.add '='
  result.add signature


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


proc olderTrades*(self: Binance; symbol: string; limit: 1..500 = 500; fromId: int): string =
  ## Old historical Trades.
  assert fromId > 0, "fromId must be greater than 0."
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


proc aggrTrades*(self: Binance; symbol: string; fromId, startTime, endTime: int; limit: 1..500 = 500): string =
  ## Aggregated Trades list.
  assert fromId > 0, "fromId must be an integer greater than 0."
  assert startTime > 0, "startTime must be an integer greater than 0."
  assert endTime > 0, "endTime must be an integer greater than 0."
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


proc aggrTrades*(self: Binance; symbol: string; fromId: int; limit: 1..500 = 500): string =
  ## Aggregated Trades list.
  assert fromId > 0, "fromId must be an integer greater than 0."
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


proc klines*(self: Binance; symbol: string; interval: Interval, startTime, endTime: int; limit: 1..500 = 500): string =
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
proc getOrder*(self: Binance, symbol:string, orderId:uint = 1, origClientOrderId: uint = 1): string =
  var queryString: string = encodeQuery({
    "symbol": symbol, "orderID": $orderId, "origClientOrderId": $origClientOrderId, "timestamp": genTimestamp()
  })
  signQueryString(self.apiSecret, queryString, "order")


#POST /api/v3/order
#Send in a new order.
proc postOrder*(self: Binance, side:Side, tipe: OrderType, timeInForce,symbol:string, quantity, price:float): string =
  var queryString: string = encodeQuery({
    "symbol": symbol, "side": $side, "type": $tipe, "timeInForce": timeInForce, "quantity": $quantity,
    "price": $price, "recvWindow": $self.recvWindow, "timestamp": genTimestamp()
  })
  signQueryString(self.apiSecret, queryString, "order")


#POST /api/v3/order/test
#Test new order creation and signature/recvWindow long.
#Creates and validates a new order but does not send it into the matching engine
proc orderTest*(self: Binance; side: Side; tipe: OrderType; newOrderRespType: ResponseType;
    timeInForce, newClientOrderId, symbol: string; quantity, price: float): string =

  var queryString: string = encodeQuery({
    "symbol": symbol, "side": $side, "type": $tipe, "timeInForce": timeInForce,
    "quantity": $quantity, "price": $price, "newClientOrderId": newClientOrderId,
    "newOrderRespType": $newOrderRespType, "recvWindow": $self.recvWindow, "timestamp": genTimestamp()
  })
  signQueryString(self.apiSecret, queryString, "order/test")


#GET /api/v3/account
#Get the current account information
proc accountData*(self: Binance): string =
  var queryString: string = encodeQuery({
    "recvWindow": $self.recvWindow, "timestamp": genTimestamp()
  })
  signQueryString(self.apiSecret, queryString, "account")


#GET /api/v3/myTrades
#Get trades for a specific account and symbol.
proc myTrades*(self: Binance, symbol:string):string =
  var queryString: string = encodeQuery({
    "symbol": symbol, "recvWindow": $self.recvWindow, "timestamp": genTimestamp()
  })
  signQueryString(self.apiSecret, queryString, "myTrades")


#GET /api/v3/rateLimit/order
#Displays the user's current order count usage for all intervals.
proc rateLimitOrder*(self: Binance): string =
  var queryString: string = encodeQuery({
    "recvWindow": $self.recvWindow, "timestamp": genTimestamp()
  })
  signQueryString(self.apiSecret, queryString, "rateLimit/order")


#GET /api/v3/orderList
#Retrieves all OCO based on provided optional parameters
proc orderList*(self: Binance, orderListId:uint = 1):string =
  var queryString: string = encodeQuery({
    "orderListId": $orderListId, "recvWindow": $self.recvWindow, "timestamp": genTimestamp()
  })
  signQueryString(self.apiSecret, queryString, "orderList")


#GET /api/v3/allOrderList
#Retrieves all OCO based on provided optional parameters
proc allOrderList*(self: Binance):string =
  var queryString: string = encodeQuery({
    "recvWindow": $self.recvWindow, "timestamp": genTimestamp()
  })
  signQueryString(self.apiSecret, queryString, "allOrderList")


#GET /api/v3/openOrderList
proc openOrderList*(self: Binance):string =
  var queryString: string = encodeQuery({
    "recvWindow": $self.recvWindow, "timestamp": genTimestamp()
  })
  signQueryString(self.apiSecret, queryString, "openOrderList")


proc request*(self: Binance, endpoint: string, httpMethod: HttpMethod = HttpGet): string =
  self.client.request(endpoint, httpMethod = httpMethod).body


runnableExamples"-d:ssl -d:nimDisableCertificateValidation -r:off":
  from std/os import getEnv
  let client: Binance = newBinance(getEnv"BINANCE_API_KEY", getEnv"BINANCE_API_SECRET")
  let preparedEndpoint: string = client.ping()
  echo client.getContent(preparedEndpoint)
