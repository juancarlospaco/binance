import std/[strutils, uri, times]


type
  Binance* = object  ## Binance API Client.
    apiKey*, apiSecret*: string  ## Get API Key and API Secret at https://www.binance.com/en/my/settings/api-management

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


func newBinance*(apiKey, apiSecret: string): Binance {.inline.} =
  ## Constructor for Binance client.
  Binance(apiKey: apiKey, apiSecret: apiSecret)

template newDefaultHeaders(apiKey: static[string]): array[1, (string, string)] =
  ## Binance API requires a `X-MBX-APIKEY` header with the `apiKey` (Not the Secret).
  [("X-MBX-APIKEY", apiKey)]  # Es util esto ???.


proc sha256(queryString, apiSecret: string): string =
  # TODO:
  # Get code to do sha256 from somewhere?, preferably in pure Nim so it can compile to JS and C.
  # Needs SHA256, see  https://github.com/sammchardy/python-binance/blob/master/binance/client.py#L223
  #
  # Pseudocode:
  # result = sha256( API_SECRET + QUERY_STRING ).hexdigest()
  result = apiSecret  # Placeholder.

proc genTimestamp(): string =
  # TODO:
  # return current time UTC Timestamp in miliseconds as string.
  result = now().utc.format"ffffff"  # Chequear si esto es correcto ???, probablemente no.


func ping*(_: Binance): string =
  ## Test connectivity to Binance, just a ping.
  result = static(binanceAPIUrl & "/api/v3/ping")

proc time*(_: Binance): string =
  ## Get current Binance API server time.
  result = static(binanceAPIUrl & "/api/v3/time")

proc orderTest*(self: Binance; side: Side; tipe: OrderType; newOrderRespType: ResponseType;
    timeInForce, newClientOrderId, symbol: string;
    quantity, quoteOrderQty, price, stopPrice, icebergQty: float;
    recvWindow: 5_000..60_000 = 10_000): string =

  let queryString: string = encodeQuery({
    "symbol": symbol, "side": $side, "type": $tipe, "timeInForce": timeInForce, "quantity": $quantity,
    "quoteOrderQty": $quoteOrderQty, "price": $price, "stopPrice": $stopPrice, "icebergQty": $icebergQty,
    "recvWindow": $recvWindow, "newClientOrderId": newClientOrderId, "newOrderRespType": $newOrderRespType,
    "timestamp": genTimestamp()
  })
  let signature: string = sha256(queryString, self.apiSecret)

  result = static(binanceAPIUrl & "/api/v3/order/test")
  result.add queryString
  result.add encodeQuery({"signature": signature})


when isMainModule:
  import std/httpclient
  let client = newHttpClient()
  let binance = newBinance("", "")
  client.headers.add "X-MBX-APIKEY", binance.apiKey
  let preparedEndpoint = binance.ping()
  echo client.getContent(preparedEndpoint)




#[


API de Binance observaciones:

- Toda la API esta documentada aca https://binance.github.io/binance-api-swagger
- La API es todo JSON.
- BODY siempre va vacio.
- HEADER siempre requiere `X-MBX-APIKEY` con el API KEY, SIN el Secret.
- URL todo va encodeado como URL query params.
- URL requiere `signature` con el SHA256 de todo el query_string y la API SECRET.
- El `signature` va en el query_string al final.
- El `timestamp` es el tiempo en UTC en milisegundos.
- Usar la "Testnet" para pruebas y desarrollo.


TODO:

Hacer funciones que devuelvan la URL "preparada" para hacer una peticion,
asi funciona para cualquier backend, el usuario puede usar fetch de JS, o HttpClient de stdlib, o Harpoon, o Curl,
el usuario debera proveer la URL preparada, body vacio, http method GET o POST, header con `X-MBX-APIKEY`,
tambien es menos trabajo implementar el cliente si solamente retorna URLs.

La API de Binance es gigante, implementar primero los endpoints de "TRADE" ?
https://binance.github.io/binance-api-swagger/#/Trade

]#
