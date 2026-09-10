// test/atomic/nivel_1/multihash_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo multihash (transpiled_multihash).

import 'dart:typed_data';
import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'package:test/test.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

void main() {
  group('TooShortException [Atomic Audit]', () {
    test('offset - getter retorna nulo por padrão', () {
      const ex = TooShortException();
      expect(ex.offset, isNull);
    });

    test('source - getter retorna nulo por padrão', () {
      const ex = TooShortException();
      expect(ex.source, isNull);
    });

    test('toString() - retorna mensagem de erro de multihash curto', () {
      const ex = TooShortException();
      expect(ex.toString(), contains('multihash too short'));
    });
  });

  group('InconsistentLenException [Atomic Audit]', () {
    test('offset - getter retorna nulo por padrão', () {
      const ex = InconsistentLenException(32, 10);
      expect(ex.offset, isNull);
    });

    test('source - getter retorna nulo por padrão', () {
      const ex = InconsistentLenException(32, 10);
      expect(ex.source, isNull);
    });

    test('toString() - retorna mensagem com tamanhos esperado e obtido', () {
      const ex = InconsistentLenException(32, 10);
      expect(ex.toString(), contains('expected 32; got 10'));
    });
  });

  group('Multihash [Atomic Audit]', () {
    test('hexString() - formata bytes em representação hexadecimal minúscula', () {
      final mh = Multihash(Uint8List.fromList([0x12, 0x02, 0xaa, 0xbb]));
      expect(mh.hexString(), equals('1202aabb'));
    });

    test('b58String() - formata bytes em representação Base58 BTC', () {
      final mh = Multihash(Uint8List.fromList([0x12, 0x02, 0xaa, 0xbb]));
      expect(mh.b58String().isNotEmpty, isTrue);
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('sum() - calcula digest com algoritmo especificado pelo código uint64', () {
      final res = sum(Uint8List.fromList([1, 2, 3, 4]), Golang.Uint64(0x12));
      expect(res.isNotEmpty, isTrue);
      expect(res[0], equals(0x12));
      expect(res[1], equals(32));
    });

    test('encodeName() - codifica digest arbitrário usando o nome da função de hash', () {
      final digest = Uint8List(32);
      final encoded = encodeName(digest, 'sha2-256');
      expect(encoded[0], equals(0x12));
      expect(encoded[1], equals(32));
    });

    test('cast() - valida fatia de bytes de multihash consistente e a retorna', () {
      final digest = Uint8List(32);
      final valid = encodeName(digest, 'sha2-256');
      final result = cast(valid);
      expect(result, equals(valid));
    });

    test('mhFromBytes() - consome o primeiro multihash do buffer ignorando bytes excedentes', () {
      final digest = Uint8List(32);
      final valid = encodeName(digest, 'sha2-256');
      final buffer = Uint8List.fromList([...valid, 0x99, 0x88]);
      final (consumed, slice) = mhFromBytes(buffer);
      expect(consumed, equals(valid.length));
      expect(slice, equals(valid));
    });
  });

  group('MultihashUtils [Atomic Audit]', () {
    test('sha256() - encapsula digest pré-computado de 32 bytes como multihash sha2-256', () {
      final digest = Uint8List(32);
      final decoded = MultihashUtils.sha256(digest);
      expect(decoded.name, equals('sha2-256'));
      expect(decoded.length, equals(32));
    });

    test('encode() - codifica digest pré-computado com o nome do hash especificado', () {
      final digest = Uint8List(32);
      final decoded = MultihashUtils.encode('sha2-256', digest);
      expect(decoded.name, equals('sha2-256'));
      expect(decoded.length, equals(32));
    });

    test('decode() - decodifica bytes de multihash gerando estrutura DecodedMultihash', () {
      final digest = Uint8List(32);
      final encoded = encodeName(digest, 'sha2-256');
      final decoded = MultihashUtils.decode(encoded);
      expect(decoded.name, equals('sha2-256'));
      expect(decoded.length, equals(32));
    });

    test('sum() - computa hash diretamente dos dados com o nome do algoritmo informado', () {
      final decoded = MultihashUtils.sum('sha2-256', Uint8List.fromList([1, 2, 3]));
      expect(decoded.name, equals('sha2-256'));
      expect(decoded.digest.length, equals(32));
    });
  });

  group('DecodedMultihash [Atomic Audit]', () {
    test('size - getter retorna comprimento exato do digest contido', () {
      final decoded = MultihashUtils.sum('sha2-256', Uint8List.fromList([1, 2, 3]));
      expect(decoded.size, equals(32));
      expect(decoded.size, equals(decoded.length));
    });

    test('toBytes() - serializa a estrutura decodificada de volta para bytes binários', () {
      final decoded = MultihashUtils.sum('sha2-256', Uint8List.fromList([1, 2, 3]));
      final raw = decoded.toBytes();
      expect(raw.length, equals(34));
      expect(raw[0], equals(0x12));
      expect(raw[1], equals(32));
    });
  });
}
