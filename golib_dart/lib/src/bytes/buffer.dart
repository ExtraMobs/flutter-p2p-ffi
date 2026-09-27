part of '../../bytes.dart';

/// `bytes.MinRead`.
final Golang.Int minRead = Golang.Int(512);

/// `bytes.ErrTooLarge`.
final GoError errTooLarge = ErrorString(
  Golang.String.fromDart('bytes.Buffer: too large'),
);

final GoError _errNegativeRead = ErrorString(
  Golang.String.fromDart(
    'bytes.Buffer: reader returned negative count from Read',
  ),
);

final GoError _errUnreadByte = ErrorString(
  Golang.String.fromDart(
    'bytes.Buffer: UnreadByte: previous operation was not a successful read',
  ),
);

const _smallBufferSize = 64;

const _opRead = -1, _opInvalid = 0, _opReadRune1 = 1;

_Bytes _bytesOf(Golang.String s) =>
    Slice.of([for (final b in s.toBytes()) Golang.Uint8(b)], _byteElem);

/// `bytes.NewBuffer(buf)`.
Buffer? newBuffer(_Bytes buf) => Buffer().._buf = buf;

/// `bytes.NewBufferString(s)`.
Buffer? newBufferString(Golang.String s) => Buffer().._buf = _bytesOf(s);

