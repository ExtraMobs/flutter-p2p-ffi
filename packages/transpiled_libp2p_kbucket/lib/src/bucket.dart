// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/bucket.dart
//
// Port of go-libp2p-kbucket's bucket.go. Go uses container/list (a
// doubly-linked list) since it needs stable iteration while removing
// arbitrary elements; a plain growable List does the same job just as
// well at the small sizes (<=20 peers) real k-buckets hold, and is more
// idiomatic Dart.
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

import 'util.dart';

/// All information tracked for a peer in a [Bucket]. Equivalent to
/// go-libp2p-kbucket's `PeerInfo`.
class PeerInfo {
  /// Creates a peer-info record.
  PeerInfo({
    required this.id,
    required this.dhtId,
    DateTime? lastUsefulAt,
    DateTime? lastSuccessfulOutboundQueryAt,
    DateTime? addedAt,
    this.replaceable = false,
  }) : lastUsefulAt = lastUsefulAt ?? _zero,
       lastSuccessfulOutboundQueryAt = lastSuccessfulOutboundQueryAt ?? _zero,
       addedAt = addedAt ?? _zero;

  static final DateTime _zero = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  /// The peer this record describes.
  final PeerId id;

  /// The instant this peer was last "useful" to us.
  DateTime lastUsefulAt;

  /// The instant we last got a successful query response from this peer.
  DateTime lastSuccessfulOutboundQueryAt;

  /// The instant this peer was added to the routing table.
  final DateTime addedAt;

  /// This peer's ID in the DHT XOR keyspace.
  final DhtId dhtId;

  /// Whether this peer can be replaced to make space for a new peer, if
  /// its bucket is full.
  bool replaceable;

  /// Whether [lastUsefulAt] has never been set.
  bool get lastUsefulAtIsZero => lastUsefulAt == _zero;
}

/// Holds a list of peers sharing a common prefix length with the local
/// peer. Equivalent to go-libp2p-kbucket's `bucket`.
class Bucket {
  final List<PeerInfo> _peers = [];

  /// A defensive copy of all peers in this bucket.
  List<PeerInfo> peers() => List.unmodifiable(_peers);

  /// The peer in this bucket for which [lessThan] never returns `false`
  /// when compared against any other, or `null` if the bucket is empty.
  /// It is NOT safe for [lessThan] to mutate its arguments.
  PeerInfo? min(bool Function(PeerInfo a, PeerInfo b) lessThan) {
    if (_peers.isEmpty) return null;
    var minVal = _peers.first;
    for (final val in _peers.skip(1)) {
      if (lessThan(val, minVal)) minVal = val;
    }
    return minVal;
  }

  /// Applies [update] to every peer in this bucket.
  void updateAllWith(void Function(PeerInfo p) update) {
    for (final p in _peers) {
      update(p);
    }
  }

  /// The IDs of all peers in this bucket.
  List<PeerId> peerIds() => [for (final p in _peers) p.id];

  /// The peer with the given [id], or `null` if it isn't in this bucket.
  PeerInfo? getPeer(PeerId id) {
    for (final p in _peers) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Removes the peer with the given [id]. Returns `true` if it was
  /// found and removed.
  bool remove(PeerId id) {
    final index = _peers.indexWhere((p) => p.id == id);
    if (index < 0) return false;
    _peers.removeAt(index);
    return true;
  }

  /// Adds [p] to the front of this bucket.
  void pushFront(PeerInfo p) => _peers.insert(0, p);

  /// The number of peers in this bucket.
  int get length => _peers.length;

  /// Splits this bucket's peers into two: this bucket keeps peers with
  /// common-prefix-length equal to [cpl] against [target]; the returned
  /// bucket gets peers with a common-prefix-length greater than [cpl]
  /// (the closer peers). Equivalent to go-libp2p-kbucket's `bucket.split`.
  Bucket split(int cpl, DhtId target) {
    final newBucket = Bucket();
    _peers.removeWhere((p) {
      final peerCpl = commonPrefixLen(p.dhtId, target);
      if (peerCpl > cpl) {
        newBucket._peers.add(p);
        return true;
      }
      return false;
    });
    return newBucket;
  }

  /// The maximum common-prefix-length between any peer in this bucket and
  /// [target]. Equivalent to go-libp2p-kbucket's `bucket.maxCommonPrefix`.
  int maxCommonPrefix(DhtId target) {
    var maxCpl = 0;
    for (final p in _peers) {
      final cpl = commonPrefixLen(p.dhtId, target);
      if (cpl > maxCpl) maxCpl = cpl;
    }
    return maxCpl;
  }
}
