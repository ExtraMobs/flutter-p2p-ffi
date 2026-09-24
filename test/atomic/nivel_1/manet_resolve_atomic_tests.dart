import 'package:test/test.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  group(
    'manet.ResolveUnspecifiedAddresses [Atomic Audit - go-multiaddr resolve_test.go]',
    () {
      test(
        'TestResolvingAddrs - expands unspecified addresses to matching interfaces',
        () {
          final unspec = [
            Multiaddr.parse('/ip4/0.0.0.0/tcp/1234'),
            Multiaddr.parse('/ip4/1.2.3.4/tcp/1234'),
            Multiaddr.parse('/ip6/::/tcp/1234'),
            Multiaddr.parse('/ip6/::100/tcp/1234'),
            Multiaddr.parse('/ip4/0.0.0.0'),
          ];

          final iface = [
            Multiaddr.parse('/ip4/127.0.0.1'),
            Multiaddr.parse('/ip4/10.20.30.40'),
            Multiaddr.parse('/ip6/::1'),
            Multiaddr.parse('/ip6/::f'),
          ];

          final spec = [
            Multiaddr.parse('/ip4/127.0.0.1/tcp/1234'),
            Multiaddr.parse('/ip4/10.20.30.40/tcp/1234'),
            Multiaddr.parse('/ip4/1.2.3.4/tcp/1234'),
            Multiaddr.parse('/ip6/::1/tcp/1234'),
            Multiaddr.parse('/ip6/::f/tcp/1234'),
            Multiaddr.parse('/ip6/::100/tcp/1234'),
            Multiaddr.parse('/ip4/127.0.0.1'),
            Multiaddr.parse('/ip4/10.20.30.40'),
          ];

          final actual = resolveUnspecifiedAddresses(unspec, iface);
          expect(actual.length, equals(spec.length));
          for (var i = 0; i < actual.length; i++) {
            expect(actual[i].toString(), equals(spec[i].toString()));
          }

          final ip4u = [Multiaddr.parse('/ip4/0.0.0.0')];
          final ip4i = [Multiaddr.parse('/ip4/1.2.3.4')];

          final ip6u = [Multiaddr.parse('/ip6/::')];
          final ip6i = [Multiaddr.parse('/ip6/::1')];

          expect(
            () => resolveUnspecifiedAddress(ip4u[0], ip6i),
            throwsA(isA<StateError>()),
          );
          expect(
            () => resolveUnspecifiedAddress(ip6u[0], ip4i),
            throwsA(isA<StateError>()),
          );

          expect(
            () => resolveUnspecifiedAddresses(ip6u, ip4i),
            throwsA(isA<StateError>()),
          );
          expect(
            () => resolveUnspecifiedAddresses(ip4u, ip6i),
            throwsA(isA<StateError>()),
          );
        },
      );
    },
  );

  // Grupo em caixa baixa de propósito: mantém as chamadas abaixo mapeadas
  // como funções de nível superior (sem prefixo de classe), pois é assim que
  // existem em go-multiaddr/net/ip.go e resolve.go.
  group('manet funcoes de nivel superior [Atomic Audit]', () {
    test(
      'splitFirstSlice() - separa o primeiro componente do restante (Go: manet.splitFirstSlice, ip.go:107-116)',
      () {
        final addr = Multiaddr.parse('/ip4/1.2.3.4/tcp/1234');
        final (first, rest) = splitFirstSlice(addr);
        expect(first?.toString(), equals('/ip4/1.2.3.4'));
        expect(rest?.toString(), equals('/tcp/1234'));
      },
    );

    test(
      'splitFirstSlice() - devolve (m, null) quando so ha um componente',
      () {
        final addr = Multiaddr.parse('/ip4/1.2.3.4');
        final (first, rest) = splitFirstSlice(addr);
        expect(first?.toString(), equals('/ip4/1.2.3.4'));
        expect(rest, isNull);
      },
    );

    test(
      'splitFirstSlice() - devolve (null, null) para um multiaddr vazio',
      () {
        final (first, rest) = splitFirstSlice(Multiaddr.empty);
        expect(first, isNull);
        expect(rest, isNull);
      },
    );

    test(
      'resolveUnspecifiedAddress() - expande /ip4/0.0.0.0 para os enderecos de interface do mesmo protocolo (Go: manet.ResolveUnspecifiedAddress, resolve.go:11-41)',
      () {
        final resolved = resolveUnspecifiedAddress(
          Multiaddr.parse('/ip4/0.0.0.0/tcp/1234'),
          [Multiaddr.parse('/ip4/127.0.0.1'), Multiaddr.parse('/ip6/::1')],
        );
        expect(
          resolved.map((a) => a.toString()).toList(),
          equals(['/ip4/127.0.0.1/tcp/1234']),
        );
      },
    );

    test(
      'resolveUnspecifiedAddress() - devolve o proprio endereco quando ja e especifico',
      () {
        final addr = Multiaddr.parse('/ip4/1.2.3.4/tcp/1234');
        final resolved = resolveUnspecifiedAddress(addr, const []);
        expect(resolved, equals([addr]));
      },
    );

    test(
      'resolveUnspecifiedAddress() - lanca StateError quando nenhuma interface do mesmo protocolo existe',
      () {
        expect(
          () => resolveUnspecifiedAddress(Multiaddr.parse('/ip4/0.0.0.0'), [
            Multiaddr.parse('/ip6/::1'),
          ]),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'resolveUnspecifiedAddresses() - resolve varios enderecos de uma vez, preservando os ja especificos (Go: manet.ResolveUnspecifiedAddresses, resolve.go:45-69)',
      () {
        final resolved = resolveUnspecifiedAddresses(
          [
            Multiaddr.parse('/ip4/0.0.0.0/tcp/4001'),
            Multiaddr.parse('/ip4/9.9.9.9/tcp/4001'),
          ],
          [Multiaddr.parse('/ip4/192.168.1.10')],
        );
        expect(
          resolved.map((a) => a.toString()).toList(),
          equals(['/ip4/192.168.1.10/tcp/4001', '/ip4/9.9.9.9/tcp/4001']),
        );
      },
    );

    test(
      'resolveUnspecifiedAddresses() - lanca StateError quando nenhum endereco pode ser resolvido',
      () {
        expect(
          () => resolveUnspecifiedAddresses(
            [Multiaddr.parse('/ip4/0.0.0.0/tcp/1')],
            [Multiaddr.parse('/ip6/::1')],
          ),
          throwsA(isA<StateError>()),
        );
      },
    );
  });
}
