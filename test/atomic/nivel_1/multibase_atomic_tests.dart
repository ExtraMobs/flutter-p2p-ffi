// test/atomic/nivel_1/multibase_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo multibase (transpiled_multibase).

import 'dart:convert';
import 'dart:typed_data';
import 'package:multibase/multibase.dart' as mb;
import 'package:test/test.dart';
import 'package:transpiled_multibase/transpiled_multibase.dart';

void main() {
  final sampleBytes = Uint8List.fromList(utf8.encode('hello world'));

  group('MultibaseUtils [Atomic Audit]', () {
    test('decode() - decodifica string multibase com prefixo z (base58btc) e b (base32)', () {
      final encodedB58 = MultibaseUtils.encodeWithName('base58btc', sampleBytes);
      expect(encodedB58.startsWith('z'), isTrue);
      final decodedB58 = MultibaseUtils.decode(encodedB58);
      expect(decodedB58, equals(sampleBytes));

      final encodedB32 = MultibaseUtils.encodeWithName('base32', sampleBytes);
      expect(encodedB32.startsWith('b'), isTrue);
      final decodedB32 = MultibaseUtils.decode(encodedB32);
      expect(decodedB32, equals(sampleBytes));
    });

    test('decode() - lança FormatException quando a entrada é uma string vazia', () {
      expect(() => MultibaseUtils.decode(''), throwsA(isA<FormatException>()));
    });

    test('encode() - codifica bytes usando enum Multibase do pacote multibase', () {
      final resB58 = MultibaseUtils.encode(mb.Multibase.base58btc, sampleBytes);
      expect(resB58.startsWith('z'), isTrue);
      expect(MultibaseUtils.decode(resB58), equals(sampleBytes));

      final resB16 = MultibaseUtils.encode(mb.Multibase.base16, sampleBytes);
      expect(resB16.startsWith('f'), isTrue);
      expect(MultibaseUtils.decode(resB16), equals(sampleBytes));
    });

    test('encodeWithName() - codifica por nome canônico e faz fallback para base32 em nome desconhecido', () {
      final resB58 = MultibaseUtils.encodeWithName('base58btc', sampleBytes);
      expect(resB58.startsWith('z'), isTrue);

      final fallback = MultibaseUtils.encodeWithName('nao_existe_codec_xyz', sampleBytes);
      expect(fallback.startsWith('b'), isTrue); // fallback é base32 ('b')
    });
  });

  group('UnsupportedEncodingException [Atomic Audit]', () {
    test('toString() - formata mensagem com e sem causa especificada', () {
      const eNoCause = UnsupportedEncodingException();
      expect(eNoCause.toString(), equals('unsupported encoding'));

      const eWithCause = UnsupportedEncodingException('base88');
      expect(eWithCause.toString(), equals('unsupported encoding: base88'));
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('encode() - codifica usando extension type Encoding', () {
      final enc = encode(Encoding.base58btc, sampleBytes);
      expect(enc.startsWith('z'), isTrue);
      expect(decode(enc).$2, equals(sampleBytes));
    });

    test('decode() - decodifica para tupla (Encoding, Uint8List) e rejeita string vazia', () {
      final enc = encode(Encoding.base32, sampleBytes);
      final (base, data) = decode(enc);
      expect(base, equals(Encoding.base32));
      expect(data, equals(sampleBytes));

      expect(() => decode(''), throwsA(isA<FormatException>()));
    });
  });
}
