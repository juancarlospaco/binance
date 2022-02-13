# Binance

![](binance.jpg)

![](https://github.com/juancarlospaco/binance/actions/workflows/build.yml/badge.svg)
![](https://img.shields.io/github/languages/top/juancarlospaco/binance?style=for-the-badge)
![](https://img.shields.io/github/stars/juancarlospaco/binance?style=for-the-badge)
![](https://img.shields.io/github/languages/code-size/juancarlospaco/binance?style=for-the-badge)
![](https://img.shields.io/github/issues-raw/juancarlospaco/binance?style=for-the-badge)
![](https://img.shields.io/github/issues-pr-raw/juancarlospaco/binance?style=for-the-badge)
![](https://img.shields.io/github/last-commit/juancarlospaco/binance?style=for-the-badge)


# Requisites

- Valid API Key and API Secret, get it for free at https://www.binance.com/en/my/settings/api-management
- Device Date and Time must be configured, up to the seconds precision, Binance is strict about Timestamps.


# Examples

```nim
import binance
let client = newBinance(getEnv"BINANCE_API_KEY", getEnv"BINANCE_API_SECRET")
let preparedEndpoint = client.orderTest(SIDE_BUY, ORDER_TYPE_LIMIT, ORDER_RESP_TYPE_FULL, $TIME_IN_FORCE_GTC, "1", "BTCUSDT", 0.1, 10_000.00)
echo client.request(preparedEndpoint, HttpPost)
```


# Stars

![](https://starchart.cc/juancarlospaco/binance.svg)


# TestNet Vs Prod

- TestNet (Fake Binance, for testing) ` -d:binanceAPIUrl="https://testnet.binance.vision" `.
- Production (Real Binance, for prod) ` -d:binanceAPIUrl="https://api.binance.com" `.


# More

- See also https://github.com/juancarlospaco/tradingview#tradingview