/// `bytes.Buffer`: struct de shim usada por valor no código gerado
/// (`go.GoStruct`). Porta de `bytes/buffer.go` do Go 1.26, com o mesmo
/// crescimento (`Cap`, `Available`) e os mesmos erros e pânicos.
final class Buffer extends GoStruct<Buffer>
    implements
        io.Reader,
        io.Writer,
        io.ByteReader,
        io.ByteWriter,
        io.StringWriter,
        Stringer {
  Buffer();

  /// `(*Buffer)(nil)` dentro de uma interface.
  static final Buffer $nil = Buffer()..$nilPtr = true;

  _Bytes _buf = _nilBytes();
  int _off = 0;
  int _lastRead = _opInvalid;

  @override
  String get $goType => 'bytes.Buffer';

  @override
  List<String> get $ptrMethods => const [
    'Available',
    'AvailableBuffer',
    'Bytes',
    'Cap',
    'Grow',
    'Len',
    'Next',
    'Peek',
    'Read',
    'ReadByte',
    'ReadBytes',
    'ReadFrom',
    'ReadRune',
    'ReadString',
    'Reset',
    'String',
    'Truncate',
    'UnreadByte',
    'UnreadRune',
    'Write',
    'WriteByte',
    'WriteRune',
    'WriteString',
    'WriteTo',
  ];

  @override
  Buffer $copy() => Buffer()
    .._buf = _buf
    .._off = _off
    .._lastRead = _lastRead;

  @override
  void $set(Buffer o) {
    _buf = o._buf;
    _off = o._off;
    _lastRead = o._lastRead;
  }

  @override
  List<Object?> get $fields => [_buf, Golang.Int(_off), Golang.Int8(_lastRead)];

  @override
  List<String> get $fieldNames => const ['buf', 'off', 'lastRead'];

  bool _empty() => _buf.length <= _off;

  /// `Bytes()`.
  _Bytes bytes() => _buf.slice(_off);

  /// `AvailableBuffer()`.
  _Bytes availableBuffer() => _buf.slice(_buf.length);

  /// `String()` (`<nil>` com receptor nil, como o Go).
  @override
  Golang.String string() =>
      $nilPtr ? Golang.String.fromDart('<nil>') : _str(_buf.slice(_off));

  /// `Peek(n)`.
  (_Bytes, GoError?) peek(Golang.Int n) {
    final k = n.toInt();
    if (_buf.length - _off < k) return (_buf.slice(_off), io.eof);
    return (_buf.slice(_off, _off + k), null);
  }

  /// `Len()`.
  Golang.Int len() => Golang.Int(_buf.length - _off);

  /// `Cap()`.
  Golang.Int cap() => Golang.Int(_buf.capacity);

  /// `Available()`.
  Golang.Int available() => Golang.Int(_buf.capacity - _buf.length);

  /// `Truncate(n)`.
  void truncate(Golang.Int n) {
    final k = n.toInt();
    if (k == 0) {
      reset();
      return;
    }
    _lastRead = _opInvalid;
    if (k < 0 || k > _buf.length - _off) {
      throw Panic(
        Golang.String.fromDart('bytes.Buffer: truncation out of range'),
      );
    }
    _buf = _buf.slice(0, _off + k);
  }

  /// `Reset()`.
  void reset() {
    _buf = _buf.slice(0, 0);
    _off = 0;
    _lastRead = _opInvalid;
  }

  int? _tryGrowByReslice(int n) {
    final l = _buf.length;
    if (n <= _buf.capacity - l) {
      _buf = _buf.slice(0, l + n);
      return l;
    }
    return null;
  }

  int _grow(int n) {
    final m = _buf.length - _off;
    if (m == 0 && _off != 0) reset();
    final i = _tryGrowByReslice(n);
    if (i != null) return i;
    if (_buf.isNil && n <= _smallBufferSize) {
      _buf = Slice.make(n, _smallBufferSize, _byteElem);
      return 0;
    }
    final c = _buf.capacity;
    if (n <= c ~/ 2 - m) {
      _buf.copyFrom(_buf.slice(_off));
    } else {
      _buf = _growSlice(_buf.slice(_off), _off + n);
    }
    _off = 0;
    _buf = _buf.slice(0, m + n);
    return m;
  }

  static _Bytes _growSlice(_Bytes b, int n) {
    var c = b.length + n;
    if (c < 2 * b.capacity) c = 2 * b.capacity;
    // append([]byte(nil), make([]byte, c)...): o cap do growslice do Go.
    final b2 = _nilBytes().appendSlice(Slice.make(c, c, _byteElem));
    final i = b2.copyFrom(b);
    return b2.slice(0, i);
  }

  /// `Grow(n)`.
  void grow(Golang.Int n) {
    final k = n.toInt();
    if (k < 0) {
      throw Panic(Golang.String.fromDart('bytes.Buffer.Grow: negative count'));
    }
    final m = _grow(k);
    _buf = _buf.slice(0, m);
  }

  /// `Write(p)`.
  @override
  (Golang.Int, GoError?) write(_Bytes p) {
    _lastRead = _opInvalid;
    final m = _tryGrowByReslice(p.length) ?? _grow(p.length);
    return (Golang.Int(_buf.slice(m).copyFrom(p)), null);
  }

  /// `WriteString(s)`.
  @override
  (Golang.Int, GoError?) writeString(Golang.String s) => write(_bytesOf(s));

  /// `WriteByte(c)`.
  @override
  GoError? writeByte(Golang.Uint8 c) {
    _lastRead = _opInvalid;
    final m = _tryGrowByReslice(1) ?? _grow(1);
    _buf[m] = c;
    return null;
  }

  /// `WriteRune(r)`.
  (Golang.Int, GoError?) writeRune(Golang.Rune r) {
    final v = r.toInt();
    if (v >= 0 && v < 0x80) {
      writeByte(Golang.Uint8(v));
      return (Golang.Int(1), null);
    }
    _lastRead = _opInvalid;
    final m = _tryGrowByReslice(4) ?? _grow(4);
    final enc = Golang.String.fromRune(r).toBytes();
    _buf = _buf.slice(0, m).append([for (final b in enc) Golang.Uint8(b)]);
    return (Golang.Int(_buf.length - m), null);
  }

  /// `ReadFrom(r)`.
  (Golang.Int64, GoError?) readFrom(io.Reader? r) {
    _lastRead = _opInvalid;
    var n = 0;
    for (;;) {
      final i = _grow(512);
      _buf = _buf.slice(0, i);
      final (m, e) = r!.read(_buf.slice(i, _buf.capacity));
      if (m.toInt() < 0) throw Panic(_errNegativeRead);
      _buf = _buf.slice(0, i + m.toInt());
      n += m.toInt();
      if (identical(e, io.eof)) return (Golang.Int64(n), null);
      if (e != null) return (Golang.Int64(n), e);
    }
  }

  /// `WriteTo(w)`.
  (Golang.Int64, GoError?) writeTo(io.Writer? w) {
    _lastRead = _opInvalid;
    final nBytes = _buf.length - _off;
    var n = 0;
    if (nBytes > 0) {
      final (m, e) = w!.write(_buf.slice(_off));
      final k = m.toInt();
      if (k > nBytes) {
        throw Panic(
          Golang.String.fromDart('bytes.Buffer.WriteTo: invalid Write count'),
        );
      }
      _off += k;
      n = k;
      if (e != null) return (Golang.Int64(n), e);
      if (k != nBytes) return (Golang.Int64(n), io.errShortWrite);
    }
    reset();
    return (Golang.Int64(n), null);
  }

  /// `Read(p)`.
  @override
  (Golang.Int, GoError?) read(_Bytes p) {
    _lastRead = _opInvalid;
    if (_empty()) {
      reset();
      if (p.length == 0) return (Golang.Int(), null);
      return (Golang.Int(), io.eof);
    }
    final n = p.copyFrom(_buf.slice(_off));
    _off += n;
    if (n > 0) _lastRead = _opRead;
    return (Golang.Int(n), null);
  }

  /// `Next(n)`.
  _Bytes next(Golang.Int n) {
    _lastRead = _opInvalid;
    var k = n.toInt();
    final m = _buf.length - _off;
    if (k > m) k = m;
    final data = _buf.slice(_off, _off + k);
    _off += k;
    if (k > 0) _lastRead = _opRead;
    return data;
  }

  /// `ReadByte()`.
  @override
  (Golang.Uint8, GoError?) readByte() {
    if (_empty()) {
      reset();
      return (Golang.Uint8(), io.eof);
    }
    final c = _buf[_off];
    _off++;
    _lastRead = _opRead;
    return (c, null);
  }

  /// `ReadRune()`.
  (Golang.Rune, Golang.Int, GoError?) readRune() {
    if (_empty()) {
      reset();
      return (Golang.Rune(), Golang.Int(), io.eof);
    }
    final c = _buf[_off].toInt();
    if (c < 0x80) {
      _off++;
      _lastRead = _opReadRune1;
      return (Golang.Rune(c), Golang.Int(1), null);
    }
    final (r, n) = _str(_buf.slice(_off)).decodeRune(0);
    _off += n;
    _lastRead = n;
    return (Golang.Rune(r), Golang.Int(n), null);
  }

  /// `UnreadRune()`.
  GoError? unreadRune() {
    if (_lastRead <= _opInvalid) {
      return ErrorString(
        Golang.String.fromDart(
          'bytes.Buffer: UnreadRune: previous operation was not a successful ReadRune',
        ),
      );
    }
    if (_off >= _lastRead) _off -= _lastRead;
    _lastRead = _opInvalid;
    return null;
  }

  /// `UnreadByte()`.
  GoError? unreadByte() {
    if (_lastRead == _opInvalid) return _errUnreadByte;
    _lastRead = _opInvalid;
    if (_off > 0) _off--;
    return null;
  }

  (_Bytes, GoError?) _readSlice(Golang.Uint8 delim) {
    final i = indexByte(_buf.slice(_off), delim).toInt();
    var end = _off + i + 1;
    GoError? err;
    if (i < 0) {
      end = _buf.length;
      err = io.eof;
    }
    final line = _buf.slice(_off, end);
    _off = end;
    _lastRead = _opRead;
    return (line, err);
  }

  /// `ReadBytes(delim)`: cópia (`append(nil, slice...)`).
  (_Bytes, GoError?) readBytes(Golang.Uint8 delim) {
    final (slice, err) = _readSlice(delim);
    return (_nilBytes().appendSlice(slice), err);
  }

  /// `ReadString(delim)`.
  (Golang.String, GoError?) readString(Golang.Uint8 delim) {
    final (slice, err) = _readSlice(delim);
    return (_str(slice), err);
  }
}
