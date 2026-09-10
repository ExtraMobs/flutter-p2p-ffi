// test/atomic/nivel_1/multiaddr_dns_atomic_tests.dart
// Testes atômicos 1 para 1 para o módulo multiaddr_dns (transpiled_multiaddr_dns).

import 'package:test/test.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_multiaddr_dns/transpiled_multiaddr_dns.dart';

class _CustomTestResolver implements BasicResolver {
  _CustomTestResolver({
    Map<String, List<String>>? ipMap,
    Map<String, List<String>>? txtMap,
  })  : _ipMap = ipMap ?? const {},
        _txtMap = txtMap ?? const {};

  final Map<String, List<String>> _ipMap;
  final Map<String, List<String>> _txtMap;

  @override
  Future<List<String>> lookupIpAddr(String name) async => _ipMap[name] ?? const [];

  @override
  Future<List<String>> lookupTxt(String name) async => _txtMap[name] ?? const [];
}

void main() {
  group('BasicResolver [Atomic Audit]', () {
    test('lookupIpAddr() - busca enderecos IP atraves da interface BasicResolver', () async {
      final BasicResolver resolver = _CustomTestResolver(
        ipMap: {'meuhost': ['192.168.1.50', '2001:db8::1']},
      );
      final ips = await resolver.lookupIpAddr('meuhost');
      expect(ips, equals(['192.168.1.50', '2001:db8::1']));

      final desconhecido = await resolver.lookupIpAddr('inexistente');
      expect(desconhecido, isEmpty);
    });

    test('lookupTxt() - busca registros TXT atraves da interface BasicResolver', () async {
      final BasicResolver resolver = _CustomTestResolver(
        txtMap: {'_dnsaddr.servico': ['dnsaddr=/ip4/10.0.0.1/tcp/4001', 'custom text']},
      );
      final txts = await resolver.lookupTxt('_dnsaddr.servico');
      expect(txts, equals(['dnsaddr=/ip4/10.0.0.1/tcp/4001', 'custom text']));

      final desconhecido = await resolver.lookupTxt('_dnsaddr.inexistente');
      expect(desconhecido, isEmpty);
    });
  });

  group('MockResolver [Atomic Audit]', () {
    test('lookupIpAddr() - retorna enderecos IP mapeados ou lista vazia', () async {
      final mock = MockResolver(
        ip: {
          'host-a': ['10.0.0.1'],
          'host-b': ['10.0.0.2', '10.0.0.3'],
        },
      );

      expect(await mock.lookupIpAddr('host-a'), equals(['10.0.0.1']));
      expect(await mock.lookupIpAddr('host-b'), equals(['10.0.0.2', '10.0.0.3']));
      expect(await mock.lookupIpAddr('host-c'), isEmpty);
    });

    test('lookupTxt() - retorna registros TXT mapeados ou lista vazia', () async {
      final mock = MockResolver(
        txt: {
          'dominio-x': ['entrada txt 1', 'entrada txt 2'],
        },
      );

      expect(await mock.lookupTxt('dominio-x'), equals(['entrada txt 1', 'entrada txt 2']));
      expect(await mock.lookupTxt('dominio-y'), isEmpty);
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('isFqdn() - valida se string termina com ponto nao escapado', () {
      expect(isFqdn('example.com.'), isTrue);
      expect(isFqdn('sub.domain.org.'), isTrue);
      expect(isFqdn('.'), isTrue);
      expect(isFqdn('example.com'), isFalse);
      expect(isFqdn(''), isFalse);

      // Barra invertida simples escapa o ponto (nao FQDN)
      expect(isFqdn(r'example\.'), isFalse);
      // Duas barras invertidas se anulam, mantendo o ponto sem escape (FQDN)
      expect(isFqdn(r'example\\.'), isTrue);
      // Tres barras invertidas escapam o ponto (nao FQDN)
      expect(isFqdn(r'example\\\.'), isFalse);
    });

    test('fqdn() - garante ponto final para nomes de dominio', () {
      expect(fqdn('example.com'), equals('example.com.'));
      expect(fqdn('example.com.'), equals('example.com.'));
      expect(fqdn(r'escaped\.'), equals(r'escaped\..'));
      expect(fqdn(r'double\\.'), equals(r'double\\.'));
    });

    test('dnsMatches() - detecta presenca de protocolos dns no Multiaddr', () {
      expect(dnsMatches(Multiaddr.parse('/dns/example.com')), isTrue);
      expect(dnsMatches(Multiaddr.parse('/dns4/example.com')), isTrue);
      expect(dnsMatches(Multiaddr.parse('/dns6/example.com')), isTrue);
      expect(dnsMatches(Multiaddr.parse('/dnsaddr/example.com')), isTrue);
      expect(dnsMatches(Multiaddr.parse('/tcp/1234/dns4/example.com/udp/5678')), isTrue);

      expect(dnsMatches(Multiaddr.parse('/ip4/127.0.0.1/tcp/8080')), isFalse);
      expect(dnsMatches(Multiaddr.parse('/ip6/::1/tcp/443')), isFalse);
      expect(dnsMatches(Multiaddr.empty), isFalse);
    });
  });

  group('Resolver [Atomic Audit]', () {
    test('withDomainResolver() - registra resolver customizado para dominio e subdominios', () async {
      final defaultMock = MockResolver(ip: {'padrao': ['1.1.1.1']});
      final customMock = MockResolver(ip: {
        'especial.org': ['2.2.2.2'],
        'sub.especial.org': ['3.3.3.3'],
      });

      final resolver = Resolver(defaultResolver: defaultMock);
      resolver.withDomainResolver('especial.org', customMock);

      expect(await resolver.lookupIpAddr('especial.org'), equals(['2.2.2.2']));
      expect(await resolver.lookupIpAddr('sub.especial.org'), equals(['3.3.3.3']));
      expect(await resolver.lookupIpAddr('padrao'), equals(['1.1.1.1']));
    });

    test('withDefaultResolver() - configura resolver padrao de contingencia', () async {
      final resolver = Resolver();
      // Sem default resolver configurado deve lancar StateError
      expect(() => resolver.lookupIpAddr('qualquer'), throwsA(isA<StateError>()));

      final fallbackMock = MockResolver(ip: {'qualquer': ['9.9.9.9']});
      resolver.withDefaultResolver(fallbackMock);
      expect(await resolver.lookupIpAddr('qualquer'), equals(['9.9.9.9']));
    });

    test('lookupIpAddr() - delega resolucao de IP ao resolver correspondente ao dominio', () async {
      final mock = MockResolver(
        ip: {'node.local': ['192.168.0.100']},
      );
      final resolver = Resolver(defaultResolver: mock);
      final ips = await resolver.lookupIpAddr('node.local');
      expect(ips, equals(['192.168.0.100']));
    });

    test('lookupTxt() - delega resolucao TXT ao resolver correspondente ao dominio', () async {
      final mock = MockResolver(
        txt: {'_dnsaddr.p2p.local': ['dnsaddr=/ip4/10.0.0.5/tcp/4001/p2p/QmTest']},
      );
      final resolver = Resolver(defaultResolver: mock);
      final txts = await resolver.lookupTxt('_dnsaddr.p2p.local');
      expect(txts, equals(['dnsaddr=/ip4/10.0.0.5/tcp/4001/p2p/QmTest']));
    });

    test('resolve() - substitui componente DNS pelos enderecos resolvidos no Multiaddr', () async {
      final mock = MockResolver(
        ip: {
          'example.com': ['192.0.2.1', '2001:db8::a3'],
        },
        txt: {
          '_dnsaddr.example.com': [
            'dnsaddr=/ip4/192.0.2.1/tcp/4001',
            'dnsaddr=/ip6/2001:db8::a3/tcp/4001',
            'invalido txt ignorado',
          ],
        },
      );
      final resolver = Resolver(defaultResolver: mock);

      // dns4 filtra apenas IPv4
      final dns4Result = await resolver.resolve(Multiaddr.parse('/dns4/example.com/tcp/80'));
      expect(dns4Result, equals([Multiaddr.parse('/ip4/192.0.2.1/tcp/80')]));

      // dns6 filtra apenas IPv6
      final dns6Result = await resolver.resolve(Multiaddr.parse('/dns6/example.com/tcp/80'));
      expect(dns6Result, equals([Multiaddr.parse('/ip6/2001:db8::a3/tcp/80')]));

      // dns aceita ambos IPv4 e IPv6
      final dnsResult = await resolver.resolve(Multiaddr.parse('/dns/example.com/tcp/80'));
      expect(dnsResult, equals([
        Multiaddr.parse('/ip4/192.0.2.1/tcp/80'),
        Multiaddr.parse('/ip6/2001:db8::a3/tcp/80'),
      ]));

      // dnsaddr resolve entradas a partir dos TXT
      final dnsaddrResult = await resolver.resolve(Multiaddr.parse('/dnsaddr/example.com/tcp/4001'));
      expect(dnsaddrResult, equals([
        Multiaddr.parse('/ip4/192.0.2.1/tcp/4001'),
        Multiaddr.parse('/ip6/2001:db8::a3/tcp/4001'),
      ]));

      // Multiaddr sem componentes dns retorna o endereco original
      final noDns = Multiaddr.parse('/ip4/127.0.0.1/tcp/8080');
      final plainResult = await resolver.resolve(noDns);
      expect(plainResult, equals([noDns]));

      // Multiaddr nulo retorna lista vazia
      final nullResult = await resolver.resolve(null);
      expect(nullResult, isEmpty);
    });
  });
}
