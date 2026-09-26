/// `error`, `panic` e erros de runtime do Go.
// ignore_for_file: library_prefixes
library;

import '../../fixed_types/golang.dart' as Golang;

/// A interface `error` do Go.
abstract interface class GoError {
  Golang.String error();
}

/// Valor lançado por `panic(v)`; `recover()` devolve [value].
class Panic implements Exception {
  Panic(this.value);

  final Object? value;

  @override
  String toString() => 'panic: ${describePanic(value)}';
}

/// `runtime.Error` do Go (índice fora do intervalo, divisão por zero...).
final class RuntimeError implements GoError {
  const RuntimeError(this.message);

  final String message;

  @override
  Golang.String error() => Golang.String.fromDart(message);

  @override
  String toString() => message;
}

/// Desreferência de ponteiro nil (receptor valor chamado sobre `(*T)(nil)`).
Never nilDeref() => throw Panic(
  const RuntimeError(
    'runtime error: invalid memory address or nil pointer dereference',
  ),
);

/// Valor de panic Go correspondente a uma exceção lançada no Dart: panics
/// explícitos mantêm o valor; falhas do runtime Dart viram o `runtime.Error`
/// que o Go produziria no mesmo ponto.
Object? panicValue(Object e) => switch (e) {
  Panic(:final value) => value,
  // Os inteiros de fixed_types lançam esta exceção na divisão por zero, em
  // todas as plataformas; o substituto sugerido (UnsupportedError) seria
  // amplo demais.
  // ignore: deprecated_member_use
  IntegerDivisionByZeroException() => const RuntimeError(
    'runtime error: integer divide by zero',
  ),
  Golang.BoundsError(:final goMessage) => RuntimeError(
    'runtime error: $goMessage',
  ),
  IndexError(:final invalidValue, :final length) => RuntimeError(
    'runtime error: index out of range [$invalidValue] with length $length',
  ),
  // `p!` com p nil: desreferência de ponteiro nil.
  TypeError() => const RuntimeError(
    'runtime error: invalid memory address or nil pointer dereference',
  ),
  _ => e,
};

/// Texto do valor de um panic não recuperado (`panic: ...`).
String describePanic(Object? v) => switch (v) {
  null => 'nil',
  GoError e => e.error().toString(),
  _ => v.toString(),
};

/// `range` sobre func: o iterador chamou yield depois de o corpo sair.
Never rangeFuncContinued() => throw Panic(
  const RuntimeError(
    'runtime error: range function continued iteration after function for loop body returned false',
  ),
);
