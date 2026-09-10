// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/sorting.dart
//
// Port of go-libp2p-kbucket's sorting.go.
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

import 'bucket.dart';
import 'util.dart';

class _PeerDistance {
  _PeerDistance(this.peer, this.distance);
  final PeerId peer;
  final DhtId distance;
}

/// Sorts peers by XOR distance to a target. Equivalent to
/// go-libp2p-kbucket's `peerDistanceSorter`.
class PeerDistanceSorter {
  /// Creates a sorter for peers relative to [target].
  PeerDistanceSorter(this.target);

  /// The key peers are sorted by distance to.
  final DhtId target;

  final List<_PeerDistance> _peers = [];

  /// The number of peers appended so far.
  int get length => _peers.length;

  /// Appends [peer] (whose DHT-keyspace ID is [peerDhtId]) to this sorter.
  /// The sorter may no longer be sorted after this.
  void appendPeer(PeerId peer, DhtId peerDhtId) {
    _peers.add(_PeerDistance(peer, xor(target, peerDhtId)));
  }

  /// Appends every peer in [bucket] to this sorter.
  void appendPeersFromBucket(Bucket bucket) {
    for (final p in bucket.peers()) {
      appendPeer(p.id, p.dhtId);
    }
  }

  /// Sorts the appended peers by ascending distance to [target].
  void sort() {
    _peers.sort((a, b) => _compareBytes(a.distance, b.distance));
  }

  /// The peers appended so far, in their current order.
  List<PeerId> get peers => [for (final pd in _peers) pd.peer];
}

/// Sorts [peers] by ascending XOR distance from [target]. Returns a new
/// list. Equivalent to go-libp2p-kbucket's `SortClosestPeers`.
List<PeerId> sortClosestPeers(List<PeerId> peers, DhtId target) {
  final sorter = PeerDistanceSorter(target);
  for (final p in peers) {
    sorter.appendPeer(p, convertPeerId(p));
  }
  sorter.sort();
  return sorter.peers;
}

int _compareBytes(DhtId a, DhtId b) {
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    if (a[i] != b[i]) return a[i] - b[i];
  }
  return a.length - b.length;
}
