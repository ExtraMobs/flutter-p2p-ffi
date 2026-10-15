// ignore_for_file: library_prefixes
import 'dart:async';

import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/sync.dart' as sync;
import 'package:test/test.dart';

void main() {
  test('Mutex contendido entre goroutines, com await no meio da seção '
      'crítica', () async {
    final mu = sync.Mutex();
    final order = <String>[];
    final gate = Completer<void>();
    final aEntered = Completer<void>();
    final bDone = Completer<void>();

    go.spawn(() async {
      await mu.lock$async();
      order.add('A entra');
      aEntered.complete();
      await gate.future; // segura a seção crítica até o teste liberar.
      order.add('A sai');
      mu.unlock();
    });

    await aEntered.future;

    go.spawn(() async {
      order.add('B pede');
      await mu.lock$async(); // tem que esperar A soltar.
      order.add('B entra');
      mu.unlock();
      order.add('B sai');
      bDone.complete();
    });

    await Future<void>.delayed(
      Duration.zero,
    ); // dá tempo de B pedir e bloquear.
    order.add('teste libera A');
    gate.complete();

    await bDone.future;
    expect(order, [
      'A entra',
      'B pede',
      'teste libera A',
      'A sai',
      'B entra',
      'B sai',
    ]);
  });

  test(
    'RWMutex: escritor pendente bloqueia leitor novo (preferência de escritor)',
    () async {
      final rw = sync.RWMutex();
      final order = <String>[];
      final readerGate = Completer<void>();
      final readerIn = Completer<void>();
      final writerDone = Completer<void>();
      final newReaderDone = Completer<void>();

      go.spawn(() async {
        await rw.rLock$async();
        order.add('r1 entra');
        readerIn.complete();
        await readerGate.future;
        order.add('r1 sai');
        rw.rUnlock();
      });
      await readerIn.future;

      go.spawn(() async {
        order.add('w pede');
        await rw.lock$async(); // espera r1 soltar.
        order.add('w entra');
        rw.unlock();
        order.add('w sai');
        writerDone.complete();
      });
      await Future<void>.delayed(Duration.zero);

      go.spawn(() async {
        order.add('r2 pede');
        // chegou depois do escritor: tem que esperar ele também, não furar a
        // fila (preferência de escritor, como o Go).
        await rw.rLock$async();
        order.add('r2 entra');
        rw.rUnlock();
        order.add('r2 sai');
        newReaderDone.complete();
      });
      await Future<void>.delayed(Duration.zero);

      order.add('teste libera r1');
      readerGate.complete();

      await writerDone.future;
      await newReaderDone.future;

      expect(order, [
        'r1 entra',
        'w pede',
        'r2 pede',
        'teste libera r1',
        'r1 sai',
        'w entra',
        'w sai',
        'r2 entra',
        'r2 sai',
      ]);
    },
  );

  test('RWMutex: leitores concorrentes não se bloqueiam entre si', () async {
    final rw = sync.RWMutex();
    final order = <String>[];
    final gate = Completer<void>();
    final r1In = Completer<void>();
    final r2In = Completer<void>();
    final done = <Completer<void>>[Completer(), Completer()];

    go.spawn(() async {
      await rw.rLock$async();
      order.add('r1 entra');
      r1In.complete();
      await gate.future;
      rw.rUnlock();
      done[0].complete();
    });
    await r1In.future;

    go.spawn(() async {
      // outro leitor, sem escritor no meio: entra na hora, não espera r1.
      await rw.rLock$async();
      order.add('r2 entra');
      r2In.complete();
      rw.rUnlock();
      done[1].complete();
    });
    await r2In.future;

    expect(order, ['r1 entra', 'r2 entra']);
    gate.complete();
    await Future.wait(done.map((c) => c.future));
  });

  test('WaitGroup: Go + Wait assíncrono', () async {
    final wg = sync.WaitGroup();
    final order = <int>[];
    final gates = List.generate(3, (_) => Completer<void>());

    for (var i = 0; i < 3; i++) {
      wg.go$(() async {
        await gates[i].future;
        order.add(i);
      });
    }

    final waitFuture = wg.wait$async(); // bloqueia: contador em 3.
    for (final g in gates) {
      g.complete();
    }
    await waitFuture;

    expect(order.toSet(), {0, 1, 2});
  });

  test('Cond: wait\$async destrava L, espera Signal, retrava', () async {
    final mu = sync.Mutex();
    final cond = sync.Cond(l: mu);
    final order = <String>[];
    final waiterLocked = Completer<void>();
    final waiterDone = Completer<void>();

    go.spawn(() async {
      await mu.lock$async();
      order.add('waiter: trava L');
      waiterLocked.complete();
      await cond.wait$async(); // destrava L, espera Signal, retrava.
      order.add('waiter: acordou com L travado de novo');
      mu.unlock();
      waiterDone.complete();
    });

    await waiterLocked.future;
    await Future<void>.delayed(Duration.zero); // dá tempo do Wait destravar L.

    // Cond.Wait já destravou L: o teste consegue travar agora.
    await mu.lock$async();
    order.add('teste: travou L (Cond.Wait tinha destravado)');
    cond.signal();
    mu.unlock();

    await waiterDone.future;
    expect(order, [
      'waiter: trava L',
      'teste: travou L (Cond.Wait tinha destravado)',
      'waiter: acordou com L travado de novo',
    ]);
  });

  test('Cond: broadcast acorda todo mundo', () async {
    final mu = sync.Mutex();
    final cond = sync.Cond(l: mu);
    final woke = <int>[];
    final entered = List.generate(3, (_) => Completer<void>());
    final done = List.generate(3, (_) => Completer<void>());

    for (var i = 0; i < 3; i++) {
      go.spawn(() async {
        await mu.lock$async();
        entered[i].complete();
        await cond.wait$async();
        woke.add(i);
        mu.unlock();
        done[i].complete();
      });
    }
    // Espera cada um travar e entrar em Wait antes do próximo tentar travar
    // (senão eles brigariam pela mesma trava síncrona no setup).
    for (var i = 0; i < 3; i++) {
      await entered[i].future;
      await Future<void>.delayed(Duration.zero);
    }

    cond.broadcast();
    await Future.wait(done.map((c) => c.future));
    expect(woke.toSet(), {0, 1, 2});
  });

  test('Once.do\$async: chamadas concorrentes esperam a primeira terminar '
      '(sem rodar f de novo)', () async {
    final once = sync.Once();
    var runs = 0;
    final order = <String>[];
    final gate = Completer<void>();
    final firstEntered = Completer<void>();
    final aDone = Completer<void>();
    final bDone = Completer<void>();

    // A e B são goroutines de verdade (go.spawn): duas chamadas
    // concorrentes a Do vêm sempre de goroutines distintas, nunca da
    // mesma pilha de chamadas — senão não seriam "concorrentes".
    go.spawn(() async {
      await once.do$async(() async {
        runs++;
        order.add('A roda f');
        firstEntered.complete();
        await gate.future;
        order.add('A termina f');
      });
      order.add('A: Do voltou');
      aDone.complete();
    });

    await firstEntered.future;

    go.spawn(() async {
      await once.do$async(() async {
        runs++;
        order.add('B roda f'); // não deveria rodar: já era pra estar done.
      });
      order.add('B: Do voltou');
      bDone.complete();
    });

    await Future<void>.delayed(
      Duration.zero,
    ); // dá tempo de B pedir e bloquear.
    gate.complete();

    await aDone.future;
    await bDone.future;

    expect(runs, 1);
    expect(order.contains('B roda f'), isFalse);
    expect(
      order.indexOf('A termina f'),
      lessThan(order.indexOf('A: Do voltou')),
    );
    expect(order.contains('B: Do voltou'), isTrue);
  });
}
