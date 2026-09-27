part of '../../strconv.dart';

/// `*strconv.NumError`: struct de shim (como `bytes.Buffer`), para que o
/// código gerado use `err.(*strconv.NumError)`, `errors.As` e os campos
/// `Func`/`Num`/`Err` (`func`/`num`/`err` no Dart).
final class NumError extends GoStruct<NumError> implements GoError, Unwrapper {
  NumError(this.func, this.num, this.err);

  /// `(*NumError)(nil)` dentro de uma interface (não é nil no Go); os
  /// campos nunca são lidos nesse estado (`error()` desreferencia antes).
  static final NumError $nil = NumError(Golang.String(), Golang.String(), errSyntax)
    ..$nilPtr = true;

  /// `Func`: o nome da função que falhou (`"ParseInt"`, `"ParseFloat"`...).
  Golang.String func;

  /// `Num`: a entrada original.
  Golang.String num;

  /// `Err`: o motivo (`ErrRange`, `ErrSyntax`...).
  GoError err;

  @override
  Golang.String error() {
    if ($nilPtr) nilDeref();
    return Golang.String.fromDart('strconv.') +
        func +
        Golang.String.fromDart(': parsing ') +
        quote(num) +
        Golang.String.fromDart(': ') +
        err.error();
  }

  /// `Unwrap() error`.
  @override
  GoError? unwrap() => err;

  @override
  String get $goType => 'strconv.NumError';

  @override
  List<String> get $valueMethods => const [];
  @override
  List<String> get $ptrMethods => const ['Error', 'Unwrap'];

  @override
  NumError $copy() => NumError(func, num, err);

  @override
  void $set(NumError o) {
    func = o.func;
    num = o.num;
    err = o.err;
  }

  @override
  List<Object?> get $fields => [func, num, err];

  @override
  List<String> get $fieldNames => const ['Func', 'Num', 'Err'];
}
