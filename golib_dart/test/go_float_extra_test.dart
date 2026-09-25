// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

double fromBits(String hex) {
  final bits = BigInt.parse(hex, radix: 16).toSigned(64).toInt();
  final b = ByteData(8)..setUint64(0, bits);
  return b.getFloat64(0);
}

List<String> conv(Golang.Float64 x) => [
  Golang.Int64.from(x.toInteger(64, signed: true)).toString(),
  Golang.Uint64.from(x.toInteger(64, signed: false)).toString(),
  Golang.Int32.from(x.toInteger(32, signed: true)).toString(),
  Golang.Uint32.from(x.toInteger(32, signed: false)).toString(),
  Golang.Int16.from(x.toInteger(16, signed: true)).toString(),
  Golang.Uint16.from(x.toInteger(16, signed: false)).toString(),
  Golang.Int8.from(x.toInteger(8, signed: true)).toString(),
  Golang.Uint8.from(x.toInteger(8, signed: false)).toString(),
];

void main() {
  late List<List<String>> rows;

  setUpAll(() async {
    final go = await Process.run('go', [
      'run',
      'test/go_float_vectors_extra.go',
    ]);
    expect(go.exitCode, 0, reason: '${go.stderr}');
    rows = [
      for (final r in jsonDecode(go.stdout as String) as List)
        (r as List).cast<String>(),
    ];
  });

  test('%v de float64/float32/complex bate com o Go', () {
    for (final r in rows) {
      final x = fromBits(r[0]);
      final y = fromBits(r[1]);
      final f64 = Golang.Float64(x);
      expect(
        [
          f64.toString(),
          Golang.Float32.fromFloat64(f64).toString(),
          Golang.Complex128.fromDoubles(x, y).toString(),
          Golang.Complex64.fromDoubles(x, y).toString(),
        ],
        r.sublist(2, 6),
        reason: 'bits ${r[0]}',
      );
    }
  });

  test('conversão float → inteiro bate com o gc/amd64', () {
    for (final r in rows) {
      final f64 = Golang.Float64(fromBits(r[0]));
      final f32 = Golang.Float64.fromFloat32(Golang.Float32.fromFloat64(f64));
      expect(
        [...conv(f64), ...conv(f32)],
        r.sublist(6),
        reason: 'bits ${r[0]}',
      );
    }
  });
}
