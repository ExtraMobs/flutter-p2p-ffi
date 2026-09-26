/// Shim do pacote Go `errors` (só `New`; `Is`/`As`/`Unwrap`/`Join` em
/// `TODO/P0-shim-errors.md`).
// ignore_for_file: library_prefixes
library;

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;

/// `errors.New(text)`: um `*errorString` novo; dois `New` com o mesmo texto
/// são erros diferentes (identidade, como o ponteiro do Go).
GoError new$(Golang.String text) => ErrorString(text);
