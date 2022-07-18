import std/[times, httpcore, json, strutils, tables, os, algorithm, macros], binance/binance_sha256

when defined(js): import nodejs/jshttpclient
else:             import std/httpclient


type
  Binance* = object  ## Binance API Client.
    apiSecret*: string  ## Get API Key and API Secret at https://www.binance.com/en/my/settings/api-management
    client: (when defined(js): JsHttpClient else: HttpClient)

  Side* = enum
    SIDE_BUY  = "BUY"
    SIDE_SELL = "SELL"

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
    ORDER_TYPE_TRAILING_STOP_MARKET = "TRAILING_STOP_MARKET"
    ORDER_TYPE_STOP_MARKET          = "STOP_MARKET"
    ORDER_TYPE_STOP_LIMIT           = "STOP_LIMIT"

  IncomeType* {.pure.} = enum
    TRANSFER             = "TRANSFER"
    WELCOME_BONUS        = "WELCOME_BONUS"
    REALIZED_PNL         = "REALIZED_PNL"
    FUNDING_FEE          = "FUNDING_FEE"
    COMMISSION           = "COMMISSION"
    INSURANCE_CLEAR      = "INSURANCE_CLEAR"
    REFERRAL_KICKBACK    = "REFERRAL_KICKBACK"
    COMMISSION_REBATE    = "COMMISSION_REBATE"
    DELIVERED_SETTELMENT = "DELIVERED_SETTELMENT"
    COIN_SWAP_DEPOSIT    = "COIN_SWAP_DEPOSIT"
    COIN_SWAP_WITHDRAW   = "COIN_SWAP_WITHDRAW"

  TransferType* {.pure.} = enum
    spotToFutures     = "1"  ## Spot            to  Futures.
    futuresToSpot     = "2"  ## Futures         to  Spot.
    spotToFuturesCoin = "3"  ## Spot            to  Futures Coin-M.
    futuresCoinToSpot = "4"  ## Futures Coin-M  to  Spot.


const stableCoins* = ["USDT", "BUSD", "USDC", "DAI", "USDP"]


macro unrollEncodeQuery*(target: var string; args: openArray[(string, auto)]; charL: static[char] = '&'; charR: static[char] = '\0') =
  doAssert args.len > 0, "Iterable must not be empty, because theres nothing to unroll"
  result = newStmtList()
  if charL != '\0': result.add nnkCall.newTree(nnkDotExpr.newTree(target, newIdentNode"add"), newLit(charL))
  for i, item in args:
    let key: string = item[1][0].strVal
    doAssert key.len > 0, "Key must not be empty string."
    if i > 0: result.add nnkCall.newTree(nnkDotExpr.newTree(target, newIdentNode"add"), newLit('&'))
    for c in key: result.add nnkCall.newTree(nnkDotExpr.newTree(target, newIdentNode"add"), c.newLit)
    result.add nnkCall.newTree(nnkDotExpr.newTree(target, newIdentNode"add"), newLit('='))
    result.add nnkCall.newTree(nnkDotExpr.newTree(target, newIdentNode"add"), item[1][1])
  if charR != '\0': result.add nnkCall.newTree(nnkDotExpr.newTree(target, newIdentNode"add"), newLit(charR))


converter interval_to_milliseconds(interval: Interval): int =
  ## Get numeric part of Interval.
  ($interval)[0..^2].parseInt * (
    case ($interval)[^1]:
    of 'm': 60
    of 'h': 60 * 60
    of 'd': 24 * 60 * 60
    of 'w': 7  * 24 * 60 * 60
    else  : 1
  ) * 1_000


converter date_to_milliseconds(d: Duration): int64 =
  ## Date to milliseconds.
  var epoch = initDuration(seconds = now().utc.toTime.toUnix)
  epoch -= d
  epoch.inMilliseconds


template close*(self: Binance) = self.client.close()


proc request*(self: Binance; endpoint: string; httpMethod: static[HttpMethod]): JsonNode =
  ## Httpclient request but with a Retry.
  when defined(js):
    let rekuest = JsRequest(
      url: endpoint, `method`: httpMethod, integrity: "", referrer: "", mode: fmCors, keepAlive: false,
      credentials: fcOmit, cache: fchDefault, redirect: frFollow, referrerPolicy: frpOrigin, body: cstring.default,
    )
    result = parseJson($(self.client.request(rekuest).responseText))
  else:
    for _ in 0 .. 9:
      try:
        result = parseJson(self.client.request(url = endpoint, httpMethod = httpMethod).body)
        break
      except:
        continue


template signQueryString(self: Binance; endpoint: string) =
  ## Sign the query string for Binance API, reusing the same string.
  unrollEncodeQuery(result, {"recvWindow": "60000", "timestamp": $(now().utc.toTime.toUnix * 1_000)})
  let signature: string = sha256hmac(self.apiSecret, result)
  unrollEncodeQuery(result, {"signature": signature})  # This is special cased, starts with '&'.
  result = endpoint & '?' & result


