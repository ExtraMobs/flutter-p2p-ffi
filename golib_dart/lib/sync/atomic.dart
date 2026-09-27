/// Shim do pacote Go `sync/atomic`.
///
/// Num isolate só (sem goroutines, M4) as operações atômicas são leituras e
/// escritas simples; o que importa é a semântica Go: os tipos (`Int64`,
/// `Bool`, `Value`, `Pointer[T]`...) são structs de shim por valor
/// (`go.GoStruct`, impressos como o Go: `{{} {} 5}`), e as funções operam
/// sobre `*T` (`go.Ptr`). As variantes com `unsafe.Pointer` ficam de fora
/// (`unsafe:Pointer`).
// ignore_for_file: library_prefixes
library;

import '../builtin.dart';
import '../fixed_types/golang.dart' as Golang;

part '../src/sync/atomic/int.dart';
part '../src/sync/atomic/value.dart';
part '../src/sync/atomic/funcs.dart';

/// Campo `_ noCopy` / `_ align64` do Go: struct vazia (`{}` no `%v`).
final class _Empty extends GoStruct<_Empty> {
  @override
  String get $goType => 'atomic.noCopy';
  @override
  _Empty $copy() => _Empty();
  @override
  void $set(_Empty o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];
}
