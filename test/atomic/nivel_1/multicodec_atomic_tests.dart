// test/atomic/nivel_1/multicodec_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo multicodec (transpiled_multicodec).

import 'package:test/test.dart';
import 'package:transpiled_multicodec/transpiled_multicodec.dart';

void main() {
  group('Code [Atomic Audit]', () {
    test('toUint64() - converte para uint64 de 64 bits', () {
      expect(Code.raw.toUint64().toBigInt(), equals(BigInt.from(0x55)));
      expect(Code.dagPb.toUint64().toBigInt(), equals(BigInt.from(0x70)));
      expect(const Code(0x12).toUint64().toBigInt(), equals(BigInt.from(0x12)));
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('code() - retorna Code correspondente ao nome canônico', () {
      expect(code('raw'), equals(Code.raw));
      expect(code('dag-pb'), equals(Code.dagPb));
      expect(code('sha2-256'), equals(Code.sha2_256));
    });

    test('code() - lança ArgumentError para codec desconhecido', () {
      expect(() => code('nonexistent-codec-xyz'), throwsA(isA<ArgumentError>()));
    });

    test('name() - retorna nome canônico a partir do Code', () {
      expect(name(Code.raw), equals('raw'));
      expect(name(Code.dagPb), equals('dag-pb'));
      expect(name(Code.sha2_256), equals('sha2-256'));
    });
  });

  group('Multicodec [Atomic Audit]', () {
    test('code() - retorna código numérico para nome válido e lança para desconhecido', () {
      expect(Multicodec.code('raw'), equals(0x55));
      expect(Multicodec.code('sha2-256'), equals(0x12));
      expect(() => Multicodec.code('unknown-codec-xyz'), throwsA(isA<ArgumentError>()));
    });

    test('name() - retorna nome canônico para código válido e lança para inválido', () {
      expect(Multicodec.name(0x55), equals('raw'));
      expect(Multicodec.name(0x12), equals('sha2-256'));
      expect(() => Multicodec.name(0x9999999), throwsA(isA<ArgumentError>()));
    });

    test('supports() - valida se o nome está presente na tabela de codecs', () {
      expect(Multicodec.supports('raw'), isTrue);
      expect(Multicodec.supports('dag-pb'), isTrue);
      expect(Multicodec.supports('unknown-codec-xyz'), isFalse);
    });

    test('supportsByCode() - valida se o código numérico está presente na tabela', () {
      expect(Multicodec.supportsByCode(0x55), isTrue);
      expect(Multicodec.supportsByCode(0x70), isTrue);
      expect(Multicodec.supportsByCode(0x9999999), isFalse);
    });

    test('supported - retorna lista não-modificável contendo nomes registrados', () {
      final list = Multicodec.supported;
      expect(list.contains('raw'), isTrue);
      expect(list.contains('dag-pb'), isTrue);
      expect(() => (list as dynamic).add('fake'), throwsA(isA<UnsupportedError>()));
    });

    test('count - retorna a contagem total de codecs registrados', () {
      expect(Multicodec.count, greaterThan(600));
      expect(Multicodec.count, equals(Multicodec.supported.length));
    });
  });
}
