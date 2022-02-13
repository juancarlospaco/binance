from std/os import getEnv
import std/httpcore
import binance

let client = newBinance(getEnv"BINANCE_API_KEY", getEnv"BINANCE_API_SECRET")


#orderTest
var preparedEndpoint = client.orderTest(SIDE_BUY,ORDER_TYPE_LIMIT, ORDER_RESP_TYPE_FULL, $TIME_IN_FORCE_GTC, "1", "BTCUSDT", 0.1, 10_000.00)

echo "\nPOST -> /api/v3/order/test"
echo client.request(preparedEndpoint, HttpPost)


#postOrder -> api/v3/order POST
echo "\nPOST -> api/v3/order"
preparedEndpoint = client.postOrder(SIDE_BUY, ORDER_TYPE_LIMIT, $TIME_IN_FORCE_GTC, "BNBUSDT", 0.01, 100.00)
echo client.request(preparedEndpoint, HttpPost)


#getOrder -> api/v3/order GET
echo "\nGET -> api/v3/order"
preparedEndpoint = client.getOrder("BTCUSDT")
echo client.request(preparedEndpoint)


#GET -> api/v3/account
echo "\nGET -> api/v3/account"
preparedEndpoint = client.accountData()
echo client.request(preparedEndpoint)


#GET -> api/v3/myTrades
echo "\nGET -> api/v3/myTrades"
preparedEndpoint = client.myTrades("BTCUSDT")
echo client.request(preparedEndpoint)


#GET -> api/v3/rateLimit/order
echo "\nGET -> api/v3/rateLimit/order"
preparedEndpoint = client.rateLimitOrder()
echo client.request(preparedEndpoint)


#GET -> api/v3/allOrderList
echo "\nGET -> api/v3/allOrderList"
preparedEndpoint = client.allOrderList()
echo client.request(preparedEndpoint)


#GET -> api/v3/allOrderList
echo "\nGET -> api/v3/openOrderList"
preparedEndpoint = client.openOrderList()
echo client.request(preparedEndpoint)


#GET -> api/v3/orderList
echo "\nGET -> api/v3/orderList"
preparedEndpoint = client.orderList(1)
echo client.request(preparedEndpoint)
