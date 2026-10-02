/// Shim do pacote Go `strings` (só as funções que o grafo pede primeiro;
/// o resto em `TODO/P0-shim-strings.md`). Tudo sobre os bytes, como no Go.
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import 'builtin.dart';
import 'fmt.dart' show Stringer;
import 'io.dart' as io;
import 'fixed_types/golang.dart' as Golang;
import 'src/unicode/utf8.dart';
import 'unicode.dart' as unicode;

part 'src/strings/funcs.dart';
part 'src/strings/builder.dart';
part 'src/strings/case.dart';
