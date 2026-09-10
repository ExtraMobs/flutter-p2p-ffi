// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

void main() {
  test('protocol events preserve peer and protocol deltas', () {
    final peer = PeerId.fromBase58(
      'QmYwAPJzv5CZsnAzt8auVZRnGfB9cG1m6Y4X8sH5wT6q7r',
    );
    final remote = EvtPeerProtocolsUpdated(
      peer: peer,
      added: ['/ipfs/id/1.0.0'],
      removed: ['/ipfs/ping/1.0.0'],
    );
    const local = EvtLocalProtocolsUpdated(added: ['/ipfs/kad/1.0.0']);
    expect(remote.peer, peer);
    expect(remote.added.single, '/ipfs/id/1.0.0');
    expect(remote.removed.single, '/ipfs/ping/1.0.0');
    expect(local.added.single, '/ipfs/kad/1.0.0');
  });
}
