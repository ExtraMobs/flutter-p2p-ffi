/// Shim do pacote Go `math` (constantes vêm dobradas pelo g2d).
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import 'fixed_types/golang.dart' as Golang;

/// `math.NaN()`.
Golang.Float64 naN() => Golang.Float64(double.nan);

/// `math.Copysign(f, sign)`: magnitude de f com o bit de sinal de sign
/// (vale para ±0 e NaN, como no Go).
Golang.Float64 copysign(Golang.Float64 f, Golang.Float64 sign) {
  final b = ByteData(16)
    ..setFloat64(0, f.toDouble())
    ..setFloat64(8, sign.toDouble());
  b.setUint8(0, (b.getUint8(0) & 0x7f) | (b.getUint8(8) & 0x80));
  return Golang.Float64(b.getFloat64(0));
}
