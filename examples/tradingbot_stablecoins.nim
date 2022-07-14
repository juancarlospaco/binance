## Crypto Trading Bot for Stablecoin pairs, see https://youtu.be/Ve687Pvzplk
import std/[os, json, strutils, httpcore, rdstdin]
import binance


proc main() =
  ## Binance does NOT charge commissions for stablecoins trading pairs so this is free money.
  const ticker = "BUSDUSDT"  # Other stablecoin pairs: "TUSDUSDT", "USDPUSDT", "USDCUSDT", "BUSDUSDT", "TUSDBUSD", "USDPBUSD", "USDCBUSD"
  let
    client      = newBinance(readLineFromStdin"Binance API Key?: ", readLineFromStdin"Binance API Secret?: ")
    usdQuantity = readLineFromStdin"USD quantity for position size? (integer >10): ".parseInt.float
  var lastOp: binance.Side

  while true:
    let
      price = client.getPrice(ticker)
      (hi24h, lo24h) = client.get24hHiLo(ticker)
    var
      order: string
      trade: JsonNode
    if (hi24h > 1.0 and lo24h < 1.0) and (price >= hi24h or price <= lo24h):
      let side = if price >= hi24h: SIDE_SELL else: SIDE_BUY
      if lastOp == side: continue  # Swing trade.
      order = client.postOrder(
        symbol   = ticker,
        quantity = usdQuantity,
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
      sleep 300_000  # Sleep for 5 minutes.
  client.close()


when isMainModule:
  main()
