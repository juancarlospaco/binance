## TradingBot that buys new coins listed on Binance, as soon as they are available, at a cheap price, and sell them when they are pumped up in price.
import std/[os, json, strutils, httpcore, math], binance


proc main() =

  let
    client = newBinance(getEnv"BINANCE_API_KEY", getEnv"BINANCE_API_SECRET")
    exchangeData = parseJson(client.exchangeInfo(fromMemory = true))["symbols"]

  var
    i = 0
    currentCryptos: JsonNode
    currentLen, newCoin: int
    amount, priceToBuy: float
    symbolToBuy, symbol: string
    message = newStringOfCap(6)
    prevCryptos = parseJson(client.request(client.tickerPrice()))
    prevLen = prevCryptos.len

  while on:
    currentCryptos = parseJson(client.request(client.tickerPrice()))
    currentLen = currentCryptos.len
    message.addInt prevLen
    echo message
    message.setLen 0

    if prevLen < currentLen:
      newCoin = prevLen
      echo currentCryptos[newCoin]
      break
    else:
      sleep 10_000

  for indx in newCoin ..< currentLen:
    symbol = currentCryptos[indx]["symbol"].getStr

    for asset in exchangeData:
      if asset["symbol"].getStr == symbol:
        symbolToBuy = asset["quoteAsset"].getStr
        break

    priceToBuy = currentCryptos[i]["price"].getStr.parseFloat
    checkFloat priceToBuy

    case symbolToBuy
    of "BTC" : amount = 0.0013
    of "ETH" : amount = 0.03
    of "USDT": amount = 15.0
    of "BUSD": amount = 15.0
    of "BNB" : amount = 0.7
    else: echo "symbolToBuy not in 'BTC', 'ETH', 'USDT', 'BUSD', 'BNB'."

    if amount == 0.0: continue
    elif amount > 0.0:
      inc i
      echo client.request(client.postOrder(
        symbol   = symbol,
        side     = SIDE_BUY,
        quantity = client.truncate(amount / priceToBuy, 3),
        price    = client.truncate(priceToBuy, 3),
        tipe     = ORDER_TYPE_LIMIT,
      ), HttpPost)

      echo client.request(client.newOrderOco(
        symbol               = symbol,
        side                 = SIDE_SELL,
        quantity             = client.truncate(amount / priceToBuy, 3),
        price                = client.truncate(priceToBuy * 1.020, 3),
        stopPrice            = client.truncate(priceToBuy * 0.995, 3),
        stopLimitPrice       = client.truncate(priceToBuy * 0.994, 3),
        stopLimitTimeInForce = $TIME_IN_FORCE_GTC
      ), HttpPost)
    sleep 10_000
  client.close()


when isMainModule:
  main()
