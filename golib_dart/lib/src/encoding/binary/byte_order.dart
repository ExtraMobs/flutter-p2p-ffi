part of '../../../encoding/binary.dart';

int _b(_Bytes s, int i) => s[i].toInt();

/// A ordem de bytes de `binary.LittleEndian`, `BigEndian` e `NativeEndian`.
/// No Go são as structs vazias `littleEndian`, `bigEndian` e `nativeEndian`
/// (as subclasses [BigEndian], [LittleEndian], [NativeEndian]; o g2d as
/// mapeia em `SHIM_TYPES`), que implementam as interfaces `ByteOrder` e
/// `AppendByteOrder`, esta base. Os acessos começam pelo último índice, como
/// a dica de bounds check do Go: slice curto dá o mesmo pânico
/// (`index out of range [n] with length m`).
abstract base class ByteOrder extends GoStruct<ByteOrder>
    implements fmt.Stringer {
  ByteOrder._(this._big, this._name);

  final bool _big;
  final String _name;

  static const _ms = [
    'AppendUint16',
    'AppendUint32',
    'AppendUint64',
    'GoString',
    'PutUint16',
    'PutUint32',
    'PutUint64',
    'String',
    'Uint16',
    'Uint32',
    'Uint64',
  ];

  @override
  String get $goType => 'binary.${_name[0].toLowerCase()}${_name.substring(1)}';
  @override
  List<String> get $valueMethods => _ms;
  @override
  List<String> get $ptrMethods => _ms;
  @override
  void $set(ByteOrder o) {} // struct vazia
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];

  /// `String()`: `LittleEndian`, `BigEndian`, `NativeEndian`.
  @override
  Golang.String string() => Golang.String.fromDart(_name);

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

  // Os n bytes de (hi, lo) na ordem desta ByteOrder.
  List<Golang.Uint8> _bytes(int n, int hi, int lo) => [
    for (var i = 0; i < n; i++) Golang.Uint8(_byteOf(_at(i, n), hi, lo)),
  ];

  static int _byteOf(int k, int hi, int lo) =>
      (k < 4 ? lo >> (8 * k) : hi >> (8 * (k - 4))) & 0xff;

  /// `AppendUint16(b, v)`.
  _Bytes appendUint16(_Bytes b, Golang.Uint16 v) =>
      b.append(_bytes(2, 0, v.toInt()));

  /// `AppendUint32(b, v)`.
  _Bytes appendUint32(_Bytes b, Golang.Uint32 v) =>
      b.append(_bytes(4, 0, v.toInt()));

  /// `AppendUint64(b, v)`.
  _Bytes appendUint64(_Bytes b, Golang.Uint64 v) =>
      b.append(_bytes(8, v.$hi, v.$lo));
}

/// O tipo `binary.littleEndian`.
final class LittleEndian extends ByteOrder {
  LittleEndian() : super._(false, 'LittleEndian');

  @override
  LittleEndian $copy() => LittleEndian();
}

/// O tipo `binary.bigEndian`.
final class BigEndian extends ByteOrder {
  BigEndian() : super._(true, 'BigEndian');

  @override
  BigEndian $copy() => BigEndian();
}

/// O tipo `binary.nativeEndian`: little-endian (o contexto de build do g2d
/// é amd64).
final class NativeEndian extends ByteOrder {
  NativeEndian() : super._(false, 'NativeEndian');

  @override
  NativeEndian $copy() => NativeEndian();
}

/// `binary.LittleEndian`.
final littleEndian = LittleEndian();

/// `binary.BigEndian`.
final bigEndian = BigEndian();

/// `binary.NativeEndian`.
final nativeEndian = NativeEndian();
