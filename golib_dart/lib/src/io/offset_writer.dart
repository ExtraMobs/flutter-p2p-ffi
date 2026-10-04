part of '../../io.dart';

/// `io.NewOffsetWriter(w, off)`.
OffsetWriter newOffsetWriter(WriterAt? w, Golang.Int64 off) =>
    OffsetWriter._(w, off, off);

/// `io.OffsetWriter`: mapeia escritas no offset `base` para `base+off` no
/// [WriterAt] de baixo. As duas formas (D2) esperam o de baixo.
final class OffsetWriter extends GoStruct<OffsetWriter>
    implements Writer, WriterAt, Seeker {
  OffsetWriter._(this._w, this._base, this._off);

  /// Zero de `io.OffsetWriter` (campos não exportados zerados).
  OffsetWriter() : this._(null, Golang.Int64(), Golang.Int64());

  /// `(*OffsetWriter)(nil)` dentro de uma interface.
  static final OffsetWriter $nil = OffsetWriter()..$nilPtr = true;

  WriterAt? _w;
  Golang.Int64 _base; // the original offset
  Golang.Int64 _off; // the current offset

  @override
  String get $goType => 'io.OffsetWriter';

  @override
  List<String> get $ptrMethods => const ['Write', 'WriteAt', 'Seek'];

  @override
  OffsetWriter $copy() => OffsetWriter._(_w, _base, _off);

  @override
  void $set(OffsetWriter o) {
    _w = o._w;
    _base = o._base;
    _off = o._off;
  }

  @override
  List<Object?> get $fields => [_w, _base, _off];

  @override
  List<String> get $fieldNames => const ['w', 'base', 'off'];

  /// `Write(p)`.
  @override
  (Golang.Int, GoError?) write(Slice<Golang.Uint8> p) {
    final (n, err) = _w!.writeAt(p, _off);
    _off += Golang.Int64.from(n);
    return (n, err);
  }

  /// `Write(p)` suspensivo.
  @override
  Future<(Golang.Int, GoError?)> write$async(Slice<Golang.Uint8> p) async {
    final (n, err) = await _w!.writeAt$async(p, _off);
    _off += Golang.Int64.from(n);
    return (n, err);
  }

  /// `WriteAt(p, off)`.
  @override
  (Golang.Int, GoError?) writeAt(Slice<Golang.Uint8> p, Golang.Int64 off) {
    if (off < Golang.Int64(0)) return (Golang.Int(0), _errOffset);
    return _w!.writeAt(p, off + _base);
  }

  /// `WriteAt(p, off)` suspensivo.
  @override
  Future<(Golang.Int, GoError?)> writeAt$async(
    Slice<Golang.Uint8> p,
    Golang.Int64 off,
  ) async {
    if (off < Golang.Int64(0)) return (Golang.Int(0), _errOffset);
    return _w!.writeAt$async(p, off + _base);
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
      default:
        return (Golang.Int64(0), _errWhence);
    }
    if (off < _base) return (Golang.Int64(0), _errOffset);
    _off = off;
    return (off - _base, null);
  }
}
