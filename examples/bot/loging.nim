import std/macros


macro logs*(file: var File; args: openArray[(string, auto)]; level: static[string] = "") =
  result = newStmtList()

  template writes(it) =
    if level.len > 0: result.add nnkCall.newTree(nnkDotExpr.newTree(file, newIdentNode"write"), it)
    result.add nnkCall.newTree(nnkDotExpr.newTree(newIdentNode"stdout", newIdentNode"write"), it)

  writes newLit('{')
  writes newLit('"')
  writes newLit('t')
  writes newLit('i')
  writes newLit('m')
  writes newLit('e')
  writes newLit('"')
  writes newLit(':')
  writes newLit('"')
  writes nnkPrefix.newTree(newIdentNode"$", nnkCall.newTree(newIdentNode"now"))
  writes newLit('"')
  writes newLit(',')
  if level.len > 0:
    writes newLit('"')
    writes newLit('l')
    writes newLit('v')
    writes newLit('l')
    writes newLit('"')
    writes newLit(':')
    writes newLit('"')
    writes newLit(level)
    writes newLit('"')
    writes newLit(',')
  for i, item in args:
    let key: string = item[1][0].strVal
    doAssert key.len > 0, "Key must not be empty string."
    writes newLit('"')
    for c in key: writes c.newLit
    writes newLit('"')
    writes newLit(':')
    case item[1][1].kind
    of nnkNilLit:
      writes newLit('n')
      writes newLit('u')
      writes newLit('l')
      writes newLit('l')
    of nnkIntLit .. nnkUInt64Lit, nnkFloatLit .. nnkFloat64Lit:
      writes item[1][1]
    else:
      writes newLit('"')
      writes item[1][1]
      writes newLit('"')
    if i < args.len - 1: writes newLit(',')
  writes newLit('}')
  writes newLit('\n')
