// test/atomic/nivel_1/boilerplate_netip_atomic_tests.dart
// Testes atomicos 1 para 1 para o modulo boilerplate (net_netip/golang).
//
// Os valores esperados foram produzidos executando net/netip em Go 1.25.7,
// nao deduzidos: ver o registro em doc/transpilation/PROGRESS.md.

import 'dart:typed_data';

import 'package:boilerplate/net_netip/golang.dart';
import 'package:test/test.dart';

void main() {
  group('Addr [Atomic Audit]', () {
    test('tryParse() - aceita IPv4 em forma decimal pontuada', () {
      final addr = Addr.tryParse('127.0.0.1');
      expect(addr, isNotNull);
      expect(addr!.asSlice(), equals(Uint8List.fromList([127, 0, 0, 1])));
    });

    test('tryParse() - aceita IPv6 e devolve 16 bytes', () {
      final addr = Addr.tryParse('::1');
      expect(addr, isNotNull);
      expect(addr!.asSlice().length, equals(16));
      expect(addr.asSlice().last, equals(1));
    });

    test('tryParse() - devolve null para texto que nao e endereco', () {
      expect(Addr.tryParse('nao-e-um-ip'), isNull);
      expect(Addr.tryParse(''), isNull);
    });

    test('tryParse() - rejeita endereco com zona, que nao e representada', () {
      expect(Addr.tryParse('fe80::1%eth0'), isNull);
    });

    test('tryFromSlice() - aceita 4 e 16 bytes', () {
      expect(Addr.tryFromSlice(const [1, 2, 3, 4]), isNotNull);
      expect(Addr.tryFromSlice(List<int>.filled(16, 0)), isNotNull);
    });

    test('tryFromSlice() - devolve null para qualquer outro tamanho', () {
      expect(Addr.tryFromSlice(const [1, 2, 3]), isNull);
      expect(Addr.tryFromSlice(const []), isNull);
      expect(Addr.tryFromSlice(List<int>.filled(15, 0)), isNull);
    });

    test('isValid - falso para o endereco zero, verdadeiro para os demais', () {
      expect(const Addr.zero().isValid, isFalse);
      expect(Addr.tryParse('127.0.0.1')!.isValid, isTrue);
    });

    test('bitLen - 32 para IPv4, 128 para IPv6, 0 para o zero', () {
      expect(Addr.tryParse('127.0.0.1')!.bitLen, equals(32));
      expect(Addr.tryParse('::1')!.bitLen, equals(128));
      expect(const Addr.zero().bitLen, equals(0));
    });

    test('is4 - verdadeiro so para IPv4 de verdade', () {
      expect(Addr.tryParse('127.0.0.1')!.is4, isTrue);
      expect(Addr.tryParse('::1')!.is4, isFalse);
      // Go: m4.Is4 false, para ::ffff:127.0.0.1
      expect(Addr.tryParse('::ffff:127.0.0.1')!.is4, isFalse);
    });

    test('is6 - verdadeiro para IPv6, inclusive mapeado de IPv4', () {
      expect(Addr.tryParse('::1')!.is6, isTrue);
      expect(Addr.tryParse('::ffff:127.0.0.1')!.is6, isTrue);
      expect(Addr.tryParse('127.0.0.1')!.is6, isFalse);
    });

    test('is4In6 - identifica o bloco ::ffff:0:0/96', () {
      expect(Addr.tryParse('::ffff:127.0.0.1')!.is4In6, isTrue);
      expect(Addr.tryParse('::1')!.is4In6, isFalse);
      expect(Addr.tryParse('127.0.0.1')!.is4In6, isFalse);
    });

    test('asSlice() - devolve copia dos bytes', () {
      final addr = Addr.tryParse('1.2.3.4')!;
      final bytes = addr.asSlice()..[0] = 9;
      expect(bytes[0], equals(9));
      expect(addr.asSlice()[0], equals(1));
    });

    test('unmap() - remove o prefixo mapeado de IPv4', () {
      final unmapped = Addr.tryParse('::ffff:127.0.0.1')!.unmap();
      expect(unmapped.is4, isTrue);
      expect(unmapped.asSlice(), equals(Uint8List.fromList([127, 0, 0, 1])));
    });

    test('unmap() - devolve o proprio endereco quando nao e mapeado', () {
      final addr = Addr.tryParse('::1')!;
      expect(addr.unmap(), equals(addr));
    });

    test('prefix() - mascara os bits excedentes em IPv4', () {
      // Go: netip.MustParseAddr("1.2.3.4").Prefix(24) -> 1.2.3.0/24
      expect(
        Addr.tryParse('1.2.3.4')!.prefix(24).toString(),
        equals('1.2.3.0/24'),
      );
    });

    test('prefix() - mascara os bits excedentes em IPv6', () {
      // Go: netip.MustParseAddr("2001:db8::1").Prefix(56) -> 2001:db8::/56
      expect(
        Addr.tryParse('2001:db8::1')!.prefix(56).toString(),
        equals('2001:db8::/56'),
      );
    });

    test('prefix() - endereco zero devolve prefixo invalido, sem lancar', () {
      // Go: zero.Prefix(8) devolve Prefix invalido com err == nil.
      expect(const Addr.zero().prefix(8).isValid, isFalse);
    });

    test('prefix() - lanca para contagem negativa', () {
      expect(
        () => Addr.tryParse('1.2.3.4')!.prefix(-1),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('prefix() - lanca quando a contagem excede a familia', () {
      expect(
        () => Addr.tryParse('1.2.3.4')!.prefix(33),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => Addr.tryParse('::1')!.prefix(129),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('sharesPrefixWith() - compara apenas os bits pedidos', () {
      final a = Addr.tryParse('10.1.2.3')!;
      final b = Addr.tryParse('10.1.9.9')!;
      expect(a.sharesPrefixWith(b, 16), isTrue);
      expect(a.sharesPrefixWith(b, 24), isFalse);
      expect(a.sharesPrefixWith(b, 0), isTrue);
    });

    test('toString() - IPv4 pontuado e IPv6 comprimido', () {
      expect(Addr.tryParse('127.0.0.1').toString(), equals('127.0.0.1'));
      // Go: a6.String() == "::1"
      expect(Addr.tryParse('::1').toString(), equals('::1'));
    });

    test('toString() - endereco zero se identifica como invalido', () {
      expect(const Addr.zero().toString(), equals('invalid IP'));
    });

    test('compareTo() - ordena por tamanho e depois por bytes', () {
      final v4 = Addr.tryParse('1.2.3.4')!;
      final v6 = Addr.tryParse('::1')!;
      expect(v4.compareTo(v6), lessThan(0));
      expect(v6.compareTo(v4), greaterThan(0));
      expect(
        Addr.tryParse('1.2.3.4')!.compareTo(Addr.tryParse('1.2.3.5')!),
        lessThan(0),
      );
      expect(v4.compareTo(Addr.tryParse('1.2.3.4')!), equals(0));
    });

    test('operator == - iguala por familia e bytes', () {
      expect(Addr.tryParse('1.2.3.4'), equals(Addr.tryParse('1.2.3.4')));
      expect(Addr.tryParse('1.2.3.4'), isNot(equals(Addr.tryParse('1.2.3.5'))));
      // IPv4 e o seu mapeado nao sao o mesmo valor, como no Go.
      expect(
        Addr.tryParse('127.0.0.1'),
        isNot(equals(Addr.tryParse('::ffff:127.0.0.1'))),
      );
    });

    test('hashCode - serve de chave de mapa', () {
      final counts = <Addr, int>{};
      counts[Addr.tryParse('1.2.3.4')!] = 1;
      counts[Addr.tryParse('1.2.3.4')!] = 2;
      expect(counts.length, equals(1));
      expect(counts[Addr.tryParse('1.2.3.4')!], equals(2));
    });
  });

  group('Prefix [Atomic Audit]', () {
    test('mustParse() - aceita prefixo IPv4', () {
      final p = Prefix.mustParse('127.0.0.0/8');
      expect(p.bits, equals(8));
      expect(p.isValid, isTrue);
    });

    test('mustParse() - lanca FormatException para prefixo invalido', () {
      expect(() => Prefix.mustParse('127.0.0.0'), throwsFormatException);
      expect(() => Prefix.mustParse('1.2.3.4/33'), throwsFormatException);
      expect(() => Prefix.mustParse('lixo/8'), throwsFormatException);
    });

    test('tryParse() - devolve null em vez de lancar', () {
      expect(Prefix.tryParse('1.2.3.4/33'), isNull);
      expect(Prefix.tryParse('::1/128'), isNotNull);
    });

    test('from() - devolve prefixo invalido quando os bits nao cabem', () {
      final addr = Addr.tryParse('1.2.3.4')!;
      expect(Prefix.from(addr, 33).isValid, isFalse);
      expect(Prefix.from(addr, -1).isValid, isFalse);
      expect(Prefix.from(const Addr.zero(), 0).isValid, isFalse);
    });

    test('addr - devolve o endereco original, sem mascarar', () {
      expect(
        Prefix.from(Addr.tryParse('1.2.3.4')!, 24).addr,
        equals(Addr.tryParse('1.2.3.4')),
      );
    });

    test('bits - devolve -1 para o prefixo zero', () {
      expect(const Prefix.zero().bits, equals(-1));
      expect(Prefix.mustParse('::1/128').bits, equals(128));
    });

    test('isValid - falso so para o prefixo zero', () {
      expect(const Prefix.zero().isValid, isFalse);
      expect(Prefix.mustParse('10.0.0.0/8').isValid, isTrue);
    });

    test('isSingleIp - verdadeiro quando cobre um unico endereco', () {
      expect(Prefix.mustParse('::1/128').isSingleIp, isTrue);
      expect(Prefix.mustParse('1.2.3.4/32').isSingleIp, isTrue);
      expect(Prefix.mustParse('1.2.3.4/24').isSingleIp, isFalse);
    });

    test('masked() - zera os bits alem da contagem', () {
      expect(
        Prefix.from(Addr.tryParse('1.2.3.4')!, 24).masked().toString(),
        equals('1.2.3.0/24'),
      );
      expect(const Prefix.zero().masked().isValid, isFalse);
    });

    test('contains() - IPv4 dentro do proprio bloco', () {
      // Go: p4.Contains(a4) == true
      expect(
        Prefix.mustParse('127.0.0.0/8').contains(Addr.tryParse('127.0.0.1')!),
        isTrue,
      );
    });

    test('contains() - IPv6 nao casa com prefixo IPv4', () {
      // Go: p4.Contains(a6) == false
      expect(
        Prefix.mustParse('127.0.0.0/8').contains(Addr.tryParse('::1')!),
        isFalse,
      );
    });

    test('contains() - mapeado de IPv4 nao casa com prefixo IPv4', () {
      // Go: p4.Contains(m4) == false, para ::ffff:127.0.0.1
      expect(
        Prefix.mustParse(
          '127.0.0.0/8',
        ).contains(Addr.tryParse('::ffff:127.0.0.1')!),
        isFalse,
      );
    });

    test('contains() - IPv6 dentro do proprio bloco', () {
      // Go: p6.Contains(a6) == true
      expect(
        Prefix.mustParse('::1/128').contains(Addr.tryParse('::1')!),
        isTrue,
      );
    });

    test('contains() - fronteira de /56 em IPv6', () {
      // Go: true para ...:56ff::9 e false para ...:5700::9
      final p = Prefix.mustParse('2001:db8:1234:5600::/56');
      expect(p.contains(Addr.tryParse('2001:db8:1234:56ff::9')!), isTrue);
      expect(p.contains(Addr.tryParse('2001:db8:1234:5700::9')!), isFalse);
    });

    test('contains() - falso para prefixo ou endereco invalidos', () {
      expect(const Prefix.zero().contains(Addr.tryParse('1.2.3.4')!), isFalse);
      expect(
        Prefix.mustParse('1.0.0.0/8').contains(const Addr.zero()),
        isFalse,
      );
    });

    test('toString() - endereco barra bits', () {
      expect(Prefix.mustParse('10.0.0.0/8').toString(), equals('10.0.0.0/8'));
      expect(const Prefix.zero().toString(), equals('invalid Prefix'));
    });

    test('operator == - iguala por endereco e contagem', () {
      expect(
        Prefix.mustParse('10.0.0.0/8'),
        equals(Prefix.mustParse('10.0.0.0/8')),
      );
      expect(
        Prefix.mustParse('10.0.0.0/8'),
        isNot(equals(Prefix.mustParse('10.0.0.0/9'))),
      );
    });

    test('hashCode - serve de chave de mapa, como no conn_limiter', () {
      final counts = <Prefix, int>{};
      counts[Prefix.mustParse('10.0.0.0/8')] = 1;
      counts[Prefix.mustParse('10.0.0.0/8')] = 2;
      expect(counts.length, equals(1));
      expect(counts[Prefix.mustParse('10.0.0.0/8')], equals(2));
    });
  });
}
