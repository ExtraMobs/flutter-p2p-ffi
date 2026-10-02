// ignore_for_file: library_prefixes
import 'package:golib_dart/builtin.dart' as go;
import 'package:test/test.dart';

void main() {
  group('selectNow (com default)', () {
    test('nada pronto devolve -1 (roda o default)', () {
      final a = go.Chan<int>(0, 0);
      final result = go.selectNow([go.RecvCase(a)]);
      expect(result, (-1, null, false));
    });

    test('recv pronto (buffer) devolve índice, valor e ok', () {
      final ch = go.Chan<int>(1, 0);
      ch.send(5); // buffer com espaço: completa sem suspender.
      final (idx, v, ok) = go.selectNow([go.RecvCase(ch)]);
      expect(idx, 0);
      expect(v, 5);
      expect(ok, isTrue);
    });

    test('recv pronto num canal fechado devolve (zero, false)', () {
      final ch = go.Chan<int>(0, -9);
      ch.close();
      final (idx, v, ok) = go.selectNow([go.RecvCase(ch)]);
      expect(idx, 0);
      expect(v, -9);
      expect(ok, isFalse);
    });

    test('send pronto (buffer com espaço) entrega o valor', () {
      final ch = go.Chan<int>(1, 0);
      final (idx, v, ok) = go.selectNow([go.SendCase(ch, 7)]);
      expect((idx, v, ok), (0, null, true));
      expect(go.chanLen(ch), 1);
    });

    test('send pronto num canal fechado panica ao ser escolhido', () {
      final ch = go.Chan<int>(0, 0);
      ch.close();
      expect(
        () => go.selectNow([go.SendCase(ch, 1)]),
        throwsA(
          isA<go.Panic>().having(
            (p) => p.toString(),
            'toString',
            'panic: send on closed channel',
          ),
        ),
      );
    });

    test('canal nil nunca fica pronto', () {
      final real = go.Chan<int>(1, 0);
      real.send(5);
      final (idx, v, ok) = go.selectNow([
        go.RecvCase<int>(null),
        go.RecvCase(real),
      ]);
      expect(idx, 1);
      expect(v, 5);
      expect(ok, isTrue);
    });

    test('só canais nil: nada pronto', () {
      final result = go.selectNow([go.RecvCase<int>(null), go.SendCase<int>(null, 1)]);
      expect(result.$1, -1);
    });

    test('fairness aproximada: escolha uniforme entre vários prontos', () {
      final counts = <int, int>{};
      for (var i = 0; i < 300; i++) {
        final a = go.Chan<int>(1, 0);
        final b = go.Chan<int>(1, 0);
        a.send(1);
        b.send(2);
        final (idx, _, _) = go.selectNow([go.RecvCase(a), go.RecvCase(b)]);
        counts[idx] = (counts[idx] ?? 0) + 1;
      }
      // Com 300 tentativas e duas opções, uma escolha uniforme não deve
      // ficar perto de sempre escolher a mesma (o teste tolera bastante
      // desvio; só quer pegar um `_rand` quebrado ou uma ordem fixa).
      expect(counts[0], greaterThan(50));
      expect(counts[1], greaterThan(50));
    });
  });

  group('select (bloqueante)', () {
    test('escolhe o canal que fica pronto (handoff no mesmo turno)', () async {
      final a = go.Chan<int>(0, 0);
      final b = go.Chan<int>(0, 0);
      final selectFuture = go.select([go.RecvCase(a), go.RecvCase(b)]);
      await b.send(7); // mesmo turno: entrega direta pro waiter do select em b.
      expect(await selectFuture, (1, 7, true));
    });

    test('send escolhido entrega quando um recv aparece', () async {
      final ch = go.Chan<int>(0, 0);
      final selectFuture = go.select([go.SendCase(ch, 9)]);
      expect(await ch.recv(), 9); // mesmo turno: completa o select.
      expect(await selectFuture, (0, null, true));
    });

    test('canal nil nunca destrava um select bloqueante', () async {
      final real = go.Chan<int>(0, 0);
      final selectFuture = go.select([go.RecvCase<int>(null), go.RecvCase(real)]);
      await real.send(3);
      expect(await selectFuture, (1, 3, true));
    });

    test('send panica se o canal fecha enquanto ainda esperava', () async {
      final ch = go.Chan<int>(0, 0);
      final selectFuture = go.select([go.SendCase(ch, 1)]);
      ch.close(); // mesmo turno: o send pendente do select panica.
      await expectLater(
        selectFuture,
        throwsA(
          isA<go.Panic>().having(
            (p) => p.toString(),
            'toString',
            'panic: send on closed channel',
          ),
        ),
      );
    });

    test('o caso não escolhido é retirado do canal (não vaza um recv)', () async {
      final a = go.Chan<int>(0, 0);
      final b = go.Chan<int>(0, 0);
      final selectFuture = go.select([go.RecvCase(a), go.RecvCase(b)]);
      await b.send(1); // escolhe b; a não deveria mais ter um waiter pendente.
      await selectFuture;
      // Um send solto em `a` agora não tem receptor nenhum: fica pendente.
      final loneSend = a.send(2);
      var delivered = false;
      loneSend.then((_) => delivered = true);
      expect(delivered, isFalse);
      // Consumidor de verdade ainda funciona normalmente.
      expect(await a.recv(), 2);
    });
  });
}
