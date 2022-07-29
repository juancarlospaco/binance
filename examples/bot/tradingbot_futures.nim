## Crypto Trading Bot for Leveraged Perpetual Futures.
import std/[json, os, strutils, httpcore, times, math, random]
import dotenv, constants, loging
import binance


template cancelAllFutures() =
  ## Cancel all orders (but NOT open positions). {#000}
  sl[ti] = (price: 0.0, orderId: 0)
  order = client.cancelAllOrdersFutures(symbol = ticker)
  for _ in 0 .. 2:
    trade = client.request(order, HttpDelete)
    echo trade


proc main(config: JsonNode) =

  # Tickers for perpertual futures. {#f0f}
  const tickers = ["BTCUSDT", "ETHUSDT", "BNBUSDT", "YFIUSDT", "MKRUSDT", "BCHUSDT", "XMRUSDT", "ZECUSDT", "LTCUSDT", "EGLDUSDT"]

  # Read the configuration from file into variables. {#000}
  let
    startTime = now()
    walletBscProfits = config["wallet_address_bsc_to_send_profits"].getStr
    minLeverage:              1 .. 25     = config["min_leverage"].getInt
    doNotTradeBelow:         50 .. 500    = config["do_not_trade_coins_below_usd"].getInt
    trailingStopLossOffset: 1.0 .. 5.0    = config["trailing_stop_loss_offset_percent"].getInt.float
    marketEntryOffset:    0.015 .. 0.9999 = config["price_offset_for_market_entry_order"].getFloat
    usdQuantity:           55.0 .. 9999.9 = config["usd_quantity"].getInt.float
    maxBalanceUsdt:        99.9 .. 9999.9 = config["max_balance_usdt_to_keep"].getInt.float
    autoCancelTimeout:      Natural       = (config["auto_cancel_order_timeout_hours"].getInt * 1_000) * 60 * 60
    tradeCounts:            Positive      = config["trade_count_limit"].getInt
    client = newBinance(config["binance_api_key"].getStr, config["binance_api_secret"].getStr)
  var
    sl: array[tickers.len, tuple[price: float, orderId: int]]
    prevPrice: array[tickers.len, float]
    i, leverage, positions: int
    order: string
    trade: JsonNode
    logFile = open(getCurrentDir() / "tradingbot_futures_" & startTime.format("yyyy-MM-dd") & ".log", fmWrite, 4_096)

  ## Basic sanity checks for the config. {#000}
  let accountStatus = client.request(client.apiRestrictions(), HttpGet)
  doAssert accountStatus["enableSpotAndMarginTrading"].getBool, "Configure your Binance API Key with 'Spot and Margin trading' permissions enabled. https://www.binance.com/en/my/settings/api-management"
  doAssert accountStatus["enableFutures"].getBool, "Configure your Binance API Key with 'Futures' permissions enabled. https://www.binance.com/en/my/settings/api-management"
  doAssert accountStatus["enableWithdrawals"].getBool, "Configure your Binance API Key with 'Spot and Margin trading' and 'Withdraw' permissions enabled. https://www.binance.com/en/my/settings/api-management"

  # Force MultiAssets-Mode to OFF. {#000}
  order = client.postMultiAssetModeFutures(multiAssetsMode = false)
  trade = client.request(order, HttpPost)
  echo '#', '\t', order, '\n', trade

  # Force Hedge-Mode to OFF. {#000}
  order = client.postPositionModeFutures(hedgeMode = false)
  trade = client.request(order, HttpPost)
  echo '#', '\t', order, '\n', trade

  randomize()
  for ti, ticker in tickers:
    # Set Margin Type to "Isolated". {#000}
    order = client.marginTypeFutures(
      symbol   = ticker,
      isolated = true,
    )
    trade = client.request(order, HttpPost)  # {"code":200,"msg":"success"}
    echo '#', '\t', order, '\n', trade

    # Set position timeout, this auto-closes the position. {#000}
    if trade.hasKey"msg" and trade["msg"].getStr in ["success", "No need to change margin type."]:
      order = client.autoCancelAllOrdersFutures(
        symbol        = ticker,
        countdownTime = autoCancelTimeout,
      )
      trade = client.request(order, HttpPost)  # {"symbol":"LPTUSDT","countdownTime":"0"}
      echo '#', '\t', order, '\n', trade

      # Set Leverage for the position, can not be changed with open positions. {#000}
      if trade.hasKey"countdownTime":
        leverage = rand(minLeverage.int .. 25)  # >25 gets Liquidated.
        order = client.postLeverageFutures(symbol = ticker, leverage = leverage)
        trade = client.request(order, HttpPost)  # {"symbol":"LPTUSDT","leverage":9,"maxNotionalValue":"100000"}
        echo '#', '\t', order, '\n', trade

        # Init array of previous prices to a big float, so it is overwritten later. {#000}
        prevPrice[ti] = 999_999_999.9

  # Trading loop.
  while tradeCounts > i:
    # This iterates all trading pairs of tickers.
    for ti, ticker in tickers:
      let
        hasOpenOrders    = client.hasOpenOrdersFutures(ticker)
        hasOpenPositions = client.hasOpenPositionsFutures(ticker)

      if not hasOpenOrders and not hasOpenPositions:
        let baseAssetPrice = client.getPrice(ticker)
        if int(prevPrice[ti]) > int(baseAssetPrice):
          prevPrice[ti] = baseAssetPrice
          let
            baseAssetPriceAbove = (baseAssetPrice * (1.0 + marketEntryOffset)).int.float  # Long + TSL
            baseAssetPriceBelow = (baseAssetPrice * (1.0 - marketEntryOffset)).int.float  # SL
            baseAssetQuantity   = truncate(round(usdQuantity / baseAssetPrice, 3))  # {"code":-1111,"msg":"Precision is over the maximum defined for this asset."}
          echo '#', '\t', ticker, "\tlong=", baseAssetPriceAbove, "\tprice=", baseAssetPrice, "\tSL=", baseAssetPriceBelow

          # Stop-Market because Stop-Limit can not be placed too far from price.
          if int(baseAssetPrice) > doNotTradeBelow and baseAssetQuantity > 0.0:

            # Trailing Stop-Loss market-exit order, closes position. {#000}
            order = client.postOrderFutures(
              symbol          = ticker,
              quantity        = baseAssetQuantity,
              activationPrice = baseAssetPriceAbove,
              callbackRate    = trailingStopLossOffset,  # 2.0 ~ 3.0 ?
              tipe            = ORDER_TYPE_TRAILING_STOP_MARKET,
              side            = SIDE_SELL,
            ) # closePosition=true  does NOT work here.
            trade = client.request(order, HttpPost)
            echo '#', '\t', order, '\n', trade

            if trade.hasKey"orderId":
              # Fixed Stop-Loss market-exit order, closes position. {#000}
              order = client.postOrderFutures(
                closePosition = true,
                symbol        = ticker,
                stopPrice     = baseAssetPriceBelow,
                tipe          = ORDER_TYPE_STOP_MARKET,
                side          = SIDE_SELL,
              )
              trade = client.request(order, HttpPost)
              echo '#', '\t', order, '\n', trade

              if trade.hasKey"orderId":
                # Open position market-entry order at specific price. {#000}
                sl[ti] = (price: baseAssetPriceBelow, orderId: trade["orderId"].getInt)  # Remember SL.
                order = client.postOrderFutures(
                  symbol       = ticker,
                  quantity     = baseAssetQuantity,
                  stopPrice    = baseAssetPriceAbove,
                  tipe         = ORDER_TYPE_STOP_MARKET,
                  side         = SIDE_BUY,
                )
                trade = client.request(order, HttpPost)
                echo '#', '\t', order, '\n', trade

                if trade.hasKey"orderId":
                  ## Show information after a trade. {#000}
                  inc i
                  logfile.logs {
                    "coin"     : ticker,
                    "price"    : $int(baseAssetPrice),
                    "long"     : $int(baseAssetPriceAbove),
                    "sl"       : $int(sl[ti].price),
                    "tsl"      : $int(trailingStopLossOffset) & '%',
                    "lever"    : $leverage & 'x',
                    "size"     : $int(usdQuantity) & '$',
                    "orders"   : $i,
                    "positions": $positions,
                  }, "future"
                else: cancelAllFutures()
              else: cancelAllFutures()
            else: cancelAllFutures()

      if hasOpenOrders and hasOpenPositions:
        order = client.positionRiskFutures(symbol = ticker)
        trade = client.request(order, HttpGet)
        echo '#', '\t', order, '\n', trade

        # Get unRealizedProfit, if > 0, get markPrice, move SL up. {#000}
        if trade[0]["unRealizedProfit"].getStr != "0.00000000":
          let slPrice = float(int(trade[0]["markPrice"].getStr.parseFloat * 0.95))

          if int(slPrice) > int(sl[ti].price):
            # Fixed Stop-Loss market-exit order only moves up. {#000}
            order = client.postOrderFutures(
              closePosition = true,
              symbol        = ticker,
              stopPrice     = slPrice,
              tipe          = ORDER_TYPE_STOP_MARKET,
              side          = SIDE_SELL,
            )
            trade = client.request(order, HttpPost)
            echo '#', '\t', order, '\n', trade

            # Close old SL.
            if trade.hasKey"orderId":
              inc positions
              prevPrice[ti] = 999_999_999.9
              if sl[ti].orderId > 0:
                let newOrderId = trade["orderId"].getInt
                order = client.cancelOrderFutures(ticker, sl[ti].orderId)
                trade = client.request(order, HttpDelete)
                echo '#', '\t', order, '\n', trade
                sl[ti] = (price: slPrice, orderId: newOrderId)

      if hasOpenOrders and not hasOpenPositions:
        # Previous price is bigger than current price, orders are too high, cancel all orders to move them down. {#000}
        if int(prevPrice[ti]) > int(client.getPrice(ticker)):
          prevPrice[ti] = 999_999_999.9
          cancelAllFutures()

    if i > tickers.len and i mod tickers.len == 0:
      # Check for maximum balance in USDT to keep in Binance,
      # withdraw profits out of the exchange to user wallet if balance grew too much.
      # 10 USDT is the minimum allowed to withdraw via BSC.
      if client.getBalanceFutures("USDT") > maxBalanceUsdt + 10.0:
        # Move 10 USDT from Futures to Spot, because cant withdraw from Futures.
        order = client.postTransferFutures(
          asset  = "USDT",
          amount = 10.0,
          tipe   = TransferType.futuresToSpot,
        )
        trade = client.request(order, HttpPost)
        echo '#', '\t', order, '\n', trade

        if trade.hasKey"tranId":
          trade = client.donateToAddress(walletBscProfits, 10.0, "USDT")
          echo trade

  client.close()
  logFile.close()


when isMainModule:
  let pat = absolutePath(getCurrentDir() / "config_futures.ini")
  if not fileExists(pat):
    writeFile pat, configiniTemplateFutures
    quit(pat & " not found, wrote an empty blank template config_futures.ini please edit the config_futures.ini and restart.\n\n" &
      pat & " no encontrado, creado un nuevo template config_futures.ini vacio por favor editar el config_futures.ini y reiniciar.")
  main(pat.readFile.parseDotEnv)
