part of '../../io.dart';

/// `1<<63 - 1` (`math.MaxInt64`): sem depender de literal fora do intervalo
/// seguro do `int` da plataforma (JS).
final Golang.Int64 _maxInt64 = Golang.Int64.fromBigInt(
  (BigInt.one << 63) - BigInt.one,
);

/// `io.NewSectionReader(r, off, n)`.
SectionReader newSectionReader(ReaderAt? r, Golang.Int64 off, Golang.Int64 n) {
  final remaining = off <= _maxInt64 - n ? n + off : _maxInt64;
  return SectionReader._(r, off, off, remaining, n);
}

/// `io.SectionReader`: `Read`, `Seek` e `ReadAt` sobre uma seção de um
/// [ReaderAt] (offset e tamanho constantes após a criação). As duas formas
/// (D2) de `Read`/`ReadAt` esperam o `ReadAt` de baixo.
final class SectionReader extends GoStruct<SectionReader>
    implements Reader, Seeker, ReaderAt {
  SectionReader._(this._r, this._base, this._off, this._limit, this._n);

  /// Zero de `io.SectionReader` (campos não exportados zerados).
  SectionReader()
    : this._(
        null,
        Golang.Int64(),
        Golang.Int64(),
        Golang.Int64(),
        Golang.Int64(),
      );

  /// `(*SectionReader)(nil)` dentro de uma interface.
  static final SectionReader $nil = SectionReader()..$nilPtr = true;

  ReaderAt? _r; // r: constante após a criação
  Golang.Int64 _base; // constante após a criação
  Golang.Int64 _off;
  Golang.Int64 _limit; // constante após a criação
  Golang.Int64 _n; // constante após a criação

  @override
  String get $goType => 'io.SectionReader';

  @override
  List<String> get $ptrMethods => const [
    'Read',
    'Seek',
    'ReadAt',
    'Size',
    'Outer',
  ];

  @override
  SectionReader $copy() => SectionReader._(_r, _base, _off, _limit, _n);

  @override
  void $set(SectionReader o) {
    _r = o._r;
    _base = o._base;
    _off = o._off;
    _limit = o._limit;
    _n = o._n;
  }

  @override
  List<Object?> get $fields => [_r, _base, _off, _limit, _n];

  @override
  List<String> get $fieldNames => const ['r', 'base', 'off', 'limit', 'n'];

  /// O pedaço de [p] que cabe antes de `limit`; null se acabou.
  Slice<Golang.Uint8>? _window(Slice<Golang.Uint8> p) {
    if (_off >= _limit) return null;
    final max = _limit - _off;
    return Golang.Int64(p.length) > max ? p.slice(0, max.toInt()) : p;
  }

  /// `Read(p)`.
  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p) {
    final pp = _window(p);
    if (pp == null) return (Golang.Int(0), eof);
    final (n, err) = _r!.readAt(pp, _off);
    _off += Golang.Int64.from(n);
    return (n, err);
  }

  /// `Read(p)` suspensivo.
  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> p) async {
    final pp = _window(p);
    if (pp == null) return (Golang.Int(0), eof);
    final (n, err) = await _r!.readAt$async(pp, _off);
    _off += Golang.Int64.from(n);
    return (n, err);
  }

  /// `Seek(offset, whence)`.
  @override
  (Golang.Int64, GoError?) seek(Golang.Int64 offset, Golang.Int whence) {
    var off = offset;
    switch (whence.toInt()) {
      case 0: // io.SeekStart
        off += _base;
      case 1: // io.SeekCurrent
        off += _off;
      case 2: // io.SeekEnd
        off += _limit;
      default:
        return (Golang.Int64(0), _errWhence);
    }
    if (off < _base) return (Golang.Int64(0), _errOffset);
    _off = off;
    return (off - _base, null);
  }

  /// `ReadAt(p, off)`.
  @override
  (Golang.Int, GoError?) readAt(Slice<Golang.Uint8> p, Golang.Int64 off) {
    if (off < Golang.Int64(0) || off >= size()) return (Golang.Int(0), eof);
    final o = off + _base;
    final max = _limit - o;
    if (Golang.Int64(p.length) > max) {
      final (n, err) = _r!.readAt(p.slice(0, max.toInt()), o);
      return (n, err ?? eof);
    }
    return _r!.readAt(p, o);
  }

  /// `ReadAt(p, off)` suspensivo.
  @override
  Future<(Golang.Int, GoError?)> readAt$async(
    Slice<Golang.Uint8> p,
    Golang.Int64 off,
  ) async {
    if (off < Golang.Int64(0) || off >= size()) return (Golang.Int(0), eof);
    final o = off + _base;
    final max = _limit - o;
    if (Golang.Int64(p.length) > max) {
      final (n, err) = await _r!.readAt$async(p.slice(0, max.toInt()), o);
      return (n, err ?? eof);
    }
    return _r!.readAt$async(p, o);
  }

  /// `Size()`.
  Golang.Int64 size() => _limit - _base;

  /// `Outer()`.
  (ReaderAt?, Golang.Int64, Golang.Int64) outer() => (_r, _base, _n);
}
