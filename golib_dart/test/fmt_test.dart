// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/builtin.dart' as go;
import 'package:golib_dart/errors.dart' as errors;
import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/fmt.dart';
import 'package:test/test.dart';

go.Slice<Object?> args(List<Object?> a) =>
    go.Slice.of(a, const go.Elem(16, go.zeroNull, pointers: true));

Golang.String s(String x) => Golang.String.fromDart(x);

/// O argumento Go da linha do oráculo (`go_fmt_sharp_vectors.go`).
Object? operand(String kind, String arg) {
  switch (kind) {
    case 'f64':
      final b = ByteData(8)
        ..setUint64(0, BigInt.parse(arg, radix: 16).toSigned(64).toInt());
      return Golang.Float64(b.getFloat64(0));
    case 'f32':
      final b = ByteData(4)..setUint32(0, int.parse(arg, radix: 16));
      return Golang.Float32(b.getFloat32(0));
    case 'rune':
      return Golang.Rune(int.parse(arg));
    case 'err':
      return switch (arg) {
        'new' => errors.new$(s('x"y')),
        'wrapnil' => errorf(s('a %w'), args([null])),
        'errorf' => errorf(s('b %d'), args([Golang.Int(1)])),
        _ => throw ArgumentError(arg),
      };
  }
  throw ArgumentError(kind);
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

  test('%#v: TypeTag dá o nome; sem nome, UnimplementedError', () {
    final f = Golang.String.fromDart('%#v');
    String sharp(Object? x) => sprintf(f, args([x])).toString();
    final elem = go.Elem<Golang.Int>(8, () => Golang.Int(0));
    final xs = go.Slice.of([Golang.Int(1), Golang.Int(2)], elem);
    expect(sharp(go.TypeTag(xs, '[]int')), '[]int{1, 2}');
    expect(sharp(go.TypeTag(go.Slice.nil(elem), '[]int')), '[]int(nil)');
    expect(sharp(Golang.Uint8(7)), '0x7');
    expect(sharp(Golang.String.fromDart('a"')), r'"a\""');
    // Elemento básico: o nome sai do zero value do descritor.
    expect(sharp(xs), '[]int{1, 2}');
    final m = go.GoMap<Golang.Int, Golang.Int>(elem);
    expect(() => sharp(m), throwsA(isA<UnimplementedError>()));
    expect(sharp(go.TypeTag(m, 'map[int]int')), 'map[int]int{}');
  });

  test(
    '# em float e runa, %#v dos erros do runtime (oráculo: go run)',
    () async {
      final r = await Process.run('go', [
        'run',
        'test/go_fmt_sharp_vectors.go',
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final rows = [
        for (final row in jsonDecode(r.stdout as String) as List)
          (row as List).cast<String>(),
      ];
      expect(rows, isNotEmpty);
      for (final [format, kind, arg, want] in rows) {
        final got = sprintf(s(format), args([operand(kind, arg)])).toString();
        expect(got, want, reason: '$format de $kind $arg');
      }
    },
  );

  test('%#v de erro do runtime aninhado: endereço, não reproduzível', () {
    final e = errors.new$(s('x'));
    expect(
      () => sprintf(
        s('%#v'),
        args([
          errorf(s('a %w'), args([e])),
        ]),
      ),
      throwsA(isA<UnimplementedError>()),
    );
    expect(
      () => sprintf(
        s('%#v'),
        args([
          errors.join(go.Slice.of([e], go.errorElem)),
        ]),
      ),
      throwsA(isA<UnimplementedError>()),
    );
  });
}
