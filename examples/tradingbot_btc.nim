## Crypto Trading Bot for BTC pairs, see https://www.binance.com/en/support/announcement/10435147c55d4a40b64fcbf43cb46329
import std/[os, json, strutils, httpcore, rdstdin]
import binance


proc main() =
  ## Binance does NOT charge commissions for BTC trading pairs so this is free money.
  # Other BTC pairs: "BTCAUD", "BTCBIDR", "BTCBRL", "BTCBUSD", "BTCEUR", "BTCGBP", "BTCRUB", "BTCTRY", "BTCTUSD", "BTCUAH", "BTCUSDC", "BTCUSDP".
  const ticker = "BTCUSDT"
  let
    client = newBinance(readLineFromStdin"Binance API Key?: ", readLineFromStdin"Binance API Secret?: ")
    usdQuantity = readLineFromStdin"USD quantity for position size? (integer >10): ".parseInt.float
    quantity = truncate(usdQuantity / client.getPrice(ticker))
  var lastOp: binance.Side

  while true:
    let
      price = client.getPrice(ticker)
      (hi24h, lo24h) = client.get24hHiLo(ticker)
    var
      order: string
      trade: JsonNode
    if hi24h.int > lo24h.int and (price.int >= hi24h.int or price.int <= lo24h.int):
      let side = if price >= hi24h: SIDE_SELL else: SIDE_BUY
      if lastOp == side: continue  # Swing trade.
      order = client.postOrder(
        symbol   = ticker,
        quantity = quantity,
        side     = side,
        tipe     = ORDER_TYPE_MARKET,
      )
      trade = client.request(order, HttpPost)
      echo '#', order, '\n', trade

      if trade.hasKey"fills":
        lastOp = side  # Remember last trade operation side.
        doAssert parseFloat(trade["fills"][0]["commission"].getStr) == 0.0, "Commission is not zero."
        echo(
          "ticker=", ticker,
          ",side=" , side,
          ",price=", price,
          ",size=" , int(usdQuantity),
        )
    else:
      echo ticker, '\t', price
      sleep 60_000  # Sleep for 1 minute.
  client.close()


when isMainModule:
  main()
