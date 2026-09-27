part of '../../../encoding/binary.dart';

const _byte = Elem<Golang.Uint8>(1, Golang.Uint8.new, ofInt: Golang.Uint8.from);

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
