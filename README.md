# Binance

![](https://raw.githubusercontent.com/juancarlospaco/binance/nim/binance.jpg)

![](https://raw.githubusercontent.com/juancarlospaco/binance/nim/futures.png "Leveraged Perpetual Futures")


![](https://github.com/juancarlospaco/binance/actions/workflows/build.yml/badge.svg)
![](https://img.shields.io/github/languages/top/juancarlospaco/binance?style=for-the-badge)
![](https://img.shields.io/github/stars/juancarlospaco/binance?style=for-the-badge)
![](https://img.shields.io/github/languages/code-size/juancarlospaco/binance?style=for-the-badge)
![](https://img.shields.io/github/issues-raw/juancarlospaco/binance?style=for-the-badge)
![](https://img.shields.io/github/issues-pr-raw/juancarlospaco/binance?style=for-the-badge)
![](https://img.shields.io/github/last-commit/juancarlospaco/binance?style=for-the-badge)


# Requisites

- Valid API Key and API Secret, with all permissions, get it for free at https://www.binance.com/en/my/settings/api-management

![](https://raw.githubusercontent.com/juancarlospaco/binance/nim/api_key_web.png)

- Device Date and Time must be configured, up to the seconds precision, Binance is strict about timestamps,
  use https://github.com/juancarlospaco/binance/blob/nim/examples/binanceVslocalTime.nim to debug time diff.
  In Windows, if you get `400 Bad Request`, check the time, Windows like to change the time without warning after updates,
  set the correct time, up to the seconds precision, and disable Windows auto-update of time from the Windows settings.

- Some USDT in Binance Spot wallet to trade with, >10 USDT minimal, >100 USDT recommended.
- Some BNB coins in Binance Spot wallet for commisions, >1 USD in BNB minimal, >10 USD in BNB recommended.
- Some USDT in Binance Futures USD-M wallet to trade with, >100 USDT minimal, >1000 USDT recommended, for NO Leverage (1x).
- Some USDT in Binance Futures USD-M wallet to trade with, >1000 USDT minimal, >10000 USDT recommended, for Leverage (125x).
- Some BNB coins in Binance Spot wallet for commisions, >1 USD in BNB minimal, >10 USD in BNB recommended.


# Examples

```nim
import std/httpcore, binance
let client = newBinance("YOUR_BINANCE_API_KEY", "YOUR_BINANCE_API_SECRET")
let preparedEndpoint = client.orderTest(SIDE_BUY, ORDER_TYPE_LIMIT, ORDER_RESP_TYPE_FULL, $TIME_IN_FORCE_GTC, "1", "BTCUSDT", 0.1, 10_000.00)
echo client.request(preparedEndpoint, HttpPost)
```


# Documentation

- https://juancarlospaco.github.io/binance
- By default is using the real production Binance API.
- Spot API (including OCO Orders) and Futures API (including 125x Leveraged Perpetual Futures) are supported.
- Automatic Trailing Stop-Loss is supported.
- Automatic Cancelation of Futures is supported.


# TradingBot

- How to create a TradingBot ?.

TradingBot example: https://github.com/juancarlospaco/binance/blob/nim/examples/newcoin.nim

Gift-Card Bot example: https://github.com/juancarlospaco/binance/blob/nim/examples/giftcardbot.nim

Leveraged Perpetual Futures with Stop-Loss and Trailing Stop-Loss example:
https://github.com/juancarlospaco/binance/blob/nim/examples/futures_maker.nim


# More

- See also https://github.com/juancarlospaco/tradingview#tradingview
- See also https://github.com/juancarlospaco/cloudbet#cloudbet


# 💰➡️🍕

<details>
<summary title="Send Bitcoin"><kbd> Bitcoin BTC </kbd></summary>

**BEP20 Binance Smart Chain Network BSC**
```
0xb78c4cf63274bb22f83481986157d234105ac17e
```
**BTC Bitcoin Network**
```
1Pnf45MgGgY32X4KDNJbutnpx96E4FxqVi
```
**Lightning Network**
```
juancarlospaco@bitrefill.me
```
</details>

<details>
<summary title="Send Ethereum and DAI"><kbd> Ethereum ETH </kbd> <kbd> Dai DAI </kbd> <kbd> Uniswap UNI </kbd> <kbd> Axie Infinity AXS </kbd> <kbd> Smooth Love Potion SLP </kbd> <kbd> Uniswap UNI </kbd> <kbd> USDC </kbd> </summary>

**BEP20 Binance Smart Chain Network BSC**
```
0xb78c4cf63274bb22f83481986157d234105ac17e
```
**ERC20 Ethereum Network**
```
0xb78c4cf63274bb22f83481986157d234105ac17e
```
</details>
<details>
<summary title="Send Tether"><kbd> Tether USDT </kbd></summary>

**BEP20 Binance Smart Chain Network BSC**
```
0xb78c4cf63274bb22f83481986157d234105ac17e
```
**ERC20 Ethereum Network**
```
0xb78c4cf63274bb22f83481986157d234105ac17e
```
**TRC20 Tron Network**
```
TWGft53WgWvH2mnqR8ZUXq1GD8M4gZ4Yfu
```
</details>
<details>
<summary title="Send Solana"><kbd> Solana SOL </kbd></summary>

**BEP20 Binance Smart Chain Network BSC**
```
0xb78c4cf63274bb22f83481986157d234105ac17e
```
**SOL Solana Network**
```
FKaPSd8kTUpH7Q76d77toy1jjPGpZSxR4xbhQHyCMSGq
```
</details>
<details>
<summary title="Send Cardano"><kbd> Cardano ADA </kbd></summary>

**BEP20 Binance Smart Chain Network BSC**
```
0xb78c4cf63274bb22f83481986157d234105ac17e
```
**ADA Cardano Network**
```
DdzFFzCqrht9Y1r4Yx7ouqG9yJNWeXFt69xavLdaeXdu4cQi2yXgNWagzh52o9k9YRh3ussHnBnDrg7v7W2hSXWXfBhbo2ooUKRFMieM
```
</details>
<details>
<summary title="Send Sandbox"><kbd> Sandbox SAND </kbd> <kbd> Decentraland MANA </kbd></summary>

**ERC20 Ethereum Network**
```
0xb78c4cf63274bb22f83481986157d234105ac17e
```
</details>
<details>
<summary title="Send Algorand"><kbd> Algorand ALGO </kbd></summary>

**ALGO Algorand Network**
```
WM54DHVZQIQDVTHMPOH6FEZ4U2AU3OBPGAFTHSCYWMFE7ETKCUUOYAW24Q
```
</details>
<details>
<summary title="Send Polkadot"><kbd> Polkadot DOT </kbd></summary>

**DOT Network**
```
13GdxHQbQA1K6i7Ctf781nQkhQhoVhGgUnrjn9EvcJnYWCEd
```
**BEP20 Binance Smart Chain Network BSC**
```
0xb78c4cf63274bb22f83481986157d234105ac17e
```
</details>
<details>
<summary title="Send via Binance Pay"> Binance </summary>

[https://pay.binance.com/en/checkout/e92e536210fd4f62b426ea7ee65b49c3](https://pay.binance.com/en/checkout/e92e536210fd4f62b426ea7ee65b49c3 "Send via Binance Pay")
</details>


# Stars

![](https://starchart.cc/juancarlospaco/binance.svg)
:star: [@juancarlospaco](https://github.com/juancarlospaco '2022-02-15')
:star: [@kennym](https://github.com/kennym '2022-02-16')
:star: [@nickolaz](https://github.com/nickolaz '2022-02-18')
:star: [@Nacho512](https://github.com/Nacho512 '2022-02-20')
:star: [@hannylicious](https://github.com/hannylicious '2022-03-02')
:star: [@Walter-Santillan](https://github.com/Walter-Santillan '2022-03-21')
:star: [@kamilchm](https://github.com/kamilchm '2022-03-23')
:star: [@Parzivalcen](https://github.com/Parzivalcen '2022-04-06')
:star: [@hugosenari](https://github.com/hugosenari '2022-05-28')
:star: [@RodrigoTorresWeb](https://github.com/RodrigoTorresWeb '2022-06-25')
