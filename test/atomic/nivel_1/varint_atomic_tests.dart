// test/atomic/nivel_1/varint_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo varint (transpiled_varint).

import 'dart:typed_data';
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_varint/transpiled_varint.dart';

void main() {
  group('Top-Level Functions [Atomic Audit]', () {
    test('uvarintSize() - calcula tamanho em bytes para diferentes valores uint64', () {
      expect(uvarintSize(Golang.Uint64(0)), equals(1));
      expect(uvarintSize(Golang.Uint64(1)), equals(1));
      expect(uvarintSize(Golang.Uint64(127)), equals(1));
      expect(uvarintSize(Golang.Uint64(128)), equals(2));
      expect(uvarintSize(Golang.Uint64(16383)), equals(2));
      expect(uvarintSize(Golang.Uint64(16384)), equals(3));
    });

    test('toUvarint() - serializa uint64 para bytes de tamanho exato', () {
      final b1 = toUvarint(Golang.Uint64(1));
      expect(b1, equals(Uint8List.fromList([1])));

      final b128 = toUvarint(Golang.Uint64(128));
      expect(b128, equals(Uint8List.fromList([0x80, 0x01])));

      final b300 = toUvarint(Golang.Uint64(300));
      expect(b300, equals(Uint8List.fromList([0xAC, 0x02])));
    });

    test('putUvarint() - escreve no buffer e lança RangeError se buffer for curto', () {
      final buffer = Uint8List(10);
      final written = putUvarint(buffer, Golang.Uint64(300));
      expect(written, equals(2));
      expect(buffer[0], equals(0xAC));
      expect(buffer[1], equals(0x02));

      final shortBuffer = Uint8List(1);
      expect(() => putUvarint(shortBuffer, Golang.Uint64(300)), throwsA(isA<RangeError>()));
    });

    test('fromUvarint() - decodifica varint válido e detecta underflow, overflow e não-minimal', () {
      // Caso de sucesso
      final (val, len) = fromUvarint(Uint8List.fromList([0xAC, 0x02]));
      expect(val.toBigInt().toInt(), equals(300));
      expect(len, equals(2));

      // Underflow (termina antes de byte < 128)
      expect(() => fromUvarint(Uint8List.fromList([0x80, 0x80])), throwsA(isA<FormatException>()));

      // Non-minimal encoding (redundant zero byte)
      expect(() => fromUvarint(Uint8List.fromList([0x81, 0x00])), throwsA(isA<FormatException>()));

      // Overflow (> 9 bytes / uint63)
      final overflowBytes = Uint8List.fromList([0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x01]);
      expect(() => fromUvarint(overflowBytes), throwsA(isA<FormatException>()));
    });

    test('readVarint() - lê valor com offset em array de bytes', () {
      final data = Uint8List.fromList([0xFF, 0xFF, 0xAC, 0x02, 0xEE]);
      final (val, consumed) = readVarint(data, 2);
      expect(val, equals(300));
      expect(consumed, equals(2));
    });

    test('encodeVarint() - codifica int válido e rejeita valores negativos', () {
      final bytes = encodeVarint(300);
      expect(bytes, equals(Uint8List.fromList([0xAC, 0x02])));

      expect(() => encodeVarint(-1), throwsA(isA<ArgumentError>()));
    });
  });
}
