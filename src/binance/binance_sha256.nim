from std/strutils import toLowerAscii


type
  HexFlags {.pure.} = enum
    LowerCase,  ## Produce lowercase hexadecimal characters
    PadOdd,     ## Pads odd strings
    SkipSpaces, ## Skips all the whitespace characters inside of string
    SkipPrefix

  bchar = byte | char

  SHA256 = object
    bits: int       # 256
    block_size: int # block-size 64
    count: array[2, uint32]
    state: array[8, uint32]
    buffer: array[64,byte]

  sha256* = SHA256

  HMAC = object
    mdctx: sha256
    opadctx: sha256
    ipad: array[64, byte]
    opad: array[64, byte]

const
  K0 = [
    0x428a2f98'u32, 0x71374491'u32, 0xb5c0fbcf'u32, 0xe9b5dba5'u32,
    0x3956c25b'u32, 0x59f111f1'u32, 0x923f82a4'u32, 0xab1c5ed5'u32,
    0xd807aa98'u32, 0x12835b01'u32, 0x243185be'u32, 0x550c7dc3'u32,
    0x72be5d74'u32, 0x80deb1fe'u32, 0x9bdc06a7'u32, 0xc19bf174'u32,
    0xe49b69c1'u32, 0xefbe4786'u32, 0x0fc19dc6'u32, 0x240ca1cc'u32,
    0x2de92c6f'u32, 0x4a7484aa'u32, 0x5cb0a9dc'u32, 0x76f988da'u32,
    0x983e5152'u32, 0xa831c66d'u32, 0xb00327c8'u32, 0xbf597fc7'u32,
    0xc6e00bf3'u32, 0xd5a79147'u32, 0x06ca6351'u32, 0x14292967'u32,
    0x27b70a85'u32, 0x2e1b2138'u32, 0x4d2c6dfc'u32, 0x53380d13'u32,
    0x650a7354'u32, 0x766a0abb'u32, 0x81c2c92e'u32, 0x92722c85'u32,
    0xa2bfe8a1'u32, 0xa81a664b'u32, 0xc24b8b70'u32, 0xc76c51a3'u32,
    0xd192e819'u32, 0xd6990624'u32, 0xf40e3585'u32, 0x106aa070'u32,
    0x19a4c116'u32, 0x1e376c08'u32, 0x2748774c'u32, 0x34b0bcb5'u32,
    0x391c0cb3'u32, 0x4ed8aa4a'u32, 0x5b9cca4f'u32, 0x682e6ff3'u32,
    0x748f82ee'u32, 0x78a5636f'u32, 0x84c87814'u32, 0x8cc70208'u32,
    0x90befffa'u32, 0xa4506ceb'u32, 0xbef9a3f7'u32, 0xc67178f2'u32
  ]

when defined(gcc) or defined(llvm_gcc) or defined(clang):
  func swapBytesBuiltin(x: uint8 ): uint8 = x
  func swapBytesBuiltin(x: uint16): uint16 {.importc: "__builtin_bswap16", nodecl.}
  func swapBytesBuiltin(x: uint32): uint32 {.importc: "__builtin_bswap32", nodecl.}
  func swapBytesBuiltin(x: uint64): uint64 {.importc: "__builtin_bswap64", nodecl.}
elif defined(icc):
  func swapBytesBuiltin(x: uint8 ): uint8 = x
  func swapBytesBuiltin(a: uint16): uint16 {.importc: "_bswap16", nodecl.}
  func swapBytesBuiltin(a: uint32): uint32 {.importc: "_bswap",   nodec.}
  func swapBytesBuiltin(a: uint64): uint64 {.importc: "_bswap64", nodecl.}
elif defined(vcc):
  func swapBytesBuiltin(x: uint8 ): uint8 = x
  proc swapBytesBuiltin(a: uint16): uint16 {.importc: "_byteswap_ushort", cdecl, header: "<intrin.h>".}
  proc swapBytesBuiltin(a: uint32): uint32 {.importc: "_byteswap_ulong",  cdecl, header: "<intrin.h>".}
  proc swapBytesBuiltin(a: uint64): uint64 {.importc: "_byteswap_uint64", cdecl, header: "<intrin.h>".}


template copyMem[A, B](dst: var openArray[A], dsto: int, src: openArray[B], srco: int, length: int) =
  copyMem(addr dst[dsto], unsafeAddr src[srco], length * sizeof(B))

template ROR(x: uint32, n: int): uint32 =
  (x shr uint32(n and 0x1F)) or (x shl uint32(32 - (n and 0x1F)))

template ROR(x: uint64, n: int): uint64 =
  (x shr uint64(n and 0x3F)) or (x shl uint64(64 - (n and 0x3F)))

