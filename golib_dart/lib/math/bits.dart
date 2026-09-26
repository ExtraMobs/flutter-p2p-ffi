/// Shim do pacote Go `math/bits` (`UintSize` vem dobrada pelo g2d).
///
/// Tudo sobre os fixed_types: as metades de 32 bits (`$hi`/`$lo`) dos
/// inteiros de 64 bits e operações que não passam de 32 bits, iguais em VM,
/// JS e Wasm.
// ignore_for_file: library_prefixes
library;

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;

// --- auxiliares sobre um int de 0 a 2^32-1 ---

int _ones32(int v) {
  v = v - ((v >> 1) & 0x55555555);
  v = (v & 0x33333333) + ((v >> 2) & 0x33333333);
  v = (v + (v >> 4)) & 0x0f0f0f0f;
  v = v + (v >> 8);
  return (v + (v >> 16)) & 0x3f;
}

// Zeros à direita de v != 0: v ^ (v-1) acende até o bit mais baixo.
int _tz32(int v) => (v ^ (v - 1)).bitLength - 1;

int _len64(Golang.IntBase x) =>
    x.$hi != 0 ? 32 + x.$hi.bitLength : x.$lo.bitLength;

int _tz64(Golang.IntBase x) => x.$lo != 0
    ? _tz32(x.$lo)
    : x.$hi != 0
    ? 32 + _tz32(x.$hi)
    : 64;

int _rev8x4(int v) =>
    ((v & 0xff) << 24) | ((v & 0xff00) << 8) | ((v >> 8) & 0xff00) | (v >> 24);

// --- contagem ---

/// `bits.OnesCount8(x)`.
Golang.Int onesCount8(Golang.Uint8 x) => Golang.Int(_ones32(x.toInt()));

/// `bits.OnesCount32(x)`.
Golang.Int onesCount32(Golang.Uint32 x) => Golang.Int(_ones32(x.toInt()));

/// `bits.OnesCount64(x)`.
Golang.Int onesCount64(Golang.Uint64 x) =>
    Golang.Int(_ones32(x.$hi) + _ones32(x.$lo));

/// `bits.LeadingZeros8(x)`.
Golang.Int leadingZeros8(Golang.Uint8 x) => Golang.Int(8 - x.toInt().bitLength);

/// `bits.LeadingZeros64(x)`.
Golang.Int leadingZeros64(Golang.Uint64 x) => Golang.Int(64 - _len64(x));

/// `bits.TrailingZeros(x)`.
Golang.Int trailingZeros(Golang.Uint x) => Golang.Int(_tz64(x));

/// `bits.TrailingZeros32(x)`.
Golang.Int trailingZeros32(Golang.Uint32 x) =>
    Golang.Int(x.toInt() == 0 ? 32 : _tz32(x.toInt()));

/// `bits.TrailingZeros64(x)`.
Golang.Int trailingZeros64(Golang.Uint64 x) => Golang.Int(_tz64(x));

/// `bits.Len(x)`: bits para representar x (0 para 0).
Golang.Int len(Golang.Uint x) => Golang.Int(_len64(x));

/// `bits.Len32(x)`.
Golang.Int len32(Golang.Uint32 x) => Golang.Int(x.toInt().bitLength);

/// `bits.Len64(x)`.
Golang.Int len64(Golang.Uint64 x) => Golang.Int(_len64(x));

// --- rotação e bytes ---

/// `bits.RotateLeft32(x, k)`: k negativo gira à direita.
Golang.Uint32 rotateLeft32(Golang.Uint32 x, Golang.Int k) {
  final s = k.$lo & 31;
  return s == 0 ? x : (x << s) | (x >> (32 - s));
}

/// `bits.RotateLeft64(x, k)`: k negativo gira à direita.
Golang.Uint64 rotateLeft64(Golang.Uint64 x, Golang.Int k) {
  final s = k.$lo & 63;
  return s == 0 ? x : (x << s) | (x >> (64 - s));
}

/// `bits.ReverseBytes16(x)`.
Golang.Uint16 reverseBytes16(Golang.Uint16 x) {
  final v = x.toInt();
  return Golang.Uint16(((v & 0xff) << 8) | (v >> 8));
}

