// test/atomic/nivel_1/multiaddr_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo multiaddr (transpiled_multiaddr).

import 'dart:typed_data';
import 'package:boilerplate/net/golang.dart';
import 'package:test/test.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  group('Component [Atomic Audit]', () {
    final ip4Proto = Protocols.byName('ip4')!;
    final component = Component(ip4Proto, '127.0.0.1');

    test('value - getter retorna valor decodificado em string', () {
      expect(component.value, equals('127.0.0.1'));
      final flagComp = Component(Protocols.byName('utp')!, '');
      expect(flagComp.value, equals(''));
    });

    test('toBytes() - serializa componente para formato binario', () {
      final bytes = component.toBytes();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], equals(ip4Proto.code));
    });

    test(
      'toAddrString() - formata componente com barra e nome do protocolo',
      () {
        expect(component.toAddrString(), equals('/ip4/127.0.0.1'));
      },
    );

    test(
      'toString() - converte para mesma representacao textual toAddrString',
      () {
        expect(component.toString(), equals('/ip4/127.0.0.1'));
      },
    );

    test('operator == - compara igualdade de componentes por wire bytes', () {
      final compEqual = Component(ip4Proto, '127.0.0.1');
      final compDiff = Component(ip4Proto, '10.0.0.1');
      expect(component == compEqual, isTrue);
      expect(component == compDiff, isFalse);
    });

    test('hashCode - produz hash consistente para componentes iguais', () {
      final compEqual = Component(ip4Proto, '127.0.0.1');
      expect(component.hashCode, equals(compEqual.hashCode));
    });

    test('compareTo() - compara lexicograficamente bytes dos componentes', () {
      final compEqual = Component(ip4Proto, '127.0.0.1');
      final compTcp = Component(Protocols.byName('tcp')!, '8080');
      expect(component.compareTo(compEqual), equals(0));
      expect(component.compareTo(compTcp) != 0, isTrue);
    });
  });

  group('Multiaddr [Atomic Audit]', () {
    final ma = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');

    test('toBytes() - serializa sequencia de componentes para wire bytes', () {
      final bytes = ma.toBytes();
      expect(bytes.isNotEmpty, isTrue);
      final decoded = Multiaddr.fromBytes(bytes);
      expect(decoded, equals(ma));
    });

    test('toAddrString() - produz string do multiaddr completo', () {
      expect(ma.toAddrString(), equals('/ip4/127.0.0.1/tcp/4001'));
    });

    test('toString() - converte para representacao toAddrString', () {
      expect(ma.toString(), equals('/ip4/127.0.0.1/tcp/4001'));
    });

    test('protocols - getter retorna lista de protocolos na ordem', () {
      final protos = ma.protocols;
      expect(protos.length, equals(2));
      expect(protos[0].name, equals('ip4'));
      expect(protos[1].name, equals('tcp'));
    });

    test(
      'valueForProtocol() - busca valor do protocolo pelo codigo numerico',
      () {
        expect(ma.valueForProtocol(Protocols.ip4), equals('127.0.0.1'));
        expect(ma.valueForProtocol(Protocols.tcp), equals('4001'));
        expect(ma.valueForProtocol(Protocols.udp), isNull);
      },
    );

    test('hasProtocol() - verifica se o protocolo esta presente na cadeia', () {
      expect(ma.hasProtocol(Protocols.ip4), isTrue);
      expect(ma.hasProtocol(Protocols.tcp), isTrue);
      expect(ma.hasProtocol(Protocols.udp), isFalse);
    });

    test('encapsulate() - concatena outro multiaddr ao final', () {
      final other = Multiaddr.parse('/udp/1234');
      final combined = ma.encapsulate(other);
      expect(combined.toString(), equals('/ip4/127.0.0.1/tcp/4001/udp/1234'));
    });

    test('decapsulate() - remove sufixo correspondente do multiaddr', () {
      final other = Multiaddr.parse('/tcp/4001');
      final stripped = ma.decapsulate(other);
      expect(stripped.toString(), equals('/ip4/127.0.0.1'));
    });

    test('forEach() - itera sobre componentes com saida antecipada', () {
      final visited = <String>[];
      ma.forEach((c) {
        visited.add(c.protocol.name);
        return true;
      });
      expect(visited, equals(['ip4', 'tcp']));

      final early = <String>[];
      ma.forEach((c) {
        early.add(c.protocol.name);
        return false;
      });
      expect(early, equals(['ip4']));
    });

    test(
      'splitFunc() - divide multiaddr a partir de predicado em tupla pre e post',
      () {
        final (pre, post) = ma.splitFunc((c) => c.protocol.name == 'tcp');
        expect(pre.toString(), equals('/ip4/127.0.0.1'));
        expect(post?.toString(), equals('/tcp/4001'));
      },
    );

    test('splitFirst() - divide primeiro componente separando o resto', () {
      final (first, rest) = ma.splitFirst();
      expect(first?.toAddrString(), equals('/ip4/127.0.0.1'));
      expect(rest?.toString(), equals('/tcp/4001'));
    });

    test('splitLast() - divide ultimo componente separando o prefixo', () {
      final (prefix, last) = ma.splitLast();
      expect(prefix?.toString(), equals('/ip4/127.0.0.1'));
      expect(last?.toAddrString(), equals('/tcp/4001'));
    });

    test('operator == - compara igualdade de componentes em ordem', () {
      final maEqual = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
      final maDiff = Multiaddr.parse('/ip4/127.0.0.1/tcp/4002');
      expect(ma == maEqual, isTrue);
      expect(ma == maDiff, isFalse);
    });

    test('hashCode - gera hash consistente para instancias iguais', () {
      final maEqual = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
      expect(ma.hashCode, equals(maEqual.hashCode));
    });

    test('compareTo() - compara lexicograficamente multiaddrs', () {
      final maEqual = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
      expect(ma.compareTo(maEqual), equals(0));
    });
  });

  group('Transcoder [Atomic Audit]', () {
    test(
      'validateBytes() - valida fatia de bytes executando validador do transcoder',
      () {
        var called = false;
        final transcoder = Transcoder((s) => Uint8List(0), (b) => '', (b) {
          called = true;
          if (b.length != 4) throw const FormatException('invalid length');
        });
        transcoder.validateBytes(Uint8List(4));
        expect(called, isTrue);
        expect(
          () => transcoder.validateBytes(Uint8List(3)),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('Protocol [Atomic Audit]', () {
    test(
      'isVariableSize - getter retorna verdadeiro para protocolos de tamanho variavel',
      () {
        expect(Protocols.byName('p2p')!.isVariableSize, isTrue);
        expect(Protocols.byName('ip4')!.isVariableSize, isFalse);
        expect(Protocols.byName('tcp')!.isVariableSize, isFalse);
      },
    );
  });

  group('Protocols [Atomic Audit]', () {
    test('byName() - pesquisa protocolo pelo nome registrado', () {
      expect(Protocols.byName('tcp')?.code, equals(Protocols.tcp));
      expect(Protocols.byName('ip4')?.code, equals(Protocols.ip4));
      expect(Protocols.byName('nonexistent_proto_xyz'), isNull);
    });

    test('byCode() - pesquisa protocolo pelo codigo numerico', () {
      expect(Protocols.byCode(Protocols.tcp)?.name, equals('tcp'));
      expect(Protocols.byCode(Protocols.ip4)?.name, equals('ip4'));
      expect(Protocols.byCode(999999), isNull);
    });
  });

  group('toIp [Atomic Audit]', () {
    test('toIp() - converts multiaddr to Ip', () {
      final ip4 = toIp(Multiaddr.parse('/ip4/192.168.1.1/tcp/80'));
      expect(ip4, isNotNull);
      expect(ip4?.toString(), equals('192.168.1.1'));

      final ip6 = toIp(Multiaddr.parse('/ip6/2001:db8::1/tcp/80'));
      expect(ip6, isNotNull);
      expect(ip6?.toString(), contains('2001:db8'));

      final nonIp = toIp(Multiaddr.parse('/dns4/example.com/tcp/80'));
      expect(nonIp, isNull);
    });
  });

  group('fromIp [Atomic Audit]', () {
    test('fromIp() - converts Ip to multiaddr', () {
      final v4 = Ip.tryParse('1.2.3.4')!;
      expect(fromIp(v4).toString(), equals('/ip4/1.2.3.4'));

      final v6 = Ip.tryParse('2001:db8::1')!;
      expect(fromIp(v6).toString(), contains('/ip6/'));
    });
  });

  group('isThinWaist [Atomic Audit]', () {
    test('isThinWaist() - identifies thin waist protocol stacks', () {
      expect(isThinWaist(Multiaddr.parse('/ip4/1.2.3.4/tcp/80')), isTrue);
      expect(isThinWaist(Multiaddr.parse('/ip6/::1/udp/1234')), isTrue);
      expect(isThinWaist(Multiaddr.parse('/ip4/1.2.3.4')), isTrue);
      expect(isThinWaist(Multiaddr.parse('/tcp/80')), isFalse);
      expect(isThinWaist(Multiaddr.parse('/dns4/example.com/tcp/80')), isFalse);
    });
  });

  group('isIpLoopback [Atomic Audit]', () {
    test('isIpLoopback() - checks loopback multiaddresses', () {
      expect(isIpLoopback(ip4Loopback), isTrue);
      expect(isIpLoopback(ip6Loopback), isTrue);
      expect(isIpLoopback(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')), isTrue);
      expect(isIpLoopback(Multiaddr.parse('/ip4/8.8.8.8/tcp/4001')), isFalse);
    });
  });

  group('isIp6LinkLocal [Atomic Audit]', () {
    test('isIp6LinkLocal() - checks IPv6 link local multiaddresses', () {
      expect(isIp6LinkLocal(Multiaddr.parse('/ip6/fe80::1/tcp/4001')), isTrue);
      expect(
        isIp6LinkLocal(Multiaddr.parse('/ip6/2001:db8::1/tcp/4001')),
        isFalse,
      );
      expect(
        isIp6LinkLocal(Multiaddr.parse('/ip4/169.254.1.1/tcp/4001')),
        isFalse,
      );
    });
  });

  group('isIpUnspecified [Atomic Audit]', () {
    test('isIpUnspecified() - checks unspecified multiaddresses', () {
      expect(isIpUnspecified(ip4Unspecified), isTrue);
      expect(isIpUnspecified(ip6Unspecified), isTrue);
      expect(
        isIpUnspecified(Multiaddr.parse('/ip4/1.2.3.4/tcp/4001')),
        isFalse,
      );
    });
  });

  group('isPublicAddr [Atomic Audit]', () {
    test('isPublicAddr() - validates multiaddresses for public routability', () {
      expect(isPublicAddr(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')), isFalse);
      expect(isPublicAddr(Multiaddr.parse('/ip4/10.0.0.1/tcp/4001')), isFalse);
      expect(
        isPublicAddr(Multiaddr.parse('/ip4/192.168.1.1/tcp/4001')),
        isFalse,
      );
      expect(
        isPublicAddr(
          Multiaddr.parse(
            '/p2p-circuit/p2p/12D3KooWDsMmX7axDC6HTTXUNe4upxEvFbNQjmE2FToVVbBzUK6f',
          ),
        ),
        isFalse,
      );
      expect(
        isPublicAddr(Multiaddr.parse('/ip4/203.0.113.47/tcp/4001')),
        isTrue,
      );
      expect(isPublicAddr(Multiaddr.parse('/ip4/8.8.8.8/tcp/4001')), isTrue);
      expect(isPublicAddr(Multiaddr.parse('/dns4/ipfs.io/tcp/443')), isTrue);
      expect(isPublicAddr(Multiaddr.parse('/dns4/localhost/tcp/80')), isFalse);
    });
  });

  group('isPrivateAddr [Atomic Audit]', () {
    test('isPrivateAddr() - validates multiaddresses for private networks', () {
      expect(isPrivateAddr(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')), isTrue);
      expect(isPrivateAddr(Multiaddr.parse('/ip4/10.0.0.1/tcp/4001')), isTrue);
      expect(
        isPrivateAddr(Multiaddr.parse('/ip4/192.168.1.1/tcp/4001')),
        isTrue,
      );
      expect(isPrivateAddr(Multiaddr.parse('/ip4/8.8.8.8/tcp/4001')), isFalse);
      expect(isPrivateAddr(Multiaddr.parse('/dns4/localhost/tcp/80')), isTrue);
    });
  });
}
