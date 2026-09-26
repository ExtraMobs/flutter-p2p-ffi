/// Shim do pacote Go `encoding/binary`: `LittleEndian`/`BigEndian`/
/// `NativeEndian`, varints e `Read`/`Write` sobre valores de tamanho fixo
/// (sem reflexão: ponteiro, slice e array de inteiros, floats e bool; struct
/// no `Write`).
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;
import '../fmt.dart' as fmt;
import '../io.dart' as io;

typedef _Bytes = Slice<Golang.Uint8>;

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

const _byte = Elem<Golang.Uint8>(1, Golang.Uint8.new, ofInt: Golang.Uint8.from);
final _x80 = Golang.Uint64(0x80);
final _x7f = Golang.Uint8(0x7f);
final _hiBit = Golang.Uint8(0x80);

/// `AppendUvarint(buf, x)`.
_Bytes appendUvarint(_Bytes buf, Golang.Uint64 x) {
  while (x >= _x80) {
    buf = buf.append([Golang.Uint8.from(x) | _hiBit]);
    x = x >> 7;
  }
  return buf.append([Golang.Uint8.from(x)]);
}

/// `PutUvarint(buf, x)`: bytes escritos (buf curto: o pânico de índice).
Golang.Int putUvarint(_Bytes buf, Golang.Uint64 x) {
  var i = 0;
  while (x >= _x80) {
    buf[i] = Golang.Uint8.from(x) | _hiBit;
    x = x >> 7;
    i++;
  }
  buf[i] = Golang.Uint8.from(x);
  return Golang.Int(i + 1);
}

/// `Uvarint(buf)`: (valor, n); n == 0 se buf acabou, n < 0 no overflow.
(Golang.Uint64, Golang.Int) uvarint(_Bytes buf) {
  var x = Golang.Uint64(0);
  var s = 0;
  for (var i = 0; i < buf.length; i++) {
    final b = buf[i];
    if (i == 10) return (Golang.Uint64(0), Golang.Int(-(i + 1)));
    if (b.toInt() < 0x80) {
      if (i == 9 && b.toInt() > 1) {
        return (Golang.Uint64(0), Golang.Int(-(i + 1)));
      }
      return (x | (Golang.Uint64.from(b) << s), Golang.Int(i + 1));
    }
    x = x | (Golang.Uint64.from(b & _x7f) << s);
    s += 7;
  }
  return (Golang.Uint64(0), Golang.Int(0));
}

Golang.Uint64 _zigzag(Golang.Int64 x) {
  final ux = Golang.Uint64.from(x) << 1;
  return x < Golang.Int64(0) ? ~ux : ux;
}

/// `AppendVarint(buf, x)`.
_Bytes appendVarint(_Bytes buf, Golang.Int64 x) =>
    appendUvarint(buf, _zigzag(x));

/// `PutVarint(buf, x)`.
Golang.Int putVarint(_Bytes buf, Golang.Int64 x) => putUvarint(buf, _zigzag(x));

Golang.Int64 _unzigzag(Golang.Uint64 ux) {
  final x = Golang.Int64.from(ux >> 1);
  return (ux & Golang.Uint64(1)) != Golang.Uint64(0) ? ~x : x;
}

/// `Varint(buf)`: (valor, n) como em [uvarint].
(Golang.Int64, Golang.Int) varint(_Bytes buf) {
  final (ux, n) = uvarint(buf);
  return (_unzigzag(ux), n);
}

final GoError _errOverflow = ErrorString(
  Golang.String.fromDart('binary: varint overflows a 64-bit integer'),
);

/// `ReadUvarint(r)`.
(Golang.Uint64, GoError?) readUvarint(io.ByteReader? r) {
  var x = Golang.Uint64(0);
  var s = 0;
  for (var i = 0; i < 10; i++) {
    final (b, err) = r!.readByte();
    if (err != null) {
      return (x, i > 0 && identical(err, io.eof) ? io.errUnexpectedEOF : err);
    }
    if (b.toInt() < 0x80) {
      if (i == 9 && b.toInt() > 1) return (x, _errOverflow);
      return (x | (Golang.Uint64.from(b) << s), null);
    }
    x = x | (Golang.Uint64.from(b & _x7f) << s);
    s += 7;
  }
  return (x, _errOverflow);
}

/// `ReadVarint(r)`.
(Golang.Int64, GoError?) readVarint(io.ByteReader? r) {
  final (ux, err) = readUvarint(r);
  return (_unzigzag(ux), err);
}

// Bytes de um valor de tamanho fixo (bool, inteiro de largura fixa, float),
// ou null. `int`/`uint`/`uintptr` não têm tamanho fixo no Go.
int? _size(Object? v) => switch (v) {
  bool() => 1,
  Golang.Int() || Golang.Uint() || Golang.Uintptr() => null,
  Golang.SmallIntBase n => n.$width ~/ 8,
  Golang.IntBase() => 8,
  Golang.FloatBase f => f.$bits ~/ 8,
  _ => null,
};

// Tamanho codificado de v (-1 se algo não tem tamanho fixo).
int _dataSize(Object? v) {
  switch (v) {
    case Slice s:
      return _each(s.elem.zero(), s.length);
    case GoArray a:
      return _each(a.elem.zero(), a.length);
    case GoStruct s:
      var total = 0;
      for (final f in s.$fields) {
        final n = _dataSize(f);
        if (n < 0) return -1;
        total += n;
      }
      return total;
  }
  return _size(v) ?? -1;
}

