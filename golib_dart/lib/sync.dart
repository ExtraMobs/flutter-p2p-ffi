/// Shim do pacote Go `sync`.
///
/// Cada primitiva tem uma versão síncrona (`lock()`, `wait()`...) e uma
/// suspensiva (`lock$async()`, `wait$async()`... — sufixo `$` impossível em
/// Go, nunca colide) que o g2d escolhe conforme a cor da função que chama
/// (M4, `docs/mapping-spec.md` § "Concorrência (M4)"). Sem outra goroutine viva,
/// esperar por algo que só ela resolveria ainda é o deadlock do Go (`fatal
/// error: all goroutines are asleep - deadlock!`); unlock de destravado
/// continua fatal error do Go. Com outras goroutines vivas, a versão
/// SÍNCRONA travada é um limite do g2d — um contexto que precisa ser
/// síncrono (ex. um método `String()`) tentou uma espera que só a versão
/// suspensiva resolveria — e vira `fatal` com mensagem `g2d: ...`.
// ignore_for_file: library_prefixes
library;

import 'dart:async';
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
