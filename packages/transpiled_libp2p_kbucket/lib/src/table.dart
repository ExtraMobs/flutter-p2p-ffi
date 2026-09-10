// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/table.dart
//
// Port of go-libp2p-kbucket's table.go: the Kademlia k-bucket routing
// table. Go guards all table access with a `sync.RWMutex`; this port
// drops that since Dart code sharing a single isolate never runs two
// pieces of synchronous logic concurrently -- an `await` is the only
// place another task could interleave, and there are none inside the
// critical sections ported here.
//
// The `peerdiversity.Filter` (IP/ASN-based peer diversity) integration
// point is kept (`diversityFilter`), but no implementation is provided
// yet -- it depends on go-cidranger and go-libp2p-asn-util, neither
// cloned/ported yet (see doc/transpilation/PROGRESS.md). Passing `null`
// (the default) matches Go's own `df != nil` optionality.
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

import 'bucket.dart';
import 'peer_metrics.dart';
import 'sorting.dart';
import 'util.dart';

/// Thrown by [RoutingTable.tryAddPeer] when a peer's latency exceeds
/// [RoutingTable.maxLatency]. Equivalent to go-libp2p-kbucket's
/// `ErrPeerRejectedHighLatency`.
class PeerRejectedHighLatencyException implements Exception {
  /// Creates the exception.
  const PeerRejectedHighLatencyException();
  @override
  String toString() => 'peer rejected; latency too high';
}

/// Thrown by [RoutingTable.tryAddPeer] when the peer's bucket is full of
/// non-replaceable peers. Equivalent to go-libp2p-kbucket's
/// `ErrPeerRejectedNoCapacity`.
class PeerRejectedNoCapacityException implements Exception {
  /// Creates the exception.
  const PeerRejectedNoCapacityException();
  @override
  String toString() => 'peer rejected; insufficient capacity';
}

/// A diversity filter hook for [RoutingTable], matching go-libp2p-kbucket's
/// `peerdiversity.Filter` interface at the call sites that use it. No
/// concrete implementation is ported yet -- see this file's header.
abstract class DiversityFilter {
  /// Tries to admit [id]; returns `false` to reject it.
  bool tryAdd(PeerId id);

  /// Removes [id] from the filter's state.
  void remove(PeerId id);
}

/// A Kademlia k-bucket routing table. Equivalent to go-libp2p-kbucket's
/// `RoutingTable`.
class RoutingTable {
  /// Creates a routing table for [local], with up to [bucketSize] peers
  /// per bucket, rejecting peers whose [metrics] latency exceeds
  /// [maxLatency].
  RoutingTable({
    required this.bucketSize,
    required this.local,
    required this.maxLatency,
    required this.metrics,
    required this.usefulnessGracePeriod,
    this.diversityFilter,
  }) : _buckets = [Bucket()];

  /// The maximum number of peers per bucket.
  final int bucketSize;

  /// The local peer's ID.
  final PeerId local;

  /// The maximum acceptable latency for peers in this table.
  final Duration maxLatency;

  /// Latency metrics used to decide whether to accept a peer.
  final PeerMetrics metrics;

  /// The maximum grace period given to a peer to become useful before it's
  /// eligible for eviction to make room for a new peer.
  final Duration usefulnessGracePeriod;

  /// Optional IP/ASN diversity filter -- see this file's header comment.
  final DiversityFilter? diversityFilter;

  /// Called whenever a peer is removed from the table.
  void Function(PeerId id) onPeerRemoved = (_) {};

  /// Called whenever a peer is added to the table.
  void Function(PeerId id) onPeerAdded = (_) {};

  final List<Bucket> _buckets;
  final Map<int, DateTime> _cplRefreshedAt = {};

  DhtId get _localId => convertPeerId(local);

  /// Shuts down the routing table. This port owns no background process, so
  /// the faithful idempotent close operation is a no-op.
  void close() {}

  /// The Cpls this table is tracking for refresh, indexed by Cpl. Exposed
  /// (rather than kept private) so the `table_refresh.dart` extension can
  /// reach it -- Dart extensions can't access another library's private
  /// members, unlike Go's same-package multiple files.
  Map<int, DateTime> get cplRefreshedAt => _cplRefreshedAt;

