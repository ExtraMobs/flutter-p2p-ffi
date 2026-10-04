part of '../../io.dart';

/// `io.TeeReader(r, w)`: cada `Read` de `r` é espelhado num `Write` em `w`
/// antes de devolver (sem buffer interno: a escrita termina antes da leitura).
Reader teeReader(Reader? r, Writer? w) => _TeeReader(r, w);

final class _TeeReader implements Reader, Golang.GoTyped {
  _TeeReader(this._r, this._w);

  final Reader? _r;
  final Writer? _w;

  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p) {
    final (n, err) = _r!.read(p);
    if (n.toInt() > 0) {
      final (wn, werr) = _w!.write(p.slice(0, n.toInt()));
      if (werr != null) return (wn, werr);
    }
    return (n, err);
  }

  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> p) async {
    final (n, err) = await _r!.read$async(p);
    if (n.toInt() > 0) {
      final (wn, werr) = await _w!.write$async(p.slice(0, n.toInt()));
      if (werr != null) return (wn, werr);
    }
    return (n, err);
  }

  @override
  String get $goType => 'io.teeReader';

  @override
  List<String> get $methods => const ['Read'];
}