/// `bits.ReverseBytes32(x)`.
Golang.Uint32 reverseBytes32(Golang.Uint32 x) =>
    Golang.Uint32(_rev8x4(x.toInt()));

/// `bits.ReverseBytes64(x)`.
Golang.Uint64 reverseBytes64(Golang.Uint64 x) =>
    x.$make(_rev8x4(x.$lo), _rev8x4(x.$hi));

// --- aritmética com carry, produto e quociente de 128 bits ---

/// `bits.Add(x, y, carry)`: (soma, carryOut); carry deve ser 0 ou 1.
(Golang.Uint, Golang.Uint) add(Golang.Uint x, Golang.Uint y, Golang.Uint c) {
  final sum = x + y + c;
  return (sum, ((x & y) | (x | y).andNot(sum)) >> 63);
}

/// `bits.Add64(x, y, carry)`.
(Golang.Uint64, Golang.Uint64) add64(
  Golang.Uint64 x,
  Golang.Uint64 y,
  Golang.Uint64 c,
) {
  final sum = x + y + c;
  return (sum, ((x & y) | (x | y).andNot(sum)) >> 63);
}

/// `bits.Sub(x, y, borrow)`: (diferença, borrowOut).
(Golang.Uint, Golang.Uint) sub(Golang.Uint x, Golang.Uint y, Golang.Uint b) {
  final diff = x - y - b;
  return (diff, (y.andNot(x) | (~(x ^ y) & diff)) >> 63);
}

/// `bits.Sub64(x, y, borrow)`.
(Golang.Uint64, Golang.Uint64) sub64(
  Golang.Uint64 x,
  Golang.Uint64 y,
  Golang.Uint64 b,
) {
  final diff = x - y - b;
  return (diff, (y.andNot(x) | (~(x ^ y) & diff)) >> 63);
}

/// `bits.Mul(x, y)`: (hi, lo) do produto de 128 bits.
(Golang.Uint, Golang.Uint) mul(Golang.Uint x, Golang.Uint y) {
  final (hi, lo) = mul64(Golang.Uint64.from(x), Golang.Uint64.from(y));
  return (Golang.Uint.from(hi), Golang.Uint.from(lo));
}

/// `bits.Mul64(x, y)`: (hi, lo) do produto de 128 bits.
(Golang.Uint64, Golang.Uint64) mul64(Golang.Uint64 x, Golang.Uint64 y) {
  final m32 = Golang.Uint64(0xffffffff);
  final x0 = x & m32, x1 = x >> 32, y0 = y & m32, y1 = y >> 32;
  final w0 = x0 * y0;
  final t = x1 * y0 + (w0 >> 32);
  var w1 = t & m32;
  final w2 = t >> 32;
  w1 += x0 * y1;
  return (x1 * y1 + w2 + (w1 >> 32), x * y);
}

/// `bits.Div(hi, lo, y)`: (quo, rem) de (hi, lo) / y; pânico se y == 0 ou
/// y <= hi.
(Golang.Uint, Golang.Uint) div(Golang.Uint hi, Golang.Uint lo, Golang.Uint y) {
  final (q, r) = div64(
    Golang.Uint64.from(hi),
    Golang.Uint64.from(lo),
    Golang.Uint64.from(y),
  );
  return (Golang.Uint.from(q), Golang.Uint.from(r));
}

/// `bits.Div64(hi, lo, y)`: (quo, rem) de (hi, lo) / y; pânico se y == 0
/// (divide by zero) ou y <= hi (overflow), como no Go.
// ponytail: BigInt (correto em toda plataforma); porta do algoritmo do Go
// se aparecer em caminho quente.
(Golang.Uint64, Golang.Uint64) div64(
  Golang.Uint64 hi,
  Golang.Uint64 lo,
  Golang.Uint64 y,
) {
  if (y == Golang.Uint64()) {
    throw Panic(const RuntimeError('runtime error: integer divide by zero'));
  }
  if (y <= hi) {
    throw Panic(const RuntimeError('runtime error: integer overflow'));
  }
  final n = (hi.toBigInt() << 64) | lo.toBigInt();
  final d = y.toBigInt();
  return (Golang.Uint64.fromBigInt(n ~/ d), Golang.Uint64.fromBigInt(n % d));
}