  /// The number of peers we have for a given common-prefix-length.
  /// Equivalent to go-libp2p-kbucket's `RoutingTable.NPeersForCpl`.
  int nPeersForCpl(int cpl) {
    if (cpl >= _buckets.length - 1) {
      final bucket = _buckets.last;
      var count = 0;
      for (final p in bucket.peers()) {
        if (commonPrefixLen(_localId, p.dhtId) == cpl) count++;
      }
      return count;
    }
    return _buckets[cpl].length;
  }

  /// Whether [id] would be a good fit for this table: it isn't already
  /// present, its bucket isn't full, its bucket has replaceable peers, or
  /// it's the last bucket and adding it would trigger a split. Equivalent
  /// to go-libp2p-kbucket's `RoutingTable.UsefulNewPeer`.
  bool usefulNewPeer(PeerId id) {
    final bucketId = _bucketIdForPeer(id);
    final bucket = _buckets[bucketId];

    if (bucket.getPeer(id) != null) return false;
    if (bucket.length < bucketSize) return true;

    for (final p in bucket.peers()) {
      if (p.replaceable) return true;
    }

    if (bucketId == _buckets.length - 1) {
      final cpl = commonPrefixLen(_localId, convertPeerId(id));
      for (final p in bucket.peers()) {
        if (commonPrefixLen(_localId, p.dhtId) != cpl) return true;
      }
    }

    return false;
  }

  /// Tries to add [id] to the table. Returns `true` if newly added,
  /// `false` if it already existed (never throws in that case). Throws
  /// [PeerRejectedHighLatencyException] or
  /// [PeerRejectedNoCapacityException] if it couldn't be added. Equivalent
  /// to go-libp2p-kbucket's `RoutingTable.TryAddPeer`.
  bool tryAddPeer(
    PeerId id, {
    required bool queryPeer,
    required bool isReplaceable,
  }) {
    final bucketId = _bucketIdForPeer(id);
    var bucket = _buckets[bucketId];

    final now = DateTime.now().toUtc();
    final lastUsefulAt = queryPeer ? now : null;

    final existing = bucket.getPeer(id);
    if (existing != null) {
      if (existing.lastUsefulAtIsZero && queryPeer && lastUsefulAt != null) {
        existing.lastUsefulAt = lastUsefulAt;
      }
      return false;
    }

    if (metrics.latencyEwma(id) > maxLatency) {
      throw const PeerRejectedHighLatencyException();
    }

    final filter = diversityFilter;
    if (filter != null && !filter.tryAdd(id)) {
      throw ArgumentError('peer rejected by the diversity filter');
    }

    PeerInfo newPeerInfo() => PeerInfo(
      id: id,
      dhtId: convertPeerId(id),
      lastUsefulAt: lastUsefulAt,
      lastSuccessfulOutboundQueryAt: now,
      addedAt: now,
      replaceable: isReplaceable,
    );

    if (bucket.length < bucketSize) {
      bucket.pushFront(newPeerInfo());
      onPeerAdded(id);
      return true;
    }

    if (bucketId == _buckets.length - 1) {
      _nextBucket();
      final newBucketId = _bucketIdForPeer(id);
      bucket = _buckets[newBucketId];
      if (bucket.length < bucketSize) {
        bucket.pushFront(newPeerInfo());
        onPeerAdded(id);
        return true;
      }
    }

    final replaceablePeer = bucket.min((a, b) => a.replaceable);
    if (replaceablePeer != null && replaceablePeer.replaceable) {
      bucket.pushFront(newPeerInfo());
      onPeerAdded(id);
      _removePeer(replaceablePeer.id);
      return true;
    }

    diversityFilter?.remove(id);
    throw const PeerRejectedNoCapacityException();
  }

  /// Marks every peer in the table as irreplaceable. They can still be
  /// removed via [removePeer]. Equivalent to go-libp2p-kbucket's
  /// `RoutingTable.MarkAllPeersIrreplaceable`.
  void markAllPeersIrreplaceable() {
    for (final b in _buckets) {
      b.updateAllWith((p) => p.replaceable = false);
    }
  }

  /// All peer info stored in this table. Equivalent to
  /// go-libp2p-kbucket's `RoutingTable.GetPeerInfos`.
  List<PeerInfo> getPeerInfos() => [for (final b in _buckets) ...b.peers()];

  /// Updates a peer's last-successful-outbound-query time. Returns `true`
  /// if the peer was found. Equivalent to go-libp2p-kbucket's
  /// `RoutingTable.UpdateLastSuccessfulOutboundQueryAt`.
  bool updateLastSuccessfulOutboundQueryAt(PeerId id, DateTime t) {
    final bucket = _buckets[_bucketIdForPeer(id)];
    final p = bucket.getPeer(id);
    if (p == null) return false;
    p.lastSuccessfulOutboundQueryAt = t;
    return true;
  }