proc newBinance*(apiKey, apiSecret: string): Binance =
  ## Constructor for Binance client.
  assert apiKey.len    >= 64, "apiKey must be a string of >= 64 chars."
  assert apiSecret.len >= 64, "apiSecret must be a string of >= 64 chars."
  when defined(js):
    let jeader: Headers = newHeaders()
    jeader.add "X-MBX-APIKEY".cstring, apiKey.cstring
    jeader.add "DNT".cstring, "1".cstring
    var client = newJsHttpClient(headers = jeader)
  else:
    var client = newHttpClient(timeout = 999_999)
    client.headers.add "X-MBX-APIKEY", apiKey
    client.headers.add "DNT", "1"
  result = Binance(apiSecret: apiSecret, client: client)


proc accountData*(self: Binance): string =
  ## Get the current account information
  self.signQueryString("https://api.binance.com/api/v3/account")


proc getWallet*(self: Binance; stablecoinsOnly = false): Table[string, float] =
  ## Get user wallet assets. To save memory and increase performance, only get the "free" balance, "locked" balance is ignored because is not usable whatsoever.
  for it in self.request(self.accountData(), HttpGet)["balances"]:
    let coinAmount: string = it["free"].getStr
    if coinAmount != "0.00000000":  # Ignore "0.00000000" balances.
      result[it["asset"].getStr] = coinAmount.parseFloat  # Only parseFloat the needed ones.


proc getBalance*(self: Binance; coin: string): float =
  ## Get user wallet balance of 1 specific coin, its faster than `getWallet`.
  for it in self.request(self.accountData(), HttpGet)["balances"]:
    if it["asset"].getStr == coin: return it["free"].getStr.parseFloat


template getPrice*(self: Binance; ticker: string): float =
  self.request(self.tickerPrice(ticker), HttpGet)["price"].getStr.parseFloat


# Market Data #################################################################


proc avgPrice*(self: Binance, symbol: string): string =
  ## Current average price for a symbol.
  result = "https://api.binance.com/api/v3/avgPrice"
  unrollEncodeQuery(result, {"symbol": symbol}, charL = '?')


proc orderBook*(self: Binance; symbol: string): string =
  ## Order book depth.
  result = "https://api.binance.com/api/v3/depth"
  unrollEncodeQuery(result, {"symbol": symbol, "limit": "500"}, charL = '?')


proc recentTrades*(self: Binance; symbol: string): string =
  ## Get a list of recent Trades.
  result = "https://api.binance.com/api/v3/trades"
  unrollEncodeQuery(result, {"symbol": symbol, "limit": "500"}, charL = '?')


proc olderTrades*(self: Binance; symbol: string; fromId: Positive): string =
  ## Old historical Trades.
  result = "https://api.binance.com/api/v3/historicalTrades"
  unrollEncodeQuery(result, {"symbol": symbol, "fromId": $fromId, "limit": "500"}, charL = '?')


proc olderTrades*(self: Binance; symbol: string): string =
  ## Old historical Trades.
  result = "https://api.binance.com/api/v3/historicalTrades"
  unrollEncodeQuery(result, {"symbol": symbol, "limit": "500"}, charL = '?')


proc aggrTrades*(self: Binance; symbol: string; fromId, startTime, endTime: Positive): string =
  ## Aggregated Trades list.
  assert endTime - startTime < 24 * 36000000, "startTime/endTime must be 2 integers representing a time interval smaller than 24 hours."
  result = "https://api.binance.com/api/v3/aggTrades"
  unrollEncodeQuery(result, {"symbol": symbol, "fromId": $fromId, "startTime": $startTime, "endTime": $endTime, "limit": "500"}, charL = '?')


proc aggrTrades*(self: Binance; symbol: string; fromId: Positive): string =
  ## Aggregated Trades list.
  result = "https://api.binance.com/api/v3/aggTrades"
  unrollEncodeQuery(result, {"symbol": symbol, "fromId": $fromId, "limit": "500"}, charL = '?')


proc aggrTrades*(self: Binance; symbol: string): string =
  ## Aggregated Trades list.
  result = "https://api.binance.com/api/v3/aggTrades"
  unrollEncodeQuery(result, {"symbol": symbol}, charL = '?')


proc klines*(self: Binance; symbol: string; interval: Interval, startTime, endTime: int64): string =
  ## Klines data, AKA Candlestick data.
  result = "https://api.binance.com/api/v3/klines"
  unrollEncodeQuery(result, {"symbol": symbol, "startTime": $startTime, "endTime": $endTime, "interval": $interval, "limit": "500"}, charL = '?')


