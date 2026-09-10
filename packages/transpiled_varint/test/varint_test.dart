// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:typed_data';

// ignore: library_prefixes
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_varint/transpiled_varint.dart';

void main() {
  test('FromUvarint preserves Go minimality and uint63 boundaries', () {
    final (max, maxLength) = fromUvarint(
      Uint8List.fromList([...List.filled(8, 255), 127]),
    );
    expect(max, Golang.Uint64.fromBigInt(BigInt.parse('9223372036854775807')));
    expect(maxLength, 9);
    final (wide, wideLength) = fromUvarint(
      Uint8List.fromList([129, 128, 128, 128, 128, 128, 128, 16]),
    );
    expect(wide.toBigInt(), BigInt.parse('9007199254740993'));
    expect(wideLength, 8);
    final (zero, zeroLength) = fromUvarint(Uint8List.fromList([0, 255]));
    expect(zero.toBigInt(), BigInt.zero);
    expect(zeroLength, 1);
    final (value, length) = fromUvarint(Uint8List.fromList([128, 1]));
    expect(value.toBigInt(), BigInt.from(128));
    expect(length, 2);
    for (final bytes in [<int>[], List.filled(8, 128)]) {
      expect(
        () => fromUvarint(Uint8List.fromList(bytes)),
        throwsA(same(errUnderflow)),
      );
    }
    for (final bytes in [
      [128, 0],
      [129, 0],
    ]) {
      expect(
        () => fromUvarint(Uint8List.fromList(bytes)),
        throwsA(same(errNotMinimal)),
      );
    }
    for (final bytes in [
      List.filled(9, 128),
      [...List.filled(9, 128), 1],
    ]) {
      expect(
        () => fromUvarint(Uint8List.fromList(bytes)),
        throwsA(same(errOverflow)),
      );
    }
  });

  group('Varint', () {
    test('ToUvarint and UvarintSize preserve full uint64 values', () {
      final values = [
        Golang.Uint64(),
        Golang.Uint64.fromBigInt(BigInt.parse('9007199254740993')),
        Golang.Uint64.fromBigInt(BigInt.parse('18446744073709551615')),
      ];
      for (final expected in values.take(2)) {
        final encoded = toUvarint(expected);
        expect(encoded.length, uvarintSize(expected));
        final (decoded, length) = fromUvarint(encoded);
        expect(decoded, expected);
        expect(length, encoded.length);
      }
      final max = toUvarint(values[2]);
      expect(max, Uint8List.fromList([...List.filled(9, 255), 1]));
      expect(max.length, uvarintSize(values[2]));
      final output = Uint8List(10);
      expect(putUvarint(output, values[2]), 10);
      expect(output, max);
      expect(
        () => putUvarint(
          Uint8List(1),
          Golang.Uint64.fromBigInt(BigInt.from(128)),
        ),
        throwsRangeError,
      );
    });

    test('encode/decode small integers', () {
      for (var i = 0; i < 128; i++) {
        final encoded = encodeVarint(i);
        expect(encoded.length, equals(1));
        expect(encoded[0], equals(i));

        final (decoded, length) = readVarint(encoded, 0);
        expect(decoded, equals(i));
        expect(length, equals(1));
      }
    });

    test('encode/decode multi-byte integers', () {
      final testValues = [128, 300, 16383, 16384, 2097151];
      for (final val in testValues) {
        final encoded = encodeVarint(val);
        final (decoded, length) = readVarint(encoded, 0);
        expect(decoded, equals(val));
        expect(length, equals(encoded.length));
      }
    });

    test('readVarint respects a non-zero offset', () {
      final prefix = Uint8List.fromList([0xFF, 0xFF]);
      final encoded = encodeVarint(16384);
      final combined = Uint8List.fromList([...prefix, ...encoded]);
      final (decoded, length) = readVarint(combined, prefix.length);
      expect(decoded, equals(16384));
      expect(length, equals(encoded.length));
    });

    test('throws FormatException on a truncated varint', () {
      final truncated = Uint8List.fromList([0x80, 0x80]); // never terminates
      expect(() => readVarint(truncated, 0), throwsFormatException);
    });

    test('throws FormatException on an overlong varint', () {
      final tooLong = Uint8List.fromList(List<int>.filled(11, 0x80));
      expect(() => readVarint(tooLong, 0), throwsFormatException);
    });

    test('rejects encoding a negative value', () {
      expect(() => encodeVarint(-1), throwsArgumentError);
    });
  });
}
