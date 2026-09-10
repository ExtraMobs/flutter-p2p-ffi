// test/atomic/nivel_1/base58_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo base58 (transpiled_base58).

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:transpiled_base58/transpiled_base58.dart';

void main() {
  group('Base58 [Atomic Audit]', () {
    final base58 = Base58();

    test('encode() - codifica array vazio retornando string vazia', () {
      expect(base58.encode(Uint8List(0)), equals(''));
    });

    test('encode() - codifica bytes regulares em Base58 Bitcoin/IPFS', () {
      final bytes = Uint8List.fromList([0x68, 0x65, 0x6c, 0x6c, 0x6f]); // "hello"
      expect(base58.encode(bytes), equals('Cn8eVZg'));
    });

    test('encode() - preserva zeros à esquerda como caracteres 1', () {
      final bytes = Uint8List.fromList([0, 0, 1]);
      final encoded = base58.encode(bytes);
      expect(encoded.startsWith('11'), isTrue);
      expect(encoded, equals('112'));
    });

    test('base58Decode() - decodifica string Base58 de volta para bytes', () {
      final decoded = base58.base58Decode('Cn8eVZg');
      expect(decoded, equals(Uint8List.fromList([0x68, 0x65, 0x6c, 0x6c, 0x6f])));
    });

    test('base58Decode() - preserva zeros à esquerda correspondentes a 1s', () {
      final decoded = base58.base58Decode('112');
      expect(decoded, equals(Uint8List.fromList([0, 0, 1])));
    });

    test('base58Decode() - lança ArgumentError para caractere inválido (fora do alfabeto)', () {
      expect(() => base58.base58Decode('0OIl'), throwsA(isA<ArgumentError>()));
    });

    test('bigIntToUint8List() - retorna Uint8List vazio para BigInt zero', () {
      expect(base58.bigIntToUint8List(BigInt.zero), equals(Uint8List(0)));
    });

    test('bigIntToUint8List() - converte inteiro positivo para bytes em Big Endian', () {
      final val = BigInt.from(0x1234);
      final bytes = base58.bigIntToUint8List(val);
      expect(bytes, equals(Uint8List.fromList([0x12, 0x34])));
    });

    test('bigIntToUint8List() - converte inteiros grandes de múltiplos bytes', () {
      final val = BigInt.parse('123456789ABCDEF', radix: 16);
      final bytes = base58.bigIntToUint8List(val);
      expect(bytes, isNotEmpty);
      expect(bytes.length, equals(8));
    });
  });
}
