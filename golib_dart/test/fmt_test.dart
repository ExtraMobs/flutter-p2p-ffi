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
}