template SIG0(x): uint32 =
  ROR(x, 7) xor ROR(x, 18) xor (x shr 3)

template SIG1(x): uint32 =
  ROR(x, 17) xor ROR(x, 19) xor (x shr 10)

template TAU0(x: uint32): uint32 =
  (ROR(x, 2) xor ROR(x, 13) xor ROR(x, 22))

template TAU1(x: uint32): uint32 =
  (ROR(x, 6) xor ROR(x, 11) xor ROR(x, 25))

template CH0(x, y, z): uint32 =
  ((x) and (y)) xor (not(x) and (z))

template MAJ0(x, y, z): uint32 =
  ((x) and (y)) xor ((x) and (z)) xor ((y) and (z))

template ROUND256(a, b, c, d, e, f, g, h, z) =
  t0 = h + TAU1(e) + CH0(e, f, g) + K0[z] + W[z]
  t1 = TAU0(a) + MAJ0(a, b, c)
  d = d + t0
  h = t0 + t1

template leSwap32(a: uint32): uint32 =
  when system.cpuEndian == bigEndian:
    (a)
  else:
    swapBytesBuiltin(a)

template beLoad32[T: byte|char](src: openArray[T], srco: int): uint32 =
  var p = cast[ptr uint32](unsafeAddr src[srco])[]
  leSwap32(p)

template beStore32*(dst: var openArray[byte], so: int, v: uint32) =
  cast[ptr uint32](addr dst[so])[] = leSwap32(v)

