/// Os erros concretos da stdlib: `errors.New` e os de `fmt.Errorf`.
// ignore_for_file: library_prefixes
library;

import '../../fixed_types/golang.dart' as Golang;
import 'elem.dart';
import 'panic.dart';
import 'slice.dart';

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

/// `interface{ Unwrap() error }`: o g2d declara em todo tipo com esse
/// método (errors.Unwrap/Is/As percorrem a cadeia por ela).
abstract interface class Unwrapper {
  GoError? unwrap();
}

/// `interface{ Unwrap() []error }`.
abstract interface class MultiUnwrapper {
  Slice<GoError?> unwrap();
}

/// `interface{ Is(error) bool }`.
abstract interface class ErrorIs {
  bool is$(GoError? target);
}

/// `interface{ As(any) bool }`.
abstract interface class ErrorAs {
  bool as(Object? target);
}

/// `interface{ Timeout() bool }`: usada por `os`/`io/fs` (`os.IsTimeout`,
/// `*PathError.Timeout`, `*SyscallError.Timeout`) e por `net.Error`.
abstract interface class Timeouter {
  bool timeout();
}

/// Descritor de `error` (slices de erros do runtime).
const errorElem = Elem<GoError?>(16, zeroNull, pointers: true);

/// `*fmt.wrapError` (`fmt.Errorf` com um `%w`).
final class WrapError implements GoError, Unwrapper, Golang.GoTyped {
  WrapError(this.msg, this.err);

  final Golang.String msg;
  final GoError? err;

  @override
  Golang.String error() => msg;

  /// `Unwrap() error`.
  @override
  GoError? unwrap() => err;

  @override
  String get $goType => '*fmt.wrapError';

  @override
  List<String> get $methods => const ['Error', 'Unwrap'];
}

/// `*fmt.wrapErrors` (`fmt.Errorf` com vários `%w`).
final class WrapErrors implements GoError, MultiUnwrapper, Golang.GoTyped {
  WrapErrors(this.msg, this.errs);

  final Golang.String msg;
  final List<GoError> errs;

  @override
  Golang.String error() => msg;

  /// `Unwrap() []error`.
  @override
  Slice<GoError?> unwrap() => Slice.of(errs, errorElem);

  @override
  String get $goType => '*fmt.wrapErrors';

  @override
  List<String> get $methods => const ['Error', 'Unwrap'];
}

/// `*errors.joinError` (`errors.Join`).
final class JoinError implements GoError, MultiUnwrapper, Golang.GoTyped {
  JoinError(this.errs);

  final List<GoError> errs;

  /// As mensagens separadas por `\n`, como o Go.
  @override
  Golang.String error() {
    var out = errs[0].error();
    for (final e in errs.skip(1)) {
      out = out + Golang.String.fromDart('\n') + e.error();
    }
    return out;
  }

  @override
  Slice<GoError?> unwrap() => Slice.of(errs, errorElem);

  @override
  String get $goType => '*errors.joinError';

  @override
  List<String> get $methods => const ['Error', 'Unwrap'];
}
