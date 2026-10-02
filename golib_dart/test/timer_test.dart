// Timers do shim `time` (`Sleep`, `Timer`, `Ticker`, `After`, `AfterFunc`,
// `Tick`) com a semântica do Go ≥ 1.23. Durações curtas (ms) e asserções de
// ordem de eventos, nunca de tempo absoluto. Sem `dart:io`: roda em VM, JS e
// Wasm. Os mesmos cenários contra `go run` (inclusive o deadlock) estão em
// `timer_context_oracle_test.dart`.
// ignore_for_file: library_prefixes
import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/time.dart' as time;
import 'package:test/test.dart';

time.Duration ms(int n) => time.Duration(n * 1000000);

void main() {
  test('Sleep ordena goroutines pelo prazo', () async {
    final log = <String>[];
    final wg = go.Chan<int>(3, 0);
    for (final (name, d) in [('c', 60), ('a', 20), ('b', 40)]) {
      go.spawn(() async {
        await time.sleep(ms(d));
        log.add(name);
        await wg.send(0);
      });
    }
    for (var i = 0; i < 3; i++) {
      await wg.recv();
    }
    expect(log, ['a', 'b', 'c']);
  });

  test('Sleep(0) e Sleep negativo voltam logo', () async {
    await time.sleep(time.Duration());
    await time.sleep(ms(-5));
  });

  test('After em select: timeout ganha de canal sem remetente', () async {
    final never = go.Chan<int>(0, 0);
    final (i, _, _) = await go.select([
      go.RecvCase(never),
      go.RecvCase(time.after(ms(10))),
    ]);
    expect(i, 1);
  });

  test('After em select: valor chega antes do timeout', () async {
    final ch = go.Chan<int>(0, 0);
    go.spawn(() async {
      await time.sleep(ms(5));
      await ch.send(7);
    });
    final (i, v, _) = await go.select([
      go.RecvCase(ch),
      go.RecvCase(time.after(ms(200))),
    ]);
    expect((i, v), (0, 7));
  });

  test('valor recebido é Now() aproximado (depois do início)', () async {
    final start = time.now();
    final t = time.newTimer(ms(5));
    final v = await go.chanRecv(t.c);
    expect(v.before(start), isFalse);
    expect(v.sub(start) >= ms(4), isTrue);
  });

  test('canal de timer: len e cap são 0', () async {
    final t = time.newTimer(ms(1));
    expect((go.chanLen(t.c), go.chanCap(t.c)), (0, 0));
    await time.sleep(ms(20));
    expect((go.chanLen(t.c), go.chanCap(t.c)), (0, 0));
    expect(go.selectNow([go.RecvCase(t.c)]).$1, 0);
  });

  test('Stop antes de disparar: true, e nada chega em C', () async {
    final t = time.newTimer(ms(10));
    expect(t.stop(), isTrue);
    expect(t.stop(), isFalse);
    await time.sleep(ms(30));
    expect(go.selectNow([go.RecvCase(t.c)]).$1, -1);
  });

  test(
    'Stop depois de disparar sem receber: true e descarta (Go 1.23)',
    () async {
      final t = time.newTimer(ms(5));
      await time.sleep(ms(25));
      expect(t.stop(), isTrue);
      expect(go.selectNow([go.RecvCase(t.c)]).$1, -1);
      expect(t.stop(), isFalse);
    },
  );

  test('Stop depois de receber: false', () async {
    final t = time.newTimer(ms(5));
    await go.chanRecv(t.c);
    expect(t.stop(), isFalse);
  });

  test('Reset: rearma, devolve se estava pendente, sem valor velho', () async {
    final t = time.newTimer(ms(5));
    await time.sleep(ms(25)); // disparou; valor não recebido.
    final log = <String>[];
    expect(t.reset(ms(30)), isTrue); // descartou o disparo velho.
    go.spawn(() async {
      await time.sleep(ms(10));
      log.add('sleep');
    });
    await go.chanRecv(t.c);
    log.add('timer');
    expect(log, ['sleep', 'timer']);
    expect(t.reset(ms(5)), isFalse);
    await go.chanRecv(t.c);
  });

  test('timer vencido dispara no select com default, sem ceder', () async {
    final t = time.newTimer(ms(2));
    final sw = Stopwatch()..start();
    while (sw.elapsedMilliseconds < 10) {} // ocupado, sem `await`.
    expect(go.selectNow([go.RecvCase(t.c)]).$1, 0);
  });

  test('Ticker: N ticks em ordem, Stop encerra', () async {
    final tk = time.newTicker(ms(10));
    var n = 0;
    while (n < 3) {
      await go.chanRecv(tk.c);
      n++;
    }
    tk.stop();
    await time.sleep(ms(40));
    expect(go.selectNow([go.RecvCase(tk.c)]).$1, -1);
    expect(n, 3);
  });

  test('Ticker: leitor lento perde ticks (canal de 1)', () async {
    final tk = time.newTicker(ms(5));
    await time.sleep(ms(40));
    expect(go.selectNow([go.RecvCase(tk.c)]).$1, 0);
    expect(go.selectNow([go.RecvCase(tk.c)]).$1, -1);
    tk.reset(ms(5));
    await go.chanRecv(tk.c);
    tk.stop();
  });

  test('Tick(<=0) é nil; NewTicker(<=0) e Reset(<=0) panicam', () {
    expect(time.tick(time.Duration()), isNull);
    expect(
      () => time.newTicker(time.Duration()),
      throwsA(
        isA<go.Panic>().having(
          (p) => '${p.value}',
          'value',
          'non-positive interval for NewTicker',
        ),
      ),
    );
    final tk = time.newTicker(ms(50));
    expect(
      () => tk.reset(ms(-1)),
      throwsA(
        isA<go.Panic>().having(
          (p) => '${p.value}',
          'value',
          'non-positive interval for Ticker.Reset',
        ),
      ),
    );
    tk.stop();
  });

  test('Timer{} zero: Stop/Reset panicam; Ticker{}.Stop é no-op', () {
    expect(
      () => time.Timer().stop(),
      throwsA(
        isA<go.Panic>().having(
          (p) => '${p.value}',
          'value',
          'time: Stop called on uninitialized Timer',
        ),
      ),
    );
    expect(
      () => time.Timer().reset(ms(1)),
      throwsA(
        isA<go.Panic>().having(
          (p) => '${p.value}',
          'value',
          'time: Reset called on uninitialized Timer',
        ),
      ),
    );
    time.Ticker().stop();
    expect(
      () => time.Ticker().reset(ms(1)),
      throwsA(
        isA<go.Panic>().having(
          (p) => '${p.value}',
          'value',
          'time: Reset called on uninitialized Ticker',
        ),
      ),
    );
  });

  test('AfterFunc roda f numa goroutine; Stop a tempo impede', () async {
    final log = <String>[];
    final done = go.Chan<int>(0, 0);
    final t = time.afterFunc(ms(5), () async {
      log.add('f');
      await done.send(1);
    });
    expect(t.c, isNull);
    final t2 = time.afterFunc(ms(5), () => log.add('nunca'));
    expect(t2.stop(), isTrue);
    await done.recv();
    expect(t.stop(), isFalse);
    await time.sleep(ms(20));
    expect(log, ['f']);
  });

  test('AfterFunc com Reset dispara de novo', () async {
    var n = 0;
    final t = time.afterFunc(ms(5), () => n++);
    await time.sleep(ms(20));
    expect(t.reset(ms(5)), isFalse);
    await time.sleep(ms(20));
    expect(n, 2);
  });
}
