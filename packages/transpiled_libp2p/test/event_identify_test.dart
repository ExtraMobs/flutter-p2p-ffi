// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  test('identify events preserve Go-visible fields', () {
    final peer = PeerId.fromBase58(
      'QmYwAPJzv5CZsnAzt8auVZRnGfB9cG1m6Y4X8sH5wT6q7r',
    );
    final conn = _Conn();
    final complete = EvtPeerIdentificationCompleted(
      peer: peer,
      conn: conn,
      listenAddrs: const [Multiaddr.empty],
      protocols: const ['/ipfs/id/1.0.0'],
      agentVersion: 'agent',
      protocolVersion: 'proto',
      observedAddr: Multiaddr.empty,
    );
    final failed = EvtPeerIdentificationFailed(
      peer: peer,
      reason: StateError('x'),
    );
    expect(complete.conn, conn);
    expect(complete.protocols.single, '/ipfs/id/1.0.0');
    expect(complete.agentVersion, 'agent');
    expect(failed.reason, isA<StateError>());
  });
}

final class _Conn implements Conn {}
