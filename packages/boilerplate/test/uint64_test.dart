// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: library_prefixes
// BigInt division still throws this exact deprecated SDK type; verify it rather
// than accepting unrelated UnsupportedError failures as a Go panic equivalent.
// ignore_for_file: deprecated_member_use
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';

void main() {
  test('Int64 Dart boundary rejects imprecise conversion on JS', () {
    expect(Golang.Int64(-1).toIntExact(), -1);
    final value = Golang.Int64.fromBigInt(BigInt.parse('9007199254740993'));
    const isJs = identical(1, 1.0);
    if (isJs) {
      expect(value.toIntExact, throwsUnsupportedError);
    } else {
      expect(BigInt.from(value.toIntExact()), BigInt.parse('9007199254740993'));
    }
  });

  test('uint64 wraps, shifts logically and retains all 64 bits', () {
    final max = Golang.Uint64.fromBigInt((BigInt.one << 64) - BigInt.one);
    expect(max.toString(), '18446744073709551615');
    expect(max + Golang.Uint64(1), Golang.Uint64());
    expect(Golang.Uint64() - Golang.Uint64(1), max);
    expect(max * Golang.Uint64(2), max - Golang.Uint64(1));
    expect((max >> 63).toString(), '1');
    expect(max << 64, Golang.Uint64());
    expect(max >> 1000000, Golang.Uint64());
    expect(~max, Golang.Uint64());
    expect(Golang.Uint64(7) ~/ Golang.Uint64(3), Golang.Uint64(2));
    expect(Golang.Uint64(7) % Golang.Uint64(3), Golang.Uint64(1));
    expect(() => max << -1, throwsArgumentError);
    expect(
      () => max ~/ Golang.Uint64(),
      throwsA(isA<IntegerDivisionByZeroException>()),
    );
    final bytes = max.toLittleEndianBytes()..[0] = 0;
    expect(bytes[0], 0);
    expect(max.toLittleEndianBytes()[0], 255);
  });
  test('signed conversion and shifts preserve sign and bits', () {
    final minusOne = Golang.Int64(-1);
    expect(Golang.Int64.fromUint64(minusOne.toUint64()), minusOne);
    for (final count in [0, 1, 63, 64, 65, 1000000]) {
      expect(minusOne >> count, minusOne);
      final unsigned = Golang.Uint64(1) << count;
      expect(
        unsigned.toBigInt(),
        count >= 64 ? BigInt.zero : BigInt.one << count,
      );
    }
    expect(() => minusOne >> -1, throwsArgumentError);
    expect(
      () => minusOne ~/ Golang.Int64(),
      throwsA(isA<IntegerDivisionByZeroException>()),
    );
  });
}
