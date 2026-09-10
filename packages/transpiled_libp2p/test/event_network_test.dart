// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  test('network and reachability events preserve Go fields and types', () {
    final peer = PeerId.fromBase58(
      '12D3KooWE9Gn3dipZhrnrhCVPoeDhdmK3svuy8q9PAqDGgYb8c3S',
    );
    final connected = EvtPeerConnectednessChanged(
      peer: peer,
      connectedness: Connectedness.connected,
    );
    const local = EvtLocalReachabilityChanged(
      reachability: Reachability.public_,
    );
    const host = EvtHostReachableAddrsChanged(
      reachable: [Multiaddr.empty],
      unreachable: [],
      unknown: [],
    );

    expect(connected.peer, peer);
    expect(connected.connectedness, Connectedness.connected);
    expect(local.reachability, Reachability.public_);
    expect(host.reachable.single, Multiaddr.empty);
  });
}
