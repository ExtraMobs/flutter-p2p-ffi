// test/atomic/nivel_1/boilerplate_net_ip_atomic_tests.dart
// Testes atomicos 1 para 1 para o modulo boilerplate (net/golang).
//
// Os valores esperados foram produzidos executando o pacote net em Go 1.25.7,
// nao deduzidos: ver o registro em doc/transpilation/PROGRESS.md.

import 'dart:typed_data';

import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';

void main() {
  group('Ip [Atomic Audit]', () {
    test('tryParse() - dotted-quad vira 16 bytes, como no Go', () {
      // Go: len(net.ParseIP("127.0.0.1")) == 16
      final ip = Ip.tryParse('127.0.0.1');
      expect(ip, isNotNull);
      expect(ip!.length, equals(16));
    });

    test('tryParse() - IPv6 vira 16 bytes', () {
      expect(Ip.tryParse('2001:db8::1')!.length, equals(16));
    });

    test('tryParse() - devolve null para texto invalido', () {
      // Go: net.ParseIP("lixo") == nil
      expect(Ip.tryParse('lixo'), isNull);
      expect(Ip.tryParse(''), isNull);
      expect(Ip.tryParse('10.0.0.0/8'), isNull);
    });

    test('fromBytes() - aceita qualquer tamanho, como o slice do Go', () {
      expect(Ip.fromBytes(const [1, 2, 3]).length, equals(3));
      expect(Ip.fromBytes(const [1, 2, 3, 4]).length, equals(4));
    });

    test('asBytes() - devolve copia dos bytes', () {
      final ip = Ip.fromBytes(const [1, 2, 3, 4]);
      final bytes = ip.asBytes()..[0] = 9;
      expect(bytes[0], equals(9));
      expect(ip.asBytes()[0], equals(1));
    });

    test('length - conta os bytes, como len(ip) no Go', () {
      expect(const Ip.nil().length, equals(0));
      expect(Ip.tryParse('::1')!.length, equals(16));
    });

    test('isNil - verdadeiro so para o endereco nil', () {
      expect(const Ip.nil().isNil, isTrue);
      expect(Ip.tryParse('127.0.0.1')!.isNil, isFalse);
    });

    test('to4() - devolve a forma de 4 bytes de um IPv4 mapeado', () {
      final v4 = Ip.tryParse('::ffff:127.0.0.1')!.to4();
      expect(v4, isNotNull);
      expect(v4!.asBytes(), equals(Uint8List.fromList([127, 0, 0, 1])));
    });

    test('to4() - devolve null para IPv6 que nao e mapeado', () {
      expect(Ip.tryParse('2001:db8::1')!.to4(), isNull);
      expect(const Ip.nil().to4(), isNull);
    });

    test('to16() - expande 4 bytes para a forma mapeada', () {
      final v6 = Ip.fromBytes(const [127, 0, 0, 1]).to16();
      expect(v6, isNotNull);
      expect(v6!.length, equals(16));
      expect(v6.asBytes()[10], equals(0xff));
      expect(v6.asBytes()[11], equals(0xff));
    });

    test('to16() - devolve null para tamanho que nao e 4 nem 16', () {
      expect(Ip.fromBytes(const [1, 2, 3]).to16(), isNull);
    });

    test('equal() - IPv4 e a sua forma mapeada sao iguais', () {
      // Diferenca deliberada em relacao a netip.Addr, onde sao distintos.
      expect(
        Ip.fromBytes(const [127, 0, 0, 1]).equal(Ip.tryParse('127.0.0.1')!),
        isTrue,
      );
      expect(
        Ip.tryParse('::ffff:127.0.0.1')!.equal(Ip.tryParse('127.0.0.1')!),
        isTrue,
      );
    });

    test('equal() - enderecos diferentes nao sao iguais', () {
      expect(
        Ip.tryParse('127.0.0.1')!.equal(Ip.tryParse('127.0.0.2')!),
        isFalse,
      );
      expect(Ip.tryParse('::1')!.equal(Ip.tryParse('127.0.0.1')!), isFalse);
    });

    test('toString() - mapeado imprime em forma pontuada', () {
      // Go: net.ParseIP("::ffff:127.0.0.1").String() == "127.0.0.1"
      expect(Ip.tryParse('::ffff:127.0.0.1').toString(), equals('127.0.0.1'));
      expect(Ip.tryParse('127.0.0.1').toString(), equals('127.0.0.1'));
    });

    test('toString() - IPv6 puro imprime comprimido', () {
      expect(Ip.tryParse('2001:db8::1').toString(), equals('2001:db8::1'));
    });

    test('toString() - nil imprime <nil>, como no Go', () {
      // Go: net.IP(nil).String() == "<nil>"
      expect(const Ip.nil().toString(), equals('<nil>'));
    });

    test('toString() - tamanho invalido imprime ? e hex', () {
      expect(Ip.fromBytes(const [0xde, 0xad]).toString(), equals('?dead'));
    });

    test('operator == - segue a semantica de equal()', () {
      expect(Ip.tryParse('::ffff:10.1.2.3'), equals(Ip.tryParse('10.1.2.3')));
      expect(Ip.tryParse('10.1.2.3'), isNot(equals(Ip.tryParse('10.1.2.4'))));
    });

    test('hashCode - serve de chave de mapa', () {
      final seen = <Ip, int>{};
      seen[Ip.tryParse('10.1.2.3')!] = 1;
      seen[Ip.tryParse('::ffff:10.1.2.3')!] = 2;
      expect(seen.length, equals(1));
    });
  });

  group('IpNet [Atomic Audit]', () {
    test('tryParseCidr() - IPv4 produz endereco e mascara de 4 bytes', () {
      // Go: n4.String() "10.0.0.0/8", maskLen 4, ipLen 4
      final n = IpNet.tryParseCidr('10.0.0.0/8');
      expect(n, isNotNull);
      expect(n!.ip.length, equals(4));
      expect(n.mask.length, equals(4));
    });

    test('tryParseCidr() - IPv6 produz endereco e mascara de 16 bytes', () {
      // Go: n6.String() "2001:db8::/32", maskLen 16, ipLen 16
      final n = IpNet.tryParseCidr('2001:db8::/32');
      expect(n, isNotNull);
      expect(n!.ip.length, equals(16));
      expect(n.mask.length, equals(16));
    });

    test('tryParseCidr() - mascara o endereco, como o Go', () {
      expect(
        IpNet.tryParseCidr('10.1.2.3/8')!.ip.toString(),
        equals('10.0.0.0'),
      );
    });

    test('tryParseCidr() - devolve null para CIDR invalido', () {
      // Go: net.ParseCIDR("nao-e-cidr") devolve erro e rede nil
      expect(IpNet.tryParseCidr('nao-e-cidr'), isNull);
      expect(IpNet.tryParseCidr('10.0.0.0'), isNull);
      expect(IpNet.tryParseCidr('10.0.0.0/33'), isNull);
      expect(IpNet.tryParseCidr('10.0.0.0/-1'), isNull);
    });

    test('ip - devolve o endereco de rede ja mascarado', () {
      expect(
        IpNet.tryParseCidr('10.0.0.0/8')!.ip,
        equals(Ip.tryParse('10.0.0.0')),
      );
    });

    test('mask - bits iniciais ligados conforme o prefixo', () {
      expect(
        IpNet.tryParseCidr('10.0.0.0/8')!.mask,
        equals(Uint8List.fromList([0xff, 0, 0, 0])),
      );
      expect(
        IpNet.tryParseCidr('10.0.0.0/12')!.mask,
        equals(Uint8List.fromList([0xff, 0xf0, 0, 0])),
      );
    });

    test('contains() - endereco dentro do bloco IPv4', () {
      // Go: n4.Contains(10.1.2.3) == true
      expect(
        IpNet.tryParseCidr('10.0.0.0/8')!.contains(Ip.tryParse('10.1.2.3')!),
        isTrue,
      );
    });

    test('contains() - aceita a forma mapeada do endereco', () {
      // Go: n4.Contains(::ffff:10.1.2.3) == true.
      // Esta e a diferenca em relacao a netip.Prefix.contains, que da false.
      expect(
        IpNet.tryParseCidr(
          '10.0.0.0/8',
        )!.contains(Ip.tryParse('::ffff:10.1.2.3')!),
        isTrue,
      );
    });

    test('contains() - endereco fora do bloco', () {
      // Go: n4.Contains(11.1.2.3) == false
      expect(
        IpNet.tryParseCidr('10.0.0.0/8')!.contains(Ip.tryParse('11.1.2.3')!),
        isFalse,
      );
    });

    test('contains() - bloco IPv6 aceita IPv6 e recusa IPv4', () {
      // Go: n6.Contains(2001:db8::5) true, n6.Contains(10.1.2.3) false
      final n6 = IpNet.tryParseCidr('2001:db8::/32')!;
      expect(n6.contains(Ip.tryParse('2001:db8::5')!), isTrue);
      expect(n6.contains(Ip.tryParse('10.1.2.3')!), isFalse);
    });

    test('toString() - forma CIDR canonica', () {
      // Go: "10.0.0.0/8" e "2001:db8::/32"
      expect(IpNet.tryParseCidr('10.0.0.0/8').toString(), equals('10.0.0.0/8'));
      expect(
        IpNet.tryParseCidr('2001:db8::/32').toString(),
        equals('2001:db8::/32'),
      );
    });

    test('toString() - mascara nao canonica cai no hexadecimal', () {
      final n = IpNet(
        ip: Ip.fromBytes(const [10, 0, 0, 0]),
        mask: Uint8List.fromList([0xff, 0x0f, 0, 0]),
      );
      expect(n.toString(), equals('10.0.0.0/ff0f0000'));
    });

    test('toString() - valor zero imprime <nil>', () {
      expect(
        IpNet(ip: const Ip.nil(), mask: Uint8List(0)).toString(),
        equals('<nil>'),
      );
    });

    test('operator == - iguala por endereco e mascara', () {
      expect(
        IpNet.tryParseCidr('10.0.0.0/8'),
        equals(IpNet.tryParseCidr('10.0.0.0/8')),
      );
      expect(
        IpNet.tryParseCidr('10.0.0.0/8'),
        isNot(equals(IpNet.tryParseCidr('10.0.0.0/16'))),
      );
    });

    test('hashCode - serve de chave de mapa', () {
      final seen = <IpNet, int>{};
      seen[IpNet.tryParseCidr('10.0.0.0/8')!] = 1;
      seen[IpNet.tryParseCidr('10.0.0.0/8')!] = 2;
      expect(seen.length, equals(1));
      expect(seen[IpNet.tryParseCidr('10.0.0.0/8')!], equals(2));
    });
  });
}
