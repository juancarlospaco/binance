import std/[times, httpclient, httpcore, json, strutils, math, strformat, tables, os, algorithm], binance/binance_sha256

type
  Balances = object
    spot*: Table[string, tuple[free, locked: float]]
    margin*: Table[string, tuple[free, locked, interest, netAsset, borrowed: float]]
    isolated*: Table[string, seq[tuple[asset: string, free, locked, interest, netAsset, borrowed: float]]]

  Binance* = object  ## Binance API Client.
    apiKey*, apiSecret*: string  ## Get API Key and API Secret at https://www.binance.com/en/my/settings/api-management
    recvWindow*: 5_000..60_000   ## "Tolerance" for requests timeouts, Binance is very strict about "Timestamp" diff.
    client: HttpClient
    balances: Balances
    marginAsset*: string
    exchangeData: string
    prechecks*: bool

  TradingInfoStatus* = enum
    PREPARED      = "PREPARED"
    WITHOUT_FUNDS = "WITHOUT_FUNDS"

  MarketCap*    = seq[tuple[marketCap: int, ticker: string]]
  TradingInfo*  = tuple[baseAsset, quoteAsset: string, price, amount, quoteAmount: float, status: TradingInfoStatus]

  CoinType* = enum
    STABLE_COIN = "STABLE_COIN"
    ALT_COIN    = "ALT_COIN"

  AccountType* = enum
    SPOT_ACCOUNT     = "SPOT"
    MARGIN_ACCOUNT   = "MARGIN"
    ISOLATED_ACCOUNT = "ISOLATED"

  FilterRule = enum
    PRICE_FILTER        = "PRICE_FILTER"        ## Defines the price rules for a symbol
    PERCENT_PRICE       = "PERCENT_PRICE"       ## Defines valid range for a price based on the average of the previous trades
    LOT_SIZE            = "LOT_SIZE"            ## Defines the quantity (aka "lots" in auction terms) rules for a symbol
    MIN_NOTIONAL        = "MIN_NOTIONAL"        ## Defines the minimum notional value allowed for an order on a symbol
#    ICEBERG_PARTS       = "ICEBERG_PARTS"       ## Defines the maximum parts an iceberg order can have
    MARKET_LOT_SIZE     = "MARKET_LOT_SIZE"     ## Defines the quantity (aka "lots" in auction terms) rules for MARKET orders on a symbol
    MAX_NUM_ORDERS      = "MAX_NUM_ORDERS"      ## Defines the maximum number of orders an account is allowed to have open on a symbol
#    MAX_NUM_ALGO_ORDERS = "MAX_NUM_ALGO_ORDERS" ## Defines the maximum number of "algo" orders an account is allowed to have open on a symbol


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
    SPOT_TO_MARGIN_ISOLATED     = "SPOT_TO_MARGIN_ISOLATED"
    SPOT_TO_MINING              = "MAIN_MINING"
    FIAT_TO_SPOT                = "C2C_MAIN"
    FIAT_TO_USDT_FUTURE         = "C2C_UMFUTURE"
    FIAT_TO_MINING              = "C2C_MINING"
    USDT_FUTURE_TO_SPOT         = "UMFUTURE_MAIN"
    USDT_FUTURE_TO_FIAT         = "UMFUTURE_C2C"
    USDT_FUTURE_TO_MARGIN_CROSS = "UMFUTURE_MARGIN"
    COIN_FUTURE_TO_SPOT         = "CMFUTURE_MAIN"
    MARGIN_CROSS_TO_SPOT        = "MARGIN_MAIN"
    MARGIN_ISOLATED_TO_SPOT     = "MARGIN_ISOLATED_TO_SPOT"
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
const stableCoins* = ["USDT", "BUSD", "USDC", "UST", "DAI", "USDP"]


template checkFloat*(floaty: float; lowest: static[float] = NaN; highest: static[float] = NaN) =
  ## Utility template to check if a float is valid, because float sux.
  assert not floaty.isNaN, "Value must not be  NaN"
  assert floaty != +Inf,   "Value must not be +Inf"
  assert floaty != -Inf,   "Value must not be -Inf"
  when not lowest.isNaN:  assert floaty >= lowest,  "Value must be >= " & $lowest
  when not highest.isNaN: assert floaty <= highest, "Value must be <= " & $highest

proc truncate*(self: Binance; number: float, digits: uint): float =
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
    result = parseFloat(resp[0 .. 5])
  else:
    result = round(number,2)


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

