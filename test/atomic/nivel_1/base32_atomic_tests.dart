import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:test/test.dart';

import '../../../packages/transpiled_base32/lib/transpiled_base32.dart';
import '../../fixtures/base32/vectors.dart';

Uint8List _bytes(String value) => Uint8List.fromList([
  for (var i = 0; i < value.length; i += 2)
    int.parse(value.substring(i, i + 2), radix: 16),
]);

void main() {
  final vectors = convert.jsonDecode(goVectorsJson) as Map<String, dynamic>;
  final encodings = [stdEncoding, hexEncoding, rawStdEncoding, rawHexEncoding];
  group('Encoding [Atomic Audit]', () {
    test('alphabet() - retains the selected alphabet', () {
      expect(stdEncoding.alphabet(), 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567');
      expect(hexEncoding.alphabet(), '0123456789ABCDEFGHIJKLMNOPQRSTUV');
    });
    test('withPadding() - leaves the original encoding unchanged', () {
      final bytes = Uint8List.fromList([102]);
      expect(stdEncoding.withPadding(33).encodeToString(bytes), 'MY!!!!!!');
      expect(stdEncoding.encodeToString(bytes), 'MY======');
      expect(stdEncoding.withPadding(noPadding).encodeToString(bytes), 'MY');
    });
    test('encodedLen() - matches Go output lengths', () {
      for (final row in vectors['roundtrips'] as List) {
        expect(
          encodings[row['mode'] as int].encodedLen(
            (row['hex'] as String).length ~/ 2,
          ),
          (row['encoded'] as String).length,
        );
      }
    });
    test('decodedLen() - preserves raw upper-bound rounding', () {
      expect(stdEncoding.decodedLen(7), 0);
      expect(stdEncoding.decodedLen(8), 5);
      expect(rawStdEncoding.decodedLen(1), 1);
      expect(rawStdEncoding.decodedLen(2), 2);
      expect(rawStdEncoding.decodedLen(8), 5);
    });
    test('encode() - matches 516 Go-generated vectors', () {
      for (final row in vectors['roundtrips'] as List) {
        final enc = encodings[row['mode'] as int];
        final bytes = _bytes(row['hex'] as String);
        final dst = Uint8List(enc.encodedLen(bytes.length) + 1)..last = 42;
        enc.encode(dst, bytes);
        expect(
          String.fromCharCodes(dst.sublist(0, dst.length - 1)),
          row['encoded'],
        );
        expect(dst.last, 42);
      }
    });
    test('encodeToString() - matches Go across all tail lengths', () {
      for (final row in vectors['roundtrips'] as List) {
        expect(
          encodings[row['mode'] as int].encodeToString(
            _bytes(row['hex'] as String),
          ),
          row['encoded'],
        );
      }
    });
    test('decode() - preserves complete prefix on corrupt input', () {
      final dst = Uint8List(10);
      expect(
        () => stdEncoding.decode(
          dst,
          Uint8List.fromList('MZXW6YTB!!!!!!!!'.codeUnits),
        ),
        throwsA(isA<CorruptInputException>()),
      );
      expect(dst.sublist(0, 5), 'fooba'.codeUnits);
      expect(
        stdEncoding.decode(dst, Uint8List.fromList('MY======'.codeUnits)),
        1,
      );
      expect(dst.first, 102);
    });
    test('decodeString() - matches Go bytes and corruption offsets', () {
      for (final row in vectors['roundtrips'] as List) {
        final enc = encodings[row['mode'] as int];
        expect(
          enc.decodeString(row['encoded'] as String),
          _bytes(row['hex'] as String),
        );
        expect(
          enc.decodeString((row['encoded'] as String).toLowerCase()),
          _bytes(row['hex'] as String),
        );
      }
      for (final row in vectors['decodes'] as List) {
        final enc = encodings[row['mode'] as int];
        final input = row['input'] as String;
        final error = row['error'] as String;
        if (error.isEmpty) {
          expect(
            enc.decodeString(input),
            _bytes(row['hex'] as String),
            reason: 'mode ${row['mode']}: $input',
          );
        } else {
          expect(
            () => enc.decodeString(input),
            throwsA(
              isA<CorruptInputException>().having(
                (e) => e.toString(),
                'error',
                error,
              ),
            ),
            reason: 'mode ${row['mode']}: $input',
          );
        }
      }
      final strict = Encoding('ABCDEFGHIJKLMNOPQRSTUVWXYZ234567');
      expect(
        () => strict.decodeString('my======'),
        throwsA(isA<CorruptInputException>()),
      );
    });
  });
  group('CorruptInputException [Atomic Audit]', () {
    test('toString() - matches the Go error message', () {
      expect(
        const CorruptInputException(7).toString(),
        'illegal base32 data at input byte 7',
      );
    });
  });
}
