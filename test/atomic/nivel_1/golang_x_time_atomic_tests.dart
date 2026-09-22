// test/atomic/nivel_1/golang_x_time_atomic_tests.dart
// Testes atomicos 1 para 1 para packages/transpiled_golang_x_time
// (porte de golang org x time rate)
//
// Os valores numericos esperados (tokens, delays em nanossegundos, decisoes
// de Allow/Reserve) foram produzidos executando um programa Go temporario
// contra golang org x time rate v0-15-0 (a mesma revisao travada em
// doc/transpilation/UPSTREAM_LOCK.md), em go1-25-7, nao deduzidos. Cada
// teste que usa um vetor Go cita o valor exato impresso por esse programa.
//
// Observacao de estilo deste arquivo, exigida pelo parser regex do auditor
// (tool/audit_ast_nomenclature.py): nenhum titulo de test()/group() contem
// o caractere ponto, e nenhum titulo e escrito como dois literais de string
// concatenados implicitamente -- o parser so enxerga o primeiro literal.

import 'dart:async';

import 'package:test/test.dart';
import 'package:transpiled_golang_x_time/transpiled_golang_x_time.dart';

void main() {
  final base = DateTime.utc(2024);

  group('Limit [Atomic Audit]', () {
    test('Limit() - guarda o valor em eventos por segundo', () {
      const limit = Limit(7);
      expect(limit.value, equals(7.0));
    });

    test('inf - e o maior double finito, nao Infinity', () {
      // Go: rate Inf = Limit(math MaxFloat64) double maxFinite e o mesmo
      // padrao de bits IEEE-754 de math MaxFloat64
      expect(Limit.inf.value, equals(double.maxFinite));
      expect(Limit.inf.value.isFinite, isTrue);
    });

    test('operator == - compara por valor, nao por identidade', () {
      expect(const Limit(10) == const Limit(10), isTrue);
      expect(const Limit(10) == const Limit(5), isFalse);
      // ignore: unrelated_type_equality_checks
      expect(const Limit(10) == 10, isFalse);
    });

    test('hashCode - iguala para limites de valor igual', () {
      expect(const Limit(3).hashCode, equals(const Limit(3).hashCode));
    });

    test('toString() - inclui o valor numerico', () {
      expect(const Limit(2).toString(), contains('2'));
    });
  });

  group('every() [Atomic Audit]', () {
    test('every() - 200 ms vira limite 5, vetor Go Every 200ms = 5', () {
      expect(every(const Duration(milliseconds: 200)), equals(const Limit(5)));
    });

    test('every() - intervalo zero devolve o limite infinito', () {
      expect(every(Duration.zero), equals(Limit.inf));
    });

    test('every() - intervalo negativo devolve o limite infinito', () {
      expect(every(const Duration(seconds: -1)), equals(Limit.inf));
    });
  });

  group('infDuration [Atomic Audit]', () {
    test(
      'infDuration - preserva a magnitude real de cerca de 292 anos do Go em '
      'vez do inteiro bruto reinterpretado (que estouraria o range de '
      'DateTime)',
      () {
        // Go: InfDuration = time Duration(math MaxInt64) nanossegundos =
        // 9223372036854775807 ns Convertido para microssegundos (a unidade
        // nativa de Duration) por divisao inteira por 1000, preservando o
        // span real (cerca de 292 anos) em vez do valor bruto reinterpretado
        // (que daria cerca de 292471 anos e faria DateTime add lancar
        // RangeError)
        expect(infDuration.isNegative, isFalse);
        expect(infDuration.inMicroseconds, equals(9223372036854775));
        final years = infDuration.inDays / 365;
        expect(years, inInclusiveRange(290, 295));

        // Deve ser somavel a qualquer DateTime razoavel sem RangeError, que
        // era exatamente o defeito do valor bruto reinterpretado
        expect(() => base.add(infDuration), returnsNormally);
      },
    );
  });

  group('WaitBurstExceededException [Atomic Audit]', () {
    test('WaitBurstExceededException() - guarda n e burst', () {
      const e = WaitBurstExceededException(10, 5);
      expect(e.n, equals(10));
      expect(e.burst, equals(5));
    });

    test('toString() - reproduz a mensagem de erro do Go', () {
      const e = WaitBurstExceededException(10, 5);
      expect(
        e.toString(),
        equals("rate: Wait(n=10) exceeds limiter's burst 5"),
      );
    });
  });

  group('WaitDeadlineExceededException [Atomic Audit]', () {
    test('WaitDeadlineExceededException() - guarda n', () {
      const e = WaitDeadlineExceededException(3);
      expect(e.n, equals(3));
    });

    test('toString() - reproduz a mensagem de erro do Go', () {
      const e = WaitDeadlineExceededException(3);
      expect(
        e.toString(),
        equals('rate: Wait(n=3) would exceed context deadline'),
      );
    });
  });

  group('WaitCanceledException [Atomic Audit]', () {
    test('WaitCanceledException() - e construtivel como const', () {
      const e = WaitCanceledException();
      expect(e, isA<Exception>());
    });

    test('toString() - descreve o cancelamento', () {
      const e = WaitCanceledException();
      expect(e.toString(), equals('rate: wait canceled'));
    });
  });

  group('Limiter [Atomic Audit]', () {
    test('Limiter() - zero value rejeita tudo, vetor Go AllowN false', () {
      final zero = Limiter(const Limit(0), 0);
      expect(zero.allowN(base, 1), isFalse);
    });

    test('limit - devolve a taxa passada ao construtor', () {
      final lim = Limiter(const Limit(7), 3);
      expect(lim.limit, equals(const Limit(7)));
    });

    test('burst - devolve o burst passado ao construtor', () {
      final lim = Limiter(const Limit(7), 3);
      expect(lim.burst, equals(3));
    });

    test('allowN() - cinco chamadas passam e a sexta falha, vetor Go '
        'true true true true true false', () {
      final lim = Limiter(const Limit(10), 5);
      final results = List.generate(6, (_) => lim.allowN(base, 1));
      expect(results, equals([true, true, true, true, true, false]));
    });

    test('tokensAt() - fica em zero apos esgotar o burst, vetor Go tokens '
        'after burst at t0 = 0', () {
      final lim = Limiter(const Limit(10), 5);
      for (var i = 0; i < 5; i++) {
        lim.allowN(base, 1);
      }
      expect(lim.tokensAt(base), equals(0));
    });

    test('tokensAt() - recarrega 3 tokens apos 300ms a 10 por segundo, '
        'vetor Go tokens at t0 mais 300ms = 3', () {
      final lim = Limiter(const Limit(10), 5);
      for (var i = 0; i < 5; i++) {
        lim.allowN(base, 1);
      }
      final t1 = base.add(const Duration(milliseconds: 300));
      expect(lim.tokensAt(t1), equals(3));
    });

    test('tokensAt() - recarga plena e limitada pelo burst, vetor Go tokens '
        'after 1s = 5', () {
      final lim = Limiter(const Limit(10), 5);
      lim.allowN(base, 5);
      final t2 = base.add(const Duration(seconds: 1));
      expect(lim.tokensAt(t2), equals(5));
    });

    test('tokensAt() - tempo anterior ao ultimo evento nao gera elapsed '
        'negativo, vetor Go tokens at earlier time = 0', () {
      final lim = Limiter(const Limit(10), 5);
      lim.allowN(base, 5);
      final earlier = base.subtract(const Duration(seconds: 1));
      expect(lim.tokensAt(earlier), equals(0));
    });

    test('tokens() - e o atalho de tokensAt usando a hora atual', () {
      final lim = Limiter(const Limit(10), 5);
      // Sem eventos, tokens() deve refletir o burst completo
      expect(lim.tokens(), equals(5));
    });

    test('allowN() - com limite infinito, permite tudo mesmo com burst zero, '
        'vetor Go true', () {
      final limInf = Limiter(Limit.inf, 0);
      expect(limInf.allowN(base, 1000000), isTrue);
    });

    test('allow() - e o atalho de allowN usando a hora atual e n igual 1', () {
      final lim = Limiter(const Limit(10), 5);
      expect(lim.allow(), isTrue);
    });

    test('reserveN() - a um token por segundo e burst um, apos drenar o delay '
        'e 1 segundo, vetor Go delay from base = 1000000000 ns', () {
      final lim = Limiter(const Limit(1), 1);
      lim.allowN(base, 1);
      final r = lim.reserveN(base, 1);
      expect(r.ok, isTrue);
      expect(r.delayFrom(base), equals(const Duration(seconds: 1)));
    });

    test('reserveN() - n acima do burst nao e ok e o delay e infinito, '
        'vetor Go ok false delay InfDuration', () {
      final lim = Limiter(const Limit(10), 5);
      final r = lim.reserveN(base, 6);
      expect(r.ok, isFalse);
      expect(r.delayFrom(base), equals(infDuration));
    });

    test('reserveN() - limite minusculo tem o delay coberto pelo cap de '
        'infDuration, vetor Go ok true delay InfDuration', () {
      final lim = Limiter(const Limit(1e-15), 1);
      lim.allowN(base, 1);
      final r = lim.reserveN(base, 1);
      expect(r.ok, isTrue);
      expect(r.delayFrom(base), equals(infDuration));
    });

    test(
      'reserve() - e o atalho de reserveN usando a hora atual e n igual 1',
      () {
        final lim = Limiter(const Limit(10), 5);
        final r = lim.reserve();
        expect(r.ok, isTrue);
      },
    );

    test('reserveN() - cancelar restaura os tokens no mesmo instante, vetor Go '
        'menos 1 apos reservar e 0 apos cancelar', () {
      final lim = Limiter(const Limit(1), 2);
      lim.allowN(base, 2);
      final r = lim.reserveN(base, 1);
      expect(lim.tokensAt(base), equals(-1));
      r.cancelAt(base);
      expect(lim.tokensAt(base), equals(0));
    });

    test('cancelAt() - reserva nao ok nao tem efeito, vetor Go tokens '
        'unaffected by cancel = 5', () {
      final lim = Limiter(const Limit(10), 5);
      final r = lim.reserveN(base, 100);
      expect(r.ok, isFalse);
      r.cancelAt(base);
      expect(lim.tokensAt(base), equals(5));
    });

    test('setLimitAt() - avanca os tokens antes de trocar o limite, vetor Go '
        'tokens = 5 e Limit = 2', () {
      final lim = Limiter(const Limit(10), 5);
      lim.allowN(base, 5);
      final t3 = base.add(const Duration(milliseconds: 500));
      lim.setLimitAt(t3, const Limit(2));
      expect(lim.tokensAt(t3), equals(5));
      expect(lim.limit, equals(const Limit(2)));
    });

    test('setLimit() - e o atalho de setLimitAt usando a hora atual', () {
      final lim = Limiter(const Limit(10), 5);
      lim.setLimit(const Limit(3));
      expect(lim.limit, equals(const Limit(3)));
    });

    test('setBurstAt() - avanca os tokens e depois os limita ao novo burst, '
        'vetor Go tokens = 1 e Burst = 1', () {
      final lim = Limiter(const Limit(10), 5);
      lim.allowN(base, 5);
      final t3 = base.add(const Duration(milliseconds: 500));
      lim.setLimitAt(t3, const Limit(2));
      lim.setBurstAt(t3, 1);
      expect(lim.tokensAt(t3), equals(1));
      expect(lim.burst, equals(1));
    });

    test('setBurst() - e o atalho de setBurstAt usando a hora atual', () {
      final lim = Limiter(const Limit(10), 5);
      lim.setBurst(2);
      expect(lim.burst, equals(2));
    });

    test(
      'waitN() - retorna imediatamente quando ha tokens disponiveis',
      () async {
        final lim = Limiter(const Limit(10), 5);
        await expectLater(lim.waitN(1), completes);
      },
    );

    test('waitN() - lanca WaitBurstExceededException quando n excede o burst '
        'e o limite nao e infinito', () async {
      final lim = Limiter(const Limit(10), 5);
      await expectLater(
        lim.waitN(6),
        throwsA(isA<WaitBurstExceededException>()),
      );
    });

    test('waitN() - com limite infinito n acima do burst nao lanca excecao de '
        'burst', () async {
      final lim = Limiter(Limit.inf, 0);
      await expectLater(lim.waitN(1000), completes);
    });

    test('waitN() - lanca WaitDeadlineExceededException quando o delay excede '
        'o deadline', () async {
      final lim = Limiter(const Limit(1), 1);
      lim.allowN(DateTime.now(), 1); // drena o unico token
      await expectLater(
        lim.waitN(
          1,
          deadline: DateTime.now().add(const Duration(milliseconds: 10)),
        ),
        throwsA(isA<WaitDeadlineExceededException>()),
      );
    });

    test('waitN() - lanca WaitCanceledException quando cancellation dispara '
        'antes do delay terminar', () async {
      final lim = Limiter(const Limit(1), 1);
      lim.allowN(DateTime.now(), 1); // forca uma espera de cerca de 1s
      final cancelCompleter = Completer<void>();
      final future = lim.waitN(1, cancellation: cancelCompleter.future);
      cancelCompleter.complete();
      await expectLater(future, throwsA(isA<WaitCanceledException>()));
    });

    test('waitN() - lanca WaitCanceledException quando cancellation ja esta '
        'completo antes da chamada', () async {
      final lim = Limiter(const Limit(10), 5);
      await expectLater(
        lim.waitN(1, cancellation: Future<void>.value()),
        throwsA(isA<WaitCanceledException>()),
      );
    });

    test('wait() - e o atalho de waitN com n igual 1', () async {
      final lim = Limiter(const Limit(10), 5);
      await expectLater(lim.wait(), completes);
    });
  });

  group('Reservation [Atomic Audit]', () {
    test('ok - verdadeiro quando a reserva foi concedida', () {
      final lim = Limiter(const Limit(10), 5);
      expect(lim.reserveN(base, 1).ok, isTrue);
    });

    test('ok - falso quando n excede o burst', () {
      final lim = Limiter(const Limit(10), 5);
      expect(lim.reserveN(base, 100).ok, isFalse);
    });

    test('delayFrom() - zero quando o tempo de agir ja passou', () {
      final lim = Limiter(const Limit(1), 1);
      lim.allowN(base, 1);
      final r = lim.reserveN(base, 1);
      final muchLater = base.add(const Duration(seconds: 10));
      expect(r.delayFrom(muchLater), equals(Duration.zero));
    });

    test('delayFrom() - infDuration quando a reserva nao e ok', () {
      final lim = Limiter(const Limit(10), 5);
      final r = lim.reserveN(base, 100);
      expect(r.delayFrom(base), equals(infDuration));
    });

    test('delay() - e o atalho de delayFrom usando a hora atual', () {
      final lim = Limiter(const Limit(10), 5);
      final r = lim.reserveN(DateTime.now(), 1);
      expect(r.delay(), equals(Duration.zero));
    });

    test('cancel() - e o atalho de cancelAt usando a hora atual', () {
      final lim = Limiter(const Limit(1), 2);
      lim.allowN(DateTime.now(), 2);
      final r = lim.reserveN(DateTime.now(), 1);
      expect(lim.tokens(), lessThan(0));
      r.cancel();
      // Apos cancelar imediatamente, os tokens voltam para perto de zero
      // (tolerancia generosa para o tempo real decorrido no teste)
      expect(lim.tokens(), inInclusiveRange(-0.5, 1.5));
    });

    test('cancelAt() - e um no-op quando a reserva nao e ok', () {
      final lim = Limiter(const Limit(10), 5);
      final r = lim.reserveN(base, 100);
      r.cancelAt(base);
      expect(lim.tokensAt(base), equals(5));
    });
  });

  group('Sometimes [Atomic Audit]', () {
    test('first - as primeiras N chamadas de run executam a acao, vetor Go '
        'First 2 e cinco chamadas rodam 2 vezes', () {
      final s = Sometimes()..first = 2;
      var count = 0;
      for (var i = 0; i < 5; i++) {
        s.run(() => count++);
      }
      expect(count, equals(2));
    });

    test('every - a cada N-esima chamada contando a partir da primeira executa '
        'a acao, vetor Go Every 3 e sete chamadas rodam 3 vezes', () {
      final s = Sometimes()..every = 3;
      var count = 0;
      for (var i = 0; i < 7; i++) {
        s.run(() => count++);
      }
      expect(count, equals(3));
    });

    test('run() - valor zero executa a acao exatamente uma vez, vetor Go '
        'quatro chamadas rodam 1 vez', () {
      final s = Sometimes();
      var count = 0;
      for (var i = 0; i < 4; i++) {
        s.run(() => count++);
      }
      expect(count, equals(1));
    });

    test('interval - executa novamente apos o intervalo decorrido', () async {
      final s = Sometimes()..interval = const Duration(milliseconds: 20);
      var count = 0;
      s.run(() => count++); // primeira chamada sempre executa
      s.run(() => count++); // muito cedo, nao executa
      expect(count, equals(1));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      s.run(() => count++); // intervalo decorrido, executa
      expect(count, equals(2));
    });
  });
}
