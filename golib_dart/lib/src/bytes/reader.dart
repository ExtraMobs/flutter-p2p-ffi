part of '../../bytes.dart';

const _seekStart = 0, _seekCurrent = 1, _seekEnd = 2;

/// `bytes.Reader`: struct de shim usada por ponteiro (`*Reader`, do
/// `NewReader`). Porta de `bytes/reader.go` do Go 1.26. Implementa as
/// interfaces de shim que `io.dart` já tem (`Reader`, `ReaderAt`,
/// `ByteReader`, `Seeker`); `RuneReader`, `RuneScanner`, `ByteScanner` e
/// `WriterTo` ainda não existem em `io.dart`.
/// ponytail: adicionar ao `implements` quando `io.RuneReader`,
/// `io.RuneScanner`, `io.ByteScanner` e `io.WriterTo` existirem.
final class Reader extends GoStruct<Reader>
    with io.ReaderSync, io.ReaderAtSync, io.ByteReaderSync
    implements io.Reader, io.ReaderAt, io.ByteReader, io.Seeker {
  Reader();

  /// `(*Reader)(nil)` dentro de uma interface.
  static final Reader $nil = Reader()..$nilPtr = true;

  _Bytes _s = _nilBytes();
  int _i = 0; // índice de leitura atual
  int _prevRune = 0; // índice da runa anterior, ou < 0; 0 no zero value

  @override
  String get $goType => 'bytes.Reader';

  @override
  List<String> get $ptrMethods => const [
    'Len',
    'Size',
    'Read',
    'ReadAt',
    'ReadByte',
    'UnreadByte',
    'ReadRune',
    'UnreadRune',
    'Seek',
    'WriteTo',
    'Reset',
  ];

  @override
  Reader $copy() => Reader()
    .._s = _s
    .._i = _i
    .._prevRune = _prevRune;

  @override
  void $set(Reader o) {
    _s = o._s;
    _i = o._i;
    _prevRune = o._prevRune;
  }

  @override
  List<Object?> get $fields => [_s, Golang.Int64(_i), Golang.Int(_prevRune)];

  @override
  List<String> get $fieldNames => const ['s', 'i', 'prevRune'];

  /// `Len()`.
  Golang.Int len() => Golang.Int(_i >= _s.length ? 0 : _s.length - _i);

  /// `Size()`.
  Golang.Int64 size() => Golang.Int64(_s.length);

  /// `Read(b)`.
  @override
  (Golang.Int, GoError?) read(_Bytes b) {
    if (_i >= _s.length) return (Golang.Int(0), io.eof);
    _prevRune = -1;
    final n = b.copyFrom(_s.slice(_i));
    _i += n;
    return (Golang.Int(n), null);
  }

  /// `ReadAt(b, off)`: não muda o estado do Reader, como o `io.ReaderAt`.
  @override
  (Golang.Int, GoError?) readAt(_Bytes b, Golang.Int64 off) {
    final o = off.toInt();
    if (o < 0) {
      return (
        Golang.Int(0),
        ErrorString(
          Golang.String.fromDart('bytes.Reader.ReadAt: negative offset'),
        ),
      );
    }
    if (o >= _s.length) return (Golang.Int(0), io.eof);
    final n = b.copyFrom(_s.slice(o));
    return (Golang.Int(n), n < b.length ? io.eof : null);
  }

  /// `ReadByte()`.
  @override
  (Golang.Uint8, GoError?) readByte() {
    _prevRune = -1;
    if (_i >= _s.length) return (Golang.Uint8(), io.eof);
    final b = _s[_i];
    _i++;
    return (b, null);
  }

  /// `UnreadByte()`.
  GoError? unreadByte() {
    if (_i <= 0) {
      return ErrorString(
        Golang.String.fromDart(
          'bytes.Reader.UnreadByte: at beginning of slice',
        ),
      );
    }
    _prevRune = -1;
    _i--;
    return null;
  }

  /// `ReadRune()`.
  (Golang.Rune, Golang.Int, GoError?) readRune() {
    if (_i >= _s.length) {
      _prevRune = -1;
      return (Golang.Rune(), Golang.Int(), io.eof);
    }
    _prevRune = _i;
    final c = _s[_i].toInt();
    if (c < 0x80) {
      _i++;
      return (Golang.Rune(c), Golang.Int(1), null);
    }
    final (r, size) = _str(_s.slice(_i)).decodeRune(0);
    _i += size;
    return (Golang.Rune(r), Golang.Int(size), null);
  }

  /// `UnreadRune()`.
  GoError? unreadRune() {
    if (_i <= 0) {
      return ErrorString(
        Golang.String.fromDart(
          'bytes.Reader.UnreadRune: at beginning of slice',
        ),
      );
    }
    if (_prevRune < 0) {
      return ErrorString(
        Golang.String.fromDart(
          'bytes.Reader.UnreadRune: previous operation was not ReadRune',
        ),
      );
    }
    _i = _prevRune;
    _prevRune = -1;
    return null;
  }

  /// `Seek(offset, whence)`: `whence` chega já dobrado pelo g2d
  /// (`io.SeekStart`/`SeekCurrent`/`SeekEnd` são 0/1/2 sem tipo no Go).
  @override
  (Golang.Int64, GoError?) seek(Golang.Int64 offset, Golang.Int whence) {
    _prevRune = -1;
    int abs;
    switch (whence.toInt()) {
      case _seekStart:
        abs = offset.toInt();
      case _seekCurrent:
        abs = _i + offset.toInt();
      case _seekEnd:
        abs = _s.length + offset.toInt();
      default:
        return (
          Golang.Int64(0),
          ErrorString(
            Golang.String.fromDart('bytes.Reader.Seek: invalid whence'),
          ),
        );
    }
    if (abs < 0) {
      return (
        Golang.Int64(0),
        ErrorString(
          Golang.String.fromDart('bytes.Reader.Seek: negative position'),
        ),
      );
    }
    _i = abs;
    return (Golang.Int64(abs), null);
  }

  /// `WriteTo(w)`.
  (Golang.Int64, GoError?) writeTo(io.Writer? w) {
    _prevRune = -1;
    if (_i >= _s.length) return (Golang.Int64(0), null);
    final b = _s.slice(_i);
    final (m, err) = w!.write(b);
    return _wroteTo(b.length, m.toInt(), err);
  }

  /// `WriteTo(w)` suspensivo (D2).
  Future<(Golang.Int64, GoError?)> writeTo$async(io.Writer? w) async {
    _prevRune = -1;
    if (_i >= _s.length) return (Golang.Int64(0), null);
    final b = _s.slice(_i);
    final (m, err) = await w!.write$async(b);
    return _wroteTo(b.length, m.toInt(), err);
  }

  (Golang.Int64, GoError?) _wroteTo(int len, int mi, GoError? err) {
    if (mi > len) {
      throw Panic(
        Golang.String.fromDart('bytes.Reader.WriteTo: invalid Write count'),
      );
    }
    _i += mi;
    if (mi != len && err == null) {
      return (Golang.Int64(mi), io.errShortWrite);
    }
    return (Golang.Int64(mi), err);
  }

  /// `Reset(b)`.
  void reset(_Bytes b) {
    _s = b;
    _i = 0;
    _prevRune = -1;
  }
}

/// `bytes.NewReader(b)`.
Reader? newReader(_Bytes b) => Reader()
  .._s = b
  .._prevRune = -1;
