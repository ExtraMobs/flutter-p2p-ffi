/// Tipos e funções do universo Go (importado como `go` pelo código gerado;
/// `go` é palavra-chave em Go, então o prefixo nunca colide).
// ignore_for_file: library_prefixes
library;

import 'dart:typed_data';

import 'fixed_types/golang.dart' as Golang;

import 'src/runtime/panic.dart';

export 'src/runtime/array.dart';
export 'src/runtime/defer.dart';
export 'src/runtime/elem.dart';
export 'src/runtime/iface.dart';
export 'src/runtime/map.dart';
export 'src/runtime/panic.dart';
export 'src/runtime/ptr.dart';
export 'src/runtime/slice.dart';
export 'src/runtime/struct.dart';

/// Constante string Go que não é UTF-8 válido (bytes exatos).
Golang.String stringOfBytes(List<int> bytes) =>
    Golang.String.fromBytes(Uint8List.fromList(bytes));

/// Contagem de shift com tipo inteiro wrapper → `int` Dart. Negativa: panic
/// (spec Go). Qualquer contagem >= 64 dá o mesmo resultado; satura para caber.
int shiftCount(BigInt count) {
  if (count.isNegative) {
    throw Panic(const RuntimeError('runtime error: negative shift amount'));
  }
  return count > BigInt.from(64) ? 64 : count.toInt();
}
