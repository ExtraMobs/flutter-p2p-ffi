/// Shim do pacote Go `io/fs` (parcial: erros sentinela, `PathError`,
/// `FileMode`). O `os` os reexporta (`os.PathError`, `os.FileMode` e
/// `os.ErrNotExist` são aliases/cópias dos daqui).
// ignore_for_file: library_prefixes
library;

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;
import '../fmt.dart' show Stringer;

part '../src/io/fs/errors.dart';
part '../src/io/fs/file_mode.dart';
