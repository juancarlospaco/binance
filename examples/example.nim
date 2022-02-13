import binance

let client = newBinance(env("API_KEY"), env("SECURE_KEY"))

#ordertTest
var preparedEndpoint = client.orderTest(SIDE_BUY,ORDER_TYPE_LIMIT, ORDER_RESP_TYPE_FULL, $TIME_IN_FORCE_GTC, "-1", "BTCUSDT", 0.1, 10_000.00)

echo client.request(preparedEndpoint,"POST")

#postOrder -> api/v3/order POST
preparedEndpoint = client.postOrder(SIDE_BUY, ORDER_TYPE_LIMIT, $TIME_IN_FORCE_GTC, "BNBUSDT", 0.01, 200.00)

#POST
echo client.request(preparedEndpoint, "POST")

#getOrder -> api/v3/order GET
preparedEndpoint = client.getOrder("BTCUSDT")
echo client.request(preparedEndpoint)

#GET -> api/v3/account
preparedEndpoint = client.accountData()
echo client.request(preparedEndpoint)

#GET -> api/v3/myTrades
preparedEndpoint = client.myTrades("BTCUSDT")
echo client.request(preparedEndpoint)

