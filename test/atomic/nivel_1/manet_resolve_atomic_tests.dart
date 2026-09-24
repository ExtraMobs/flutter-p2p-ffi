import 'package:test/test.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  group('manet.ResolveUnspecifiedAddresses [Atomic Audit - go-multiaddr resolve_test.go]', () {
    test('TestResolvingAddrs - expands unspecified addresses to matching interfaces', () {
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

      expect(() => resolveUnspecifiedAddress(ip4u[0], ip6i), throwsA(isA<StateError>()));
      expect(() => resolveUnspecifiedAddress(ip6u[0], ip4i), throwsA(isA<StateError>()));

      expect(() => resolveUnspecifiedAddresses(ip6u, ip4i), throwsA(isA<StateError>()));
      expect(() => resolveUnspecifiedAddresses(ip4u, ip6i), throwsA(isA<StateError>()));
    });
  });
}
