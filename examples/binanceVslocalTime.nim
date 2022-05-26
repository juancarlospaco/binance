## Show time diff between Binance and your PC, Binance is strict about Timestamps this helps debugging.
import std/[times, os, json, httpcore], binance


var
  message = newStringOfCap(150)
  localTime, serverTime, diff: int64
let client = newBinance(getEnv"BINANCE_API_KEY", getEnv"BINANCE_API_SECRET")


for i in 0 .. 9:
  # localTime = now().utc.toTime.toUnix * 1_000
  localTime = fromUnixFloat(epochTime() * 1_000).toUnix
  serverTime = client.request(client.time(), HttpGet)["serverTime"].getBiggestInt
  diff = serverTime - localTime
  message.add "{\"binance\": "
  message.addInt serverTime
  message.add ",\t\"local1\": "
  message.addInt localTime
  localTime =  fromUnixFloat(epochTime() * 1_000).toUnix
  message.add ",\t\"local2\": "
  message.addInt localTime
  message.add ",\t\"diff1\": "
  message.addInt diff
  message.add ",\t\"diff2\": "
  message.addInt localTime - serverTime
  message.add '}'
  echo message
  message.setLen 0
  sleep 3_000