template close*(self: Binance) = self.client.close()
template getContent*(self: Binance, url: string): string = self.client.getContent(url)
proc request*(self: Binance, endpoint: string, httpMethod: HttpMethod = HttpGet): string {.inline.} = self.client.request(url = endpoint, httpMethod = httpMethod).body


template signQueryString(self: Binance; endpoint: string, sapi: bool = false) =
  ## Sign the query string for Binance API, reusing the same string.
  result.add if len(result) > 0: "&recvWindow=" else: "recvWindow="
  result.addInt self.recvWindow
  result.add "&timestamp="
  result.addInt now().utc.toTime.toUnix * 1_000  # UTC Timestamp.
  let signature: string = sha256.hmac(self.apiSecret, result)
  result.add "&signature="
  result.add signature
  result = binanceAPIUrl & (if not sapi: "/api/v3/" else: "/sapi/v1/") & endpoint & '?' & result

#GET /{s}api/v3/account
#Get the current account information
proc accountData*(self: Binance, accountType: AccountType = SPOT_ACCOUNT): string =
  case accountType:
  of SPOT_ACCOUNT:  self.signQueryString"account"
  of MARGIN_ACCOUNT: self.signQueryString("margin/account", sapi = true)
  else: self.signQueryString("margin/isolated/account", sapi = true)


#GET /api/v3/avgPrice
#Current average price for a symbol.
proc avgPrice*(self: Binance, symbol: string): string =
  result = static(binanceAPIUrl & "/api/v3/avgPrice?symbol=")
  result.add symbol


#Get user wallet assets
proc updateUserWallet(self: var Binance, accountType: AccountType = SPOT_ACCOUNT) =
  let wallet = parseJson(self.getContent(self.accountData(accountType)))
  var key: string
  case accountType:
  of SPOT_ACCOUNT:
    self.balances.spot = initTable[string, tuple[free, locked: float]]()
    key = "balances"
  of MARGIN_ACCOUNT:
    self.balances.margin = initTable[string, tuple[free, locked, interest, netAsset, borrowed: float]]()
    key = "userAssets"
  else:
    self.balances.isolated = initTable[string, seq[tuple[asset: string, free, locked, interest, netAsset, borrowed: float]]]()
    key = "assets"

  let wallet_data = wallet[key]
  for asset in wallet_data:
    # Hide 0 balances
    if asset{"free"}.getStr != "":
      if asset{"free"}.getStr.parseFloat != 0.0:
        case accountType:
        of SPOT_ACCOUNT:
          self.balances.spot[asset["asset"].getStr] = (asset["free"].getStr.parseFloat, asset["locked"].getStr.parseFloat)
        else:
          self.balances.margin[asset["asset"].getStr] = (asset["free"].getStr.parseFloat, asset["locked"].getStr.parseFloat, asset["interest"].getStr.parseFloat, asset["netAsset"].getStr.parseFloat, asset["borrowed"].getStr.parseFloat)
    else:
      var data:seq[tuple[asset: string, free, locked, interest, netAsset, borrowed: float]]
      for a in ["baseAsset", "quoteAsset"]:
        var item = asset[a]
        data.add (item["asset"].getStr, item["free"].getStr.parseFloat, item["locked"].getStr.parseFloat, item["interest"].getStr.parseFloat, item["netAsset"].getStr.parseFloat, item["borrowed"].getStr.parseFloat)
      self.balances.isolated[asset["symbol"].getStr] = data


proc exchangeInfo*(self: Binance, symbols: seq[string] = @[], fromMemory: bool = false): string =
  ## Exchange information, info about Binance.
  if not fromMemory:
    result = binanceAPIUrl & "/api/v3/exchangeInfo"
    if len(symbols) != 0:
      # Get information about 1 or more symbols
      if len(symbols) == 1:
        result.add "?symbol="
        result.add symbols[0]
      else:
        result.add "?symbols="
        result.add "%5B%22"
        result.add symbols.join(",").replace(",","%22%2C%22")
        result.add "%22%5D"
  else:
    result = self.exchangeData.parseJson.pretty
    if len(symbols) != 0:
      result = ""
      var temp_result = (self.exchangeData.parseJson)["symbols"]
      var fetched:seq[string]
      for symbol in symbols:
        for k in temp_result:
          if k["symbol"].getStr notin fetched and k["symbol"].getStr == symbol:
            fetched.add symbol
            result.add k.pretty


