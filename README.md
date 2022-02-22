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
import std/httpcore, binance
let client = newBinance("YOUR_BINANCE_API_KEY", "YOUR_BINANCE_API_SECRET")
let preparedEndpoint = client.orderTest(SIDE_BUY, ORDER_TYPE_LIMIT, ORDER_RESP_TYPE_FULL, $TIME_IN_FORCE_GTC, "1", "BTCUSDT", 0.1, 10_000.00)
echo client.request(preparedEndpoint, HttpPost)
```


# Documentation

- https://juancarlospaco.github.io/binance


# TestNet Vs Prod

**BY DEFAULT IS USING REAL BINANCE API!.**

- TestNet (Fake Binance, for testing) ` -d:binanceAPIUrl="https://testnet.binance.vision" `.
- Production (Real Binance, for prod) ` -d:binanceAPIUrl="https://api.binance.com" `.


# More

- See also https://github.com/juancarlospaco/tradingview#tradingview


# Stars

![](https://starchart.cc/juancarlospaco/binance.svg)
:star: [@juancarlospaco](https://github.com/juancarlospaco '2022-02-15')	
:star: [@kennym](https://github.com/kennym '2022-02-16')	
:star: [@nickolaz](https://github.com/nickolaz '2022-02-18')	
:star: [@Nacho512](https://github.com/Nacho512 '2022-02-20')	
:star: [@Nacho512](https://github.com/Nacho512 '2022-02-20')	
