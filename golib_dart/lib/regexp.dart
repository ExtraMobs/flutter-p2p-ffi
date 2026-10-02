/// Shim do pacote Go `regexp`: motor próprio com a sintaxe RE2 do Go
/// (`regexp/syntax`, flags Perl) e a semântica leftmost-first (simulação
/// Pike, tempo linear, sem backtracking). Opera sobre os bytes UTF-8, como o
/// Go: os índices dos resultados são em bytes e UTF-8 inválido casa como
/// U+FFFD de largura 1. Limites conhecidos em `docs/mapping-spec.md`.
// ignore_for_file: library_prefixes
library;

import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'builtin.dart';
import 'fmt.dart' show Stringer;
import 'fixed_types/golang.dart' as Golang;
import 'unicode.dart' as unicode;
import 'src/unicode/isprint.dart' as isprint;

part 'src/regexp/ast.dart';
part 'src/regexp/escape.dart';
part 'src/regexp/charclass.dart';
part 'src/regexp/parser.dart';
part 'src/regexp/prog.dart';
part 'src/regexp/vm.dart';
part 'src/regexp/regexp.dart';
part 'src/regexp/find.dart';
part 'src/regexp/replace.dart';
part 'src/regexp/funcs.dart';

const _strElem = Elem<Golang.String>(16, Golang.String.new, pointers: true);
const _intElem = Elem<Golang.Int>(8, Golang.Int.new, ofInt: Golang.Int.from);
const _byteElem = Elem<Golang.Uint8>(
  1,
  Golang.Uint8.new,
  ofInt: Golang.Uint8.from,
);
Slice<Golang.Uint8> _nilBytes() => Slice.nil(_byteElem);
const _bytesElem = Elem<Slice<Golang.Uint8>>(24, _nilBytes, pointers: true);
Slice<Golang.Int> _nilInts() => Slice.nil(_intElem);
const _intsElem = Elem<Slice<Golang.Int>>(24, _nilInts, pointers: true);
Slice<Golang.String> _nilStrs() => Slice.nil(_strElem);
const _strsElem = Elem<Slice<Golang.String>>(24, _nilStrs, pointers: true);
Slice<Slice<Golang.Uint8>> _nilBytess() => Slice.nil(_bytesElem);
const _bytessElem = Elem<Slice<Slice<Golang.Uint8>>>(
  24,
  _nilBytess,
  pointers: true,
);
