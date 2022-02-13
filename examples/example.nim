import binance

let client = newBinance(env("API_KEY"), env("SECURE_KEY"))

#orderTest
var preparedEndpoint = client.orderTest(SIDE_BUY,ORDER_TYPE_LIMIT, ORDER_RESP_TYPE_FULL, $TIME_IN_FORCE_GTC, "1", "BTCUSDT", 0.1, 10_000.00)

echo "POST -> /api/v3/order/test"
echo client.request(preparedEndpoint,"POST") & "\n"

#postOrder -> api/v3/order POST
echo "POST -> api/v3/order"
preparedEndpoint = client.postOrder(SIDE_BUY, ORDER_TYPE_LIMIT, $TIME_IN_FORCE_GTC, "BNBUSDT", 0.01, 100.00)
echo client.request(preparedEndpoint, "POST") & "\n"

#getOrder -> api/v3/order GET
echo "GET -> api/v3/order"
preparedEndpoint = client.getOrder("BTCUSDT")
echo client.request(preparedEndpoint) & "\n"

#GET -> api/v3/account
echo "GET -> api/v3/account"
preparedEndpoint = client.accountData()
echo client.request(preparedEndpoint) & "\n"

#GET -> api/v3/myTrades
echo "GET -> api/v3/myTrades"
preparedEndpoint = client.myTrades("BTCUSDT")
echo client.request(preparedEndpoint) & "\n"

#GET -> api/v3/rateLimit/order
echo "GET -> api/v3/rateLimit/order"
preparedEndpoint = client.rateLimitOrder()
echo client.request(preparedEndpoint) & "\n"


#GET -> api/v3/allOrderList
echo "GET -> api/v3/allOrderList"
preparedEndpoint = client.allOrderList()
echo client.request(preparedEndpoint) & "\n"


#GET -> api/v3/allOrderList
echo "GET -> api/v3/openOrderList"
preparedEndpoint = client.openOrderList()
echo client.request(preparedEndpoint) & "\n"

#GET -> api/v3/orderList
echo "GET -> api/v3/orderList"
preparedEndpoint = client.orderList(1)
echo client.request(preparedEndpoint) & "\n"
