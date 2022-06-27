when not defined(js):

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
      count:  array[2, uint32]
      state:  array[8, uint32]
      buffer: array[64,byte]

    sha256 = SHA256

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
  else: {.fatal: "Requires GCC or Clang or LLVM Compiler.".}

  template copyMem[A, B](dst: var openArray[A], dsto: int, src: openArray[B], srco: int, length: int) = copyMem(addr dst[dsto], unsafeAddr src[srco], length * sizeof(B))
  template ROR(x: uint32, n: int): uint32 = (x shr uint32(n and 0x1F)) or (x shl uint32(32 - (n and 0x1F)))
  template ROR(x: uint64, n: int): uint64 = (x shr uint64(n and 0x3F)) or (x shl uint64(64 - (n and 0x3F)))
  template SIG0(x): uint32 = ROR(x, 7) xor ROR(x, 18) xor (x shr 3)
  template SIG1(x): uint32 = ROR(x, 17) xor ROR(x, 19) xor (x shr 10)
  template TAU0(x: uint32): uint32 = (ROR(x, 2) xor ROR(x, 13) xor ROR(x, 22))
  template TAU1(x: uint32): uint32 = (ROR(x, 6) xor ROR(x, 11) xor ROR(x, 25))
  template CH0(x, y, z): uint32 = ((x) and (y)) xor (not(x) and (z))
  template MAJ0(x, y, z): uint32 = ((x) and (y)) xor ((x) and (z)) xor ((y) and (z))
  template leSwap32(a: uint32): uint32 = (when system.cpuEndian == bigEndian: (a) else: swapBytesBuiltin(a))
  template beStore32*(dst: var openArray[byte], so: int, v: uint32) = cast[ptr uint32](addr dst[so])[] = leSwap32(v)

  template ROUND256(a, b, c, d, e, f, g, h, z) =
    t0 = h + TAU1(e) + CH0(e, f, g) + K0[z] + W[z]
    t1 = TAU0(a) + MAJ0(a, b, c)
    d = d + t0
    h = t0 + t1

  template beLoad32[T: byte|char](src: openArray[T], srco: int): uint32 =
    var p = cast[ptr uint32](unsafeAddr src[srco])[]
    leSwap32(p)

  proc sha256Transform(state: var array[8, uint32], data: openArray[byte]) =
    var
      t0, t1: uint32
      W {.noinit.}: array[64, uint32]

    W[0]  = beLoad32(data, 0)
    W[1]  = beLoad32(data, 4)
    W[2]  = beLoad32(data, 8)
    W[3]  = beLoad32(data, 12)
    W[4]  = beLoad32(data, 16)
    W[5]  = beLoad32(data, 20)
    W[6]  = beLoad32(data, 24)
    W[7]  = beLoad32(data, 28)
    W[8]  = beLoad32(data, 32)
    W[9]  = beLoad32(data, 36)
    W[10] = beLoad32(data, 40)
    W[11] = beLoad32(data, 44)
    W[12] = beLoad32(data, 48)
    W[13] = beLoad32(data, 52)
    W[14] = beLoad32(data, 56)
    W[15] = beLoad32(data, 60)

    for i in 16 ..< 64: W[i] = SIG1(W[i - 2]) + W[i - 7] + SIG0(W[i - 15]) + W[i - 16]

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
    hmctx.mdctx   = sha256()
    hmctx.opadctx = sha256()
    init hmctx.opadctx

    if key.len > 0: copyMem(kpad, 0, key, 0, len(key))

    for i in 0 ..< 64:
      hmctx.opad[i] = 0x5C'u8 xor kpad[i]
      hmctx.ipad[i] = 0x36'u8 xor kpad[i]

    init hmctx.mdctx
    update hmctx.mdctx, hmctx.ipad
    update hmctx.opadctx, hmctx.opad

  proc finalize256(ctx: var SHA256) {.inline.} =
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

  proc finish*(ctx: var SHA256, data: var openArray[byte]): uint {.inline.} =
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

  proc burnMem[T](a: var T)   {.inline.} = burnMem(addr a, sizeof(T))
  proc clear(hmctx: var HMAC) {.inline.} = burnMem(hmctx)

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

  proc sha256hmac*(key, data: openArray[char]): string =
    var ctx: HMAC
    ctx.init key
    ctx.mdctx.update data
    var result_data: array[32, byte]
    ctx.finish result_data
    var res = newString((len(result_data) shl 1))
    discard bytesToHex(result_data, res, {})
    ctx.clear
    res.toLowerAscii


