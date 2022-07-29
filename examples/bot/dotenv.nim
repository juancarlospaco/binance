# https://juancarlospaco.github.io/nodejs/nodejs/jsdotenv
from std/strutils import split, strip
from std/parseutils import parseSaturatedNatural, parseFloat
from std/json import JsonNode, newJInt, newJFloat, newJBool, newJString, newJObject, newJArray, add, parseJson

proc parseBool(s: string): bool {.inline.} =
  case s
  of "true":  result = true
  of "false": result = false
  else: doAssert false, "Can not interpret as a bool."

func validateKey(s: string): bool {.inline.} =
  result = true
  for c in s:
    if c notin {'a'..'z', 'A'..'Z', '0'..'9', '_'}: return false

proc parseDotEnv*(s: string): JsonNode =
  assert s.len > 0, "DotEnv must not be empty string"
  result = newJObject()
  if likely(s.len > 1):
    for zz in s.split('\n'):        # Split by lines
      var z = zz                    # k= is the shortest possible
      z = strip(z)
      if z.len > 1 and z[0] != '#': # No comment lines, no empty lines
        let kV = z.split('=')
        if kV.len >= 2:            # k sep v
          var k = kV[0]            # Key name
          k = strip(k)
          doAssert validateKey(k), "DotEnv key must be a non-empty ASCII string ([a-zA-Z0-9_])"
          var v = kV[1].split('#')[0] # remove inline comments
          v = strip(v)
          var tipe = kV[^1].split('#')[1]  # Get type annotation
          tipe = strip(tipe)
          if k.len > 0:   # k must not be empty string
            case tipe
            of "bool":   result.add k, newJBool(parseBool(v))
            of "string": result.add k, newJString(v)
            of "json":   result.add k, parseJson(v)
            of "int":
              var i = 0
              discard parseSaturatedNatural(v, i)
              result.add k, newJInt(i)
            of "float":
              var f = 0.0
              discard parseFloat(v, f)
              result.add k, newJFloat(f)
            else: doAssert false, "Type must be 1 of int, float, bool, string, json"
