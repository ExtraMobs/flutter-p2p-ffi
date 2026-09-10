// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
import 'dart:convert';
import 'dart:io';

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('complex128 arithmetic matches Go binary64 output bits', () async {
    final result = await Process.run('go', [
      'run',
      'test/go_complex_vectors.go',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final expected = jsonDecode(result.stdout as String) as List<dynamic>;

    final values = [
      (0.0, 0.0),
      (1.0, 0.0),
      (0.0, 1.0),
      (1.0, 1.0),
      (-2.0, 3.0),
      (3.0, -4.0),
      (0.5, -1.5),
    ].map((p) => Golang.Complex128.fromDoubles(p.$1, p.$2)).toList();

    String fmtFloat(Golang.Float64 f) {
      if (f.toDouble().isNaN) return 'NaN';
      return f
          .toLittleEndianBytes()
          .reversed
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
    }

    String fmtComplex(Golang.Complex128 c) {
      return '${fmtFloat(c.real)},${fmtFloat(c.imag)}';
    }

    var idx = 0;
    for (final a in values) {
      for (final b in values) {
        final exp = expected[idx++] as Map<String, dynamic>;
        expect(fmtComplex(a + b), exp['add']);
        expect(fmtComplex(a - b), exp['sub']);
        expect(fmtComplex(a * b), exp['mul']);
        if (b != Golang.Complex128()) {
          expect(fmtComplex(a / b), exp['div']);
        } else {
          expect(exp['div'], 'zero');
        }
      }
    }
  });

  test('complex64 and typedefs (Int, Uint, Uintptr) basic operations', () {
    final c64_1 = Golang.Complex64.fromDoubles(1.0, 2.0);
    final c64_2 = Golang.Complex64.fromDoubles(3.0, 4.0);
    expect(c64_1 + c64_2, Golang.Complex64.fromDoubles(4.0, 6.0));
    expect(c64_1 - c64_2, Golang.Complex64.fromDoubles(-2.0, -2.0));
    expect(-c64_1, Golang.Complex64.fromDoubles(-1.0, -2.0));
    expect(c64_1 * c64_2, Golang.Complex64.fromDoubles(-5.0, 10.0));

    final c128 = Golang.Complex128.fromComplex64(c64_1);
    expect(c128.real.toDouble(), 1.0);
    expect(c128.imag.toDouble(), 2.0);

    final back = Golang.Complex64.fromComplex128(c128);
    expect(back, c64_1);

    // Verify Int, Uint, Uintptr
    final i = Golang.Int(42);
    final u = Golang.Uint(100);
    final ptr = Golang.Uintptr(0xDEADBEEF);
    expect(i + Golang.Int(8), Golang.Int(50));
    expect(u - Golang.Uint(1), Golang.Uint(99));
    expect(ptr, Golang.Uint64(0xDEADBEEF));
  });
}
