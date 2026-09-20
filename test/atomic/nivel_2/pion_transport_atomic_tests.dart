// test/atomic/nivel_2/pion_transport_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo pion/transport v3 (transpiled_pion_transport).
// Vetores adaptados de go-ipfs-reference/pion-transport/deadline/deadline_test.go.
// Nível 2: depende de Timer/relógio real (mesmo motivo do teste Go original).

import 'package:test/test.dart';
import 'package:transpiled_pion_transport/transpiled_pion_transport.dart';

void main() {
  group('Deadline [Atomic Audit]', () {
    test('Deadline() - construtor inicia sem prazo definido', () {
      final d = Deadline();
      expect(d.deadline, isNull);
      expect(d.err, isNull);
    });

    test('done() - completa quando o prazo definido expira', () async {
      final d = Deadline();
      d.set(DateTime.now().add(const Duration(milliseconds: 15)));
      await d.done.timeout(const Duration(milliseconds: 100));
      expect(d.err, isA<DeadlineExceededException>());
    });

    test('set() - dispara done() apenas após o prazo definido expirar '
        '(porta TestDeadline/Deadline)', () async {
      final d = Deadline();
      d.set(DateTime.now().add(const Duration(milliseconds: 30)));

      var firedEarly = false;
      d.done.then((_) => firedEarly = true);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(firedEarly, isFalse, reason: 'done completou cedo demais');

      await d.done.timeout(const Duration(milliseconds: 100));
      expect(d.err, isA<DeadlineExceededException>());
    });

    test('set() - adiar o prazo posterga o disparo de done() '
        '(porta TestDeadline/DeadlineExtend)', () async {
      final d = Deadline();
      final start = DateTime.now();
      d.set(start.add(const Duration(milliseconds: 20)));
      d.set(start.add(const Duration(milliseconds: 60)));

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(d.err, isNull, reason: 'não deveria ter expirado ainda');

      await d.done.timeout(const Duration(milliseconds: 100));
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inMilliseconds, greaterThanOrEqualTo(55));
    });

    test('set() - antecipar o prazo faz done() disparar mais cedo '
        '(porta TestDeadline/DeadlinePretend)', () async {
      final d = Deadline();
      final start = DateTime.now();
      d.set(start.add(const Duration(milliseconds: 60)));
      d.set(start.add(const Duration(milliseconds: 15)));

      await d.done.timeout(const Duration(milliseconds: 100));
      final elapsed = DateTime.now().difference(start);
      expect(elapsed.inMilliseconds, lessThan(50));
    });

    test('set(null) - cancela o prazo e done() nunca dispara '
        '(porta TestDeadline/DeadlineCancel)', () async {
      final d = Deadline();
      d.set(DateTime.now().add(const Duration(milliseconds: 20)));
      d.set(null);
      expect(d.deadline, isNull);

      var fired = false;
      d.done.then((_) => fired = true);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(fired, isFalse);
    });

    test('err - retorna null antes do prazo, exceção após '
        '(porta TestContext/Cancel)', () async {
      final d = Deadline();
      expect(d.err, isNull);
      d.set(DateTime.fromMillisecondsSinceEpoch(1)); // já no passado
      await d.done.timeout(const Duration(milliseconds: 50));
      expect(d.err, isA<DeadlineExceededException>());
    });

    test('deadline - reflete o valor definido e não apenas se expirou '
        '(porta TestContext/Deadline)', () {
      final d = Deadline();
      expect(d.deadline, isNull);

      final dl = DateTime.fromMillisecondsSinceEpoch(12345000);
      d.set(dl);
      expect(d.deadline, equals(dl));
      expect(d.err, isA<DeadlineExceededException>());
    });

    test('value() - sempre retorna null', () {
      final d = Deadline();
      expect(d.value('qualquer-chave'), isNull);
      d.set(DateTime.now().add(const Duration(milliseconds: 5)));
      expect(d.value(null), isNull);
    });
  });

  group('DeadlineExceededException [Atomic Audit]', () {
    test('toString() - identifica a exceção de prazo excedido', () {
      expect(
        DeadlineExceededException().toString(),
        contains('deadline exceeded'),
      );
    });
  });
}
