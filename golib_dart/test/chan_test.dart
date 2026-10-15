// ignore_for_file: library_prefixes
import 'package:golib_dart/builtin.dart' as go;
import 'package:test/test.dart';

void main() {
  group('sem buffer', () {
    test('handoff direto: recv completa o send pendente', () async {
      final ch = go.Chan<int>(0, 0);
      final sendFuture = ch.send(42); // bloqueia: sem receptor ainda.
      final v = await ch.recv(); // mesmo turno: entrega direta.
      expect(v, 42);
      await sendFuture; // já resolvido pelo handoff acima.
    });

    test('produtor/consumidor concorrentes preservam a ordem', () async {
      final ch = go.Chan<int>(0, 0);
      final received = <int>[];
      Future<void> consume() async {
        for (var i = 0; i < 5; i++) {
          received.add(await ch.recv());
        }
      }

      final consumer = consume();
      for (var i = 0; i < 5; i++) {
        await ch.send(i);
      }
      await consumer;
      expect(received, [0, 1, 2, 3, 4]);
    });
  });

  group('com buffer', () {
    test('send não bloqueia enquanto há espaço', () async {
      final ch = go.Chan<int>(2, 0);
      await ch.send(1);
      await ch.send(2);
      expect(ch.len, 2);
      expect(ch.cap, 2);
      expect(await ch.recv(), 1);
      expect(await ch.recv(), 2);
    });

    test(
      'send bloqueia com buffer cheio; recv libera o próximo da fila',
      () async {
        final ch = go.Chan<int>(2, 0);
        await ch.send(1);
        await ch.send(2);
        final third = ch.send(3); // buffer cheio: entra na fila de espera.
        expect(
          await ch.recv(),
          1,
        ); // libera espaço e promove o send(3) pendente.
        await third; // já deve ter completado (valor 3 movido pro buffer).
        expect(ch.len, 2); // [2, 3]: o buffer continua cheio.
        expect(await ch.recv(), 2);
        expect(await ch.recv(), 3);
      },
    );

    test('FIFO', () async {
      final ch = go.Chan<int>(3, 0);
      for (final v in [1, 2, 3]) {
        await ch.send(v);
      }
      expect([await ch.recv(), await ch.recv(), await ch.recv()], [1, 2, 3]);
    });
  });

  group('close', () {
    test('acorda receptores esperando com (zero, false)', () async {
      final ch = go.Chan<int>(0, -1);
      final r1 = ch.recv2(); // bloqueia: buffer e fila de envio vazios.
      final r2 = ch.recv2();
      ch.close(); // mesmo turno: acorda os dois.
      expect(await r1, (-1, false));
      expect(await r2, (-1, false));
    });

    test('drena o buffer antes de devolver (zero, false)', () async {
      final ch = go.Chan<int>(2, -1);
      await ch.send(10);
      ch.close();
      expect(await ch.recv2(), (10, true));
      expect(await ch.recv2(), (-1, false));
      expect(await ch.recv2(), (-1, false)); // recv extra continua ok=false.
    });

    test('recv sem comma-ok devolve zero num canal fechado', () async {
      final ch = go.Chan<int>(0, -7);
      ch.close();
      expect(await ch.recv(), -7);
    });

    test('send em canal fechado panica com a mensagem exata do Go', () async {
      final ch = go.Chan<int>(0, 0);
      ch.close();
      await expectLater(
        ch.send(1),
        throwsA(
          isA<go.Panic>().having(
            (p) => p.toString(),
            'toString',
            'panic: send on closed channel',
          ),
        ),
      );
    });

    test('close de canal fechado panica com a mensagem exata do Go', () {
      final ch = go.Chan<int>(0, 0);
      ch.close();
      expect(
        ch.close,
        throwsA(
          isA<go.Panic>().having(
            (p) => p.toString(),
            'toString',
            'panic: close of closed channel',
          ),
        ),
      );
    });

    test(
      'close acorda send bloqueado com panic (não entrega o valor)',
      () async {
        final ch = go.Chan<int>(0, 0);
        final sendFuture = ch.send(1); // bloqueia: sem receptor.
        ch.close(); // mesmo turno: o send pendente panica, não é entregue.
        await expectLater(sendFuture, throwsA(isA<go.Panic>()));
        expect(ch.len, 0);
      },
    );

    test('panic de canal fechado é recuperável dentro de um Defers', () async {
      final ch = go.Chan<int>(0, 0);
      ch.close();
      String? recovered;
      final d = go.Defers();
      d.defer(() {
        final e = go.recover(d);
        if (e is go.GoError) recovered = e.error().toString();
      });
      try {
        await ch.send(1);
      } catch (e, st) {
        d.fail(e, st);
      } finally {
        d.run();
      }
      expect(recovered, 'send on closed channel');
    });
  });

  group('canal nil', () {
    test('len e cap são 0', () {
      expect(go.chanLen(null), 0);
      expect(go.chanCap(null), 0);
    });

    test('close panica com a mensagem exata do Go', () {
      expect(
        () => go.chanClose<int>(null),
        throwsA(
          isA<go.Panic>().having(
            (p) => p.toString(),
            'toString',
            'panic: close of nil channel',
          ),
        ),
      );
    });
  });

  group('make(chan T, n)', () {
    test('tamanho negativo panica', () {
      expect(
        () => go.Chan<int>(-1, 0),
        throwsA(
          isA<go.Panic>().having(
            (p) => p.toString(),
            'toString',
            'panic: makechan: size out of range',
          ),
        ),
      );
    });

    test('tamanho absurdo panica', () {
      expect(() => go.Chan<int>(1 << 40, 0), throwsA(isA<go.Panic>()));
    });
  });

  test('identidade por referência: == é identical', () {
    final a = go.Chan<int>(1, 0);
    final b = go.Chan<int>(1, 0);
    // ignore: unrelated_type_equality_checks
    expect(a == a, isTrue);
    expect(a == b, isFalse);
  });
}
