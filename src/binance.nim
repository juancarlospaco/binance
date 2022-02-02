import std/[net, macros, strutils, json, httpcore, importutils, parseutils, uri ]

const binanceAPIUrl* {.strdefine.} = "https://api.binance.com"  ## `-d:binanceAPIUrl="https://testnet.binance.vision"` for Testnet.

macro unrollStringOps(x: ForLoopStmt) =
  expectKind x, nnkForStmt
  var body = newStmtList()
  for chara in x[^2][^2].strVal:
    body.add nnkAsgn.newTree(x[^2][^1], chara.newLit)
    body.add x[^1]
  result = body

type Binance* = object
  apiKey*, apiSecret*: string

template newDefaultHeaders(apiKey: static[string]): array[1, (string, string)] =
  [(when apiKey.len > 0: ("X-MBX-APIKEY", apiKey) else: ("Dnt", "1"))]

func newBinance*(apiKey, apiSecret: string): Binance {.inline.} =
  Binance(apiKey: apiKey, apiSecret: apiSecret)

proc ping*(_: Binance): HttpCode =
  fetch("/api/v3/ping", HttpGet, newDefaultHeaders"").code

proc time*(_: Binance): string =
  fetch("/api/v3/time", HttpGet, newDefaultHeaders"").body[0]


when isMainModule:
  let client = newBinance("", "")
  # echo client.ping()
  echo client.time()







# Needs SHA256  https://github.com/sammchardy/python-binance/blob/master/binance/client.py#L223
# signature = sha256( API_SECRET + QUERY_STRING ).hexdigest()

# armar query string a partir de TODOS los argumentos
# armar signature con SHA256 con todo el query_string y la API_SECRET
# mandar signature, signature va en el query_string al final
# el body siempre va vacio


#[

Hacer funciones que devuelvan la URL preparada para hacer una peticion y el HTTP Method ???
Asi funciona para cualquier backend y cualquier metodo

]#










