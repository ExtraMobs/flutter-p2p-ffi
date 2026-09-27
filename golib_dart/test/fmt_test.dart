// ignore_for_file: library_prefixes
import 'dart:typed_data';

import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/fmt.dart';
import 'package:test/test.dart';

go.Slice<Object?> args(List<Object?> a) =>
    go.Slice.of(a, const go.Elem(16, go.zeroNull, pointers: true));

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
}
