// test/transport/dns/system_resolver_network_test.dart
//
// End-to-end proof that the DNS gap this whole transpilation effort started
// from (see doc/transpilation/PROGRESS.md's go-multiaddr-dns row) is
// actually closed: SystemResolver (real DNS, this package) plugged into
// transpiled_multiaddr_dns's Resolver orchestration (go-multiaddr-dns's own
// logic, ported in the previous session) resolves a real production
// `/dnsaddr/` bootstrap multiaddr -- the exact kind of address in
// lib/src/core/config/network_config.dart's default bootstrap list -- into
// concrete dialable addresses.
//
// Talks to real DNS resolvers and a real domain, so it's tagged 'network'
// and skipped by default (see dart_test.yaml); run explicitly with
// `dart test --preset network`.
@Tags(['network'])
library;

import 'package:transpiled_ipfs/src/transport/dns/system_resolver.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_multiaddr_dns/transpiled_multiaddr_dns.dart';
import 'package:test/test.dart';

/// Repeatedly calls [Resolver.resolve] until every address is DNS-free.
/// bootstrap.libp2p.io's TXT records point at per-node dnsaddr aliases
/// (e.g. sv15.bootstrap.libp2p.io), not concrete addresses directly, so a
/// single resolve() pass is not expected to be enough -- this mirrors what
/// a real caller (and go-multiaddr-dns's own resolve_test.go
/// `resolveAllDNS` helper, already covered with mocks in
/// dns_resolver_parity_test.dart) has to do.
Future<List<Multiaddr>> _resolveAll(Resolver resolver, Multiaddr addr) async {
  var toResolve = [addr];
  final out = <Multiaddr>[];
  while (toResolve.isNotEmpty) {
    final next = <Multiaddr>[];
    for (final a in toResolve) {
      for (final resolved in await resolver.resolve(a)) {
        if (dnsMatches(resolved)) {
          next.add(resolved);
        } else {
          out.add(resolved);
        }
      }
    }
    toResolve = next;
  }
  return out;
}

void main() {
  group('SystemResolver + transpiled_multiaddr_dns Resolver (live network)', () {
    test('resolves a real /dnsaddr/ bootstrap multiaddr', () async {
      final resolver = Resolver(defaultResolver: SystemResolver());

      final addrs = await _resolveAll(
        resolver,
        Multiaddr.parse(
          '/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
        ),
      );

      expect(addrs, isNotEmpty);
      for (final a in addrs) {
        // Every resolved address must still end in the same PeerId suffix
        // that was requested -- the whole point of go-multiaddr-dns's
        // suffix-matching algorithm.
        expect(
          a.valueForProtocol(Protocols.p2p),
          equals('QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN'),
        );
        // And it should now carry a concrete transport address in front of
        // that PeerId, not a dns component anymore.
        expect(dnsMatches(a), isFalse);
      }
    });

    test('resolves a plain dns4 hostname to real IPv4 addresses', () async {
      final resolver = Resolver(defaultResolver: SystemResolver());
      final addrs = await resolver.resolve(Multiaddr.parse('/dns4/dns.google'));
      expect(addrs, isNotEmpty);
      for (final a in addrs) {
        expect(a.hasProtocol(Protocols.ip4), isTrue);
      }
    });
  });
}
