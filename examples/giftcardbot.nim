import std/[json, os, httpcore, rdstdin, strutils], binance


proc main() =
  let
    client: Binance = newBinance(getEnv"BINANCE_API_KEY", getEnv"BINANCE_API_SECRET")  # API key and secret from env vars.
    ticker:  string = readLineFromStdin"Cryptocurrency coin ticker?: ".toUpperAscii                         # "BTC"
    quantity: float = readLineFromStdin"Cryptocurrency coin quantity per Gift-Card code?: ".parseFloat      # 0.0000001
    count:      int = readLineFromStdin"How many Gift-Card codes to generate in total?: ".parseInt.Positive # 1

  for _ in 0 .. count: echo client.request(client.createCode(token = ticker, quantity = quantity), HttpPost).parseJson["data"]
  client.close()


when isMainModule:
  main()
