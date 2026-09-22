// test/atomic/nivel_1/clock_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo benbjohnson/clock (transpiled_clock).
// Vetores adaptados de go-ipfs-reference/benbjohnson-clock/clock_test.go.

import 'dart:async';

import 'package:test/test.dart';
import 'package:transpiled_clock/transpiled_clock.dart';

/// Epoch usado pelo `NewMock` upstream (`clock.go:87`, `time.Unix(0, 0)`).
final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

void main() {
  group('Clock [Atomic Audit]', () {
    test(
      'Clock() - a factory devolve um relógio de tempo real, não um Mock',
      () {
        final c = Clock();
        expect(c, isA<Clock>());
        expect(c, isNot(isA<Mock>()));
      },
    );

    test('now() - o relógio real acompanha o relógio da plataforma', () {
      final before = DateTime.now();
      final observed = Clock().now();
      final after = DateTime.now();
      expect(observed.isBefore(before), isFalse);
      expect(observed.isAfter(after), isFalse);
    });

    test('since() - devolve o tempo decorrido desde um instante passado', () {
      final c = Clock();
      final past = c.now().subtract(const Duration(seconds: 30));
      expect(c.since(past), greaterThanOrEqualTo(const Duration(seconds: 30)));
    });

    test('until() - devolve o tempo restante até um instante futuro', () {
      final c = Clock();
      final future = c.now().add(const Duration(seconds: 30));
      expect(c.until(future), lessThanOrEqualTo(const Duration(seconds: 30)));
      expect(c.until(future), greaterThan(const Duration(seconds: 25)));
    });

    test('after() - completa depois do intervalo pedido', () async {
      final c = Clock();
      final start = c.now();
      final fired = await c.after(const Duration(milliseconds: 20));
      expect(fired.difference(start), greaterThanOrEqualTo(Duration.zero));
    });

    test('afterFunc() - executa a função depois do intervalo', () async {
      final c = Clock();
      final done = Completer<void>();
      final t = c.afterFunc(const Duration(milliseconds: 10), done.complete);
      expect(t, isA<Timer>());
      await done.future.timeout(const Duration(seconds: 5));
      expect(done.isCompleted, isTrue);
    });

    test('sleep() - só completa depois do intervalo pedido', () async {
      final c = Clock();
      final start = DateTime.now();
      await c.sleep(const Duration(milliseconds: 20));
      expect(
        DateTime.now().difference(start),
        greaterThanOrEqualTo(const Duration(milliseconds: 15)),
      );
    });

    test('timer() - devolve um Timer que emite uma única vez', () async {
      final c = Clock();
      final t = c.timer(const Duration(milliseconds: 10));
      final values = await t.c.take(1).toList();
      expect(values, hasLength(1));
    });

    test('ticker() - devolve um Ticker que emite repetidamente', () async {
      final c = Clock();
      final t = c.ticker(const Duration(milliseconds: 5));
      final values = await t.c.take(3).toList();
      t.stop();
      expect(values, hasLength(3));
    });

    test('tick() - emite repetidamente no stream devolvido', () async {
      final c = Clock();
      final values = await c
          .tick(const Duration(milliseconds: 5))
          .take(2)
          .toList();
      expect(values, hasLength(2));
    });
  });

  group('Mock [Atomic Audit]', () {
    test('Mock() - o tempo inicial é o epoch Unix', () {
      expect(Mock().now(), equals(_epoch));
    });

    test('now() - não avança sozinho sem uma chamada a add ou set', () async {
      final m = Mock();
      final first = m.now();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(m.now(), equals(first));
    });

    test('add() - avança o tempo exatamente pela duração pedida', () async {
      final m = Mock();
      await m.add(const Duration(hours: 3));
      expect(m.now(), equals(_epoch.add(const Duration(hours: 3))));
    });

    test(
      'add() - dispara os timers vencidos e deixa os futuros pendentes',
      () async {
        final m = Mock();
        var early = false;
        var late = false;
        m.afterFunc(const Duration(seconds: 10), () => early = true);
        m.afterFunc(const Duration(seconds: 100), () => late = true);

        await m.add(const Duration(seconds: 20));
        expect(early, isTrue);
        expect(late, isFalse);

        await m.add(const Duration(seconds: 100));
        expect(late, isTrue);
      },
    );

    test('set() - move o tempo para o instante indicado', () async {
      final m = Mock();
      final target = _epoch.add(const Duration(days: 2));
      await m.set(target);
      expect(m.now(), equals(target));
    });

    test(
      'set() - dispara os timers cujo vencimento cai antes do alvo',
      () async {
        final m = Mock();
        var fired = false;
        m.afterFunc(const Duration(minutes: 1), () => fired = true);
        await m.set(_epoch.add(const Duration(minutes: 5)));
        expect(fired, isTrue);
      },
    );

    test('waitForAllTimers() - avança até o último timer pendente', () async {
      final m = Mock();
      var count = 0;
      m.afterFunc(const Duration(seconds: 5), () => count++);
      m.afterFunc(const Duration(seconds: 50), () => count++);

      final reached = await m.waitForAllTimers();
      expect(count, equals(2));
      expect(reached, equals(_epoch.add(const Duration(seconds: 50))));
    });

    test(
      'waitForAllTimers() - sem timers devolve o tempo atual sem avançar',
      () async {
        final m = Mock();
        await m.add(const Duration(seconds: 7));
        expect(
          await m.waitForAllTimers(),
          equals(_epoch.add(const Duration(seconds: 7))),
        );
      },
    );

    test(
      'since() - mede contra o tempo do mock, não contra o relógio real',
      () async {
        final m = Mock();
        await m.add(const Duration(seconds: 90));
        expect(m.since(_epoch), equals(const Duration(seconds: 90)));
      },
    );

    test('until() - mede contra o tempo do mock', () {
      final m = Mock();
      expect(
        m.until(_epoch.add(const Duration(seconds: 45))),
        equals(const Duration(seconds: 45)),
      );
    });

    test(
      'after() - completa somente quando o mock avança além do intervalo',
      () async {
        final m = Mock();
        var fired = false;
        unawaited(
          m.after(const Duration(seconds: 10)).then((_) => fired = true),
        );

        await m.add(const Duration(seconds: 5));
        expect(fired, isFalse);

        await m.add(const Duration(seconds: 10));
        expect(fired, isTrue);
      },
    );

    test(
      'afterFunc() - devolve um Timer registrado que pode ser parado',
      () async {
        final m = Mock();
        var fired = false;
        final t = m.afterFunc(const Duration(seconds: 10), () => fired = true);
        expect(t.stop(), isTrue);
        await m.add(const Duration(seconds: 30));
        expect(fired, isFalse);
      },
    );

    test('sleep() - só retorna quando o mock avança além da duração', () async {
      final m = Mock();
      var awake = false;
      unawaited(m.sleep(const Duration(seconds: 10)).then((_) => awake = true));

      await m.add(const Duration(seconds: 3));
      expect(awake, isFalse);

      await m.add(const Duration(seconds: 10));
      expect(awake, isTrue);
    });

    test(
      'timer() - emite o instante de vencimento quando o mock avança',
      () async {
        final m = Mock();
        final t = m.timer(const Duration(seconds: 10));
        final received = <DateTime>[];
        final sub = t.c.listen(received.add);

        await m.add(const Duration(seconds: 10));
        expect(received, equals([_epoch.add(const Duration(seconds: 10))]));

        await sub.cancel();
      },
    );

    test('ticker() - emite um tique por intervalo percorrido', () async {
      final m = Mock();
      final t = m.ticker(const Duration(seconds: 10));
      final received = <DateTime>[];
      final sub = t.c.listen(received.add);

      await m.add(const Duration(seconds: 35));
      t.stop();

      expect(received, hasLength(3));
      await sub.cancel();
    });

    test('tick() - devolve o stream de um Ticker do mock', () async {
      final m = Mock();
      final received = <DateTime>[];
      final sub = m.tick(const Duration(seconds: 10)).listen(received.add);

      await m.add(const Duration(seconds: 20));

      expect(received, hasLength(2));
      await sub.cancel();
    });
  });

  group('Timer [Atomic Audit]', () {
    test('c - carrega o instante de disparo até alguém escutar', () async {
      final m = Mock();
      final t = m.timer(const Duration(seconds: 1));
      await m.add(const Duration(seconds: 1));
      expect(await t.c.first, equals(_epoch.add(const Duration(seconds: 1))));
    });

    test('next - é o instante de vencimento calculado no registro', () {
      final m = Mock();
      final t = m.timer(const Duration(seconds: 25));
      expect(t.next, equals(_epoch.add(const Duration(seconds: 25))));
    });

    test(
      'stop() - devolve true para um timer ainda registrado e o desarma',
      () async {
        final m = Mock();
        var fired = false;
        final t = m.afterFunc(const Duration(seconds: 5), () => fired = true);
        expect(t.stop(), isTrue);
        await m.add(const Duration(seconds: 60));
        expect(fired, isFalse);
      },
    );

    test('stop() - devolve false quando o timer já havia sido parado', () {
      final m = Mock();
      final t = m.afterFunc(const Duration(seconds: 5), () {});
      expect(t.stop(), isTrue);
      expect(t.stop(), isFalse);
    });

    test(
      'reset() - reprograma o vencimento a partir do agora do mock',
      () async {
        final m = Mock();
        var fired = false;
        final t = m.afterFunc(const Duration(seconds: 5), () => fired = true);

        expect(t.reset(const Duration(seconds: 100)), isTrue);
        expect(t.next, equals(_epoch.add(const Duration(seconds: 100))));

        await m.add(const Duration(seconds: 10));
        expect(fired, isFalse);

        await m.add(const Duration(seconds: 100));
        expect(fired, isTrue);
      },
    );

    test('reset() - devolve false e re-registra um timer já parado', () async {
      final m = Mock();
      var fired = false;
      final t = m.afterFunc(const Duration(seconds: 5), () => fired = true);
      t.stop();

      expect(t.reset(const Duration(seconds: 10)), isFalse);

      await m.add(const Duration(seconds: 20));
      expect(fired, isTrue);
    });

    test('tick() - entrega o instante e desregistra o timer do mock', () async {
      final m = Mock();
      final t = m.timer(const Duration(seconds: 3));
      final received = <DateTime>[];
      final sub = t.c.listen(received.add);

      await t.tick(_epoch.add(const Duration(seconds: 3)));

      expect(received, equals([_epoch.add(const Duration(seconds: 3))]));
      // Desregistrado: avançar o mock não produz um segundo disparo.
      await m.add(const Duration(seconds: 60));
      expect(received, hasLength(1));

      await sub.cancel();
    });
  });

  group('Ticker [Atomic Audit]', () {
    test('c - emite um valor por tique', () async {
      final m = Mock();
      final t = m.ticker(const Duration(seconds: 4));
      final received = <DateTime>[];
      final sub = t.c.listen(received.add);

      await m.add(const Duration(seconds: 12));
      t.stop();

      expect(received, hasLength(3));
      await sub.cancel();
    });

    test('next - é o instante do próximo tique', () {
      final m = Mock();
      final t = m.ticker(const Duration(seconds: 8));
      expect(t.next, equals(_epoch.add(const Duration(seconds: 8))));
    });

    test('stop() - impede tiques posteriores', () async {
      final m = Mock();
      final t = m.ticker(const Duration(seconds: 5));
      final received = <DateTime>[];
      final sub = t.c.listen(received.add);

      await m.add(const Duration(seconds: 5));
      expect(received, hasLength(1));

      t.stop();
      await m.add(const Duration(seconds: 60));
      expect(received, hasLength(1));

      await sub.cancel();
    });

    test('reset() - troca o intervalo e reprograma o próximo tique', () async {
      final m = Mock();
      final t = m.ticker(const Duration(seconds: 5));
      final received = <DateTime>[];
      final sub = t.c.listen(received.add);

      t.reset(const Duration(seconds: 20));
      expect(t.next, equals(_epoch.add(const Duration(seconds: 20))));

      await m.add(const Duration(seconds: 10));
      expect(received, isEmpty);

      await m.add(const Duration(seconds: 15));
      expect(received, hasLength(1));

      t.stop();
      await sub.cancel();
    });

    test('reset() - re-registra um ticker que havia sido parado', () async {
      final m = Mock();
      final t = m.ticker(const Duration(seconds: 5));
      final received = <DateTime>[];
      final sub = t.c.listen(received.add);

      t.stop();
      t.reset(const Duration(seconds: 5));

      await m.add(const Duration(seconds: 10));
      expect(received, hasLength(2));

      t.stop();
      await sub.cancel();
    });

    test(
      'tick() - entrega o instante e reprograma o próximo vencimento',
      () async {
        final m = Mock();
        final t = m.ticker(const Duration(seconds: 6));
        final received = <DateTime>[];
        final sub = t.c.listen(received.add);

        final at = _epoch.add(const Duration(seconds: 6));
        await t.tick(at);

        expect(received, equals([at]));
        expect(t.next, equals(at.add(const Duration(seconds: 6))));

        t.stop();
        await sub.cancel();
      },
    );
  });
}