proc newBinance*(apiKey, apiSecret: string): Binance =
  ## Constructor for Binance client.
  assert apiKey.len > 0 and apiSecret.len > 0, "apiKey and apiSecret must not be empty string."
  var client = newHttpClient()
  client.headers.add "X-MBX-APIKEY", apiKey
  result = Binance(apiKey: apiKey, apiSecret: apiSecret, recvWindow: 10_000, client: client)
  # user wallet is cached in memory at runtime
  result.updateUserWallet
  result.updateUserWallet(MARGIN_ACCOUNT)
  result.updateUserWallet(ISOLATED_ACCOUNT)
  # retrieves exchange info for trading uses
  result.exchangeData = result.getContent(result.exchangeInfo())


## Retrieves current or updated wallet info
proc userWallet*(self: var Binance, update:bool = false, accountType: AccountType = SPOT_ACCOUNT): Balances =
  if update:
    self.updateUserWallet(accountType)
  self.balances

proc getStableCoinsInWallet*(self: var Binance): Table[string, float] =
  var myWallet = self.userWallet(update = true).spot
  for coin in myWallet.keys:
    if coin in stableCoins:
      result[coin] = myWallet[coin].free


proc verifyFiltersRule(self:Binance, symbol: string, price, quantity:float, tipe: OrderType):bool =
  var
    data = parseJson(self.exchangeInfo(fromMemory = true))["symbols"].getElems
    min:float
    max:float
    stepSize:float

  for item in data:
    if item["symbol"].getStr == symbol:
      var filters = item["filters"]
      for f in filters:
        case f["filterType"].getStr:
        of $PRICE_FILTER:
          result = true
          # price_filter is disabled for market orders
          if tipe != ORDER_TYPE_MARKET:
            min = f["minPrice"].getStr.parseFloat
            max = f["maxPrice"].getStr.parseFloat
            stepSize = f["tickSize"].getStr.parseFloat
            result = price >= min and price <= max and price - (price / stepSize) * stepSize == 0
          echo "PRICE_FILTER: ", $result
        of $PERCENT_PRICE:
          min = f["multiplierDown"].getStr.parseFloat
          max = f["multiplierUp"].getStr.parseFloat
          stepSize = parseJson(self.getContent(self.avgPrice(symbol)))["price"].getStr.parseFloat
          result = price >= stepSize * min and price <= stepSize * max
          echo "PERCENT_PRICE: ", $result
        of $MIN_NOTIONAL:
          min = f["minNotional"].getStr.parseFloat
          result = price * quantity >= min
          echo "MIN_NOTIONAL: ", $result
        of $LOT_SIZE:
          min = f["minQty"].getStr.parseFloat
          max = f["maxQty"].getStr.parseFloat
          stepSize = f["stepSize"].getStr.parseFloat
          result = quantity >= min and quantity <= max and round(quantity - (quantity / stepSize) * stepSize) == 0
          echo "LOT_SIZE: ", $result
        of $MARKET_LOT_SIZE:
          result = true
          if tipe == ORDER_TYPE_MARKET:
            min = f["minQty"].getStr.parseFloat
            max = f["maxQty"].getStr.parseFloat
            stepSize = f["stepSize"].getStr.parseFloat
            result = quantity >= min and quantity <= max and round(quantity - (quantity / stepSize) * stepSize) == 0
            echo "MARKET_LOT_SIZE: ", result

      break


# Generic endpoints.

proc ping*(self: Binance): string =
  ## Test connectivity to Binance, just a ping.
  result = binanceAPIUrl & "/api/v3/ping"


proc time*(self: Binance): string =
  ## Get current Binance API server time.
  result = binanceAPIUrl & "/api/v3/time"


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
proc postOrder*(self: var Binance; side: Side; tipe: OrderType; timeInForce, symbol: string; quantity, price: float): string =
  self.prechecks = self.verifyFiltersRule(symbol, price, quantity, tipe)
  result = "symbol="
  result.add symbol
  result.add "&side="
  result.add $side
  result.add "&type="
  result.add $tipe
  result.add "&quantity="
  result.add quantity.formatFloat(ffDecimal, 8)

  if tipe == ORDER_TYPE_LIMIT:
    result.add "&timeInForce="
    result.add timeInForce
    result.add "&price="
    result.add price.formatFloat(ffDecimal, 2)

  self.signQueryString"order"


proc postOrder*(self: Binance; side: Side; tipe: OrderType; symbol: string; quantity, price: float): string =
  result = "symbol="
  result.add symbol
  result.add "&side="
  result.add $side
  result.add "&type="
  result.add $tipe
  result.add "&quantity="
  result.add quantity.formatFloat(ffDecimal, 8)
  result.add "&price="
  result.add price.formatFloat(ffDecimal, 2)
  self.signQueryString"order"


