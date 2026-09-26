/// Shim do pacote Go `math` (constantes vêm dobradas pelo g2d).
// ignore_for_file: library_prefixes
library;

import 'dart:math' as dart_math;
import 'dart:typed_data';

import 'fixed_types/golang.dart' as Golang;
import 'src/math/pure.dart' as pure;

/// `math.NaN()`: os bits do Go (0x7ff8000000000001, sinal +). O `double.nan`
/// do Dart é o NaN padrão da plataforma (negativo na VM/Wasm em x86).
Golang.Float64 naN() => Golang.Float64(_goNaN);

final double _goNaN =
    (ByteData(8)
          ..setUint32(0, 0x7ff80000)
          ..setUint32(4, 1))
        .getFloat64(0);

/// `math.Copysign(f, sign)`: magnitude de f com o bit de sinal de sign
/// (vale para ±0 e NaN, como no Go).
Golang.Float64 copysign(Golang.Float64 f, Golang.Float64 sign) {
  final b = ByteData(16)
    ..setFloat64(0, f.toDouble())
    ..setFloat64(8, sign.toDouble());
  b.setUint8(0, (b.getUint8(0) & 0x7f) | (b.getUint8(8) & 0x80));
  return Golang.Float64(b.getFloat64(0));
}

/// `math.Sqrt(x)`: raiz quadrada IEEE 754, com arredondamento correto no Go,
/// na VM, no JS (`Math.sqrt`) e no Wasm (`f64.sqrt`).
Golang.Float64 sqrt(Golang.Float64 x) =>
    Golang.Float64(dart_math.sqrt(x.toDouble()));

/// `math.Inf(sign)`: +Inf se sign >= 0, senão -Inf.
Golang.Float64 inf(Golang.Int sign) => Golang.Float64(
  sign >= Golang.Int(0) ? double.infinity : double.negativeInfinity,
);

/// `math.IsInf(f, sign)`: sign > 0 só +Inf, < 0 só -Inf, 0 qualquer.
bool isInf(Golang.Float64 f, Golang.Int sign) {
  final d = f.toDouble();
  final s = sign.toInt();
  return (s >= 0 && d == double.infinity) ||
      (s <= 0 && d == double.negativeInfinity);
}

/// `math.IsNaN(f)`.
bool isNaN(Golang.Float64 f) => f.toDouble().isNaN;

/// `math.Signbit(x)`: bit de sinal (vale para -0 e NaN).
bool signbit(Golang.Float64 x) =>
    (ByteData(8)..setFloat64(0, x.toDouble())).getUint8(0) >= 0x80;

/// `math.Abs(x)`: limpa o bit de sinal (Abs(-0) = +0, Abs(NaN) = NaN).
Golang.Float64 abs(Golang.Float64 x) => copysign(x, Golang.Float64(1.0));

/// `math.Floor(x)`; ±0, ±Inf e NaN voltam iguais.
Golang.Float64 floor(Golang.Float64 x) =>
    _integral(x, (d) => d.floorToDouble());

/// `math.Ceil(x)`: Ceil(-0.5) = -0.
Golang.Float64 ceil(Golang.Float64 x) => _integral(x, (d) => d.ceilToDouble());

/// `math.Trunc(x)`: Trunc(-0.5) = -0.
Golang.Float64 trunc(Golang.Float64 x) =>
    _integral(x, (d) => d.truncateToDouble());

// Valor inteiro já é o resultado (inclui ±0, ±Inf e NaN); o resto mantém o
// sinal do argumento, como no Go (resultado zero de um negativo é -0).
Golang.Float64 _integral(Golang.Float64 x, double Function(double) f) {
  final d = x.toDouble();
  if (d.isNaN || d.isInfinite || d == 0) return x;
  return copysign(Golang.Float64(f(d)), x);
}

/// `math.Max(x, y)`: +Inf vence NaN; NaN vence o resto; Max(+0, -0) = +0.
Golang.Float64 max(Golang.Float64 x, Golang.Float64 y) {
  final a = x.toDouble(), b = y.toDouble();
  if (a == double.infinity || b == double.infinity) {
    return Golang.Float64(double.infinity);
  }
  if (a.isNaN || b.isNaN) return Golang.Float64(double.nan);
  if (a == 0 && a == b) return signbit(x) ? y : x;
  return a > b ? x : y;
}

/// `math.Min(x, y)`: -Inf vence NaN; NaN vence o resto; Min(+0, -0) = -0.
Golang.Float64 min(Golang.Float64 x, Golang.Float64 y) {
  final a = x.toDouble(), b = y.toDouble();
  if (a == double.negativeInfinity || b == double.negativeInfinity) {
    return Golang.Float64(double.negativeInfinity);
  }
  if (a.isNaN || b.isNaN) return Golang.Float64(double.nan);
  if (a == 0 && a == b) return signbit(x) ? x : y;
  return a < b ? x : y;
}

/// `math.Float64bits(f)`: os bits IEEE 754 de f.
// ponytail: payload de NaN não é portável (o JS canoniza), e `naN()` é o NaN
// do Dart, não o 0x7ff8000000000001 do Go; bits exatos só fora do NaN.
Golang.Uint64 float64bits(Golang.Float64 f) {
  final b = ByteData(8)..setFloat64(0, f.toDouble());
  return Golang.Uint64().$make(b.getUint32(0), b.getUint32(4));
}

