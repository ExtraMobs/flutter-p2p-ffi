@Tags(['network'])
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:transpiled_ipfs/src/transport/dns/system_resolver.dart';
import 'package:transpiled_ipfs/transpiled_ipfs.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_multiaddr_dns/transpiled_multiaddr_dns.dart';

/// Marco G.3 -- WebSocket transport (`/wss`) dialed against a real, public
/// peer, closing the one gap `doc/transpilation/PROGRESS.md` still lists for
/// this milestone: the transport and its `/wss` canonicalization are already
/// implemented (`packages/transpiled_libp2p/.../websocket/websocket.dart`),
/// but nothing had ever dialed a real external `/wss` listener with it.
///
/// Address discovery is not hardcoded: it resolves the official libp2p
/// bootstrapper `dnsaddr` TXT records at runtime (`_dnsaddr.bootstrap.libp2p.io`)
/// through this project's own `SystemResolver` + `transpiled_multiaddr_dns`
/// `Resolver`, exactly as a real libp2p bootstrap flow would, then keeps only
/// the resolved addresses that carry a `/wss` component.
const List<String> _dnsaddrBootstrapPeers = [
  'QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN',
  'QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa',
  'QmbLHAnMoJPWSCR5Zhtx6BHJX9KiKNN6tpvbUcqanj75Nb',
  'QmcZf59bWwK5XFi76CZX8cbJ4BhTzzA3gU1ZjYZcYW3dwt',
];

void main() {
  test(
    'dials a real public peer over /wss and establishes a websocket connection',
    () async {
      final resolver = Resolver(defaultResolver: SystemResolver());

      final wssCandidates = <String>{};
      for (final peer in _dnsaddrBootstrapPeers) {
        final seed = Multiaddr.parse('/dnsaddr/bootstrap.libp2p.io/p2p/$peer');
        final resolved = await _resolveDnsAddrFully(resolver, seed);
        for (final m in resolved) {
          final hasWss = m.components.any(
            (c) => c.protocol.code == Protocols.wss,
          );
          final endsWithPeer = m.components.isNotEmpty &&
              m.components.last.protocol.code == Protocols.p2p;
          if (hasWss && endsWithPeer) wssCandidates.add(m.toString());
        }
      }

      expect(
        wssCandidates,
        isNotEmpty,
        reason: 'no /wss address resolved from bootstrap.libp2p.io dnsaddr TXT '
            'records; either DNS/network is unavailable in this environment '
            'or the bootstrapper stopped publishing /wss addresses',
      );
      printOnFailure('Resolved /wss candidates: $wssCandidates');

      final failures = <String, Object>{};
      for (final candidate in wssCandidates) {
        final info = addrInfoFromString(candidate);
        IpfsNode? node;
        try {
          node = await IpfsNode.fromBuildCfg(
            BuildCfg(
              online: true,
              config: const IpfsConfig(
                offline: false,
                network: NetworkConfig(bootstrapPeers: []),
              ),
            ),
          );

          await node.connect(info).timeout(const Duration(seconds: 20));

          // Honest signal of an actual /wss connection, not just that
          // connect() returned: the swarm must record a live conn to that
          // peer, upgraded through WebsocketTransport (which always reports
          // transport: 'websocket' for both /ws and /wss -- see
          // _WebsocketCapableConn.connState() in websocket.dart), and that
          // conn's remote multiaddr must still carry the /wss component we
          // dialed (ruling out some other transport having answered for the
          // same peer id).
          final conns = node.peerHost!.network.connsToPeer(info.id);
          expect(
            conns,
            isNotEmpty,
            reason: 'connect() returned but no conn is recorded for $candidate',
          );
          final conn = conns.first;
          expect(
            conn.connState().transport,
            equals('websocket'),
            reason: 'conn to $candidate was not upgraded by WebsocketTransport',
          );
          expect(
            conn.remoteMultiaddr().components.any(
                  (c) => c.protocol.code == Protocols.wss,
                ),
            isTrue,
            reason: 'conn to $candidate reports remoteMultiaddr '
                '${conn.remoteMultiaddr()} without a /wss component',
          );

          printOnFailure('Connected over /wss to $candidate');
          return; // one real, verified /wss connection is the proof.
        } catch (e) {
          failures[candidate] = e;
        } finally {
          await node?.close();
        }
      }

      fail(
        'no /wss candidate could be dialed and verified; tried '
        '${wssCandidates.length} address(es):\n'
        '${failures.entries.map((e) => '  ${e.key}\n    ${e.value}').join('\n')}',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// Repeatedly applies [resolver] to [addr] until no `/dnsaddr/` component
/// remains -- a dnsaddr TXT record may itself point at another `/dnsaddr`
/// host -- and stops there.
///
/// Deliberately does **not** resolve the `/dns/`, `/dns4/` and `/dns6/`
/// components the TXT records hand back. A `/wss` address is dialled over
/// TLS, and the hostname is the only thing that can become the SNI and the
/// `Host` header; resolving it to an `/ip4/` here throws that away, and the
/// dial then reaches a shared TLS terminator with no name to route on, which
/// answers by closing the connection ("EOF reading multistream varint").
///
/// go-libp2p keeps the name for the same reason, by ordering its resolver
/// chain so that the transport's own `Resolve` -- which copies the DNS name
/// into an `/sni/` component (`websocket.go:180-214`) -- runs *before* the
/// DNS-to-IP step: `dnsAddrResolver`, `skipResolver`, `tptResolver`,
/// `dnsResolver`, in that order (`p2p/net/swarm/swarm_dial.go:383-446`).
/// This port's `Swarm.dialPeer` runs no resolver chain at all and hands the
/// address straight to the transport, where `_maDial` reads the hostname
/// from the `/dns*/` component itself -- so leaving that component in place
/// is what reproduces upstream's behaviour here.
Future<List<Multiaddr>> _resolveDnsAddrFully(
  Resolver resolver,
  Multiaddr addr, {
  int maxRounds = 4,
}) async {
  var frontier = [addr];
  for (var round = 0; round < maxRounds; round++) {
    var anyDnsAddr = false;
    final next = <Multiaddr>[];
    for (final m in frontier) {
      final isDnsAddr = m.components.any(
        (c) => c.protocol.code == Protocols.dnsaddr,
      );
      if (isDnsAddr) {
        anyDnsAddr = true;
        next.addAll(await resolver.resolve(m));
      } else {
        next.add(m);
      }
    }
    frontier = next;
    if (!anyDnsAddr) break;
  }
  return frontier;
}
