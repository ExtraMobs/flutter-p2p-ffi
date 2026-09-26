// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';

import 'package:golib_dart/fixed_types/golang.dart' as Golang;
import 'package:golib_dart/math.dart' as math;
import 'package:golib_dart/math/bits.dart' as bits;
import 'package:test/test.dart';

String _hex(Golang.IntBase v) => v.toBigInt().toRadixString(16);

String _fb(Golang.Float64 v) => v.toDouble().isNaN
    ? 'NaN' // payload de NaN não é portável
    : _hex(math.float64bits(v)).padLeft(16, '0');

Golang.Uint64 _u64(String hex) =>
    Golang.Uint64.fromBigInt(BigInt.parse(hex, radix: 16));

void main() {
  late Map<String, dynamic> go;

  setUpAll(() async {
    final r = await Process.run('go', ['run', 'test/go_math_vectors.go']);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    go = jsonDecode(r.stdout as String) as Map<String, dynamic>;
  });

  test('math igual ao Go, bit a bit', () {
    final fs = [
      for (final h in go['in']['f'] as List)
        math.float64frombits(_u64(h as String)),
    ];
    final out = <String, List<String>>{};
    void add(String k, Object v) => (out[k] ??= []).add('$v');
    for (final f in fs) {
      add('sqrt', _fb(math.sqrt(f)));
      add('floor', _fb(math.floor(f)));
      add('ceil', _fb(math.ceil(f)));
      add('trunc', _fb(math.trunc(f)));
      add('abs', _fb(math.abs(f)));
      add('signbit', math.signbit(f));
      add('isNaN', math.isNaN(f));
      add(
        'isInf',
        [-1, 0, 1].map((s) => math.isInf(f, Golang.Int(s))).join(' '),
      );
      add(
        'f32bits',
        _hex(math.float32bits(Golang.Float32.fromFloat64(f))).padLeft(8, '0'),
      );
      if (!math.isNaN(f)) {
        add('f64bits', _hex(math.float64bits(f)).padLeft(16, '0'));
      }
      for (final g in fs) {
        add('max', _fb(math.max(f, g)));
        add('min', _fb(math.min(f, g)));
      }
    }
    final want = go['out'] as Map<String, dynamic>;
    for (final k in out.keys) {
      expect(out[k], want[k], reason: k);
    }
    // float32frombits ∘ float32bits é a identidade fora do NaN.
    for (final f in fs.where((f) => !math.isNaN(f))) {
      final f32 = Golang.Float32.fromFloat64(f);
      expect(math.float32frombits(math.float32bits(f32)), f32);
    }
  });

  test('math/bits igual ao Go', () {
    final us = [for (final h in go['in']['u'] as List) _u64(h as String)];
    final ks = [for (final k in go['in']['k'] as List) Golang.Int(k as int)];
    final out = <String, List<String>>{};
    void add(String k, Object v) => (out[k] ??= []).add('$v');
    for (final u in us) {
      final u32 = Golang.Uint32.from(u), u8 = Golang.Uint8.from(u);
      final uu = Golang.Uint.from(u);
      add(
        'ones',
        '${bits.onesCount64(u)} ${bits.onesCount32(u32)} ${bits.onesCount8(u8)}',
      );
      add('lz', '${bits.leadingZeros64(u)} ${bits.leadingZeros8(u8)}');
      add(
        'tz',
        '${bits.trailingZeros64(u)} ${bits.trailingZeros32(u32)} '
            '${bits.trailingZeros(uu)}',
      );
      add('len', '${bits.len64(u)} ${bits.len32(u32)} ${bits.len(uu)}');
      add(
        'rev',
        '${_hex(bits.reverseBytes64(u))} ${_hex(bits.reverseBytes32(u32))} '
            '${_hex(bits.reverseBytes16(Golang.Uint16.from(u)))}',
      );
      for (final k in ks) {
        add(
          'rot',
          '${_hex(bits.rotateLeft64(u, k))} ${_hex(bits.rotateLeft32(u32, k))}',
        );
      }
      for (final v in us) {
        final vv = Golang.Uint.from(v);
        for (final c in [0, 1]) {
          final (s, co) = bits.add64(u, v, Golang.Uint64(c));
          final (d, bo) = bits.sub64(u, v, Golang.Uint64(c));
          final (s2, co2) = bits.add(uu, vv, Golang.Uint(c));
          final (d2, bo2) = bits.sub(uu, vv, Golang.Uint(c));
          add(
            'addsub',
            [
              s,
              co,
              d,
              bo,
              s2,
              co2,
              d2,
              bo2,
            ].map((x) => _hex(x as Golang.IntBase)).join(' '),
          );
        }
        final (hi, lo) = bits.mul64(u, v);
        final (hi2, lo2) = bits.mul(uu, vv);
        add(
          'mul',
          [hi, lo, hi2, lo2].map((x) => _hex(x as Golang.IntBase)).join(' '),
        );
        if (v != Golang.Uint64()) {
          final h = u % v;
          final (q, rm) = bits.div64(h, u, v);
          final (q2, rm2) = bits.div(Golang.Uint.from(h), uu, vv);
          add(
            'div',
            [q, rm, q2, rm2].map((x) => _hex(x as Golang.IntBase)).join(' '),
          );
        }
      }
    }
    final want = go['out'] as Map<String, dynamic>;
    for (final k in out.keys) {
      expect(out[k], want[k], reason: k);
    }
  });

  test('bits.Div64 entra em pânico como o Go', () {
    final one = Golang.Uint64(1);
    expect(
      () => bits.div64(one, one, Golang.Uint64()),
      throwsA(
        predicate(
          (e) => '$e' == 'panic: runtime error: integer divide by zero',
        ),
      ),
    );
    expect(
      () => bits.div64(one, one, one),
      throwsA(
        predicate((e) => '$e' == 'panic: runtime error: integer overflow'),
      ),
    );
  });
}