proc sha256Transform(state: var array[8, uint32], data: openArray[byte]) =
  var
    t0, t1: uint32
    W {.noinit.}: array[64, uint32]

  W[0]  = beLoad32(data, 0); W[1]   = beLoad32(data, 4);
  W[2]  = beLoad32(data, 8); W[3]   = beLoad32(data, 12)
  W[4]  = beLoad32(data, 16); W[5]  = beLoad32(data, 20)
  W[6]  = beLoad32(data, 24); W[7]  = beLoad32(data, 28)
  W[8]  = beLoad32(data, 32); W[9]  = beLoad32(data, 36)
  W[10] = beLoad32(data, 40); W[11] = beLoad32(data, 44)
  W[12] = beLoad32(data, 48); W[13] = beLoad32(data, 52)
  W[14] = beLoad32(data, 56); W[15] = beLoad32(data, 60)

  for i in 16 ..< 64:
    W[i] = SIG1(W[i - 2]) + W[i - 7] + SIG0(W[i - 15]) + W[i - 16]

  var s0 = state[0]
  var s1 = state[1]
  var s2 = state[2]
  var s3 = state[3]
  var s4 = state[4]
  var s5 = state[5]
  var s6 = state[6]
  var s7 = state[7]

  ROUND256(s0, s1, s2, s3, s4, s5, s6, s7, 0)
  ROUND256(s7, s0, s1, s2, s3, s4, s5, s6, 1)
  ROUND256(s6, s7, s0, s1, s2, s3, s4, s5, 2)
  ROUND256(s5, s6, s7, s0, s1, s2, s3, s4, 3)
  ROUND256(s4, s5, s6, s7, s0, s1, s2, s3, 4)
  ROUND256(s3, s4, s5, s6, s7, s0, s1, s2, 5)
  ROUND256(s2, s3, s4, s5, s6, s7, s0, s1, 6)
  ROUND256(s1, s2, s3, s4, s5, s6, s7, s0, 7)
  ROUND256(s0, s1, s2, s3, s4, s5, s6, s7, 8)
  ROUND256(s7, s0, s1, s2, s3, s4, s5, s6, 9)
  ROUND256(s6, s7, s0, s1, s2, s3, s4, s5, 10)
  ROUND256(s5, s6, s7, s0, s1, s2, s3, s4, 11)
  ROUND256(s4, s5, s6, s7, s0, s1, s2, s3, 12)
  ROUND256(s3, s4, s5, s6, s7, s0, s1, s2, 13)
  ROUND256(s2, s3, s4, s5, s6, s7, s0, s1, 14)
  ROUND256(s1, s2, s3, s4, s5, s6, s7, s0, 15)

  ROUND256(s0, s1, s2, s3, s4, s5, s6, s7, 16)
  ROUND256(s7, s0, s1, s2, s3, s4, s5, s6, 17)
  ROUND256(s6, s7, s0, s1, s2, s3, s4, s5, 18)
  ROUND256(s5, s6, s7, s0, s1, s2, s3, s4, 19)
  ROUND256(s4, s5, s6, s7, s0, s1, s2, s3, 20)
  ROUND256(s3, s4, s5, s6, s7, s0, s1, s2, 21)
  ROUND256(s2, s3, s4, s5, s6, s7, s0, s1, 22)
  ROUND256(s1, s2, s3, s4, s5, s6, s7, s0, 23)
  ROUND256(s0, s1, s2, s3, s4, s5, s6, s7, 24)
  ROUND256(s7, s0, s1, s2, s3, s4, s5, s6, 25)
  ROUND256(s6, s7, s0, s1, s2, s3, s4, s5, 26)
  ROUND256(s5, s6, s7, s0, s1, s2, s3, s4, 27)
  ROUND256(s4, s5, s6, s7, s0, s1, s2, s3, 28)
  ROUND256(s3, s4, s5, s6, s7, s0, s1, s2, 29)
  ROUND256(s2, s3, s4, s5, s6, s7, s0, s1, 30)
  ROUND256(s1, s2, s3, s4, s5, s6, s7, s0, 31)

  ROUND256(s0, s1, s2, s3, s4, s5, s6, s7, 32)
  ROUND256(s7, s0, s1, s2, s3, s4, s5, s6, 33)
  ROUND256(s6, s7, s0, s1, s2, s3, s4, s5, 34)
  ROUND256(s5, s6, s7, s0, s1, s2, s3, s4, 35)
  ROUND256(s4, s5, s6, s7, s0, s1, s2, s3, 36)
  ROUND256(s3, s4, s5, s6, s7, s0, s1, s2, 37)
  ROUND256(s2, s3, s4, s5, s6, s7, s0, s1, 38)
  ROUND256(s1, s2, s3, s4, s5, s6, s7, s0, 39)
  ROUND256(s0, s1, s2, s3, s4, s5, s6, s7, 40)
  ROUND256(s7, s0, s1, s2, s3, s4, s5, s6, 41)
  ROUND256(s6, s7, s0, s1, s2, s3, s4, s5, 42)
  ROUND256(s5, s6, s7, s0, s1, s2, s3, s4, 43)
  ROUND256(s4, s5, s6, s7, s0, s1, s2, s3, 44)
  ROUND256(s3, s4, s5, s6, s7, s0, s1, s2, 45)
  ROUND256(s2, s3, s4, s5, s6, s7, s0, s1, 46)
  ROUND256(s1, s2, s3, s4, s5, s6, s7, s0, 47)

  ROUND256(s0, s1, s2, s3, s4, s5, s6, s7, 48)
  ROUND256(s7, s0, s1, s2, s3, s4, s5, s6, 49)
  ROUND256(s6, s7, s0, s1, s2, s3, s4, s5, 50)
  ROUND256(s5, s6, s7, s0, s1, s2, s3, s4, 51)
  ROUND256(s4, s5, s6, s7, s0, s1, s2, s3, 52)
  ROUND256(s3, s4, s5, s6, s7, s0, s1, s2, 53)
  ROUND256(s2, s3, s4, s5, s6, s7, s0, s1, 54)
  ROUND256(s1, s2, s3, s4, s5, s6, s7, s0, 55)
  ROUND256(s0, s1, s2, s3, s4, s5, s6, s7, 56)
  ROUND256(s7, s0, s1, s2, s3, s4, s5, s6, 57)
  ROUND256(s6, s7, s0, s1, s2, s3, s4, s5, 58)
  ROUND256(s5, s6, s7, s0, s1, s2, s3, s4, 59)
  ROUND256(s4, s5, s6, s7, s0, s1, s2, s3, 60)
  ROUND256(s3, s4, s5, s6, s7, s0, s1, s2, 61)
  ROUND256(s2, s3, s4, s5, s6, s7, s0, s1, 62)
  ROUND256(s1, s2, s3, s4, s5, s6, s7, s0, 63)

  state[0] = state[0] + s0
  state[1] = state[1] + s1
  state[2] = state[2] + s2
  state[3] = state[3] + s3
  state[4] = state[4] + s4
  state[5] = state[5] + s5
  state[6] = state[6] + s6
  state[7] = state[7] + s7

