import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/math.dart' as math;
import 'package:test/test.dart';

String _bits(Golang.Float64 v) {
  if (v.toDouble().isNaN) return 'NaN'; // payload de NaN não é portável
  final b = ByteData(8)..setFloat64(0, v.toDouble());
  return [
    for (var i = 0; i < 8; i++) b.getUint8(i).toRadixString(16).padLeft(2, '0'),
  ].join();
}

void main() {
  test('math.Sqrt igual ao Go, bit a bit', () async {
    final go = await Process.run('go', ['run', 'test/go_math_vectors.go']);
    expect(go.exitCode, 0, reason: '${go.stderr}');
    final values = [
      0.0,
      -0.0,
      1.0,
      -1.0,
      2.0,
      0.1,
      1e-300,
      1e300,
      5e-324,
      2.2250738585072014e-308,
      1.7976931348623157e308,
      double.infinity,
      double.negativeInfinity,
      double.nan,
      12345.6789,
      9007199254740993.0,
    ];
    final got = [for (final x in values) _bits(math.sqrt(Golang.Float64(x)))];
    expect(got, jsonDecode(go.stdout as String));
  });
}
