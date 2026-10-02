// Shim `context` (porta de `context/context.go` do Go 1.26). Os textos
// esperados (`String()`, `%T`, `%#v`, mensagens de erro e de panic) são a
// saída de `go run` (Go 1.26.5); os cenários com goroutines e timers também
// rodam contra o Go em `timer_context_oracle_test.dart`. Sem `dart:io`: roda
// em VM, JS e Wasm.
// ignore_for_file: library_prefixes
import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/context.dart' as context;
import 'package:golib_dart/errors.dart' as errors;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/fmt.dart' as fmt;
import 'package:golib_dart/time.dart' as time;
import 'package:test/test.dart';

time.Duration ms(int n) => time.Duration(n * 1000000);

Golang.String s(String x) => Golang.String.fromDart(x);

const _anyElem = go.Elem<Object?>(16, go.zeroNull, pointers: true);

String sprint(Object? v) =>
    fmt.sprint(go.Slice<Object?>.of([v], _anyElem)).toString();

String sprintf(String f, Object? v) =>
    fmt.sprintf(s(f), go.Slice<Object?>.of([v], _anyElem)).toString();

bool closed(context.Context c) => go.selectNow([go.RecvCase(c.done())]).$1 == 0;

/// `type key string` do usuário (como o g2d gera um tipo nomeado sobre
/// string).
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

/// Implementação de fora de `Context` (como um tipo gerado pelo g2d), sem
/// `String()`: o cancelamento do pai tem que chegar por uma goroutine.
final class MyCtx implements context.Context, Golang.GoTyped {
  MyCtx(this.ch);
  final go.Chan<go.EmptyStruct> ch;
  go.GoError? e;

  @override
  (time.Time, bool) deadline() => (time.Time(), false);
  @override
  go.Chan<go.EmptyStruct>? done() => ch;
  @override
  go.GoError? err() => e;
  @override
  Object? value$(Object? key) => null;
  @override
  String get $goType => '*main.myCtx';
  @override
  List<String> get $methods => const ['Deadline', 'Done', 'Err', 'Value'];
}

Matcher panics(String msg) =>
    throwsA(isA<go.Panic>().having((p) => '${p.value}', 'value', msg));

