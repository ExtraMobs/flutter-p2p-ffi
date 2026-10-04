part of '../../io.dart';

/// `io.LimitReader(r, n)`: a implementação é sempre um [LimitedReader].
Reader limitReader(Reader? r, Golang.Int64 n) => LimitedReader(r: r, n: n);

/// `io.LimitedReader`: lê de [r] até [n] bytes; cada `Read` decrementa [n].
/// `Read` devolve `EOF` quando `N <= 0` ou quando o `R` de baixo devolve EOF.
/// As duas formas (D2) são reais: a `$async` espera o `R` de baixo.
final class LimitedReader extends GoStruct<LimitedReader> implements Reader {
  LimitedReader({Reader? r, Golang.Int64? n}) : r = r, n = n ?? Golang.Int64();

  /// `(*LimitedReader)(nil)` dentro de uma interface.
  static final LimitedReader $nil = LimitedReader()..$nilPtr = true;

  /// `R`: o leitor de baixo.
  Reader? r;

  /// `N`: bytes restantes.
  Golang.Int64 n;

  @override
  String get $goType => 'io.LimitedReader';

  @override
  List<String> get $ptrMethods => const ['Read'];

  @override
  LimitedReader $copy() => LimitedReader(r: r, n: n);

  @override
  void $set(LimitedReader o) {
    r = o.r;
    n = o.n;
  }

  @override
  List<Object?> get $fields => [r, n];

  @override
  List<String> get $fieldNames => const ['R', 'N'];

  /// O pedaço de [p] que cabe em [n]; null se acabou.
  Slice<Golang.Uint8>? _window(Slice<Golang.Uint8> p) {
    if (n <= Golang.Int64(0)) return null;
    return Golang.Int64(p.length) > n ? p.slice(0, n.toInt()) : p;
  }

  /// `(*LimitedReader).Read`.
  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p) {
    final pp = _window(p);
    if (pp == null) return (Golang.Int(0), eof);
    final (nn, err) = r!.read(pp);
    n -= Golang.Int64.from(nn);
    return (nn, err);
  }

  /// `(*LimitedReader).Read` suspensivo.
  @override
  Future<(Golang.Int, GoError?)> read$async(Slice<Golang.Uint8> p) async {
    final pp = _window(p);
    if (pp == null) return (Golang.Int(0), eof);
    final (nn, err) = await r!.read$async(pp);
    n -= Golang.Int64.from(nn);
    return (nn, err);
  }
}
