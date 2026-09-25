/// Tipos e funções do universo Go (importado como `go` pelo código gerado;
/// `go` é palavra-chave em Go, então o prefixo nunca colide).
library;

/// A interface `error` do Go.
abstract interface class GoError {
  String error();
}

/// Valor lançado por `panic(v)`; `recover()` o captura.
class Panic implements Exception {
  Panic(this.value);

  final Object? value;

  @override
  String toString() => 'panic: $value';
}