proc klines*(self: Binance; symbol: string; interval: Interval): string =
  ## Klines data, AKA Candlestick data.
  result = "https://api.binance.com/api/v3/klines"
  unrollEncodeQuery(result, {"symbol": symbol, "interval": $interval, "limit": "500"}, charL = '?')


proc getHistoricalKlines*(self: Binance, symbol: string, interval: Interval, start_str: Duration, end_str: Duration = initDuration(seconds = 0)): JsonNode =
  var
    output_data = newJArray()
    timeframe: int = interval  # invoke interval_to_milliseconds
    start_ts: int64 = start_str
    idx = 0
    url: string
    temp_data: JsonNode

  while true:
    url = self.klines(symbol = symbol, interval = interval, startTime = start_str, endTime = end_str)
    temp_data = self.request(url, HttpGet)
    output_data.add temp_data

    # set our start timestamp using the last value in the array
    start_ts = temp_data[^1][0].getBiggestInt
    inc idx

    if temp_data.len < 500:  # limit is 500.
      break

    start_ts += timeframe

    if idx %% 3 == 0:
      sleep 1_000

  output_data


proc ticker24h*(self: Binance; symbol: string): string =
  ## Price changes in the last 24 hours.
  result = "https://api.binance.com/api/v3/ticker/24hr"
  unrollEncodeQuery(result, {"symbol": symbol}, charL = '?')


proc ticker24h*(self: Binance): string {.inline.} =
  ## Price changes in the last 24 hours.
  result = "https://api.binance.com/api/v3/ticker/24hr"


proc tickerPrice*(self: Binance; symbol: string): string =
  ## Symbol price.
  result = "https://api.binance.com/api/v3/ticker/price"
  unrollEncodeQuery(result, {"symbol": symbol}, charL = '?')


proc tickerPrice*(self: Binance): string {.inline.} =
  ## Symbol price.
  result = "https://api.binance.com/api/v3/ticker/price"


proc orderBookTicker*(self: Binance; symbol: string): string =
  ## Symbol order book.
  result = "https://api.binance.com/api/v3/ticker/bookTicker"
  unrollEncodeQuery(result, {"symbol": symbol}, charL = '?')


proc orderBookTicker*(self: Binance): string {.inline.} =
  ## Symbol order book.
  result = "https://api.binance.com/api/v3/ticker/bookTicker"


# Spot Trading ################################################################


proc getOrder*(self: Binance; symbol: string; orderId: Natural, origClientOrderId: Natural): string =
  ## Check an orders status.
  unrollEncodeQuery(result, {"symbol": symbol, "orderId": $orderId, "origClientOrderId": $origClientOrderId})
  self.signQueryString("https://api.binance.com/api/v3/order")


proc getOrder*(self: Binance; symbol: string; orderId: Natural): string =
  ## Check an orders status.
  unrollEncodeQuery(result, {"symbol": symbol, "orderId": $orderId})
  self.signQueryString("https://api.binance.com/api/v3/order")


proc getOrder*(self: Binance; symbol: string): string =
  ## Check an orders status.
  unrollEncodeQuery(result, {"symbol": symbol, "orderId": "0"})
  self.signQueryString("https://api.binance.com/api/v3/order")


proc postOrder*(self: Binance; side: Side; tipe: OrderType; symbol: string; quantity, price, stopPrice: float): string =
  ## Create a new order.
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "quantity": quantity.formatFloat(ffDecimal, 6), "timeInForce": "GTC", "price": price.formatFloat(ffDecimal, 6), "stopPrice": stopPrice.formatFloat(ffDecimal, 6)})
  self.signQueryString"https://api.binance.com/api/v3/order"


proc postOrder*(self: var Binance; side: Side; tipe: OrderType; symbol: string; quantity, price: float): string =
  ## Create a new order.
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "quantity": quantity.formatFloat(ffDecimal, 6)})
  if tipe == ORDER_TYPE_LIMIT: unrollEncodeQuery(result, {"timeInForce": "GTC", "price": price.formatFloat(ffDecimal, 6)})
  self.signQueryString"https://api.binance.com/api/v3/order"


proc postOrder*(self: Binance; side: Side; tipe: OrderType; symbol: string; quantity, price: float): string =
  ## Create a new order.
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "quantity": quantity.formatFloat(ffDecimal, 6), "price": price.formatFloat(ffDecimal, 6)})
  self.signQueryString"https://api.binance.com/api/v3/order"


proc postOrder*(self: Binance; side: Side; tipe: OrderType; symbol: string; quantity: float): string =
  ## Create a new order.
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "quantity": quantity.formatFloat(ffDecimal, 6)})
  self.signQueryString("https://api.binance.com/api/v3/order")


