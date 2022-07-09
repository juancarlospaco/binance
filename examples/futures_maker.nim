import std/[json, strutils, httpcore, math, rdstdin]
import binance


template cancelAllFutures() =
  order = client.cancelAllOrdersFutures(symbol = ticker)
  trade = client.request(order, HttpDelete)
  echo '#', order, '\n', trade


proc main() =
  let client = newBinance(readLineFromStdin"Binance API Key?: ", readLineFromStdin"Binance API Secret?: ")
  var
    order: string
    trade: JsonNode
    side:  binance.Side
  while true:
    case readLineFromStdin"Long or Short? (l for Long, s for Short, c for Cancel, other for Quit): "
    of "l", "L": side = SIDE_BUY
    of "s", "S": side = SIDE_SELL
    of "c", "C":
      let ticker = readLineFromStdin"Ticker? (BTCUSDT): ".toUpperAscii
      cancelAllFutures()
    else: break # quit"bye"
    let
      ticker             = readLineFromStdin"Ticker? (BTCUSDT): ".toUpperAscii
      usdQuantity        = readLineFromStdin"USD quantity for position size? (integer >10): ".parseInt.float
      leverage: 1 .. 125 = readLineFromStdin"Leverage? (integer 1-125): ".parseInt
      stopLossPrice      = readLineFromStdin"Stop-Loss market-exit close position price? (integer): ".parseInt.float
      trailingStopLossOffset = readLineFromStdin"Trailing Stop-Loss offset percentage? (integer 1-5): ".parseInt.float
      baseAssetPrice     = client.getPrice(ticker)
      baseAssetQuantity  = truncate(round(usdQuantity / baseAssetPrice, 3))

    order = client.postLeverageFutures(symbol = ticker, leverage = leverage)
    trade = client.request(order, HttpPost)
    echo '#', order, '\n', trade

    if trade.hasKey"leverage":
      # Trailing Stop-Loss market-exit order, closes position. {#000}
      order = client.postOrderFutures(
        symbol       = ticker,
        quantity     = baseAssetQuantity,
        callbackRate = trailingStopLossOffset,
        tipe         = ORDER_TYPE_TRAILING_STOP_MARKET,
        side         = side,
      )
      trade = client.request(order, HttpPost)
      echo '#', order, '\n', trade

      if trade.hasKey"orderId":
        # Fixed Stop-Loss market-exit order, closes position. {#000}
        order = client.postOrderFutures(
          closePosition = true,
          symbol        = ticker,
          stopPrice     = stopLossPrice,
          tipe          = ORDER_TYPE_STOP_MARKET,
          side          = side,
        )
        trade = client.request(order, HttpPost)
        echo '#', order, '\n', trade

        if trade.hasKey"orderId":
          # Open position market-entry order at specific price. {#000}
          order = client.postOrderFutures(
            symbol   = ticker,
            quantity = baseAssetQuantity,
            tipe     = ORDER_TYPE_MARKET,
            side     = side,
          )
          trade = client.request(order, HttpPost)
          echo '#', order, '\n', trade

          if trade.hasKey"orderId":
            order = client.positionRiskFutures(symbol = ticker)
            trade = client.request(order, HttpGet)
            echo '#', order, '\n', trade

            if trade.len == 1 and trade[0]["liquidationPrice"].getStr != "0":
              let
                liquidationPrice = round(trade[0]["liquidationPrice"].getStr.parseFloat, 1)
                sl_liq1 = round(liquidationPrice * (1.0 + 0.01), 1)
                sl_liq2 = round(liquidationPrice * (1.0 - 0.01), 1)

              # Fixed Stop-Loss market-exit order at Liquidation price and above and below Liquidation price. {#000}
              if int(sl_liq1) > 0 and int(liquidationPrice) > 0 and int(sl_liq2) > 0:
                for precio in [sl_liq1, liquidationPrice, sl_liq2]:
                  order = client.postOrderFutures(
                    closePosition = true,
                    symbol        = ticker,
                    stopPrice     = precio,
                    tipe          = ORDER_TYPE_STOP_MARKET,
                    side          = if side == SIDE_SELL: SIDE_BUY else: SIDE_SELL,
                  )
                  trade = client.request(order, HttpPost)
                  echo '#', order, '\n', trade

                if trade.hasKey"orderId":
                  echo(
                    "ticker=" , ticker,
                    ",side="  , if side == SIDE_BUY: "long" else: "short",
                    ",entry=" , int(baseAssetPrice),
                    ",SL="    , int(stopLossPrice),
                    ",TSL="   , $int(trailingStopLossOffset) & '%',
                    ",lever=" , $leverage & 'x',
                    ",size="  , $int(usdQuantity) & '$',
                    ",liquid=", int(liquidationPrice),
                    ",amount=", baseAssetQuantity,
                  )
                else: cancelAllFutures()
              else: cancelAllFutures()
            else: cancelAllFutures()
          else: cancelAllFutures()
        else: cancelAllFutures()
      else: cancelAllFutures()
    else: cancelAllFutures()
  client.close()


when isMainModule:
  main()
