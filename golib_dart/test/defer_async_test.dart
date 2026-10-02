// ignore_for_file: library_prefixes
import 'dart:async';

import 'package:golib_dart/builtin.dart' as go;
import 'package:test/test.dart';

/// `Golang.String`-like: só pro valor do panic, sem puxar fixed_types aqui.
class _Msg {
  _Msg(this.text);
  final String text;
  @override
  String toString() => text;
}

void main() {
  test(
    'recover funciona mesmo com goroutines intercaladas através de um '
    'await no meio do defer (o quadro é por Zone, não pilha global)',
    () async {
      final results = <String, Object?>{};

      Future<void> runWithDefer(
        String name,
        Completer<void> gate,
        Completer<void> started,
      ) async {
        final d = go.Defers();
        d.defer(() async {
          await gate.future; // suspende: dá chance de outra "goroutine" rodar.
          results[name] = go.recover(d);
        });
        try {
          started.complete();
          throw go.Panic(_Msg('boom-$name'));
        } catch (e, st) {
          d.fail(e, st);
        } finally {
          await d.runAsync();
        }
      }

      final gateA = Completer<void>();
      final gateB = Completer<void>();
      final startedA = Completer<void>();
      final startedB = Completer<void>();

      // Nenhuma das duas é aguardada ainda: as duas ficam "vivas" ao mesmo
      // tempo, cada uma parada no seu próprio `await gate.future` dentro do
      // defer — exatamente o cenário em que uma pilha global de frames
      // devolveria o quadro errado.
      final futA = runWithDefer('A', gateA, startedA);
      final futB = runWithDefer('B', gateB, startedB);
      await startedA.future;
      await startedB.future;

      // Libera A primeiro; B continua suspensa (seu quadro seria "o topo"
      // numa pilha global compartilhada nesse instante).
      gateA.complete();
      await Future<void>.delayed(Duration.zero);
      gateB.complete();

      await futA;
      await futB;

      expect(results['A'].toString(), 'boom-A');
      expect(results['B'].toString(), 'boom-B');
    },
  );

  test('runAsync relança o panic quando ninguém recupera', () async {
    final d = go.Defers();
    d.defer(() async {
      await Future<void>.delayed(Duration.zero);
      // não chama recover: o panic segue adiante.
    });
    Object? caught;
    try {
      throw go.Panic('sem recover');
    } catch (e, st) {
      d.fail(e, st);
    } finally {
      try {
        await d.runAsync();
      } catch (e) {
        caught = e;
      }
    }
    expect(caught, isA<go.Panic>());
    expect((caught as go.Panic).value, 'sem recover');
  });

  test('runAsync roda os defers em ordem LIFO, aguardando cada um', () async {
    final order = <int>[];
    final d = go.Defers();
    d.defer(() async {
      await Future<void>.delayed(Duration.zero);
      order.add(1);
    });
    d.defer(() async {
      order.add(2);
    });
    d.defer(() {
      order.add(3);
    });
    await d.runAsync();
    expect(order, [3, 2, 1]);
  });
}
