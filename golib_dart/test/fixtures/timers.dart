// `timers.go` escrito à mão como o g2d emitiria (sobre o shim `time`);
// `timer_context_oracle_test.dart` compara a saída com `go run` em VM, JS e
// Wasm.
// ignore_for_file: library_prefixes
import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/fmt.dart' as fmt;
import 'package:golib_dart/time.dart' as time;

const _any = go.Elem<Object?>(16, go.zeroNull, pointers: true);

void println(List<Object?> args) => fmt.println(go.Slice.of(args, _any));

Golang.String s(String x) => Golang.String.fromDart(x);

time.Duration ms(int n) => time.Duration(n * 1000000);

void main() {
  go.runMain(() async {
    final done = go.Chan<Golang.String>(0, Golang.String());
    for (final (name, d) in [('c', 60), ('a', 20), ('b', 40)]) {
      go.spawn(() async {
        await time.sleep(ms(d));
        await go.chanSend(done, s(name));
      });
    }
    println([
      await go.chanRecv(done),
      await go.chanRecv(done),
      await go.chanRecv(done),
    ]);

    final never = go.Chan<Golang.Int>(0, Golang.Int());
    final (i, _, _) = await go.select([
      go.RecvCase(never),
      go.RecvCase(time.after(ms(10))),
    ]);
    println([s(i == 0 ? 'never' : 'timeout')]);

    final t = time.newTimer(ms(10));
    println([
      Golang.Int(go.chanLen(t.c)),
      Golang.Int(go.chanCap(t.c)),
      t.stop(),
      t.stop(),
    ]);
    t.reset(ms(5));
    await time.sleep(ms(25));
    println([Golang.Int(go.chanLen(t.c)), t.stop()]);
    final (j, _, _) = go.selectNow([go.RecvCase(t.c)]);
    println([s(j == 0 ? 'stale' : 'nothing')]);
    println([t.reset(ms(5)), t.stop(), t.stop()]);
    t.reset(ms(5));
    await go.chanRecv(t.c);
    println([
      s('recv'),
      t.stop(),
      t.reset(time.Duration(3600000000000)),
      t.stop(),
    ]);

    final tk = time.newTicker(ms(10));
    for (var i = 0; i < 3; i++) {
      await go.chanRecv(tk.c);
      println([s('tick'), Golang.Int(i)]);
    }
    tk.stop();
    await time.sleep(ms(30));
    final (k, _, _) = go.selectNow([go.RecvCase(tk.c)]);
    println([s(k == 0 ? 'tick depois do Stop' : 'parado')]);

    final ran = go.Chan<Golang.String>(2, Golang.String());
    time.afterFunc(ms(5), () => go.chanSend(ran, s('f')));
    final t2 = time.afterFunc(ms(5), () => go.chanSend(ran, s('nunca')));
    println([t2.stop(), t2.c == null]);
    println([await go.chanRecv(ran)]);
    await time.sleep(ms(20));
    println([Golang.Int(go.chanLen(ran))]);

    println([time.tick(time.Duration()) == null]);
    final d = go.Defers();
    try {
      d.defer(() => println([s('recover:'), go.recover(d)]));
      time.newTicker(time.Duration());
    } catch (e, st) {
      d.fail(e, st);
    } finally {
      d.run();
    }

    time.afterFunc(ms(20), () => println([s('disparou')]));
    await go.chanRecv(never);
  });
}
