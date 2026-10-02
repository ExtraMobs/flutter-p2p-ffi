/// Os erros concretos da stdlib: `errors.New` e os de `fmt.Errorf`.
// ignore_for_file: library_prefixes
library;

import '../../fixed_types/golang.dart' as Golang;
import 'elem.dart';
import 'panic.dart';
import 'slice.dart';
import 'struct.dart' show GoOpaqueStruct;

/// `*errors.errorString` (`errors.New`, `fmt.Errorf` sem `%w`). Comparado
/// por identidade, como o ponteiro do Go.
final class ErrorString implements GoError, GoOpaqueStruct {
  ErrorString(this.s);

  final Golang.String s;

  @override
  Golang.String error() => s;

  @override
  String get $goType => '*errors.errorString';

  @override
  List<String> get $methods => const ['Error'];

  @override
  List<Object?> get $fields => [s];

  @override
  List<String> get $fieldNames => const ['s'];

  @override
  List<String> get $fieldTypes => const ['string'];
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

/// Descritor de `error` (slices de erros do runtime).
const errorElem = Elem<GoError?>(16, zeroNull, pointers: true);

/// `*fmt.wrapError` (`fmt.Errorf` com um `%w`).
final class WrapError implements GoError, Unwrapper, GoOpaqueStruct {
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

  @override
  List<Object?> get $fields => [msg, err];

  @override
  List<String> get $fieldNames => const ['msg', 'err'];

  @override
  List<String> get $fieldTypes => const ['string', 'error'];
}

/// `*fmt.wrapErrors` (`fmt.Errorf` com vários `%w`).
final class WrapErrors implements GoError, MultiUnwrapper, GoOpaqueStruct {
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

  @override
  List<Object?> get $fields => [msg, Slice.of(errs, errorElem)];

  @override
  List<String> get $fieldNames => const ['msg', 'errs'];

  @override
  List<String> get $fieldTypes => const ['string', '[]error'];
}

/// `*errors.joinError` (`errors.Join`).
final class JoinError implements GoError, MultiUnwrapper, GoOpaqueStruct {
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

  @override
  List<Object?> get $fields => [Slice.of(errs, errorElem)];

  @override
  List<String> get $fieldNames => const ['errs'];

  @override
  List<String> get $fieldTypes => const ['[]error'];
}
