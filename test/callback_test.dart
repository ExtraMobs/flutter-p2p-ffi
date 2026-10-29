// Callback sob demanda (0.17.0, WIRE.md "Callback"): o Go chama um callback
// de verdade, e os argumentos de cada invocação vêm ao Dart em lotes
// (batchSize); a função Dart roda um item por vez, e false ou uma exceção
// param o Go. A função 27 do host (CallbackBench) produz n itens sem nada do
// kubo no meio. Exige `dart run tool/build.dart`.
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:p2p_ffi/src/runtime.dart' show $W, $callCb, $callSync, GoHandle;
import 'package:test/test.dart';

/// Função 27: [n] itens de [size] bytes; devolve quantos o Go produziu.
Future<int> bench(int n, int size, dynamic Function(int i, Uint8List b) f,
    {int batch = 0}) async {
  final r = await $callCb(
      27,
      $W()
        ..u32(batch)
        ..i64(n)
        ..i64(size),
      (r) => f(r.i64(), r.bytes() ?? Uint8List(0)));
  return r.i64();
}

void main() {
  setUpAll(P2pService.start);
  tearDownAll(P2pService.stop);

  test('todos os itens, em ordem, com os argumentos', () async {
    for (final batch in [1, 7, 64, 1000]) {
      final seen = <int>[];
      final made = await bench(100, 3, (i, b) {
        seen.add(i);
        expect(b, hasLength(3));
      }, batch: batch);
      expect(made, 100);
      expect(seen, List.generate(100, (i) => i), reason: 'lote $batch');
    }
  });

  test('false para: lote 1 é exato; lote N, no máximo N-1 à frente', () async {
    for (final batch in [1, 8, 64]) {
      final seen = <int>[];
      final made = await bench(1000, 0, (i, _) {
        seen.add(i);
        return i < 10; // o 11º (índice 10) devolve false
      }, batch: batch);
      expect(seen, List.generate(11, (i) => i), reason: 'lote $batch');
      // o Go produziu o lote do índice 10 inteiro, e nada depois dele
      expect(made, ((10 ~/ batch) + 1) * batch, reason: 'lote $batch');
    }
  });

  test('a exceção do callback é a que a chamada lança', () async {
    final boom = StateError('do Dart');
    var calls = 0;
    await expectLater(
        bench(1000, 0, (i, _) {
          calls++;
          if (i == 5) throw boom;
        }, batch: 4),
        throwsA(same(boom)));
    expect(calls, 6); // nada depois da exceção
  });

  test('callback assíncrono: o próximo espera o anterior', () async {
    var running = 0, max = 0;
    final made = await bench(20, 0, (i, _) async {
      running++;
      max = running > max ? running : max;
      await Future<void>.delayed(const Duration(milliseconds: 1));
      running--;
    }, batch: 8);
    expect(made, 20);
    expect(max, 1);
  });

  test('chamadas à ponte de dentro do callback', () async {
    var noops = 0;
    await bench(50, 0, (i, _) {
      $callSync(0); // Noop: síncrona, enquanto o Go espera o veredito
      noops++;
    }, batch: 1);
    expect(noops, 50);
  });

  test('index: forEach e getAll', () async {
    final idx = Go.car.v2.index.new$(Go.multicodec.carMultihashIndexSorted);
    idx.load([
      for (var i = 0; i < 5; i++)
        CarV2IndexRecord(
            cid: Go.cid.newPrefixV1(0x55, 0x12).sum(Uint8List.fromList([i])),
            offset: 100 + i)
    ]);
    final it = idx.asIterableIndex()!;
    final offsets = <int>[];
    await it.forEach((mh, offset) {
      expect(mh, hasLength(34)); // sha2-256: 2 de prefixo + 32
      // o cast é outro objeto Dart do mesmo objeto Go: o mesmo handle, em uso
      expect(identical(it, idx), isFalse);
      expect(idx.isBusy, isTrue);
      offsets.add(offset);
    });
    expect(offsets..sort(), [100, 101, 102, 103, 104]);

    final c = Go.cid.newPrefixV1(0x55, 0x12).sum(Uint8List.fromList([3]));
    final got = <int>[];
    await idx.getAll(c, (offset) {
      got.add(offset);
      return true;
    });
    expect(got, [103]);
  });

  group('impasse (funções 29–31: um mutex que o Iterate segura)', () {
    // o objeto com trava do host
    GoHandle locker() => $callSync(29).hnn(_Locker.new);
    Future<void> iterate(GoHandle l, int n, dynamic Function(int i) f) =>
        $callCb(
            30,
            $W()
              ..h(l)
              ..u32(1)
              ..i64(n),
            (r) => f(r.i64()));
    void touch(GoHandle l) => $callSync(31, $W()..h(l));

    test(
        'tocar o objeto travado de dentro do callback: GolangDeadlockException',
        () async {
      final l = locker();
      final changes = <(bool, bool)>[];
      final sub = P2pService.busy
          .listen((c) => changes.add((identical(c.handle, l), c.busy)));
      final sw = Stopwatch()..start();
      Object? inside;
      await expectLater(
          iterate(l, 3, (i) {
            expect(l.isBusy, isTrue);
            try {
              touch(l); // o Go segura a trava esperando este callback
            } catch (e) {
              inside = e;
              rethrow;
            }
          }),
          throwsA(isA<GolangDeadlockException>()));
      expect(inside, isA<GolangDeadlockException>());
      expect((inside! as GolangDeadlockException).message,
          contains('Locker.Touch'));
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      expect(l.isBusy, isFalse);
      touch(l); // a trava saiu com o Iterate: o host segue respondendo
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      expect(changes, [(true, true), (true, false)]);
    });

    test('outro objeto, de dentro do callback: sem impasse', () async {
      final a = locker(), b = locker();
      var touched = 0;
      await iterate(a, 5, (i) {
        touch(b);
        touched++;
      });
      expect(touched, 5);
    });
  });
}

/// Handle sem classe gerada (o objeto com trava das funções de teste).
final class _Locker extends GoHandle {
  _Locker(super.$h);
}