when defined(js):
  {.emit: """

const sha256hmacjs = (function() {

  function hex_hmac_sha256(k, d) { return rstr2hex(rstr_hmac_sha256(str2rstr_utf8(k), str2rstr_utf8(d))); }

  function rstr_hmac_sha256(key, data) {
    var bkey = rstr2binb(key);
    if (bkey.length > 16) { bkey = binb_sha256(bkey, key.length * 8); }

    var ipad = Array(16), opad = Array(16);
    for (var i = 0; i < 16; i++) {
      ipad[i] = bkey[i] ^ 0x36363636;
      opad[i] = bkey[i] ^ 0x5C5C5C5C;
    }

    const hash = binb_sha256(ipad.concat(rstr2binb(data)), 512 + data.length * 8);
    return binb2rstr(binb_sha256(opad.concat(hash), 512 + 256));
  }

  function rstr2hex(input) {
    const hex_tab = "0123456789abcdef";
    var output = "";
    var x;
    for (var i = 0; i < input.length; i++) {
      x = input.charCodeAt(i);
      output += hex_tab.charAt((x >>> 4) & 0x0F) + hex_tab.charAt(x & 0x0F);
    }
    return output;
  }

  function str2rstr_utf8(input) {
    var output = "";
    var i = -1;
    var x, y;

    while (++i < input.length) {
      x = input.charCodeAt(i);
      y = i + 1 < input.length ? input.charCodeAt(i + 1) : 0;
      if (0xD800 <= x && x <= 0xDBFF && 0xDC00 <= y && y <= 0xDFFF) {
        x = 0x10000 + ((x & 0x03FF) << 10) + (y & 0x03FF);
        i++;
      }

      /* Encode output as utf-8 */
      if (x <= 0x7F)
        output += String.fromCharCode(x);
      else if (x <= 0x7FF)
        output += String.fromCharCode(0xC0 | ((x >>> 6 ) & 0x1F),
                                      0x80 | ( x         & 0x3F));
      else if (x <= 0xFFFF)
        output += String.fromCharCode(0xE0 | ((x >>> 12) & 0x0F),
                                      0x80 | ((x >>> 6 ) & 0x3F),
                                      0x80 | ( x         & 0x3F));
      else if (x <= 0x1FFFFF)
        output += String.fromCharCode(0xF0 | ((x >>> 18) & 0x07),
                                      0x80 | ((x >>> 12) & 0x3F),
                                      0x80 | ((x >>> 6 ) & 0x3F),
                                      0x80 | ( x         & 0x3F));
    }
    return output;
  }

  function rstr2binb(input) {
    var output = Array(input.length >> 2);
    for (var i = 0; i < output.length; i++)
      output[i] = 0;
    for (var i = 0; i < input.length * 8; i += 8)
      output[i>>5] |= (input.charCodeAt(i / 8) & 0xFF) << (24 - i % 32);
    return output;
  }

  function binb2rstr(input) {
    var output = "";
    for (var i = 0; i < input.length * 32; i += 8)
      output += String.fromCharCode((input[i>>5] >>> (24 - i % 32)) & 0xFF);
    return output;
  }

  function sha256_S(X, n)      { return ( X >>> n ) | (X << (32 - n));                        }
  function sha256_R(X, n)      { return ( X >>> n );                                          }
  function sha256_Ch(x, y, z)  { return ((x & y) ^ ((~x) & z));                               }
  function sha256_Maj(x, y, z) { return ((x & y) ^ (x & z) ^ (y & z));                        }
  function sha256_Sigma0256(x) { return (sha256_S(x, 2) ^ sha256_S(x, 13) ^ sha256_S(x, 22)); }
  function sha256_Sigma1256(x) { return (sha256_S(x, 6) ^ sha256_S(x, 11) ^ sha256_S(x, 25)); }
  function sha256_Gamma0256(x) { return (sha256_S(x, 7) ^ sha256_S(x, 18) ^ sha256_R(x, 3));  }
  function sha256_Gamma1256(x) { return (sha256_S(x, 17) ^ sha256_S(x, 19) ^ sha256_R(x, 10));}

  var sha256_K = new Array(
    1116352408, 1899447441, -1245643825, -373957723, 961987163, 1508970993,
    -1841331548, -1424204075, -670586216, 310598401, 607225278, 1426881987,
    1925078388, -2132889090, -1680079193, -1046744716, -459576895, -272742522,
    264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
    -1740746414, -1473132947, -1341970488, -1084653625, -958395405, -710438585,
    113926993, 338241895, 666307205, 773529912, 1294757372, 1396182291,
    1695183700, 1986661051, -2117940946, -1838011259, -1564481375, -1474664885,
    -1035236496, -949202525, -778901479, -694614492, -200395387, 275423344,
    430227734, 506948616, 659060556, 883997877, 958139571, 1322822218,
    1537002063, 1747873779, 1955562222, 2024104815, -2067236844, -1933114872,
    -1866530822, -1538233109, -1090935817, -965641998
  );

  function binb_sha256(m, l) {
    var HASH = new Array(1779033703, -1150833019, 1013904242, -1521486534, 1359893119, -1694144372, 528734635, 1541459225);
    var W = new Array(64);
    var a, b, c, d, e, f, g, h;
    var i, j, T1, T2;

    m[l >> 5] |= 0x80 << (24 - l % 32);
    m[((l + 64 >> 9) << 4) + 15] = l;

    for (i = 0; i < m.length; i += 16) {
      a = HASH[0];
      b = HASH[1];
      c = HASH[2];
      d = HASH[3];
      e = HASH[4];
      f = HASH[5];
      g = HASH[6];
      h = HASH[7];

      for (j = 0; j < 64; j++) {
        if (j < 16) { W[j] = m[j + i]; }
        else { W[j] = safe_add(safe_add(safe_add(sha256_Gamma1256(W[j - 2]), W[j - 7]), sha256_Gamma0256(W[j - 15])), W[j - 16]); }

        T1 = safe_add(safe_add(safe_add(safe_add(h, sha256_Sigma1256(e)), sha256_Ch(e, f, g)), sha256_K[j]), W[j]);
        T2 = safe_add(sha256_Sigma0256(a), sha256_Maj(a, b, c));
        h = g;
        g = f;
        f = e;
        e = safe_add(d, T1);
        d = c;
        c = b;
        b = a;
        a = safe_add(T1, T2);
      }

      HASH[0] = safe_add(a, HASH[0]);
      HASH[1] = safe_add(b, HASH[1]);
      HASH[2] = safe_add(c, HASH[2]);
      HASH[3] = safe_add(d, HASH[3]);
      HASH[4] = safe_add(e, HASH[4]);
      HASH[5] = safe_add(f, HASH[5]);
      HASH[6] = safe_add(g, HASH[6]);
      HASH[7] = safe_add(h, HASH[7]);
    }
    return HASH;
  }

  function safe_add(x, y) {
    const lsw = (x & 0xFFFF) + (y & 0xFFFF);
    const msw = (x >> 16) + (y >> 16) + (lsw >> 16);
    return (msw << 16) | (lsw & 0xFFFF);
  }

  return hex_hmac_sha256;

}());

  """.}

  func sha256hmacjs(key, data: cstring): cstring {.importjs: "$1(#, #)".}

  proc sha256hmac*(key, data: string): string =
    $sha256hmacjs(key.cstring, data.cstring)


when isMainModule:
  doAssert sha256hmac("key", "value") == "90fbfcf15e74a36b89dbdb2a721d9aecffdfdddc5c83e27f7592594f71932481"
