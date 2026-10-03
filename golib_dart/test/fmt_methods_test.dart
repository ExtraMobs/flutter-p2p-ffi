// Métodos String()/Error() chamados pelo fmt em valores aninhados, contra o
// oráculo `go_fmt_methods_vectors.go`. As classes imitam o que o g2d gera
// para os tipos Go do oráculo.
// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';

import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/fmt.dart';
import 'package:test/test.dart';

Golang.String s(String x) => Golang.String.fromDart(x);

go.Slice<Object?> args(List<Object?> a) =>
    go.Slice.of(a, const go.Elem(16, go.zeroNull, pointers: true));

/// `type T struct{ n int }` com `String()` em *T.
final class T extends go.GoStruct<T> implements Stringer {
  T([this.n = 0]);
  int n;
  @override
  String get $goType => 'main.T';
  @override
  List<String> get $ptrMethods => const ['String'];
  @override
  T $copy() => T(n);
  @override
  void $set(T o) => n = o.n;
  @override
  List<Object?> get $fields => [Golang.Int(n)];
  @override
  List<String> get $fieldNames => const ['n'];
  @override
  Golang.String string() => s('T$n');
}

/// `type V struct{ n int }` com `String()` em V.
final class V extends go.GoStruct<V> implements Stringer {
  V([this.n = 0]);
  int n;
  @override
  String get $goType => 'main.V';
  @override
  List<String> get $valueMethods => const ['String'];
  @override
  List<String> get $ptrMethods => const ['String'];
  @override
  V $copy() => V(n);
  @override
  void $set(V o) => n = o.n;
  @override
  List<Object?> get $fields => [Golang.Int(n)];
  @override
  List<String> get $fieldNames => const ['n'];
  @override
  Golang.String string() => s('V$n');
}

/// `type W struct{ v V; E V }`.
final class W extends go.GoStruct<W> {
  W(this.v, this.e);
  V v, e;
  @override
  String get $goType => 'main.W';
  @override
  W $copy() => W(v.$copy(), e.$copy());
  @override
  void $set(W o) {
    v.$set(o.v);
    e.$set(o.e);
  }

  @override
  List<Object?> get $fields => [v, e];
  @override
  List<String> get $fieldNames => const ['v', 'E'];
}

/// `type B struct{}` com `String()` em *B que entra em panic.
final class B extends go.GoStruct<B> implements Stringer {
  @override
  String get $goType => 'main.B';
  @override
  List<String> get $ptrMethods => const ['String'];
  @override
  B $copy() => B();
  @override
  void $set(B o) {}
  @override
  List<Object?> get $fields => const [];
  @override
  List<String> get $fieldNames => const [];
  @override
  Golang.String string() => throw go.Panic(s('boom'));
}

/// `type Q struct{ n int }` com `String()` em *Q que lê `q.n` (nil deref).
final class Q extends go.GoStruct<Q> implements Stringer {
  Q([this.n = 0]);
  int n;
  static final Q $nil = Q()..$nilPtr = true;
  @override
  String get $goType => 'main.Q';
  @override
  List<String> get $ptrMethods => const ['String'];
  @override
  Q $copy() => Q(n);
  @override
  void $set(Q o) => n = o.n;
  @override
  List<Object?> get $fields => [Golang.Int(n)];
  @override
  List<String> get $fieldNames => const ['n'];
  @override
  Golang.String string() {
    final Q? q = $nilPtr ? null : this;
    return s('Q${q!.n}');
  }
}

/// `type E struct{ msg string }` com `Error()` em *E.
final class E extends go.GoStruct<E> implements go.GoError {
  E([this.msg = '']);
  String msg;
  @override
  String get $goType => 'main.E';
  @override
  List<String> get $ptrMethods => const ['Error'];
  @override
  E $copy() => E(msg);
  @override
  void $set(E o) => msg = o.msg;
  @override
  List<Object?> get $fields => [s(msg)];
  @override
  List<String> get $fieldNames => const ['msg'];
  @override
  Golang.String error() => s('E:$msg');
}

/// `type Holder struct{ Err error; T *T }`.
final class Holder extends go.GoStruct<Holder> {
  Holder(this.err, this.t);
  go.GoError? err;
  T? t;
  @override
  String get $goType => 'main.Holder';
  @override
  Holder $copy() => Holder(err, t);
  @override
  void $set(Holder o) {
    err = o.err;
    t = o.t;
  }

  @override
  List<Object?> get $fields => [go.dynField(err), go.Addr(t)];
  @override
  List<String> get $fieldNames => const ['Err', 'T'];
}

const _ptrT = go.Elem<T?>(8, go.zeroNull, pointers: true);
const _valT = go.Elem<T>(8, T.new, value: true);
const _ptrQ = go.Elem<Q?>(8, go.zeroNull, pointers: true);
const _err = go.Elem<go.GoError?>(16, go.zeroNull, pointers: true);
const _any = go.Elem<Object?>(16, go.zeroNull, pointers: true);

void main() {
  test('String()/Error() em valores aninhados (oráculo: go run)', () async {
    final r = await Process.run('go', [
      'run',
      'test/go_fmt_methods_vectors.go',
    ]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final want = (jsonDecode(r.stdout as String) as List).cast<String>();
    String sp(List<Object?> a) => sprint(args(a)).toString();
    String spf(String f, List<Object?> a) => sprintf(s(f), args(a)).toString();
    final got = [
      sp([
        go.Slice.of([T(1), T(2)], _ptrT),
      ]),
      sp([
        go.Slice.of([T(3)], _valT),
      ]),
      sp([W(V(1), V(2)).$ifaceCopy()]),
      sp([B()]),
      spf('%s', [Q.$nil]),
      sp([
        go.Slice.of([E('a')], _err),
      ]),
      sp([Holder(E('d'), T(8)).$ifaceCopy()]),
      sp([
        go.Slice.of([null], _ptrQ),
      ]),
      spf('%d', [B()]),
      spf('%x|%5v', [
        B(),
        go.Slice.of([T(4)], _ptrT),
      ]),
      sprintln(
        args([
          go.Slice.of([T(5), V(6).$ifaceCopy(), T(7).$ifaceCopy()], _any),
        ]),
      ).toString(),
      spf('%v %+v', [
        go.GoMap.of({s('k'): T(9)}, _ptrT),
        W(V(1), V(2)).$ifaceCopy(),
      ]),
    ];
    expect(got, want);
  });
}