proc orderTest*(self: Binance; side: Side; tipe: OrderType; newClientOrderId, symbol: string; quantity, price: float): string =
  ## Test new order creation and signature/recvWindow. Creates and validates a new order but does not send it into the matching engine.
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "timeInForce": "GTC", "quantity": $quantity, "price": $price, "newClientOrderId": $newClientOrderId, "newOrderRespType": "ACK"})
  self.signQueryString"https://api.binance.com/api/v3/order/test"


proc myTrades*(self: Binance; symbol: string): string =
  ## Get trades for a specific account and symbol.
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString"https://api.binance.com/api/v3/myTrades"


proc rateLimitOrder*(self: Binance): string =
  ## Displays the users current order count usage for all intervals.
  self.signQueryString"https://api.binance.com/api/v3/rateLimit/order"


proc orderList*(self: Binance; orderListId = 1.Positive): string =
  ## Retrieves all Orders based on provided optional parameters.
  result = ""
  unrollEncodeQuery(result, {"orderListId": $orderListId})
  self.signQueryString"https://api.binance.com/api/v3/orderList"


proc allOrderList*(self: Binance): string =
  ## Retrieves all Orders.
  self.signQueryString"https://api.binance.com/api/v3/allOrderList"


proc openOrderList*(self: Binance): string =
  ## Retrieves all open Orders.
  self.signQueryString"https://api.binance.com/api/v3/openOrderList"


proc newOrderOco*(self: Binance, symbol: string, side: Side, quantity, price, stopPrice, stopLimitPrice :float): string =
  ## Create a new OCO order.
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "price": price.formatFloat(ffDecimal, 6), "quantity": quantity.formatFloat(ffDecimal, 6), "stopPrice": stopPrice.formatFloat(ffDecimal, 6), "stopLimitPrice": stopLimitPrice.formatFloat(ffDecimal, 6), "stopLimitTimeInForce": "GTC"})
  self.signQueryString"https://api.binance.com/api/v3/order/oco"


proc openOrders*(self: Binance, symbol: string): string =
  ## Get all open orders on a symbol.
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString"https://api.binance.com/api/v3/openOrders"


# Futures endpoints ###########################################################


proc pingFutures*(self: Binance): string {.inline.} =
  ## Test connectivity to Binance, just a ping.
  result = "https://fapi.binance.com/fapi/v1/ping"


proc timeFutures*(self: Binance): string {.inline.} =
  ## Test connectivity to the Rest API and get the current server time.
  result = "https://fapi.binance.com/fapi/v1/time"


proc exchangeInfoFutures*(self: Binance): string {.inline.} =
  ## Current exchange trading rules and symbol information.
  result = "https://fapi.binance.com/fapi/v1/exchangeInfo"


proc orderBookFutures*(self: Binance; symbol: string): string {.inline.} =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/exchangeInfo")


proc recentTradesFutures*(self: Binance; symbol: string): string {.inline.} =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/trades")


proc historicalTradesFutures*(self: Binance; symbol: string; fromId: Positive): string {.inline.} =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "fromId": $fromId, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/historicalTrades")


proc aggTradesFutures*(self: Binance; symbol: string; fromId, startTime, endTime: Positive): string {.inline.} =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "fromId": $fromId, "startTime": $startTime, "endTime": $endTime, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/aggTrades")


proc aggTradesFutures*(self: Binance; symbol: string; fromId: Positive): string {.inline.} =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "fromId": $fromId, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/aggTrades")