/// `math.Float64frombits(b)`.
Golang.Float64 float64frombits(Golang.Uint64 b) => Golang.Float64(
  (ByteData(8)
        ..setUint32(0, b.$hi)
        ..setUint32(4, b.$lo))
      .getFloat64(0),
);

/// `math.Float32bits(f)`.
Golang.Uint32 float32bits(Golang.Float32 f) =>
    Golang.Uint32((ByteData(4)..setFloat32(0, f.toDouble())).getUint32(0));

/// `math.Float32frombits(b)`.
Golang.Float32 float32frombits(Golang.Uint32 b) =>
    Golang.Float32((ByteData(4)..setUint32(0, b.toInt())).getFloat32(0));

// Transcendentais e afins: porta do Go puro (`src/math/pure.dart`), o
// resultado do Go sem assembly; no amd64 o `go run` usa assembly em Exp/Log
// (e nas que as chamam) e pode diferir no último bit.
Golang.Float64 _f(double v) => Golang.Float64(v);

/// `math.Exp(x)`.
Golang.Float64 exp(Golang.Float64 x) => _f(pure.exp(x.toDouble()));

/// `math.Expm1(x)`.
Golang.Float64 expm1(Golang.Float64 x) => _f(pure.expm1(x.toDouble()));

/// `math.Log(x)`.
Golang.Float64 log(Golang.Float64 x) => _f(pure.log(x.toDouble()));

/// `math.Log2(x)`.
Golang.Float64 log2(Golang.Float64 x) => _f(pure.log2(x.toDouble()));

/// `math.Log10(x)`.
Golang.Float64 log10(Golang.Float64 x) => _f(pure.log10(x.toDouble()));

/// `math.Log1p(x)`.
Golang.Float64 log1p(Golang.Float64 x) => _f(pure.log1p(x.toDouble()));

/// `math.Pow(x, y)`.
Golang.Float64 pow(Golang.Float64 x, Golang.Float64 y) =>
    _f(pure.pow(x.toDouble(), y.toDouble()));

/// `math.Frexp(f)`: (frac, exp).
(Golang.Float64, Golang.Int) frexp(Golang.Float64 f) {
  final (frac, e) = pure.frexp(f.toDouble());
  return (_f(frac), Golang.Int(e));
}

/// `math.Ldexp(frac, exp)`.
Golang.Float64 ldexp(Golang.Float64 frac, Golang.Int exp) {
  // Expoente fora de ±2**31: o resultado já é 0 ou ±Inf.
  final e = exp.toInt().clamp(-0x80000000, 0x7fffffff);
  return _f(pure.ldexp(frac.toDouble(), e));
}

/// `math.Modf(f)`: (parte inteira, fração).
(Golang.Float64, Golang.Float64) modf(Golang.Float64 f) {
  final (i, fr) = pure.modf(f.toDouble());
  return (_f(i), _f(fr));
}

/// `math.Mod(x, y)`.
Golang.Float64 mod(Golang.Float64 x, Golang.Float64 y) =>
    _f(pure.mod(x.toDouble(), y.toDouble()));

/// `math.Round(x)`: meio para longe de zero.
Golang.Float64 round(Golang.Float64 x) => _f(pure.round(x.toDouble()));

/// `math.RoundToEven(x)`.
Golang.Float64 roundToEven(Golang.Float64 x) =>
    _f(pure.roundToEven(x.toDouble()));

/// `math.Nextafter(x, y)`.
Golang.Float64 nextafter(Golang.Float64 x, Golang.Float64 y) =>
    _f(pure.nextafter(x.toDouble(), y.toDouble()));

/// `math.Cbrt(x)`.
Golang.Float64 cbrt(Golang.Float64 x) => _f(pure.cbrt(x.toDouble()));

/// `math.Sin(x)`.
Golang.Float64 sin(Golang.Float64 x) => _f(pure.sin(x.toDouble()));

/// `math.Cos(x)`.
Golang.Float64 cos(Golang.Float64 x) => _f(pure.cos(x.toDouble()));

/// `math.Tan(x)`.
Golang.Float64 tan(Golang.Float64 x) => _f(pure.tan(x.toDouble()));

/// `math.Sincos(x)`: (sin, cos).
(Golang.Float64, Golang.Float64) sincos(Golang.Float64 x) {
  final (s, c) = pure.sincos(x.toDouble());
  return (_f(s), _f(c));
}

/// `math.Atan(x)`.
Golang.Float64 atan(Golang.Float64 x) => _f(pure.atan(x.toDouble()));

/// `math.Lgamma(x)`: (log|Γ(x)|, sinal).
(Golang.Float64, Golang.Int) lgamma(Golang.Float64 x) {
  final (l, s) = pure.lgamma(x.toDouble());
  return (_f(l), Golang.Int(s));
}

/// `math.Gamma(x)`.
Golang.Float64 gamma(Golang.Float64 x) => _f(pure.gamma(x.toDouble()));

/// `math.Erfc(x)`.
Golang.Float64 erfc(Golang.Float64 x) => _f(pure.erfc(x.toDouble()));
