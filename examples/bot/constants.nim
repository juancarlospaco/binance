const configiniTemplateFutures* = """
# IMPORTANT RECOMMENDATIONS:
# If the market is too parallel, just dont do Futures at all, not by bot nor manually.
# Monitor the bot status and profits at least once a month or once a week approx.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# RECOMENDACIONES IMPORTANTES:
# Si el mercado esta demasiado paralelo, no hagas Futuros, no via bot ni manualmente.
# Monitorea el estado y las ganancias del bot por lo menos una vez al mes o una vez a la semana aproximadamente.
#
# Strategy:
# Bot finds lowest possible price to place a 25x Long with SL and TSL,
# if price goes down whole grid goes down, if price goes up SL and TSL goes up.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Bot encontrara el precio mas bajo posible para colocar un 25x Long con SL y TSL,
# si el precio baja todo el grid baja, si el precio sube SL y TSL suben.
#
# Trading pairs are:
# "BTCUSDT" , "ETHUSDT", "BNBUSDT" , "YFIUSDT" , "MKRUSDT" ,
# "BCHUSDT" , "XMRUSDT", "ZECUSDT" , "LTCUSDT" , "EGLDUSDT".
#
# You must have in Binance USD-M Futures Wallet:
# NO Leverage, >100 USDT minimum.
# Leveraged, >1000 USDT minimum, >10000 USDT recommended.
# >1 USD in BNB for Commisions.
# these minimum limits are fixed by Binance, not by the bot itself,
# bot may fail to trade if the stablecoins balance is not bigger than the lower limits.
# The bot will trade in all pairs in a loop to try to profit as much as possible.
# The bot may open leveraged positions in 10 trading pairs, up to 50 orders, having >100000 USDT free is recommended.
# On start the bot will force MultiAsset-Mode to OFF, Margin-Mode to Isolated, Hedge-Mode to OFF.
# Try to keep the bot working as much as possible, so it can "learn" about the market.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Los pares de Trading son:
# "BTCUSDT" , "ETHUSDT", "BNBUSDT" , "YFIUSDT" , "MKRUSDT" ,
# "BCHUSDT" , "XMRUSDT", "ZECUSDT" , "LTCUSDT" , "EGLDUSDT".
#
# Debes tener en Binance USD-M Futuros Wallet:
# SIN Apalancamiento, >100 USDT minimo.
# Apalancado, >1000 USDT minimo, >10000 USDT recomendado.
# >1 USD en BNB para Comisiones.
# Estos limites minimos los fija Binance, no el propio bot,
# bot puede fallar el Trade si el saldo de monedas estables no es mayor que los limites inferiores.
# El bot intercambiara todos los pares de monedas en bucle para intentar obtener el mayor beneficio posible.
# El bot puede abrir posiciones apalancadas en 10 pares de trading, hasta 50 ordenes, tener >100000 USDT libres es recomendado.
# Al inicio el bot forzara MultiAsset-Mode a OFF, Margin-Mode a Isolated, Hedge-Mode a ON.
# Trate de mantener el bot funcionando el mayor tiempo posible, para que pueda "aprender" sobre el mercado.
# https://www.binance.com/en/my/settings/api-management
binance_api_key    = 1CESnDgOsANx6hDvT9KmX85C0DwtSaendYbcWh6pWYZYB3df5aUnubWsSaa0pJAC  # string
binance_api_secret = COPYPASTE_YOUR_BINANCE_SECRET_API_KEY_HERE                        # string


# Position size in USDT, more quantity more profits.
# Minimum must be >50 USD, >100 USD is Ok, recommended >1000 USD.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Cantidad de la Posicion en USDT, cuanta mas cantidad mas ganancias.
# El minimo debe ser >50 USD, >100 USD esta bien, recomendado >1000 USD.
usd_quantity = 55                            # int


# Minimum leverage for trading, maximum leverage is fixed to 25x, 25 is the maximum allowed by the strategy.
# You must keep a big amount of USDT in Binance USD-M Futures Wallet to avoid getting Liquidated.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Apalancamiento minimo para trading, apalancamiento maximo esta fijado en 25x, 25 es el maximo para la estrategia.
# Debes mantener un monton de USDT en Binance USD-M Futures Wallet para evitar ser Liquidado.
min_leverage = 15                            # int


# Offset from the current market price for the market-entry limit order,
# bigger float means far from the current market price,
# smaller float means close from the current market price,
# if float is too big, then will be placed too far, then positions may never open,
# if float is too small, then will be placed too close, then positions may close by Stop-Loss.
# must be a positive float greater than 0.001 and smaller than 0.999.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Offset desde el precio de mercado actual para la order de entrada de mercado limit,
# float grandes significa lejos del precio actual de mercado,
# float chico significa cerca del precio actual de mercado,
# si el flotante es muy grande, entonces sera colocado muy lejos, entonces las posiciones nunca se abriran,
# si el flotante es muy chico, entonces sera colocado muy cerca, entonces las posiciones se cerraran por Stop-Loss.
# debe ser un flotante positivo mayor que 0.001 y menor que 0.999.
price_offset_for_market_entry_order = 0.015  # float


# Do NOT open positions for coins below this current price in USD.
# This prevents "glitchy" Liquidation prices near zero.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# NO abrir posiciones para coins por debajo de este precio en USD.
# Esto previene precios de Liquidacion "raros" cerca del cero.
do_not_trade_coins_below_usd = 55            # int


# Trailing Stop-Loss offset in percentage of the price,
# this controls how far the Stop-Loss chases the current price.
# Minimum value is 1, maximum value is 5, most used values are 3 and 5.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Offset en porcentage del precio del Trailing Stop-Loss,
# esto controla cuan lejos el Stop-Loss persigue al precio actual.
# Valor minimo es 1, valor maximo es 5, valores mas usados son 3 y 5.
trailing_stop_loss_offset_percent = 3        # int


# Auto-Cancel all open positions and cancel all orders after timeout hours.
# 0 is Disabled. 0 is Default. Use 0 if you dont known whats it means.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Auto-Cancela posiciones abiertas y cancela todas las ordenes abiertas luego de horas de timeout.
# 0 es Desabilitado. 0 es valor por defecto. Usa 0 si no sabes que significa.
auto_cancel_order_timeout_hours = 0          # int


# Maximum balance in USDT to keep in Futures wallet on Binance,
# if the balance exceeds this value, then 10 USDT will be withdraw to wallet_address_bsc_to_send_profits,
# withdraws profits out of the exchange to a cold wallet address of BSC network.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Maximo balance en USDT para mantener en Futures wallet en Binance,
# si el balance excede este valor, 10 USDT seran transferidos a wallet_address_bsc_to_send_profits,
# transfiere ganancias fuera del exchange hacia una cold wallet address de la red BSC.
max_balance_usdt_to_keep = 100                                                   # int
wallet_address_bsc_to_send_profits = 0xb78c4cf63274bb22f83481986157d234105ac17e  # string


# Maximum trade count to perform in total in a single run, then quit.
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Numero maximo de trades a realizar en total en una sola ejecucion, luego de eso, salir.
trade_count_limit = 9999999                  # int


# Please send crypto today to speed up development and improve the bot to make more profits!:
#
# Bitcoin BTC     BEP20 BSC      0xb78c4cf63274bb22f83481986157d234105ac17e
# Bitcoin BTC     BTC Network    1Pnf45MgGgY32X4KDNJbutnpx96E4FxqVi
#
# Tether USDT     BEP20 BSC      0xb78c4cf63274bb22f83481986157d234105ac17e
# Tether USDT     TRC20 Tron     TWGft53WgWvH2mnqR8ZUXq1GD8M4gZ4Yfu
#
# ETH/DAI/USDC    BEP20 BSC      0xb78c4cf63274bb22f83481986157d234105ac17e
# ETH/DAI/USDC    ERC20          0xb78c4cf63274bb22f83481986157d234105ac17e
"""
