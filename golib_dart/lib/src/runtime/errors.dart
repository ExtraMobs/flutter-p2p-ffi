/// Os erros concretos da stdlib: `errors.New` e os de `fmt.Errorf`.
// ignore_for_file: library_prefixes
library;

import '../../fixed_types/golang.dart' as Golang;
import 'panic.dart';

/// `*errors.errorString` (`errors.New`, `fmt.Errorf` sem `%w`). Comparado
/// por identidade, como o ponteiro do Go.
final class ErrorString implements GoError, Golang.GoTyped {
  ErrorString(this.s);

  final Golang.String s;

  @override
  Golang.String error() => s;

  @override
  String get $goType => '*errors.errorString';

  @override
  List<String> get $methods => const ['Error'];
}

/// `*fmt.wrapError` (`fmt.Errorf` com um `%w`).
final class WrapError implements GoError, Golang.GoTyped {
  WrapError(this.msg, this.err);

  final Golang.String msg;
  final GoError? err;

  @override
  Golang.String error() => msg;

  /// `Unwrap() error`.
  GoError? unwrap() => err;

  @override
  String get $goType => '*fmt.wrapError';

  @override
  List<String> get $methods => const ['Error', 'Unwrap'];
}

/// `*fmt.wrapErrors` (`fmt.Errorf` com vários `%w`).
final class WrapErrors implements GoError, Golang.GoTyped {
  WrapErrors(this.msg, this.errs);

  final Golang.String msg;
  final List<GoError> errs;

  @override
  Golang.String error() => msg;

  @override
  String get $goType => '*fmt.wrapErrors';

  @override
  List<String> get $methods => const ['Error', 'Unwrap'];
}