proc postOrder*(self: Binance; side: Side; tipe: OrderType; symbol: string; quantity: float; accountType: AccountType = SPOT_ACCOUNT): string =
  result = "symbol="
  result.add symbol
  result.add "&side="
  result.add $side
  result.add "&type="
  result.add $tipe
  result.add "&quantity="
  result.add quantity.formatFloat(ffDecimal, 8)
  if accountType != SPOT_ACCOUNT:
    result.add "&isIsolated="
    result.add if accountType == ISOLATED_ACCOUNT: "TRUE" else: "FALSE"
  case accountType:
  of SPOT_ACCOUNT: self.signQueryString"order"
  of MARGIN_ACCOUNT, ISOLATED_ACCOUNT: self.signQueryString("margin/order", sapi = true)


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
  result.add price.formatFloat(ffDecimal, 2)
  result.add "&quantity="
  result.add quantity.formatFloat(ffDecimal, 4)
  result.add "&stopPrice="
  result.add stopPrice.formatFloat(ffDecimal, 2)
  result.add "&stopLimitPrice="
  result.add stopLimitPrice.formatFloat(ffDecimal, 4)
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


# User data streams


proc userDataStream*(self: Binance): string =
  ## Start a new user data stream.
  ## * `POST` to Open a new user data stream.
  ## * `DELETE` to Delete an existing user data stream. Auto-closes at 60 minutes idle.
  ## * `GET` to Keep Alive an existing user data stream.
  result = binanceAPIUrl & "/api/v3/userDataStream"


proc getProducts*(self: Binance): string =
  ## Undocumented API endpoint ?, no auth required ?.
  "https://www.binance.com/exchange-api/v2/public/asset-service/product/get-products"


proc getTopMarketCapPairs*(self: Binance; stablecoin = "USDT"; limit = 100.Positive): MarketCap =
  ## Get top market cap trading pairs, ordered from big to small, filtered by `stablecoin`, maximum of `limit`.
  ## * This needs to iterate all pairs sadly, because the API sends it unordered, >300 pairs for any `stablecoin`.
  assert stablecoin.len > 0, "stablecoin must not be empty string"
  let data: JsonNode = parseJson(self.request(self.getProducts()))["data"]
  result = newSeqOfCap[tuple[marketCap: int, ticker: string]](data.len)
  for coin in data:
    let pair: string = coin["s"].getStr
    if coin["q"].getStr == stablecoin and not coin["cs"].isNil and not coin["c"].isNil and coin["cs"].getInt > 0:
      result.add (marketCap: int(coin["cs"].getInt.float * coin["c"].getStr.parseFloat), ticker: pair)
  result.sort Descending
  result.setLen limit


proc get24hHiLo*(self: Binance; symbolTicker: string): tuple[hi24h: float, lo24h: float] =
  ## Get 24 hours Highest price and Lowest price for a symbol.
  assert symbolTicker.len > 0, "symbolTicker must not be empty string"
  let temp = parseJson(self.request(self.ticker24h(symbolTicker), HttpGet))
  result = (hi24h: temp["highPrice"].getStr.parseFloat, lo24h: temp["lowPrice"].getStr.parseFloat)


proc getDynamicSleep*(self: Binance; symbolTicker: string; baseSleep: static[int] = 30_000): int =
  ## Get a "dynamic" sleep time integer for use with `sleep` and loops.
  ## * If more volatility then less sleep time, and viceversa.
  assert symbolTicker.len > 0, "symbolTicker must not be empty string"
  let temp = parseJson(self.request(self.ticker24h(symbolTicker), HttpGet))["priceChangePercent"].getStr.parseFloat
  result = int(baseSleep / (if temp > 0.0: temp else: 1.0))
  if result > 100_000: result = 100_000


proc prepareTransaction*(self: var Binance, ticker: string): TradingInfo =
  var
    tp = parseJson(self.request(self.tickerPrice(ticker)))
    data = parseJson(self.exchangeInfo(symbols = @[ticker], fromMemory = true))
    current_amount = self.getStableCoinsInWallet()[data["quoteAsset"].getStr]
    baseAsset  = data["baseAsset"].getStr
    quoteAsset = data["quoteAsset"].getStr
    priceToBuy = tp["price"].getStr.parseFloat

  let min_amount = data["filters"][3]["minNotional"].getStr.parseFloat

  if current_amount * 0.75 > min_amount:
    current_amount *= 0.75
    var quantity = if (current_amount / priceToBuy).formatFloat(ffDecimal, 4) == "0.0000": 0.0001 else: current_amount / priceToBuy
    result = (baseAsset, quoteAsset, priceToBuy, quantity, current_amount, PREPARED)
  else:
    result = (baseAsset, quoteAsset, priceToBuy, current_amount / priceToBuy, current_amount, WITHOUT_FUNDS)


