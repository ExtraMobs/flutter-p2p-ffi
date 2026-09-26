// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';

import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/math.dart' as math;
import 'package:test/test.dart';

String _fb(Golang.Float64 v) => v.toDouble().isNaN
    ? 'NaN' // payload de NaN não é portável
    : math.float64bits(v).toBigInt().toRadixString(16).padLeft(16, '0');

Golang.Float64 _f(String hex) => math.float64frombits(
  Golang.Uint64.fromBigInt(BigInt.parse(hex, radix: 16)),
);

void main() {
  late Map<String, dynamic> go;

  setUpAll(() async {
    // GOARCH=386: o math do Go só com código Go puro (o alvo do shim).
    final r = await Process.run(
      'go',
      ['run', 'test/go_math_pure_vectors.go'],
      environment: {'GOARCH': '386'},
    );
    expect(r.exitCode, 0, reason: '${r.stderr}');
    go = jsonDecode(r.stdout as String) as Map<String, dynamic>;
  });

  test('transcendentais iguais ao Go puro, bit a bit', () {
    final xs = [for (final h in go['x'] as List) _f(h as String)];
    final ys = [for (final h in go['y'] as List) _f(h as String)];
    final out = <String, List<String>>{};
    void add(String k, Object v) => (out[k] ??= []).add('$v');
    for (final x in xs) {
      add('exp', _fb(math.exp(x)));
      add('expm1', _fb(math.expm1(x)));
      add('log', _fb(math.log(x)));
      add('log2', _fb(math.log2(x)));
      add('log10', _fb(math.log10(x)));
      add('log1p', _fb(math.log1p(x)));
      final (fr, e) = math.frexp(x);
      add('frexp', '${_fb(fr)} $e');
      final (i, f) = math.modf(x);
      add('modf', '${_fb(i)} ${_fb(f)}');
      add('round', _fb(math.round(x)));
      add('roundToEven', _fb(math.roundToEven(x)));
      add('cbrt', _fb(math.cbrt(x)));
      add('sin', _fb(math.sin(x)));
      add('cos', _fb(math.cos(x)));
      add('tan', _fb(math.tan(x)));
      final (s, c) = math.sincos(x);
      add('sincos', '${_fb(s)} ${_fb(c)}');
      add('atan', _fb(math.atan(x)));
      final (lg, sg) = math.lgamma(x);
      add('lgamma', '${_fb(lg)} $sg');
      add('gamma', _fb(math.gamma(x)));
      add('erfc', _fb(math.erfc(x)));
      for (final k in [-1080, -1074, -1022, -60, -1, 0, 1, 52, 1023, 1100]) {
        add('ldexp', _fb(math.ldexp(x, Golang.Int(k))));
      }
      for (final y in ys) {
        add('pow', _fb(math.pow(x, y)));
        add('mod', _fb(math.mod(x, y)));
        add('nextafter', _fb(math.nextafter(x, y)));
      }
    }
    for (final x in ys) {
      for (final y in ys) {
        add('pow2', _fb(math.pow(x, y)));
      }
    }
    final want = go['out'] as Map<String, dynamic>;
    for (final k in want.keys) {
      final w = (want[k] as List).cast<String>();
      final got = out[k]!;
      for (var i = 0; i < w.length; i++) {
        final x = k == 'pow2'
            ? 'pow2[$i]'
            : '${go['x'][i ~/ (w.length ~/ xs.length)]}';
        expect(got[i], w[i], reason: '$k($x) #$i');
      }
    }
  });
}
