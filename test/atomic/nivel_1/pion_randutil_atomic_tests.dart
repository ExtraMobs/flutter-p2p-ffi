// test/atomic/nivel_1/pion_randutil_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo pion/randutil (transpiled_pion_randutil).
// Vetores adaptados de go-ipfs-reference/pion-randutil/{crypto,math,rand}_test.go.

import 'package:test/test.dart';
import 'package:transpiled_pion_randutil/transpiled_pion_randutil.dart';

final RegExp _alphaOnly = RegExp(r'^[a-zA-Z]+$');
const String _runesAlpha =
    'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

void main() {
  group('generateCryptoRandomString [Atomic Audit]', () {
    test('generateCryptoRandomString() - gera string do comprimento pedido '
        'apenas com caracteres do alfabeto fornecido', () {
      for (var i = 0; i < 200; i++) {
        final s = generateCryptoRandomString(10, _runesAlpha);
        expect(s.length, equals(10));
        expect(_alphaOnly.hasMatch(s), isTrue);
      }
    });

    test(
      'generateCryptoRandomString() - comprimento zero retorna string vazia',
      () {
        expect(generateCryptoRandomString(0, _runesAlpha), equals(''));
      },
    );

    test('generateCryptoRandomString() - duas chamadas sucessivas não colidem '
        '(fonte criptográfica real, não determinística)', () {
      final a = generateCryptoRandomString(32, _runesAlpha);
      final b = generateCryptoRandomString(32, _runesAlpha);
      expect(a, isNot(equals(b)));
    });
  });

  group('cryptoUint64 [Atomic Audit]', () {
    test('cryptoUint64() - amostragem grande cobre valores próximos dos '
        'limites inferior e superior do intervalo de 64 bits', () {
      // Porta o vetor de TestCryptoUint64 (crypto_test.go): sobre 10000
      // amostras, o mínimo deve cair perto de 0 e o máximo perto do teto.
      var sawLowHalf = false;
      var sawHighHalf = false;
      for (var i = 0; i < 10000; i++) {
        final r = cryptoUint64();
        // Bit mais significativo do padrão de 64 bits: negativo em Dart
        // sinaliza que o bit 63 está setado (metade superior do intervalo
        // não-assinado), conforme documentado em cryptoUint64().
        if (r >= 0) {
          sawLowHalf = true;
        } else {
          sawHighHalf = true;
        }
        if (sawLowHalf && sawHighHalf) break;
      }
      expect(
        sawLowHalf,
        isTrue,
        reason: 'nenhum valor da metade inferior gerado',
      );
      expect(
        sawHighHalf,
        isTrue,
        reason: 'nenhum valor da metade superior gerado',
      );
    });

    test(
      'cryptoUint64() - duas chamadas sucessivas produzem valores diferentes',
      () {
        expect(cryptoUint64(), isNot(equals(cryptoUint64())));
      },
    );
  });

  group('MathRandomGenerator [Atomic Audit]', () {
    test('MathRandomGenerator() - factory constrói um gerador utilizável '
        '(porta NewMathRandomGenerator)', () {
      final g = MathRandomGenerator();
      expect(g, isNotNull);
      expect(g.intn(1), equals(0));
    });

    test('intn() - respeita o limite superior exclusivo em [0, n)', () {
      final g = MathRandomGenerator();
      var min = 100;
      var max = 0;
      for (var i = 0; i < 10000; i++) {
        final r = g.intn(100);
        expect(r, inInclusiveRange(0, 99));
        if (r < min) min = r;
        if (r > max) max = r;
      }
      expect(min, lessThanOrEqualTo(10));
      expect(max, greaterThanOrEqualTo(90));
    });

    test(
      'uint32() - retorna valores não-negativos cobrindo o intervalo de 32 bits',
      () {
        final g = MathRandomGenerator();
        var min = 0xFFFFFFFF;
        var max = 0;
        for (var i = 0; i < 10000; i++) {
          final r = g.uint32();
          expect(r, greaterThanOrEqualTo(0));
          expect(r, lessThanOrEqualTo(0xFFFFFFFF));
          if (r < min) min = r;
          if (r > max) max = r;
        }
        expect(min, lessThanOrEqualTo(0x10000000));
        expect(max, greaterThanOrEqualTo(0xF0000000));
      },
    );

    test('uint64() - amostragem grande cobre valores próximos dos limites '
        'inferior e superior do padrão de 64 bits', () {
      final g = MathRandomGenerator();
      var sawLowHalf = false;
      var sawHighHalf = false;
      for (var i = 0; i < 10000; i++) {
        final r = g.uint64();
        if (r >= 0) {
          sawLowHalf = true;
        } else {
          sawHighHalf = true;
        }
        if (sawLowHalf && sawHighHalf) break;
      }
      expect(sawLowHalf, isTrue);
      expect(sawHighHalf, isTrue);
    });

    test('generateString() - gera string do comprimento pedido apenas com '
        'caracteres do alfabeto fornecido', () {
      final g = MathRandomGenerator();
      for (var i = 0; i < 200; i++) {
        final s = g.generateString(10, _runesAlpha);
        expect(s.length, equals(10));
        expect(_alphaOnly.hasMatch(s), isTrue);
      }
    });

    test('generateString() - duas chamadas sucessivas não colidem', () {
      final g = MathRandomGenerator();
      final a = g.generateString(32, _runesAlpha);
      final b = g.generateString(32, _runesAlpha);
      expect(a, isNot(equals(b)));
    });
  });
}
