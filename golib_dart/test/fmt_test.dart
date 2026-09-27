// ignore_for_file: library_prefixes
import 'dart:typed_data';

import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/fmt.dart';
import 'package:test/test.dart';

go.Slice<Object?> args(List<Object?> a) =>
    go.Slice.of(a, const go.Elem(16, go.zeroNull, pointers: true));

const _ifaceElem = go.Elem<Object?>(16, go.zeroNull, pointers: true, goType: 'interface {}');
const _intElem = go.Elem<Golang.Int>(8, Golang.Int.new, goType: 'int');
const _ptrPElem = go.Elem<_P?>(8, go.zeroNull, pointers: true, goType: '*main.P');

/// `type P struct { X, Y int; z int }` (campo não exportado), como o g2d geraria.
final class _P extends go.GoStruct<_P> {
  _P([Golang.Int? x, Golang.Int? y, Golang.Int? z])
    : x = x ?? Golang.Int(),
      y = y ?? Golang.Int(),
      z = z ?? Golang.Int();

  static final $nil = _P()..$nilPtr = true;

  Golang.Int x, y, z;

  @override
  String get $goType => 'main.P';

  @override
  _P $copy() => _P(x, y, z);

  @override
  void $set(_P o) {
    x = o.x;
    y = o.y;
    z = o.z;
  }

  @override
  List<Object?> get $fields => [x, y, z];

  @override
  List<String> get $fieldNames => const ['X', 'Y', 'z'];
}

/// `type Q struct { P *P }` (campo ponteiro para struct, embrulhado em Addr
/// como o `$fields` do g2d gera).
final class _Q extends go.GoStruct<_Q> {
  _Q([this.ptr]);

  _P? ptr;

  @override
  String get $goType => 'main.Q';

  @override
  _Q $copy() => _Q(ptr);

  @override
  void $set(_Q o) {
    ptr = o.ptr;
  }

  @override
  List<Object?> get $fields => [
    ptr == null ? const go.Addr(null, goType: 'main.P') : go.Addr(ptr),
  ];

  @override
  List<String> get $fieldNames => const ['Ptr'];
}

/// Struct anônima `struct { X int }`, como o g2d gera para tipos sintéticos.
final class _Anon extends go.GoStruct<_Anon> {
  _Anon([Golang.Int? x]) : x = x ?? Golang.Int();
  Golang.Int x;
  @override
  String get $goType => 'struct { X int }';
  @override
  _Anon $copy() => _Anon(x);
  @override
  void $set(_Anon o) => x = o.x;
  @override
  List<Object?> get $fields => [x];
  @override
  List<String> get $fieldNames => const ['X'];
}

/// Um tipo com `func (t T) GoString() string` (`fmt.GoStringer`).
final class _GoStringer implements GoStringer {
  const _GoStringer(this.n);
  final int n;
  @override
  Golang.String goString() => Golang.String.fromDart('T($n)');
}

