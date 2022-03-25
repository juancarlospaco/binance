import std/[json, os, httpcore, rdstdin, strutils], binance


proc main() =
  let
    client: Binance = newBinance(getEnv"BINANCE_API_KEY", getEnv"BINANCE_API_SECRET")
    ticker:  string = readLineFromStdin"Cryptocurrency coin ticker?: ".toUpperAscii
    quantity: float = readLineFromStdin"Cryptocurrency coin quantity per Gift-Card code?: ".parseFloat
    count:      int = readLineFromStdin"How many Gift-Card codes to generate in total?: ".parseInt.Positive

  for _ in 0 .. count: echo client.request(client.createCode(token = ticker, quantity = quantity), HttpPost).parseJson["data"]
  client.close()


when isMainModule:
  main()
