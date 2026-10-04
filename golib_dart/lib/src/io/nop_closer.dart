part of '../../io.dart';

/// `io.NopCloser(r)`: `ReadCloser` com `Close` sem efeito; se `r` implementa
/// `WriterTo`, o resultado também implementa (encaminhando para `r`).
ReadCloser nopCloser(Reader? r) {
  final Object? o = r;
  if (o case final WriterTo wt when goHasMethod(wt, 'WriteTo')) {
    return _NopCloserWriterTo(r, wt);
  }
  return _NopCloser(r);
}

final class _NopCloser with CloserSync implements ReadCloser, Golang.GoTyped {
  _NopCloser(this._r);

  final Reader? _r;

  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p) => _r!.read(p);

  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> p) =>
      _r!.read$async(p);

  @override
  GoError? close() => null;

  @override
  String get $goType => 'io.nopCloser';

  @override
  List<String> get $methods => const ['Read', 'Close'];
}

final class _NopCloserWriterTo
    with CloserSync
    implements ReadCloser, WriterTo, Golang.GoTyped {
  _NopCloserWriterTo(this._r, this._wt);

  final Reader? _r;
  final WriterTo _wt;

  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p) => _r!.read(p);

  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> p) =>
      _r!.read$async(p);

  @override
  GoError? close() => null;

  @override
  (Golang.Int64, GoError?) writeTo(Writer? w) => _wt.writeTo(w);

  @override
  Future<(Golang.Int64, GoError?)> writeTo$async(Writer? w) =>
      _wt.writeTo$async(w);

  @override
  String get $goType => 'io.nopCloserWriterTo';

  @override
  List<String> get $methods => const ['Read', 'Close', 'WriteTo'];
}