proc update[T: bchar](ctx: var SHA256, data: openArray[T])=
  var pos = 0
  var length = len(data)

  while length > 0:
    let offset = int(ctx.count[0] and 0x3f)
    let size = min(64 - offset, length)
    copyMem(ctx.buffer, offset, data, pos, size)
    pos += size
    length -= size
    ctx.count[0] += uint32(size)
    if ctx.count[0] < uint32(size):
      ctx.count[1] = ctx.count[1] + 1'u32
    if (ctx.count[0] and 0x3F'u32) == 0:
      sha256Transform(ctx.state, ctx.buffer)

proc init(ctx: var SHA256) =
  ctx.count[0] = 0
  ctx.count[1] = 0
  ctx.state[0] = 0x6A09E667'u32
  ctx.state[1] = 0xBB67AE85'u32
  ctx.state[2] = 0x3C6EF372'u32
  ctx.state[3] = 0xA54FF53A'u32
  ctx.state[4] = 0x510E527F'u32
  ctx.state[5] = 0x9B05688C'u32
  ctx.state[6] = 0x1F83D9AB'u32
  ctx.state[7] = 0x5BE0CD19'u32

proc init[M](hmctx: var HMAC, key: openArray[M]) =
  var kpad: hmctx.ipad.type
  hmctx.mdctx = sha256()
  hmctx.opadctx = sha256()
  init hmctx.opadctx

  if key.len > 0:
      copyMem(kpad, 0, key, 0, len(key))

  for i in 0 ..< 64:
    hmctx.opad[i] = 0x5C'u8 xor kpad[i]
    hmctx.ipad[i] = 0x36'u8 xor kpad[i]

  init hmctx.mdctx
  update hmctx.mdctx, hmctx.ipad
  update hmctx.opadctx, hmctx.opad


proc finalize256(ctx: var SHA256) {. inline .} =
  var j = int(ctx.count[0] and 0x3f'u32)
  ctx.buffer[j] = 0x80'u8
  j += 1
  while j != 56:
    if j == 64:
      sha256Transform(ctx.state, ctx.buffer)
      j = 0
    ctx.buffer[j] = 0x00'u8
    j += 1
  ctx.count[1] = (ctx.count[1] shl 3) + (ctx.count[0] shr 29)
  ctx.count[0] = ctx.count[0] shl 3
  beStore32(ctx.buffer, 56, ctx.count[1])
  beStore32(ctx.buffer, 60, ctx.count[0])
  sha256Transform(ctx.state, ctx.buffer)

proc finish*(ctx: var SHA256, data: var openArray[byte]):uint {.inline .} =
  finalize256(ctx)
  beStore32(data, 0, ctx.state[0])
  beStore32(data, 4, ctx.state[1])
  beStore32(data, 8, ctx.state[2])
  beStore32(data, 12, ctx.state[3])
  beStore32(data, 16, ctx.state[4])
  beStore32(data, 20, ctx.state[5])
  beStore32(data, 24, ctx.state[6])
  beStore32(data, 28, ctx.state[7])
  result = 32


proc finish[T: bchar](hmctx: var HMAC, data: var openArray[T]) {.inline.} =
  var buffer: array[32, byte]
  discard finish(hmctx.mdctx, buffer)
  hmctx.opadctx.update(buffer)
  discard hmctx.opadctx.finish(data)

proc burnMem(p: pointer, size: Natural) =
  var sp {.volatile.} = cast[ptr byte](p)
  var c = size
  if not isNil(sp):
    zeroMem(p, size)
    while c > 0:
      sp[] = 0
      sp = cast[ptr byte](cast[uint](sp) + 1)
      dec(c)

proc burnMem[T](a: var T) {.inline.} =
  burnMem(addr a, sizeof(T))


proc clear(hmctx: var HMAC) =
  burnMem(hmctx)

proc hexDigit(x: int, lowercase: bool = false): char =
  var off = uint32(0x41 - 0x3A)
  if lowercase:
    off += 0x20
  char(0x30'u32 + uint32(x) + (off and not((uint32(x) - 10) shr 8)))


proc bytesToHex(src: openArray[byte], dst: var openArray[char], flags: set[HexFlags]): int =
  if len(dst) == 0:
    (len(src) shl 1)
  else:
    var halflast = false
    let dstlen = len(dst)
    var srclen = len(src)

    if dstlen < (srclen shl 1):
      if (dstlen and 1) == 1:
        srclen = (dstlen - 1) shr 1
        halflast = true
      else:
        srclen = (dstlen shr 1)

    let lowercase = (HexFlags.LowerCase in flags)

    var k = 0
    for i in 0 ..< srclen:
      let x = int(src[i])
      dst[k + 0] = hexDigit(x shr 4, lowercase)
      dst[k + 1] = hexDigit(x and 15, lowercase)
      inc(k, 2)

    if halflast:
      let x = int(src[srclen])
      dst[k + 0] = hexDigit(x shr 4, lowercase)
      inc(k)
    k


proc hmac*[A: bchar, B: bchar](HashType: typedesc, key: openArray[A], data: openArray[B]): string =
  var ctx: HMAC
  ctx.init key
  ctx.mdctx.update data
  var result_data: array[32, byte]
  ctx.finish result_data
  var res = newString((len(result_data) shl 1))
  discard bytesToHex(result_data, res, {})
  ctx.clear
  res.toLowerAscii