int _each(Object? zero, int n) {
  final one = _dataSize(zero);
  return one < 0 ? -1 : one * n;
}

void _encode(List<Golang.Uint8> out, ByteOrder o, Object? v) {
  switch (v) {
    case bool b:
      out.add(Golang.Uint8(b ? 1 : 0));
    case Golang.SmallIntBase n:
      final w = n.$width ~/ 8;
      // Os w bytes baixos do complemento de dois (o `%` Dart é euclidiano).
      out.addAll(
        o._bytes(w, 0, n.toInt() % (w == 4 ? 0x100000000 : 1 << (8 * w))),
      );
    case Golang.WideIntBase n:
      out.addAll(o._bytes(8, n.$hi, n.$lo));
    case Golang.FloatBase f:
      final bd = ByteData(8);
      if (f.$bits == 32) {
        bd.setFloat32(0, f.toDouble());
        out.addAll(o._bytes(4, 0, bd.getUint32(0)));
      } else {
        bd.setFloat64(0, f.toDouble());
        out.addAll(o._bytes(8, bd.getUint32(0), bd.getUint32(4)));
      }
    case Slice s:
      for (final e in s.items) {
        _encode(out, o, e);
      }
    case GoArray a:
      for (final e in a.items) {
        _encode(out, o, e);
      }
    case GoStruct s:
      for (final e in s.$fields) {
        _encode(out, o, e);
      }
  }
}

// Um valor do mesmo tipo de [sample] lido de b[at:] na ordem o.
Object? _decodeOne(ByteOrder o, List<int> b, int at, Object? sample) {
  int word(int n, int from) {
    var v = 0;
    for (var k = from + 3; k >= from; k--) {
      v = v * 256 + (k < n ? b[at + o._at(k, n)] : 0);
    }
    return v;
  }

  switch (sample) {
    case bool():
      return b[at] != 0;
    case Golang.SmallIntBase n:
      final w = n.$width ~/ 8;
      final span = w == 4 ? 0x100000000 : 1 << (8 * w);
      var v = word(w, 0);
      if (n.$signed && v >= span ~/ 2) v -= span;
      return n.$make(v);
    case Golang.WideIntBase n:
      return n.$make(word(8, 4), word(8, 0));
    case Golang.FloatBase f:
      final bd = ByteData(8);
      if (f.$bits == 32) {
        bd.setUint32(0, word(4, 0));
        return f.$wrapDouble(bd.getFloat32(0));
      }
      bd
        ..setUint32(0, word(8, 4))
        ..setUint32(4, word(8, 0));
      return f.$wrapDouble(bd.getFloat64(0));
  }
  throw UnimplementedError('binary.Read: ${goTypeName(sample)}');
}

// Preenche data (slice, array, ou o alvo de um ponteiro) a partir de b.
void _decodeInto(ByteOrder o, List<int> b, Object data) {
  switch (data) {
    case Slice s:
      final z = s.elem.zero();
      final n = _dataSize(z);
      for (var i = 0; i < s.length; i++) {
        s[i] = _decodeOne(o, b, i * n, z);
      }
    case GoArray a:
      final z = a.elem.zero();
      final n = _dataSize(z);
      for (var i = 0; i < a.length; i++) {
        a[i] = _decodeOne(o, b, i * n, z);
      }
    case Ptr p:
      p.value = _decodeOne(o, b, 0, p.value);
  }
}

/// `binary.Read(r, order, data)`: data é ponteiro para valor de tamanho
/// fixo, slice ou ponteiro para array. ⚠️ struct: UnimplementedError (o
/// runtime não escreve campo por índice).
GoError? read(io.Reader? r, ByteOrder? order, Object? data) {
  final target = data is Ptr ? data.value : data;
  if (target is GoStruct) {
    throw UnimplementedError('binary.Read em struct (${goTypeName(data)})');
  }
  final size = data is Ptr || data is Slice || data is GoArray
      ? _dataSize(target)
      : -1;
  if (size < 0) {
    return ErrorString(
      Golang.String.fromDart('binary.Read: invalid type ${goTypeName(data)}'),
    );
  }
  final buf = Slice<Golang.Uint8>.make(size, size, _byte);
  final (_, err) = io.readFull(r, buf);
  if (err != null) return err;
  _decodeInto(order!, [for (final c in buf.items) c.toInt()], data!);
  return null;
}

/// `binary.Write(w, order, data)`: valor de tamanho fixo (ou ponteiro para
/// ele), slice, array ou struct; `[]byte` vai direto.
GoError? write(io.Writer? w, ByteOrder? order, Object? data) {
  if (data is Slice<Golang.Uint8>) {
    final (_, err) = w!.write(data);
    return err;
  }
  final v = data is Ptr ? data.value : data;
  if (_dataSize(v) < 0) {
    return ErrorString(
      Golang.String.fromDart(
        'binary.Write: some values are not fixed-sized in type '
        '${goTypeName(data)}',
      ),
    );
  }
  final out = <Golang.Uint8>[];
  _encode(out, order!, v);
  final (_, err) = w!.write(Slice.of(out, _byte));
  return err;
}
