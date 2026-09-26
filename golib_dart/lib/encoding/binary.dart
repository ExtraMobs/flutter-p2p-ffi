/// Shim do pacote Go `encoding/binary` (só `LittleEndian`/`BigEndian`).
// ignore_for_file: library_prefixes
library;

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;

typedef _Bytes = Slice<Golang.Uint8>;

int _b(_Bytes s, int i) => s[i].toInt();

/// A ordem de bytes de `binary.LittleEndian` e `binary.BigEndian`. Os
/// acessos começam pelo último índice, como a dica de bounds check do Go:
/// slice curto dá o mesmo pânico (`index out of range [n] with length m`).
final class ByteOrder {
  const ByteOrder._(this._big);

  final bool _big;

  // Índice do byte de peso k (0 = menos significativo) numa palavra de n.
  int _at(int k, int n) => _big ? n - 1 - k : k;

  int _get(_Bytes b, int n, int from) {
    b[n - 1];
    var v = 0;
    for (var k = from + 3; k >= from; k--) {
      v = (v << 8) | (k < n ? _b(b, _at(k, n)) : 0);
    }
    return v & 0xffffffff;
  }

  void _put(_Bytes b, int n, int v, int from) {
    for (var k = from; k < from + 4 && k < n; k++) {
      b[_at(k, n)] = Golang.Uint8((v >> (8 * (k - from))) & 0xff);
    }
  }

  /// `Uint16(b)`.
  Golang.Uint16 uint16(_Bytes b) => Golang.Uint16(_get(b, 2, 0));

  /// `Uint32(b)`.
  Golang.Uint32 uint32(_Bytes b) => Golang.Uint32(_get(b, 4, 0));

  /// `Uint64(b)`.
  Golang.Uint64 uint64(_Bytes b) =>
      Golang.Uint64().$make(_get(b, 8, 4), _get(b, 8, 0));

  /// `PutUint16(b, v)`.
  void putUint16(_Bytes b, Golang.Uint16 v) {
    b[1];
    _put(b, 2, v.toInt(), 0);
  }

  /// `PutUint32(b, v)`.
  void putUint32(_Bytes b, Golang.Uint32 v) {
    b[3];
    _put(b, 4, v.toInt(), 0);
  }

  /// `PutUint64(b, v)`.
  void putUint64(_Bytes b, Golang.Uint64 v) {
    b[7];
    _put(b, 8, v.$lo, 0);
    _put(b, 8, v.$hi, 4);
  }
}

/// `binary.LittleEndian`.
const littleEndian = ByteOrder._(false);

/// `binary.BigEndian`.
const bigEndian = ByteOrder._(true);