proc klinesFutures*(self: Binance; symbol: string; period: Interval, startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "startTime": $startTime, "endTime": $endTime, "period": $period, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/klines")


proc klinesFutures*(self: Binance; symbol: string; period: Interval): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "period": $period, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/klines")


proc continuousKlinesFutures*(self: Binance; pair: string; period: Interval, startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"pair": pair, "startTime": $startTime, "endTime": $endTime, "period": $period, "contractType": "PERPETUAL", "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/continuousKlines")


proc continuousKlinesFutures*(self: Binance; pair: string; period: Interval): string =
  result = ""
  unrollEncodeQuery(result, {"pair": pair, "period": $period, "contractType": "PERPETUAL", "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/continuousKlines")


proc indexPriceKlinesFutures*(self: Binance; pair: string; period: Interval, startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"pair": pair, "startTime": $startTime, "endTime": $endTime, "period": $period, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/indexPriceKlines")


proc indexPriceKlinesFutures*(self: Binance; pair: string; period: Interval): string =
  result = ""
  unrollEncodeQuery(result, {"pair": pair, "period": $period, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/indexPriceKlines")


proc markPriceKlinesFutures*(self: Binance; pair: string; period: Interval, startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"pair": pair, "startTime": $startTime, "endTime": $endTime, "period": $period, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/markPriceKlines")


proc markPriceKlinesFutures*(self: Binance; pair: string; period: Interval): string =
  result = ""
  unrollEncodeQuery(result, {"pair": pair, "period": $period, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/markPriceKlines")


proc markPriceFutures*(self: Binance; symbol: string): string =
  ## Mark Price AKA Premium Index.
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString("https://fapi.binance.com/fapi/v1/premiumIndex")


proc fundingRateFutures*(self: Binance; symbol: string; startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "startTime": $startTime, "endTime": $endTime, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/fundingRate")


proc fundingRateFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "limit": "500"})
  self.signQueryString("https://fapi.binance.com/fapi/v1/fundingRate")


proc ticker24hrFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString("https://fapi.binance.com/fapi/v1/ticker/24hr")


proc tickerPriceFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString("https://fapi.binance.com/fapi/v1/ticker/price")


proc tickerPriceFutures*(self: Binance): string =
  self.signQueryString("https://fapi.binance.com/fapi/v1/ticker/price")


proc tickerBookTickerFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString("https://fapi.binance.com/fapi/v1/ticker/bookTicker")


proc tickerBookTickerFutures*(self: Binance): string =
  self.signQueryString("https://fapi.binance.com/fapi/v1/ticker/bookTicker")


proc openInterestFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString("https://fapi.binance.com/fapi/v1/ticker/openInterest")


proc openInterestHistFutures*(self: Binance; symbol: string; period: Interval; startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "startTime": $startTime, "endTime": $endTime, "period": $period, "limit": "30"})
  self.signQueryString("https://fapi.binance.com/futures/data/openInterestHist")


proc openInterestHistFutures*(self: Binance; symbol: string; period: Interval): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "period": $period, "limit": "30"})
  self.signQueryString("https://fapi.binance.com/futures/data/openInterestHist")


proc topLongShortAccountRatioFutures*(self: Binance; symbol: string; period: Interval; startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "period": $period, "startTime": $startTime, "endTime": $endTime, "limit": "30"})
  self.signQueryString("https://fapi.binance.com/futures/data/topLongShortAccountRatio")


proc topLongShortAccountRatioFutures*(self: Binance; symbol: string; period: Interval): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "period": $period, "limit": "30"})
  self.signQueryString("https://fapi.binance.com/futures/data/topLongShortAccountRatio")


proc topLongShortPositionRatioFutures*(self: Binance; symbol: string; period: Interval; startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "period": $period, "startTime": $startTime, "endTime": $endTime, "limit": "30"})
  self.signQueryString("https://fapi.binance.com/futures/data/topLongShortPositionRatio")


proc topLongShortPositionRatioFutures*(self: Binance; symbol: string; period: Interval): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "period": $period, "limit": "30"})
  self.signQueryString("https://fapi.binance.com/futures/data/topLongShortPositionRatio")


proc globalLongShortAccountRatioFutures*(self: Binance; symbol: string; period: Interval; startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "period": $period, "startTime": $startTime, "endTime": $endTime, "limit": "30"})
  self.signQueryString("https://fapi.binance.com/futures/data/globalLongShortAccountRatio")


proc globalLongShortAccountRatioFutures*(self: Binance; symbol: string; period: Interval): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "period": $period, "limit": "30"})
  self.signQueryString("https://fapi.binance.com/futures/data/globalLongShortAccountRatio")


proc takerlongshortRatioFutures*(self: Binance; symbol: string; period: Interval; startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "period": $period, "startTime": $startTime, "endTime": $endTime, "limit": "30"})
  self.signQueryString("https://fapi.binance.com/futures/data/takerlongshortRatio")


proc takerlongshortRatioFutures*(self: Binance; symbol: string; period: Interval): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "period": $period, "limit": "30"})
  self.signQueryString("https://fapi.binance.com/futures/data/takerlongshortRatio")