  /// Updates a peer's last-useful time. Returns `true` if the peer was
  /// found. Equivalent to go-libp2p-kbucket's
  /// `RoutingTable.UpdateLastUsefulAt`.
  bool updateLastUsefulAt(PeerId id, DateTime t) {
    final bucket = _buckets[_bucketIdForPeer(id)];
    final p = bucket.getPeer(id);
    if (p == null) return false;
    p.lastUsefulAt = t;
    return true;
  }

  /// Evicts [id] from the table. Equivalent to go-libp2p-kbucket's
  /// `RoutingTable.RemovePeer`.
  void removePeer(PeerId id) => _removePeer(id);

  bool _removePeer(PeerId id) {
    final bucketId = _bucketIdForPeer(id);
    final bucket = _buckets[bucketId];
    if (!bucket.remove(id)) return false;

    diversityFilter?.remove(id);

    while (true) {
      final lastIndex = _buckets.length - 1;
      if (_buckets.length > 1 && _buckets[lastIndex].length == 0) {
        _buckets.removeAt(lastIndex);
      } else if (_buckets.length >= 2 && _buckets[lastIndex - 1].length == 0) {
        _buckets[lastIndex - 1] = _buckets[lastIndex];
        _buckets.removeAt(lastIndex);
      } else {
        break;
      }
    }

    onPeerRemoved(id);
    return true;
  }

  void _nextBucket() {
    final bucket = _buckets.last;
    final newBucket = bucket.split(_buckets.length - 1, _localId);
    _buckets.add(newBucket);
    if (newBucket.length >= bucketSize) _nextBucket();
  }

  /// Finds [id] in the table, or returns `null` if it isn't present.
  /// Equivalent to go-libp2p-kbucket's `RoutingTable.Find`.
  PeerId? find(PeerId id) {
    final found = nearestPeers(convertPeerId(id), 1);
    if (found.isEmpty || found.first != id) return null;
    return found.first;
  }

  /// The single peer nearest to [id], or `null` if the table is empty.
  /// Equivalent to go-libp2p-kbucket's `RoutingTable.NearestPeer`.
  PeerId? nearestPeer(DhtId id) {
    final peers = nearestPeers(id, 1);
    return peers.isEmpty ? null : peers.first;
  }

  /// The [count] peers nearest to [id]. Equivalent to go-libp2p-kbucket's
  /// `RoutingTable.NearestPeers`.
  List<PeerId> nearestPeers(DhtId id, int count) {
    var cpl = commonPrefixLen(id, _localId);
    if (cpl >= _buckets.length) cpl = _buckets.length - 1;

    final sorter = PeerDistanceSorter(id);
    sorter.appendPeersFromBucket(_buckets[cpl]);

    if (sorter.length < count) {
      for (var i = cpl + 1; i < _buckets.length; i++) {
        sorter.appendPeersFromBucket(_buckets[i]);
      }
    }
    for (var i = cpl - 1; i >= 0 && sorter.length < count; i--) {
      sorter.appendPeersFromBucket(_buckets[i]);
    }

    sorter.sort();
    final peers = sorter.peers;
    return count < peers.length ? peers.sublist(0, count) : peers;
  }

  /// The total number of peers in this table. Equivalent to
  /// go-libp2p-kbucket's `RoutingTable.Size`.
  int size() {
    var total = 0;
    for (final b in _buckets) {
      total += b.length;
    }
    return total;
  }

  /// All peer IDs in this table. Equivalent to go-libp2p-kbucket's
  /// `RoutingTable.ListPeers`.
  List<PeerId> listPeers() => [for (final b in _buckets) ...b.peerIds()];

  /// The bucket index for the given [id] under this table's current
  /// structure.
  int _bucketIdForPeer(PeerId id) {
    final cpl = commonPrefixLen(convertPeerId(id), _localId);
    return cpl >= _buckets.length ? _buckets.length - 1 : cpl;
  }

  /// The maximum common-prefix-length between any peer in the table and
  /// the local peer. Equivalent to go-libp2p-kbucket's
  /// `RoutingTable.maxCommonPrefix`.
  int maxCommonPrefix() {
    for (var i = _buckets.length - 1; i >= 0; i--) {
      if (_buckets[i].length > 0) return _buckets[i].maxCommonPrefix(_localId);
    }
    return 0;
  }
}
