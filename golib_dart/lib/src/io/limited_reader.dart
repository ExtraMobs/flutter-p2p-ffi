part of '../../io.dart';

/// `io.LimitReader(r, n)`: a implementação é sempre um [LimitedReader].
Reader limitReader(Reader? r, Golang.Int64 n) => LimitedReader(r: r, n: n);

/// `io.LimitedReader`: lê de [r] até [n] bytes; cada `Read` decrementa [n].
/// `Read` devolve `EOF` quando `N <= 0` ou quando o `R` de baixo devolve EOF.
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

  /// `(*LimitedReader).Read`.
  @override
  (Golang.Int, GoError?) read(Slice<Golang.Uint8> p) {
    if (n <= Golang.Int64(0)) return (Golang.Int(0), eof);
    var pp = p;
    if (Golang.Int64(p.length) > n) {
      pp = p.slice(0, n.toInt());
    }
    final (nn, err) = r!.read(pp);
    n -= Golang.Int64.from(nn);
    return (nn, err);
  }
}