proc symbolInformationFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString("https://fapi.binance.com/fapi/v1/indexInfo")


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType; quantity, price, stopPrice, activationPrice: float; callbackRate: 0.1 .. 5.0; closePosition: bool): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "timeInForce": "GTC", "closePosition": $closePosition, "quantity": $quantity, "price": $price, "stopPrice": $stopPrice, "activationPrice": $activationPrice, "callbackRate": $callbackRate  })
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType; quantity, price, stopPrice: float; closePosition: bool): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "closePosition": $closePosition, "quantity": $quantity, "price": $price, "stopPrice": $stopPrice})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType; stopPrice: float; closePosition: bool): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "closePosition": $closePosition, "stopPrice": $stopPrice})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side, positionSide: Side; tipe: OrderType; price, stopPrice: float; closePosition: bool): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "positionSide": if positionSide == SIDE_SELL: "SHORT" else: "LONG", "type": $tipe, "closePosition": $closePosition,  "price": $price, "stopPrice": $stopPrice})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; quantity: float; side, positionSide: Side; tipe: OrderType; callbackRate: 0.1 .. 5.0): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "quantity": $quantity, "side": $side, "positionSide": if positionSide == SIDE_SELL: "SHORT" else: "LONG", "type": $tipe, "callbackRate": $callbackRate})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; quantity: float; side, positionSide: Side; tipe: OrderType): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "quantity": $quantity, "side": $side, "positionSide": if positionSide == SIDE_SELL: "SHORT" else: "LONG", "type": $tipe})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; quantity, price: float; side, positionSide: Side; tipe: OrderType): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "quantity": $quantity, "price": $price, "timeInForce": "GTC", "side": $side, "positionSide": if positionSide == SIDE_SELL: "SHORT" else: "LONG", "type": $tipe})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; quantity, price, stopPrice: float; side, positionSide: Side; tipe: OrderType): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "quantity": $quantity, "price": $price, "stopPrice": $stopPrice, "timeInForce": "GTC", "side": $side, "positionSide": if positionSide == SIDE_SELL: "SHORT" else: "LONG", "type": $tipe})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; quantity, stopPrice: float; side, positionSide: Side; tipe: OrderType): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "quantity": $quantity, "stopPrice": $stopPrice, "side": $side, "positionSide": if positionSide == SIDE_SELL: "SHORT" else: "LONG", "type": $tipe})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; stopPrice: float; side, positionSide: Side; tipe: OrderType; closePosition: bool): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "stopPrice": $stopPrice, "positionSide": if positionSide == SIDE_SELL: "SHORT" else: "LONG", "type": $tipe, "closePosition": $closePosition})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; stopPrice: float; side, positionSide: Side; tipe: OrderType): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "stopPrice": $stopPrice, "positionSide": if positionSide == SIDE_SELL: "SHORT" else: "LONG", "type": $tipe})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; price, quantity: float; side, positionSide: Side; tipe: OrderType; callbackRate: 0.1 .. 5.0): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "price": $price, "quantity": $quantity, "callbackRate": $callbackRate, "positionSide": if positionSide == SIDE_SELL: "SHORT" else: "LONG", "type": $tipe})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; activationPrice, quantity: float; side, positionSide: Side; tipe: OrderType; callbackRate: 0.1 .. 5.0): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "activationPrice": $activationPrice, "quantity": $quantity, "callbackRate": $callbackRate, "positionSide": if positionSide == SIDE_SELL: "SHORT" else: "LONG", "type": $tipe})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType; quantity: float; callbackRate: 0.1 .. 5.0): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "quantity": $quantity, "callbackRate": $callbackRate})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType; callbackRate: 0.1 .. 5.0; closePosition: bool): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "callbackRate": $callbackRate, "closePosition": $closePosition})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType; quantity, price, stopPrice: float): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "quantity": $quantity, "price": $price, "stopPrice": $stopPrice})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType; quantity, price: float): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "quantity": $quantity, "price": $price, "timeInForce": "GTC"})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType; quantity: float): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "quantity": $quantity})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType; quantity, stopPrice: float): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "quantity": $quantity, "stopPrice": $stopPrice})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType; quantity, price, stopPrice, activationPrice: float): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "quantity": $quantity, "price": $price, "stopPrice": $stopPrice, "activationPrice": $activationPrice})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType; price: float): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe, "price": $price})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc postOrderFutures*(self: Binance; symbol: string; side: Side; tipe: OrderType): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "side": $side, "type": $tipe})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc getOrderFutures*(self: Binance; symbol: string; orderId: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "orderId": $orderId})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc getOrderFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc cancelOrderFutures*(self: Binance; symbol: string; orderId: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "orderId": $orderId})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc cancelOrderFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString"https://fapi.binance.com/fapi/v1/order"


proc cancelAllOrdersFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString"https://fapi.binance.com/fapi/v1/allOpenOrders"


proc autoCancelAllOrdersFutures*(self: Binance; symbol: string; countdownTime: Natural): string =
  ## Auto-Cancel All Open Orders with a countdown.
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "countdownTime": $countdownTime})
  self.signQueryString"https://fapi.binance.com/fapi/v1/countdownCancelAll"


proc getAllOpenOrdersFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString"https://fapi.binance.com/fapi/v1/openOrders"


proc getAllOrdersFutures*(self: Binance; symbol: string; startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "startTime": $startTime, "endTime": $endTime, "limit": "500"})
  self.signQueryString"https://fapi.binance.com/fapi/v1/allOrders"


proc getAllOrdersFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "limit": "500"})
  self.signQueryString"https://fapi.binance.com/fapi/v1/allOrders"


proc balanceFutures*(self: Binance): string =
  self.signQueryString"https://fapi.binance.com/fapi/v2/balance"


proc accountFutures*(self: Binance): string =
  self.signQueryString"https://fapi.binance.com/fapi/v2/account"


proc leverageFutures*(self: Binance; symbol: string; leverage: 1 .. 125): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "leverage": $leverage})
  self.signQueryString"https://fapi.binance.com/fapi/v1/leverage"


