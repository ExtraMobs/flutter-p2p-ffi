// `contexts.go` escrito à mão como o g2d emitiria (sobre os shims `context`
// e `time`); `timer_context_oracle_test.dart` compara a saída com `go run`
// em VM, JS e Wasm.
// ignore_for_file: library_prefixes
import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/context.dart' as context;
import 'package:golib_dart/errors.dart' as errors;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/fmt.dart' as fmt;
import 'package:golib_dart/time.dart' as time;

const _any = go.Elem<Object?>(16, go.zeroNull, pointers: true);

void println(List<Object?> args) => fmt.println(go.Slice.of(args, _any));

Golang.String s(String x) => Golang.String.fromDart(x);

time.Duration ms(int n) => time.Duration(n * 1000000);

final hour = time.Duration(3600000000000);

/// `type key string`.
final class Key extends Golang.StringBase<Key> {
  Key(String v) : _v = Golang.String.fromDart(v);
  Key._(this._v);
  final Golang.String _v;
  @override
  Golang.String get $str => _v;
  @override
  Key $wrapStr(Golang.String s) => Key._(s);
  @override
  String get $goType => 'main.key';
  @override
  List<String> get $methods => const [];
}

/// `*myCtx`.
final class MyCtx implements context.Context, Golang.GoTyped {
  MyCtx(this.ch);
  go.Chan<go.EmptyStruct>? ch;
  go.GoError? e;

  @override
  (time.Time, bool) deadline() => (time.Time(), false);
  @override
  go.Chan<go.EmptyStruct>? done() => ch;
  @override
  go.GoError? err() => e;
  @override
  Object? value$(Object? k) =>
      go.ifaceEq(k, Key('my')) ? s('valor de myCtx') : null;
  @override
  String get $goType => '*main.myCtx';
  @override
  List<String> get $methods => const ['Deadline', 'Done', 'Err', 'Value'];
}

Future<void> worker(
  context.Context ctx,
  Golang.String name,
  go.Chan<Golang.String> out,
) async {
  await go.chanRecv(ctx.done());
  await go.chanSend(out, name + s(': ') + ctx.err()!.error());
}

void main() {
  go.runMain(() async {
    final d = go.Defers();
    try {
      final bg = context.background();
      println([bg, context.todo(), bg.done() == null, bg.err()]);
      final (root, cancelRoot) = context.withCancel(bg);
      final vctx = context.withValue(root, Key('k'), Golang.Int(42));
      final (mid, cancelMid) = context.withCancel(vctx);
      println([mid]);
      println([
        context.withValue(
          context.withoutCancel(mid),
          Golang.Int(7),
          time.Duration(1000000000),
        ),
      ]);
      println([
        mid.value$(Key('k')),
        mid.value$(s('k')),
        mid.value$(Golang.Int(7)),
      ]);

      final out = go.Chan<Golang.String>(4, Golang.String());
      final (leaf, cancelLeaf) = context.withCancel(mid);
      d.defer(cancelLeaf);
      final (sib, cancelSib) = context.withCancel(root);
      go.spawn(() => worker(leaf, s('leaf'), out));
      go.spawn(() => worker(mid, s('mid'), out));
      go.spawn(() => worker(sib, s('sib'), out));
      cancelMid();
      var a = await go.chanRecv(out), b = await go.chanRecv(out);
      if (a > b) (a, b) = (b, a);
      println([a, s('|'), b, s('|'), root.err(), sib.err()]);
      cancelRoot();
      println([await go.chanRecv(out)]);
      cancelSib();

      final (tctx, cancelT) = context.withTimeoutCause(
        bg,
        ms(10),
        errors.new$(s('lento')),
      );
      final (_, ok) = tctx.deadline();
      println([ok, tctx.err()]);
      await go.chanRecv(tctx.done());
      println([
        tctx.err(),
        context.cause(tctx),
        errors.is$(tctx.err(), context.deadlineExceeded),
      ]);
      cancelT();
      final te = tctx.err() as dynamic;
      fmt.printf(
        s('%v %T %#v\n'),
        go.Slice.of([te.timeout(), tctx.err(), tctx.err()], _any),
      );

      final (p, cancelP) = context.withTimeout(bg, ms(10));
      final (c, cancelC) = context.withTimeout(p, hour);
      await go.chanRecv(c.done());
      println([c.err(), p.err()]);
      cancelC();
      cancelP();

      final (q, cancelQ) = context.withTimeout(bg, ms(10));
      cancelQ();
      await time.sleep(ms(20));
      println([q.err(), context.cause(q)]);

      final (cc, cancelCause) = context.withCancelCause(bg);
      cancelCause(errors.new$(s('boom')));
      cancelCause(errors.new$(s('outra')));
      final (child, _) = context.withCancel(cc);
      println([cc.err(), context.cause(cc), child.err(), context.cause(child)]);

      final my = MyCtx(go.Chan(0, go.EmptyStruct()));
      final (mc, cancelMy) = context.withCancel(my);
      println([mc, mc.value$(Key('my'))]);
      go.spawn(() async {
        await time.sleep(ms(5));
        my.e = context.canceled;
        go.chanClose(my.ch);
      });
      await go.chanRecv(mc.done());
      println([s('myCtx:'), mc.err()]);
      cancelMy();

      final (actx, cancelA) = context.withCancel(bg);
      final ran = go.Chan<Golang.String>(2, Golang.String());
      final stop1 = context.afterFunc(actx, () => go.chanSend(ran, s('f1')));
      final stop2 = context.afterFunc(actx, () => go.chanSend(ran, s('f2')));
      println([stop2(), stop2()]);
      cancelA();
      println([await go.chanRecv(ran), stop1()]);
      await time.sleep(ms(10));
      println([Golang.Int(go.chanLen(ran))]);

      final (wp, cancelW) = context.withTimeout(
        context.withValue(bg, Key('k'), s('v')),
        hour,
      );
      final w = context.withoutCancel(wp);
      cancelW();
      final (_, okW) = w.deadline();
      println([wp.err(), w.err(), w.done() == null, okW, w.value$(Key('k'))]);

      final (last, cancelLast) = context.withTimeout(bg, ms(20));
      d.defer(cancelLast);
      context.afterFunc(last, () => println([s('venceu:'), last.err()]));
      final (never, cancelNever) = context.withCancel(bg);
      d.defer(cancelNever);
      await go.chanRecv(never.done());
    } catch (e, st) {
      d.fail(e, st);
    } finally {
      await d.runAsync();
    }
  });
}