void main() {
  test('Background/TODO: nunca cancelam, String()', () {
    final bg = context.background();
    expect(sprint(bg), 'context.Background');
    expect(sprint(context.todo()), 'context.TODO');
    expect(bg.done(), isNull);
    expect(bg.err(), isNull);
    expect(bg.deadline().$2, isFalse);
    expect(bg.value$(s('x')), isNull);
    expect(identical(context.background(), bg), isTrue);
  });

  test('String() encadeado, como o Go', () {
    final (c1, cancel) = context.withCancel(context.background());
    expect(sprint(c1), 'context.Background.WithCancel');
    final c2 = context.withValue(c1, Key('k'), Golang.Int(42));
    expect(
      sprint(c2),
      'context.Background.WithCancel.WithValue(main.key, int)',
    );
    final c3 = context.withValue(c2, Golang.Int(7), s('x'));
    expect(
      sprint(c3),
      'context.Background.WithCancel.WithValue(main.key, int)'
      '.WithValue(int, x)',
    );
    final c5 = context.withoutCancel(c3);
    expect(sprint(c5), '${sprint(c3)}.WithoutCancel');
    final (c6, _) = context.withCancelCause(c5);
    expect(sprint(c6), '${sprint(c3)}.WithoutCancel.WithCancel');
    expect(
      sprint(context.withValue(context.todo(), s('str'), null)),
      'context.TODO.WithValue(str, <nil>)',
    );
    expect(
      sprint(context.withValue(context.todo(), Golang.Int(1), ms(1000))),
      'context.TODO.WithValue(int, 1s)',
    );
    expect(sprint(MyCtx(go.Chan(0, go.EmptyStruct()))), isNotEmpty);
    final (c7, _) = context.withCancel(MyCtx(go.Chan(0, go.EmptyStruct())));
    expect(sprint(c7), '*main.myCtx.WithCancel');
    cancel();
  });

  test('WithDeadline no passado: String() e DeadlineExceeded na hora', () {
    final d = time.date(
      Golang.Int(2020),
      time.Month(1),
      Golang.Int(2),
      Golang.Int(3),
      Golang.Int(4),
      Golang.Int(5),
      Golang.Int(6),
      time.utc,
    );
    final (c, cancel) = context.withDeadline(context.todo(), d);
    expect(
      sprint(c),
      startsWith(
        'context.TODO.WithDeadline(2020-01-02 03:04:05.000000006 +0000 UTC [-',
      ),
    );
    expect(identical(c.err(), context.deadlineExceeded), isTrue);
    expect(closed(c), isTrue);
    final (got, ok) = c.deadline();
    expect((got.equal(d), ok), (true, true));
    cancel();
    expect(identical(c.err(), context.deadlineExceeded), isTrue);
  });

  test('Value encadeado: o mais próximo ganha; tipos diferentes não casam', () {
    var c = context.withValue(context.background(), Key('k'), Golang.Int(1));
    final (cc, cancel) = context.withCancel(c);
    c = context.withValue(cc, Golang.Int(7), s('x'));
    c = context.withoutCancel(c);
    c = context.withValue(c, Key('k'), Golang.Int(2));
    expect(c.value$(Key('k')), Golang.Int(2));
    expect(c.value$(Golang.Int(7)), s('x'));
    expect(c.value$(s('k')), isNull); // string ≠ main.key
    expect(c.value$(Golang.Int64(7)), isNull); // int64 ≠ int
    expect(cc.value$(Key('k')), Golang.Int(1));
    cancel();
  });

  test('WithValue: panics do Go', () {
    expect(
      () => context.withValue(null, s('k'), null),
      panics('cannot create context from nil parent'),
    );
    expect(
      () => context.withValue(context.todo(), null, null),
      panics('nil key'),
    );
    final slice = go.Slice<Object?>.of([], _anyElem);
    expect(
      () => context.withValue(context.todo(), slice, null),
      panics('key is not comparable'),
    );
    expect(
      () => context.withCancel(null),
      panics('cannot create context from nil parent'),
    );
  });

  test('cancelamento em cascata; irmão e pai intactos', () {
    final (root, cancelRoot) = context.withCancel(context.background());
    final (mid, cancelMid) = context.withCancel(root);
    final leaf = context.withValue(mid, s('k'), s('v'));
    final (leaf2, _) = context.withCancel(leaf);
    final (sib, cancelSib) = context.withCancel(root);
    expect(
      [closed(root), closed(mid), closed(leaf2), closed(sib)],
      [false, false, false, false],
    );
    cancelMid();
    expect(
      [closed(root), closed(mid), closed(leaf2), closed(sib)],
      [false, true, true, false],
    );
    expect(identical(leaf2.err(), context.canceled), isTrue);
    expect(leaf.err(), context.canceled);
    expect(root.err(), isNull);
    cancelRoot();
    expect(closed(sib), isTrue);
    cancelSib();
    cancelMid();
  });

  test('filho de pai já cancelado nasce cancelado', () {
    final (p, cancel) = context.withCancelCause(context.background());
    cancel(errors.new$(s('boom')));
    final (c, _) = context.withCancel(p);
    expect(closed(c), isTrue);
    expect(sprint(context.cause(c)), 'boom');
    expect(sprint(c.err()), 'context canceled');
  });

  test('Cause: causa do CancelCauseFunc; nil antes; Err sem causa', () {
    final (c, cancel) = context.withCancelCause(context.background());
    expect(context.cause(c), isNull);
    final boom = errors.new$(s('boom'));
    cancel(boom);
    cancel(errors.new$(s('outra'))); // só o primeiro vale.
    expect(identical(context.cause(c), boom), isTrue);
    expect(identical(c.err(), context.canceled), isTrue);
    final (c2, cancel2) = context.withCancelCause(context.background());
    cancel2(null);
    expect(identical(context.cause(c2), context.canceled), isTrue);
    expect(context.cause(context.background()), isNull);
  });

  test('DeadlineExceeded: Error/Timeout/Temporary, %T e %#v do Go', () {
    final e = context.deadlineExceeded;
    expect(sprint(e), 'context deadline exceeded');
    expect(sprintf('%T', e), 'context.deadlineExceededError');
    expect(sprintf('%#v', e), 'context.deadlineExceededError{}');
    expect(sprintf('%T', context.canceled), '*errors.errorString');
    final dyn = e as dynamic;
    expect((dyn.timeout(), dyn.temporary()), (true, true));
    expect(errors.is$(e, context.deadlineExceeded), isTrue);
    expect(go.goHasMethod(e, 'Timeout'), isTrue);
  });

  test('WithTimeout dispara DeadlineExceeded e Cause', () async {
    final (c, cancel) = context.withTimeoutCause(
      context.background(),
      ms(5),
      errors.new$(s('slow')),
    );
    final (_, ok) = c.deadline();
    expect(ok, isTrue);
    expect(c.err(), isNull);
    await go.chanRecv(c.done());
    expect(identical(c.err(), context.deadlineExceeded), isTrue);
    expect(sprint(context.cause(c)), 'slow');
    cancel(); // depois de vencer: sem efeito.
    expect(identical(c.err(), context.deadlineExceeded), isTrue);
  });

  test('WithTimeout cancelado antes do prazo: Canceled', () async {
    final (c, cancel) = context.withTimeout(context.background(), ms(20));
    cancel();
    expect(identical(c.err(), context.canceled), isTrue);
    await time.sleep(ms(40));
    expect(identical(c.err(), context.canceled), isTrue);
  });

  test('WithDeadline mais tarde que o do pai: só WithCancel', () async {
    final (p, cancelP) = context.withTimeout(context.background(), ms(10));
    final (c, cancelC) = context.withTimeout(p, const Duration(hours: 1).ms);
    expect(sprint(c), endsWith('.WithCancel'));
    await go.chanRecv(c.done());
    expect(identical(c.err(), context.deadlineExceeded), isTrue);
    cancelC();
    cancelP();
  });

  test(
    'pai de fora (implementação do usuário) propaga por goroutine',
    () async {
      final my = MyCtx(go.Chan(0, go.EmptyStruct()));
      final (c, cancel) = context.withCancel(my);
      expect(closed(c), isFalse);
      my.e = context.canceled;
      my.ch.close();
      await go.chanRecv(c.done());
      expect(identical(c.err(), context.canceled), isTrue);
      cancel();
    },
  );

  test('AfterFunc: roda f ao cancelar; stop depois devolve false', () async {
    final (c, cancel) = context.withCancel(context.background());
    final ran = go.Chan<int>(1, 0);
    final stop = context.afterFunc(c, () async => ran.send(1));
    cancel();
    expect(await ran.recv(), 1);
    expect(stop(), isFalse);
  });

  test('AfterFunc: stop antes impede f', () async {
    final (c, cancel) = context.withCancel(context.background());
    var ran = false;
    final stop = context.afterFunc(c, () => ran = true);
    expect(stop(), isTrue);
    expect(stop(), isFalse);
    cancel();
    await time.sleep(ms(5));
    expect(ran, isFalse);
  });

  test('AfterFunc em contexto já cancelado roda logo', () async {
    final (c, cancel) = context.withCancel(context.background());
    cancel();
    final ran = go.Chan<int>(1, 0);
    context.afterFunc(c, () => ran.send(1));
    expect(await ran.recv(), 1);
  });

  test('WithoutCancel: valores do pai, sem Done/Err/Deadline', () {
    final (p, cancel) = context.withTimeout(
      context.withValue(context.background(), s('k'), s('v')),
      ms(1000),
    );
    final c = context.withoutCancel(p);
    cancel();
    expect(p.err(), context.canceled);
    expect(c.err(), isNull);
    expect(c.done(), isNull);
    expect(c.deadline().$2, isFalse);
    expect(c.value$(s('k')), s('v'));
    // Filho de WithoutCancel não herda o cancelamento.
    final (cc, _) = context.withCancel(c);
    expect(closed(cc), isFalse);
  });
}

extension on Duration {
  time.Duration get ms => time.Duration(inMicroseconds * 1000);
}