proc marginTypeFutures*(self: Binance; symbol: string; isolated: bool): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "marginType": if isolated: "ISOLATED" else: "CROSSED"})
  self.signQueryString"https://fapi.binance.com/fapi/v1/marginType"


proc positionRiskFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString"https://fapi.binance.com/fapi/v2/positionRisk"


proc userTradesFutures*(self: Binance; symbol: string; startTime, endTime: Positive): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "startTime": $startTime, "endTime": $endTime, "limit": "500"})
  self.signQueryString"https://fapi.binance.com/fapi/v1/userTrades"


proc userTradesFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "limit": "500"})
  self.signQueryString"https://fapi.binance.com/fapi/v1/userTrades"


proc incomeFutures*(self: Binance; symbol: string; startTime, endTime: Positive; incomeType: IncomeType): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "incomeType": $incomeType, "startTime": $startTime, "endTime": $endTime, "limit": "500"})
  self.signQueryString"https://fapi.binance.com/fapi/v1/income"


proc incomeFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "limit": "500"})
  self.signQueryString"https://fapi.binance.com/fapi/v1/income"


proc commissionRateFutures*(self: Binance; symbol: string): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol})
  self.signQueryString"https://fapi.binance.com/fapi/v1/commissionRate"


proc postLeverageFutures*(self: Binance; symbol: string; leverage: 1 .. 125): string =
  result = ""
  unrollEncodeQuery(result, {"symbol": symbol, "leverage": $leverage})
  self.signQueryString"https://fapi.binance.com/fapi/v1/leverage"


proc postPositionModeFutures*(self: Binance; hedgeMode: bool): string =
  result = ""
  unrollEncodeQuery(result, {"dualSidePosition": $hedgeMode})
  self.signQueryString"https://fapi.binance.com/fapi/v1/positionSide/dual"


proc postMultiAssetModeFutures*(self: Binance; multiAssetsMode: bool): string =
  result = ""
  unrollEncodeQuery(result, {"multiAssetsMargin": $multiAssetsMode})
  self.signQueryString"https://fapi.binance.com/fapi/v1/multiAssetsMargin"


proc postTransferFutures*(self: Binance; asset: string; amount: float; tipe: TransferType): string =
  result = ""
  unrollEncodeQuery(result, {"asset": asset, "amount": $amount, "type": $tipe})
  self.signQueryString"https://api.binance.com/sapi/v1/futures/transfer"


proc getBalanceFutures*(self: Binance; coin: string): float =
  ## Get user wallet Futures balance of 1 specific coin.
  for it in self.request(self.balanceFutures(), HttpGet):
    if it["asset"].getStr == coin: return it["balance"].getStr.parseFloat


# User data streams ###########################################################


proc userDataStream*(self: Binance): string {.inline.} =
  ## Start a new user data stream.
  ## * `POST` to Open a new user data stream.
  ## * `DELETE` to Delete an existing user data stream. Auto-closes at 60 minutes idle.
  ## * `GET` to Keep Alive an existing user data stream.
  result = "https://api.binance.com/api/v3/userDataStream"


# Generic endpoints ###########################################################


proc ping*(self: Binance): string {.inline.} =
  ## Test connectivity to Binance, just a ping.
  result = "https://api.binance.com/api/v3/ping"


proc time*(self: Binance): string {.inline.} =
  ## Get current Binance API server time.
  result = "https://api.binance.com/api/v3/time"


# Wallet endpoints ############################################################


proc getAllCapital*(self: Binance): string =
  self.signQueryString("https://api.binance.com/sapi/v1/capital/config/getall")


proc withDrawApply*(self: Binance, coin, address: string, amount: float, network: string): string =
  result = ""
  unrollEncodeQuery(result, {"coin": coin, "address": address, "amount": amount.formatFloat(ffDecimal, 8), "network": network})
  self.signQueryString("https://api.binance.com/sapi/v1/capital/withdraw/apply")


proc apiRestrictions*(self: Binance): string =
  self.signQueryString("https://api.binance.com/sapi/v1/account/apiRestrictions")


proc enableFastWithdraw*(self: Binance): string =
  self.signQueryString("https://api.binance.com/sapi/v1/account/enableFastWithdrawSwitch")


# Gift Cards endpoints ########################################################


proc createCode*(self: Binance; token: string; quantity: float): string =
  ## Create a new Gift Card via API.
  result = ""
  unrollEncodeQuery(result, {"token": token, "amount": quantity.formatFloat(ffDecimal, 8)})
  self.signQueryString("https://api.binance.com/sapi/v1/giftcard/createCode")


proc redeemCode*(self: Binance; code: string): string =
  ## If you enter the wrong `code` 5 times within 24 hours, you will no longer be able to redeem any Binance `code` for 1 day.
  result = ""
  unrollEncodeQuery(result, {"code": code})
  self.signQueryString("https://api.binance.com/sapi/v1/giftcard/redeemCode")