proc prepareTransactions*(self: var Binance, coinType: CoinType):seq[TradingInfo] =
  var
    symbolToBuy:string
    current_amount = 0.0
    virtual_current_amount = -1.0
    myWallet = self.userWallet().spot
    exchangeData = parseJson(self.exchangeInfo(fromMemory = true))["symbols"]
    marketDetails: Table[string, MarketCap]
    market: MarketCap
    data: MarketCap
    coin: string
    balance: tuple[free: float, locked: float]
    checked_assets: seq[string]

  #produces possible trading operations for every coin in your wallet
  for p in pairs(myWallet):
    (coin, balance) = p

    if coinType == STABLE_COIN:
      if coin in stableCoins:
        data = self.getTopMarketCapPairs(coin, 5)
    else:
      data = self.getTopMarketCapPairs(coin, 5)

    for d in data:
      if (0,"") != d:
        marketDetails[coin] = data

  # find a price and a minimal amount required for trade
  for assets in pairs(marketDetails):
    (coin, market) = assets

    for m in marketDetails[coin]:
      var tp = parseJson(self.request(self.tickerPrice(m[1])))
      var priceToBuy = tp["price"].getStr.parseFloat

      for asset in exchangeData:
        if asset["symbol"].getStr notin checked_assets:
          if asset["symbol"].getStr == tp["symbol"].getStr:
            checked_assets.add asset["symbol"].getStr
            symbolToBuy = asset["quoteAsset"].getStr
            let min_amount = asset["filters"][3]["minNotional"].getStr.parseFloat
            # let stepSize   = asset["filters"][2]["stepSize"].getStr.parseFloat

            if virtual_current_amount < 0:
              current_amount = self.getStableCoinsInWallet()[symbolToBuy]
              virtual_current_amount = current_amount

            if virtual_current_amount * 0.75 > min_amount:
              current_amount *= 0.75
              virtual_current_amount -= current_amount
              result.add (asset["baseAsset"].getStr, symbolToBuy, round(priceToBuy,4), current_amount / priceToBuy, current_amount, PREPARED)
            else:
              result.add (asset["baseAsset"].getStr, symbolToBuy, round(priceToBuy,4),current_amount / priceToBuy, current_amount, WITHOUT_FUNDS)

            virtual_current_amount = current_amount
            break

#      virtual_current_amount = -1


proc getBnb*(self: var Binance): float =
  ## Get BNB in user wallet, this is useful for Commisions.
  try: self.userWallet(update = true).spot["BNB"].free except Exception: 0.0


proc getBnbPrice*(self: Binance): string {.inline.} =
  ## BNB price in USDT, useful for commision calc.
  result = static(binanceAPIUrl & "/api/v3/ticker/price?symbol=BNBUSDT")


proc checkEarnings*(self: var Binance; coin: string): bool =
  ## Check if we made some earnings.
  assert coin.len > 0, "coin must not be empty string"
  let
    cache = self.userWallet().spot
    afterTrade = self.userWallet(update = true).spot
  result = afterTrade[coin].free > cache[coin].free


template donateToAddress*(self: Binance; address: string; amount = 0.0000095; coin = "BTC") =
  ## Donate to an specific `address`, using `"BSC"` network, using `"BTC"` as `coin` by default, the minimum `amount` possible of `0.0000095` by default.
  assert address.len > 1, "Please provide a valid address, BSC network."
  discard self.request(self.withDrawApply(coin, address, amount, "BSC"), HttpPost)


proc ma50*(self: Binance; ticker: string): float =
  ## Calculate the current Medium Average 50 of the market.
  assert ticker.len > 0, "ticker must not be empty string"
  var sum: float
  let klines = self.getHistoricalKlines(ticker, KLINE_INTERVAL_15MINUTE, initDuration(hours = 15))[0]
  if klines.len == 60:
    for i in 10 ..< 60:
      sum = sum + klines[i][4].getStr.parseFloat
    result = sum / 50


# Wallet endpoints


proc getAllCapital*(self: Binance): string =
  self.signQueryString("capital/config/getall", sapi = true)