void main() {
  test('sprint segue as regras de espaço do Go', () {
    final s = Golang.String.fromDart;
    // Go: fmt.Sprint(1, 2, "a", 3, "b", "c") == "1 2a3bc"
    expect(
      sprint(args([1, 2, s('a'), 3, s('b'), s('c')])).toString(),
      '1 2a3bc',
    );
  });

  test('%v de nil, bool, wrappers e floats', () {
    String v(Object? x) => sprint(args([x])).toString();
    expect([null, true, 42].map(v), ['<nil>', 'true', '42']);
    expect(v(Golang.Int8(-128) - Golang.Int8(1)), '127');
    expect(v(Golang.Float64(1e6)), '1e+06');
    expect(v(Golang.Float32.fromFloat64(Golang.Float64(0.1))), '0.1');
    expect(v(Golang.Complex128.fromDoubles(1, -2)), '(1-2i)');
  });

  test('strings Go preservam bytes inválidos', () {
    final bad = Golang.String.fromBytes(Uint8List.fromList([0x61, 0xff]));
    expect(formatV(bad), [0x61, 0xff]);
  });

  test('%#v de básicos (oráculo: go run)', () {
    String f(String format, Object? x) =>
        sprintf(Golang.String.fromDart(format), args([x])).toString();
    expect(f('%#v', Golang.Int(5)), '5');
    expect(f('%#v', Golang.Uint8(5)), '0x5');
    expect(f('%#v', Golang.Uint16(5)), '0x5');
    expect(f('%#v', Golang.Uint32(5)), '0x5');
    expect(f('%#v', Golang.Uint64(5)), '0x5');
    expect(f('%#v', Golang.Uint(5)), '0x5');
    expect(f('%#v', Golang.Int8(5)), '5');
    expect(f('%#v', Golang.Int64(5)), '5');
    expect(f('%#v', true), 'true');
    expect(f('%#v', false), 'false');
    expect(f('%#v', Golang.String.fromDart('hi\n')), '"hi\\n"');
    expect(f('%#v', Golang.Float64(3.5)), '3.5');
    expect(f('%#v', Golang.Float64(-3.0)), '-3');
    expect(f('%#v', Golang.Float32(1.5)), '1.5');
    expect(f('%#x', Golang.Int(255)), '0xff');
    expect(f('%#o', Golang.Int(8)), '010');
    expect(f('%#q', Golang.String.fromDart('hi')), '`hi`');
    expect(f('%#q', Golang.Rune(0x61)), "'a'");
    expect(f('%#g', Golang.Float64(3.5)), '3.50000');
    expect(f('%#.3e', Golang.Float64(3.5)), '3.500e+00');
    expect(f('%#.0f', Golang.Float64(3.0)), '3.');
  });

  test('%#v de structs (oráculo: go run)', () {
    String f(Object? x) => sprintf(Golang.String.fromDart('%#v'), args([x])).toString();
    // main.P{X:1, Y:2, z:3} — campo não exportado incluso (valor: como um
    // argumento de Printf, que sempre embrulha via `.$ifaceCopy()`).
    expect(f(_P(Golang.Int(1), Golang.Int(2), Golang.Int(3)).$ifaceCopy()), 'main.P{X:1, Y:2, z:3}');
    // struct anônima: struct { X int }{X:1}
    expect(f(_Anon(Golang.Int(1)).$ifaceCopy()), 'struct { X int }{X:1}');
    // struct aninhada: nome do tipo em cada nível.
    final q = _Q(_P(Golang.Int(1), Golang.Int(2), Golang.Int(3)));
    expect(f(q.$ifaceCopy()), 'main.Q{Ptr:(*main.P)(0x${_hexOf(q.ptr)})}');
    // campo ponteiro nulo: (*main.P)(nil), usando o goType do Addr.
    expect(f(_Q(null).$ifaceCopy()), 'main.Q{Ptr:(*main.P)(nil)}');
  });

  test('%#v de ponteiro para struct (oráculo: go run)', () {
    String f(Object? x) => sprintf(Golang.String.fromDart('%#v'), args([x])).toString();
    final p = _P(Golang.Int(1), Golang.Int(2));
    // topo: &main.P{...} (isValue=false, como uma variável/ponteiro).
    expect(f(p), '&main.P{X:1, Y:2, z:0}');
    // valor (isValue=true, como .$ifaceCopy() faria): sem '&'.
    expect(f(p.$copy()..$isValue = true), 'main.P{X:1, Y:2, z:0}');
    // ponteiro nulo no topo: (*main.P)(nil).
    expect(f(_P.$nil), '(*main.P)(nil)');
  });

  test('%#v de slices, arrays e nil (oráculo: go run)', () {
    String f(Object? x) => sprintf(Golang.String.fromDart('%#v'), args([x])).toString();
    expect(f(go.Slice.of([Golang.Int(1), Golang.Int(2)], _intElem)), '[]int{1, 2}');
    expect(
      f(go.Slice.of([Golang.Uint8(1), Golang.Uint8(2)], const go.Elem<Golang.Uint8>(1, Golang.Uint8.new, goType: 'uint8'))),
      '[]uint8{0x1, 0x2}',
    );
    expect(f(go.Slice<Golang.Int>.nil(_intElem)), '[]int(nil)');
    expect(f(go.GoArray.of([Golang.Int(1), Golang.Int(2)], _intElem)), '[2]int{1, 2}');
    expect(
      f(go.Slice.of([Golang.Int(1), Golang.Int(2)], _intElem).slice(0, 2)),
      '[]int{1, 2}',
    );
    // slice de slice: nome aninhado.
    final ss = go.Slice.of(
      [go.Slice.of([Golang.Int(1)], _intElem), go.Slice.of([Golang.Int(2)], _intElem)],
      go.Elem<go.Slice<Golang.Int>>(24, () => go.Slice.nil(_intElem), pointers: true, goType: '[]int'),
    );
    expect(f(ss), '[][]int{[]int{1}, []int{2}}');
  });

  test('%#v de maps e nil (oráculo: go run)', () {
    String f(Object? x) => sprintf(Golang.String.fromDart('%#v'), args([x])).toString();
    final se = const go.Elem<Golang.String>(16, Golang.String.new, pointers: true, goType: 'string');
    final m = go.GoMap.of({
      Golang.String.fromDart('b'): Golang.Int(2),
      Golang.String.fromDart('a'): Golang.Int(1),
    }, _intElem, se);
    expect(f(m), 'map[string]int{"a":1, "b":2}');
    expect(f(go.GoMap<Golang.String, Golang.Int>.nil(_intElem, se)), 'map[string]int(nil)');
  });

  test('%#v de interface nula em contêiner (oráculo: go run)', () {
    String f(Object? x) => sprintf(Golang.String.fromDart('%#v'), args([x])).toString();
    final s = go.Slice<Object?>.of([null, Golang.Int(1), Golang.String.fromDart('a')], _ifaceElem);
    expect(f(s), '[]interface {}{interface {}(nil), 1, "a"}');
  });

  test('%#v de ponteiro para não-struct (oráculo: go run)', () {
    // `[]*P` com um elemento nulo: elemento de ponteiro (Elem.goType='*main.P').
    String f(Object? x) => sprintf(Golang.String.fromDart('%#v'), args([x])).toString();
    final s = go.Slice<_P?>.of([null], _ptrPElem);
    expect(f(s), '[]*main.P{(*main.P)(nil)}');
  });

  test('GoStringer é chamado por %#v (oráculo: go run: T(5))', () {
    expect(
      sprintf(Golang.String.fromDart('%#v'), args([const _GoStringer(5)])).toString(),
      'T(5)',
    );
  });

  test('%#v de erro (oráculo: go run)', () {
    String f(Object? x) => sprintf(Golang.String.fromDart('%#v'), args([x])).toString();
    final inner = go.ErrorString(Golang.String.fromDart('inner'));
    expect(f(inner), '&errors.errorString{s:"inner"}');
    final wrapped = go.WrapError(Golang.String.fromDart('outer: inner'), inner);
    expect(f(wrapped), '&fmt.wrapError{msg:"outer: inner", err:(*errors.errorString)(0x${_hexOf(inner)})}');
  });
}

String _hexOf(Object? v) {
  final h = identityHashCode(v) & 0x7fffffff;
  return 'c0${h.toRadixString(16).padLeft(8, '0')}';
}