proc verify*(self: Binance; referenceNo: string): string =
  ## `referenceNo` is the number that `createCode` returns when successful, this is NOT the PIN code.
  result = ""
  unrollEncodeQuery(result, {"referenceNo": referenceNo})
  self.signQueryString("https://api.binance.com/sapi/v1/giftcard/verify")


# Misc utils ##################################################################


template getBnb*(self: Binance): float =
  ## Get BNB in user wallet, this is useful for Commisions.
  try: self.getWallet()["BNB"] except Exception: 0.0


template getBnbPrice*(self: Binance): string =
  ## BNB price in USDT, useful for commision calc.
  "https://api.binance.com/api/v3/ticker/price?symbol=BNBUSDT"


template donateToAddress*(self: Binance; address: string; amount = 0.0000095; coin = "BTC"): JsonNode =
  ## Donate to an specific `address`, using `"BSC"` network, using `"BTC"` as `coin` by default, the minimum `amount` possible of `0.0000095` by default.
  assert address.len > 1, "Please provide a valid address, BSC network."
  assert coin.len > 1, "Please provide a valid coin ticker."
  assert amount > 0.0, "Please provide a valid amount."
  self.request(self.withDrawApply(coin, address, amount, "BSC"), HttpPost)


proc ma50*(self: Binance; ticker: string): float =
  ## Calculate the current Medium Average 50 of the market.
  assert ticker.len > 0, "ticker must not be empty string"
  var sum: float
  let klines = self.getHistoricalKlines(ticker, KLINE_INTERVAL_15MINUTE, initDuration(hours = 15))[0]
  if klines.len == 60:
    for i in 10 ..< 60:
      sum = sum + klines[i][4].getStr.parseFloat
    result = sum / 50


proc getDynamicSleep*(self: Binance; symbolTicker: string; baseSleep: static[int] = 30_000): int =
  ## Get a "dynamic" sleep time integer for use with `sleep` and loops.
  ## * If more volatility then less sleep time, and viceversa.
  assert symbolTicker.len > 0, "symbolTicker must not be empty string"
  let temp = self.request(self.ticker24h(symbolTicker), HttpGet)["priceChangePercent"].getStr.parseFloat
  result = int(baseSleep / (if temp > 0.0: temp else: 1.0))
  if result > 120_000: result = 120_000


proc getProducts*(self: Binance): string {.inline.} =
  ## Undocumented API endpoint ?, no auth required ?.
  result = "https://www.binance.com/exchange-api/v2/public/asset-service/product/get-products"


proc getTopMarketCapPairs*(self: Binance; stablecoin = "USDT"; limit = 100.Positive): seq[tuple[marketCap: int, ticker: string]] =
  ## Get top market cap trading pairs, ordered from big to small, filtered by `stablecoin`, maximum of `limit`.
  ## * This needs to iterate all pairs sadly, because the API sends it unordered, >300 pairs for any `stablecoin`.
  assert stablecoin.len > 0, "stablecoin must not be empty string"
  let data: JsonNode = self.request(self.getProducts(), HttpGet)["data"]
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
  let temp = self.request(self.ticker24h(symbolTicker), HttpGet)
  result = (hi24h: temp["highPrice"].getStr.parseFloat, lo24h: temp["lowPrice"].getStr.parseFloat)


proc getAth*(self: Binance; ticker: string): float =
  ## Get ATH of a ticker.
  assert ticker.len > 0, "ticker must not be empty string"
  for it in self.getHistoricalKlines(ticker, KLINE_INTERVAL_1MONTH, initDuration(days = 365))[0]:
    let thisMonthPrice = it[2].getStr.parseFloat
    if thisMonthPrice > result: result = thisMonthPrice


template reversed*(this: Side): Side =
  if this == SIDE_SELL: SIDE_BUY else: SIDE_SELL


template truncate*(number: float): float =
  ## Truncate a float, this is a workaround, because `round` and `formatFloat` are fixed precision.
  var dotFound = false
  var s = newStringOfCap(8)
  for c in number.formatFloat(ffDecimal, 4):
    case c
    of '-': s.add '-'
    of '+': discard
    of '.':
      s.add '.'
      dotFound = true
    of '0' .. '9':
      if dotFound:
        if c == '0':
          s.add c
        else:
          s.add c
          break
      else: s.add c
    else: discard
  parseFloat(s)


runnableExamples"-d:ssl -d:nimDisableCertificateValidation -r:off":
  import std/[httpcore, json]
  let client: Binance = newBinance("YOUR_BINANCE_API_KEY", "YOUR_BINANCE_API_SECRET")
  let preparedEndpoint: string = client.ping()
  echo client.request(preparedEndpoint, HttpGet)
