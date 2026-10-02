/// Shim do pacote Go `bytes` (só as funções que o grafo pede primeiro;
/// o resto em `docs/stdlib-coverage.md`).
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import 'builtin.dart';
import 'fmt.dart' show Stringer;
import 'io.dart' as io;
import 'fixed_types/golang.dart' as Golang;
import 'src/unicode/utf8.dart';
import 'unicode.dart' as unicode;

part 'src/bytes/funcs.dart';
part 'src/bytes/split.dart';
part 'src/bytes/search.dart';
part 'src/bytes/edit.dart';
part 'src/bytes/buffer.dart';
part 'src/bytes/case.dart';
part 'src/bytes/reader.dart';

typedef _Bytes = Slice<Golang.Uint8>;

const _byteElem = Elem<Golang.Uint8>(
  1,
  Golang.Uint8.new,
  ofInt: Golang.Uint8.from,
);
_Bytes _nilBytes() => Slice.nil(_byteElem);
const _bytesElem = Elem<_Bytes>(24, _nilBytes, pointers: true);

// Os bytes da janela como string Go (para decodificar UTF-8 como o Go).
Golang.String _str(_Bytes b) => Golang.String.fromBytes(
  Uint8List.fromList([for (var i = 0; i < b.length; i++) b[i].toInt()]),
);