proc withDrawApply*(self: Binance, coin, address: string, amount: float, network: string): string =
  result.add "coin="
  result.add coin
  result.add "&address="
  result.add address
  result.add "&amount="
  result.add amount.formatFloat(ffDecimal, 4)
  result.add "&network="
  result.add network
  self.signQueryString("capital/withdraw/apply", sapi = true)


proc apiRestrictions*(self: Binance): string =
  self.signQueryString("account/apiRestrictions", sapi = true)


proc enableFastWithdraw*(self: Binance): string =
  self.signQueryString("account/enableFastWithdrawSwitch", sapi = true)


# Margin Account/Trade endpoints


proc marginLevel*(self: Binance): float =
  parseJson(self.request(self.accountData(MARGIN_ACCOUNT)))["marginLevel"].getStr.parseFloat


proc priceIndex*(self: Binance): string =
  result = binanceAPIUrl & "/sapi/v1/margin/priceIndex?symbol=" & self.marginAsset


proc totalDebt*(self: Binance): float =
  var
    debt  = parseJson(self.request(self.accountData(MARGIN_ACCOUNT)))["totalLiabilityOfBtc"].getStr.parseFloat
    price = parseJson(self.request(self.priceIndex))["price"].getStr.parseFloat
  price * debt


proc transfer*(self: Binance, asset: string, amount: float, tipe: AssetTransfer): string =
  assert tipe in {SPOT_TO_MARGIN_CROSS, MARGIN_CROSS_TO_SPOT, SPOT_TO_MARGIN_ISOLATED, MARGIN_ISOLATED_TO_SPOT}, "Transfer can only be made between spot and margin cross accounts."
  assert amount > 0, "Amount must be greater than 0"
  if tipe == MARGIN_CROSS_TO_SPOT:
    doAssert amount > self.totalDebt, "Amount must be 2 times greater than total debt"

  var url: string

  result.add "asset="
  result.add asset
  result.add "&amount="
  result.add $amount

  if tipe in { SPOT_TO_MARGIN_CROSS, MARGIN_CROSS_TO_SPOT }:
    url = "margin/transfer"
    result.add "&type="
    result.add if tipe == SPOT_TO_MARGIN_CROSS: "1" else: "2"
  else:
    url = "margin/isolated/transfer"
    result.add "&symbol="
    result.add self.marginAsset
    result.add "&transFrom="
    result.add if tipe == SPOT_TO_MARGIN_ISOLATED: "SPOT" else: "ISOLATED_MARGIN"
    result.add "&transTo="
    result.add if tipe == SPOT_TO_MARGIN_ISOLATED: "ISOLATED_MARGIN" else: "SPOT"

  self.signQueryString(url, sapi = true)

proc borrow*(self: Binance, asset: string, amount: float, accountType: AccountType): string =
  result.add "asset="
  result.add asset
  result.add "&amount="
  result.add $amount

  if accountType == ISOLATED_ACCOUNT:
    result.add "&isIsolated=TRUE"
    result.add "&symbol="
    result.add self.marginAsset

  self.signQueryString("margin/loan", sapi = true)

proc repay*(self: Binance, asset: string, amount: float, accountType: AccountType): string =
  result.add "asset="
  result.add asset
  result.add "&amount="
  result.add $amount

  if accountType == ISOLATED_ACCOUNT:
    result.add "&isIsolated=TRUE"
    result.add "&symbol="
    result.add self.marginAsset

  self.signQueryString("margin/repay", sapi = true)

proc maxBorrowable*(self: Binance, asset: string, accountType: AccountType): string =
  result.add "asset="
  result.add asset

  if accountType == ISOLATED_ACCOUNT:
    result.add "&isIsolated=TRUE"
    result.add "&symbol="
    result.add self.marginAsset

  self.signQueryString("margin/maxBorrowable", sapi = true)


proc maxTransferable*(self: Binance, asset: string, accountType: AccountType): string =
  result.add "asset="
  result.add asset

  if accountType == ISOLATED_ACCOUNT:
    result.add "&isIsolated=TRUE"
    result.add "&symbol="
    result.add self.marginAsset

  self.signQueryString("margin/maxTransferable", sapi = true)


runnableExamples"-d:ssl -d:nimDisableCertificateValidation -r:off":
  let client: Binance = newBinance("YOUR_BINANCE_API_KEY", "YOUR_BINANCE_API_SECRET")
  let preparedEndpoint: string = client.ping()
  echo client.getContent(preparedEndpoint)
