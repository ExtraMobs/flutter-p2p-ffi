/// Shim do pacote Go `crypto/subtle` (`XORBytes`, `ConstantTimeCompare`).
// ignore_for_file: library_prefixes
library;

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;

/// `subtle.XORBytes(dst, x, y)`: dst[i] = x[i] ^ y[i] para
/// i < n = min(len(x), len(y)); devolve n. Pânico se dst é curto ou se
/// sobrepõe x ou y fora dos índices correspondentes, como no Go.
Golang.Int xorBytes(
  Slice<Golang.Uint8> dst,
  Slice<Golang.Uint8> x,
  Slice<Golang.Uint8> y,
) {
  final n = x.length < y.length ? x.length : y.length;
  if (n == 0) return Golang.Int();
  if (n > dst.length) {
    throw Panic(Golang.String.fromDart('subtle.XORBytes: dst too short'));
  }
  final d = dst.slice(0, n);
  if (inexactOverlap(d, x.slice(0, n)) || inexactOverlap(d, y.slice(0, n))) {
    throw Panic(Golang.String.fromDart('subtle.XORBytes: invalid overlap'));
  }
  for (var i = 0; i < n; i++) {
    d[i] = x[i] ^ y[i];
  }
  return Golang.Int(n);
}

/// `subtle.ConstantTimeCompare(x, y)`: 1 se iguais (tamanho e bytes), senão
/// 0. Percorre tudo sem sair cedo, como o Go.
Golang.Int constantTimeCompare(Slice<Golang.Uint8> x, Slice<Golang.Uint8> y) {
  if (x.length != y.length) return Golang.Int();
  var v = 0;
  for (var i = 0; i < x.length; i++) {
    v |= x[i].toInt() ^ y[i].toInt();
  }
  return Golang.Int(v == 0 ? 1 : 0);
}
