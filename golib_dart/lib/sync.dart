/// Shim do pacote Go `sync`.
///
/// Sem goroutines (M4, `TODO/P0-design-m4-concorrencia.md`) só existe a
/// goroutine do `main`: a semântica Go fica determinística. Esperar por algo
/// que só outra goroutine faria (Lock de mutex travado, `Wait` com contador
/// positivo, `Cond.Wait`) é o deadlock do Go (`fatal error: all goroutines
/// are asleep - deadlock!`); unlock de destravado é o fatal error do Go.
/// `WaitGroup.Go` (cria goroutine) fica de fora.
// ignore_for_file: library_prefixes
library;

import 'dart:collection';

import 'builtin.dart';
import 'fixed_types/golang.dart' as Golang;
import 'sync/atomic.dart' as atomic;

part 'src/sync/mutex.dart';
part 'src/sync/once.dart';
part 'src/sync/wait_group.dart';
part 'src/sync/pool.dart';
part 'src/sync/map.dart';
part 'src/sync/cond.dart';

const _deadlock = 'all goroutines are asleep - deadlock!';

/// Campo `noCopy` do Go (`{}` no `%v`).
final class _NoCopy extends GoStruct<_NoCopy> {
  @override
  String get $goType => 'sync.noCopy';
  @override
  _NoCopy $copy() => _NoCopy();
  @override
  void $set(_NoCopy o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];
}

Never _noFmt(String t) =>
    throw UnimplementedError('fmt/== de $t (estrutura interna do Go)');
