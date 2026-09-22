import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_kbucket/transpiled_libp2p_kbucket.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import 'dht_message.dart';
import 'query_peerset.dart';

/// Kademlia DHT protocol identifier.
const String dhtProtocol = '/ipfs/kad/1.0.0';

/// LAN-scoped Kademlia DHT protocol identifier.
const String lanDhtProtocol = '/ipfs/lan/kad/1.0.0';

/// Protocols offered when opening a DHT stream, WAN first then LAN.
const List<String> _kadProtocols = [dhtProtocol, lanDhtProtocol];

/// Adapts go-libp2p's `peerstore.Metrics` (already implemented by
/// [Host.peerstore]) to go-libp2p-kbucket's narrower `PeerMetrics`, which
/// only depends on the `LatencyEWMA` reader. Equivalent to how go-libp2p's
/// `kb.NewRoutingTable` is constructed directly with `dht.host.Peerstore()`.
final class _PeerstoreLatencyMetrics implements PeerMetrics {
  const _PeerstoreLatencyMetrics(this._metrics);
  final Metrics _metrics;
  @override
  Duration latencyEwma(PeerId id) => _metrics.latencyEwma(id);
}

/// Queries the Kademlia DHT for providers of a Cid.
final class DhtClient implements ContentDiscovery {
  /// Creates a DHT provider finder using [host] and [bootstrapPeers], with
  /// a live Kademlia [routingTable] seeded and refreshed as lookups run.
  factory DhtClient({
    required Host host,
    required List<AddrInfo> bootstrapPeers,
    Duration timeout = const Duration(seconds: 10),
    Duration lookupTimeout = const Duration(minutes: 1),
    int alpha = 3,
    int beta = 3,
    int bucketSize = 20,
    Duration maxLatency = const Duration(minutes: 1),
    Duration refreshInterval = const Duration(minutes: 10),
  }) {
    final routingTable = RoutingTable(
      bucketSize: bucketSize,
      local: host.id,
      maxLatency: maxLatency,
      metrics: _PeerstoreLatencyMetrics(host.peerstore),
      usefulnessGracePeriod: _usefulnessGracePeriod(
        alpha,
        bucketSize,
        refreshInterval,
      ),
    );
    return DhtClient._(
      host: host,
      bootstrapPeers: bootstrapPeers,
      timeout: timeout,
      lookupTimeout: lookupTimeout,
      alpha: alpha,
      beta: beta,
      bucketSize: bucketSize,
      routingTable: routingTable,
      refreshInterval: refreshInterval,
    );
  }

  DhtClient._({
    required this.host,
    required this.bootstrapPeers,
    required this.timeout,
    required this.lookupTimeout,
    required this.alpha,
    required this.beta,
    required this.bucketSize,
    required this.routingTable,
    required Duration refreshInterval,
  }) : _refreshInterval = refreshInterval;

  /// Starts the periodic Kademlia bucket refresh and runs the first one.
  ///
  /// Equivalent to go-libp2p-kad-dht's `IpfsDHT.Bootstrap` plus the refresh
  /// loop that `New` starts. Go's `New` takes a `context.Context` and owns
  /// the goroutines it spawns, so construction and start are one step there;
  /// a Dart constructor has no such handle, and starting network I/O from one
  /// would make every `DhtClient` dial on construction and leave the caller
  /// no way to opt out. Splitting it follows the pattern this codebase
  /// already uses for `BitswapClient.start` and `DhtServer.start`.
  ///
  /// Calling it more than once is a no-op, and [close] stops it.
  void bootstrap() {
    if (_closed || _refreshTimer != null) return;
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(_refresh());
    });
    unawaited(_refresh());
  }

  /// Router used to query DHT peers.
  /// Host used to reach peers and their addresses.
  ///
  /// Go: `IpfsDHT.host` (`dht.go:105`), which the upstream holds directly
  /// rather than behind an adapter.
  final Host host;

  /// Initial peers from which provider lookup begins, used only as a
  /// fallback when [routingTable] doesn't yet hold peers closer to a key.
  final List<AddrInfo> bootstrapPeers;

  /// Maximum time allowed for each individual DHT RPC query.
  final Duration timeout;

  /// Maximum time allowed for the entire lookup operation.
  final Duration lookupTimeout;

  /// Concurrency factor (alpha), default 3.
  final int alpha;

  /// Concurrency termination threshold (beta), default 3.
  final int beta;

  /// Kademlia bucket size (K), default 20.
  final int bucketSize;

  /// Live Kademlia routing table, populated by successful lookups and
  /// periodically refreshed. Equivalent to go-libp2p-kad-dht's
  /// `IpfsDHT.routingTable` / `RoutingTable()`.
  final RoutingTable routingTable;

  final Duration _refreshInterval;
  Timer? _refreshTimer;
  bool _closed = false;
  final Set<NetworkStream> _activeStreams = {};

  /// Closes the DHT client, aborting in-flight queries and resetting streams.
  Future<void> close() async {
    _closed = true;
    _refreshTimer?.cancel();
    routingTable.close();
    for (final stream in _activeStreams.toList()) {
      try {
        await stream.reset();
      } catch (_) {}
    }
    _activeStreams.clear();
  }

  @override
  /// Finds up to [count] providers for [cid]. A non-positive count streams all
  /// providers discovered by the lookup.
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) {
    if (count < 0) throw RangeError.value(count, 'count');
    if (_closed) throw StateError('DhtClient is closed');
    late StreamController<AddrInfo> controller;
    var cancelled = false;
    controller = StreamController<AddrInfo>(
      onListen: () =>
          _lookup(cid, count, controller, () => cancelled || _closed),
      onCancel: () => cancelled = true,
    );
    return controller.stream;
  }

  /// Announces [provider] as a provider of [cid] via DHT ADD_PROVIDER, sending
  /// the record to the [bucketSize] peers closest to the CID multihash.
  Future<void> provide(Cid cid, AddrInfo provider) async {
    if (_closed) throw StateError('DhtClient is closed');
    final key = Uint8List.fromList(cid.multihash.toBytes());

    final candidates = <AddrInfo>[];
    for (final peerId in await getClosestPeers(key)) {
      if (peerId == provider.id) continue;
      candidates.add(AddrInfo(id: peerId, addrs: _addrsFor(host, peerId)));
    }

    // The walk reached nobody: fall back to announcing to the bootstrap set.
    if (candidates.isEmpty) {
      for (final p in bootstrapPeers) {
        if (p.id != provider.id && !candidates.any((c) => c.id == p.id)) {
          candidates.add(p);
        }
      }
    }
    if (candidates.isEmpty) return;

    final msgBytes = encodeAddProvider(cid, provider);
    await Future.wait(
      candidates.map((peer) => _sendAddProvider(peer, msgBytes)),
    );
  }

  /// Returns the [bucketSize] peers closest to [key] in the XOR keyspace,
  /// found by walking the DHT iteratively.
  Future<List<PeerId>> getClosestPeers(Uint8List key) async {
    if (_closed) throw StateError('DhtClient is closed');
    final peers = await _walk(
      key: key,
      request: encodeFindNode(key),
      isCancelled: () => _closed,
    );
    final result = peers.getClosestNInStates(bucketSize, {PeerState.queried});
    // Reset the refresh timer for this key's bucket since we've just
    // successfully interacted with the closest peers to it. Equivalent to
    // go-libp2p-kad-dht's `IpfsDHT.GetClosestPeers`.
    routingTable.resetCplRefreshedAtForId(
      Uint8List.fromList(sha256.convert(key).bytes),
      DateTime.now().toUtc(),
    );
    return result;
  }

  /// Periodic Kademlia routing-table refresh: queries for self, then for
  /// each tracked Cpl whose bucket hasn't been refreshed within
  /// [_refreshInterval], queries a random key of that Cpl. Equivalent to
  /// go-libp2p-kad-dht/rtrefresh's `RtRefreshManager.doRefresh` (minus its
  /// ping-and-evict pass over stale peers -- see PROGRESS.md).
  Future<void> _refresh() async {
    if (_closed) return;
    try {
      await getClosestPeers(Uint8List.fromList(host.id.value));
    } catch (_) {}
    if (_closed) return;

    final refreshedAt = routingTable.getTrackedCplsForRefresh();
    for (var cpl = 0; cpl < refreshedAt.length; cpl++) {
      if (_closed) return;
      if (DateTime.now().toUtc().difference(refreshedAt[cpl]) <=
          _refreshInterval) {
        continue;
      }
      try {
        await getClosestPeers(routingTable.genRandPeerId(cpl));
      } catch (_) {}
    }
  }

  static Duration _usefulnessGracePeriod(
    int alpha,
    int bucketSize,
    Duration refreshInterval,
  ) {
    // The threshold is the expected time before a refresh cycle would query
    // a peer again; go-libp2p-kad-dht uses twice that to keep older peers
    // around longer. Equivalent to `dht.go`'s
    // `maxLastSuccessfulOutboundThreshold` computation.
    if (alpha >= bucketSize) return refreshInterval * 2;
    final l1 = math.log(1 / bucketSize);
    final l2 = math.log(1 - (alpha / bucketSize));
    final thresholdMs = (l1 / l2) * refreshInterval.inMilliseconds;
    return Duration(milliseconds: (2 * thresholdMs).round());
  }

  Future<void> _sendAddProvider(AddrInfo peer, Uint8List msgBytes) async {
    NetworkStream? stream;
    try {
      // A dial that fails *after* the timeout has already fired would
      // otherwise surface as an unhandled async error and take the process
      // down; the handler below absorbs only that late failure.
      final pending = _connect(host, peer);
      unawaited(pending.catchError((Object _) {}));
      await pending.timeout(timeout);
      stream = await host.newStream(peer.id, _kadProtocols).timeout(timeout);
      _activeStreams.add(stream);
      await stream.setWriteDeadline(DateTime.now().add(timeout));
      await stream.write(msgBytes).timeout(timeout);
      await stream.close();
    } catch (_) {
      try {
        await stream?.reset();
      } catch (_) {}
    } finally {
      if (stream != null) _activeStreams.remove(stream);
    }
  }

  Future<void> _lookup(
    Cid cid,
    int count,
    StreamController<AddrInfo> output,
    bool Function() isCancelled,
  ) async {
    final emitted = <PeerId, AddrInfo>{};
    Object? lastError;
    try {
      await _walk(
        key: Uint8List.fromList(cid.multihash.toBytes()),
        request: encodeGetProviders(cid),
        isCancelled: isCancelled,
        stop: () => count > 0 && emitted.length >= count,
        onError: (error) => lastError = error,
        onProvider: (provider) {
          final prev = emitted[provider.id];
          if (prev == null ||
              (prev.addrs.isEmpty && provider.addrs.isNotEmpty)) {
            emitted[provider.id] = provider;
            output.add(provider);
          }
        },
      );

      if (emitted.isEmpty && lastError != null && !isCancelled()) {
        output.addError(lastError!);
      }
    } finally {
      await output.close();
    }
  }

  /// Runs one iterative Kademlia walk towards [key], sending [request] to each
  /// peer visited, and returns the resulting peerset.
  Future<QueryPeerset> _walk({
    required Uint8List key,
    required Uint8List request,
    required bool Function() isCancelled,
    bool Function()? stop,
    void Function(AddrInfo provider)? onProvider,
    void Function(Object error)? onError,
  }) async {
    int compareDistance(PeerId target, PeerId a, PeerId b) =>
        _distance(target.value, a).compareTo(_distance(target.value, b));

    final queryPeers = QueryPeerset(PeerId(value: key), compareDistance);
    final knownPeers = <PeerId, AddrInfo>{};
    final deadline = DateTime.now().add(lookupTimeout);
    final selfId = host.id;

    // Seed the frontier from the live routing table first: successive
    // lookups no longer restart from bootstrapPeers once the table holds
    // reachable peers close to this key. Falls back to bootstrapPeers only
    // when the table is still empty or yields nobody with a known address.
    final keyDhtId = Uint8List.fromList(sha256.convert(key).bytes);
    var seededFromTable = 0;
    for (final id in routingTable.nearestPeers(keyDhtId, bucketSize)) {
      if (id == selfId) continue;
      final addrs = _addrsFor(host, id);
      if (addrs.isEmpty) continue;
      knownPeers[id] = AddrInfo(id: id, addrs: addrs);
      queryPeers.tryAdd(id, selfId);
      seededFromTable++;
    }
    if (seededFromTable == 0) {
      for (final p in bootstrapPeers) {
        if (p.id == selfId) continue;
        knownPeers[p.id] = p;
        queryPeers.tryAdd(p.id, selfId);
      }
    }

    bool isStopped() => stop != null && stop();

    // Admits a peer that just answered a DHT query correctly into the live
    // routing table. Equivalent evidence to go-libp2p-kad-dht's separate
    // `lookupCheck` liveness probe (a FIND_NODE asking the peer for its own
    // ID) -- see PROGRESS.md for the documented divergence: this port folds
    // that verification into the walk itself instead of a dedicated
    // probing subsystem.
    void admitQueried(PeerId id) {
      if (id == selfId) return;
      try {
        routingTable.tryAddPeer(id, queryPeer: true, isReplaceable: false);
      } on PeerRejectedHighLatencyException {
        // Normal: too slow to route through, not a fatal error.
      } on PeerRejectedNoCapacityException {
        // Normal: bucket full of live, non-replaceable peers.
      }
    }

    // Admits a peer only heard about (via a response's closerPeers) as a
    // replaceable candidate, never having been queried directly.
    void admitHeard(PeerId id) {
      if (id == selfId) return;
      try {
        routingTable.tryAddPeer(id, queryPeer: false, isReplaceable: true);
      } on PeerRejectedHighLatencyException {
        // Ignored: heard peer did not meet latency threshold.
      } on PeerRejectedNoCapacityException {
        // Ignored: bucket full and candidate is replaceable.
      }
    }

    // Persists every peer the response carries and feeds the walk frontier.
    Future<void> absorb(PeerId from, DhtResponse response) async {
      for (final peer in response.closerPeers.take(2 * bucketSize)) {
        if (peer.id == selfId) continue;
        final merged = await _mergeWithPeerstore(knownPeers[peer.id], peer);
        knownPeers[peer.id] = merged;
        if (merged.addrs.isNotEmpty) {
          _maybeAddAddrs(host, merged, tempAddrTtl);
        }
        admitHeard(peer.id);
        queryPeers.tryAdd(peer.id, from);
      }

      for (final provider in response.providerPeers) {
        if (provider.id == selfId) continue;
        final complete = await _mergeWithPeerstore(
          knownPeers[provider.id],
          provider,
        );
        knownPeers[provider.id] = complete;
        if (complete.addrs.isNotEmpty) {
          _maybeAddAddrs(host, complete, tempAddrTtl);
        }
        onProvider?.call(complete);
      }
    }

    while (!isCancelled() && !isStopped()) {
      if (DateTime.now().isAfter(deadline)) break;

      // Termination condition: the closest beta peers are all queried.
      final closestBeta = queryPeers.getClosestNInStates(beta, {
        PeerState.heard,
        PeerState.waiting,
        PeerState.queried,
      });
      if (closestBeta.length >= beta &&
          closestBeta.every(
            (p) => queryPeers.getState(p) == PeerState.queried,
          )) {
        break;
      }

      // Starvation: nothing left to query, and queries are awaited in batch.
      final batch = queryPeers.getClosestNInStates(alpha, {PeerState.heard});
      if (batch.isEmpty) break;

      for (final p in batch) {
        queryPeers.setState(p, PeerState.waiting);
      }

      final responses = await Future.wait([
        for (final peerId in batch)
          _safeQuery(knownPeers[peerId]!, request, isCancelled, deadline),
      ]);

      for (var i = 0; i < batch.length; i++) {
        final peerId = batch[i];
        final response = responses[i].response;
        if (response == null) {
          queryPeers.setState(peerId, PeerState.unreachable);
          routingTable.removePeer(peerId);
          final error = responses[i].error;
          if (error != null) onError?.call(error);
          continue;
        }
        queryPeers.setState(peerId, PeerState.queried);
        admitQueried(peerId);
        if (isCancelled()) break;
        await absorb(peerId, response);
        if (isStopped()) return queryPeers;
      }
    }

    // Kademlia follow-up: query the peers still unqueried inside the top K.
    if (!isCancelled() && !isStopped() && !DateTime.now().isAfter(deadline)) {
      final topK = queryPeers.getClosestNInStates(bucketSize, {
        PeerState.heard,
        PeerState.waiting,
        PeerState.queried,
      });
      final followUpPeers = topK
          .where((p) => queryPeers.getState(p) == PeerState.heard)
          .toList();

      for (final peerId in followUpPeers) {
        if (isCancelled() || isStopped() || DateTime.now().isAfter(deadline)) {
          break;
        }
        queryPeers.setState(peerId, PeerState.waiting);
        final result = await _safeQuery(
          knownPeers[peerId]!,
          request,
          isCancelled,
          deadline,
        );
        final response = result.response;
        if (response == null) {
          queryPeers.setState(peerId, PeerState.unreachable);
          routingTable.removePeer(peerId);
          final error = result.error;
          if (error != null) onError?.call(error);
          continue;
        }
        queryPeers.setState(peerId, PeerState.queried);
        admitQueried(peerId);
        await absorb(peerId, response);
      }
    }

    return queryPeers;
  }

  Future<AddrInfo> _mergeWithPeerstore(
    AddrInfo? known,
    AddrInfo received,
  ) async {
    final fromPeerstore = _addrsFor(host, received.id);
    final allAddrs = <Multiaddr>{
      ...?known?.addrs,
      ...fromPeerstore,
      ...received.addrs,
    };
    return AddrInfo(id: received.id, addrs: allAddrs.toList());
  }

  Future<DhtResponse> _query(
    AddrInfo peer,
    Uint8List request,
    bool Function() isCancelled,
    DateTime deadline,
  ) async {
    if (isCancelled()) throw StateError('DHT query cancelled');
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) {
      throw TimeoutException('DHT query deadline exceeded');
    }
    final rpcTimeout = timeout < remaining ? timeout : remaining;

    // See the note above: absorb a dial failure arriving after the timeout.
    final pending = _connect(host, peer);
    unawaited(pending.catchError((Object _) {}));
    await pending.timeout(rpcTimeout);
    if (isCancelled()) throw StateError('DHT query cancelled');

    final stream = await host
        .newStream(peer.id, _kadProtocols)
        .timeout(rpcTimeout);

    _activeStreams.add(stream);
    try {
      if (isCancelled()) {
        await stream.reset();
        throw StateError('DHT query cancelled');
      }
      await stream.setDeadline(DateTime.now().add(rpcTimeout));
      await stream.write(request).timeout(rpcTimeout);
      final bytes = await readDhtFrame(stream).timeout(rpcTimeout);
      return DhtResponse.fromBytes(bytes);
    } catch (e) {
      try {
        await stream.reset();
      } catch (_) {}
      rethrow;
    } finally {
      _activeStreams.remove(stream);
      try {
        await stream.close();
      } catch (_) {}
    }
  }

  Future<({DhtResponse? response, Object? error})> _safeQuery(
    AddrInfo peer,
    Uint8List request,
    bool Function() isCancelled,
    DateTime deadline,
  ) async {
    try {
      return (
        response: await _query(peer, request, isCancelled, deadline),
        error: null,
      );
    } catch (error) {
      return (response: null, error: error);
    }
  }
}

BigInt _distance(Uint8List target, PeerId peer) {
  final a = sha256.convert(target).bytes;
  final b = sha256.convert(peer.value).bytes;
  var result = BigInt.zero;
  for (var i = 0; i < a.length; i++) {
    result = (result << 8) | BigInt.from(a[i] ^ b[i]);
  }
  return result;
}

/// Addresses the peerstore holds for [id], or empty when it has none.
///
/// Go inlines `dht.host.Peerstore().Addrs(p)` at the call sites
/// (`handlers.go:80-96`); this port keeps the guard the previous
/// `Libp2pRouter` adapter had.
List<Multiaddr> _addrsFor(Host host, PeerId id) {
  try {
    return host.peerstore.addrs(id);
  } catch (_) {
    return const [];
  }
}

/// Records [peer]'s addresses and dials it.
///
/// Go: `dht.host.Connect` after `maybeAddAddrs` (`dht.go:958-964`).
Future<void> _connect(Host host, AddrInfo peer) async {
  host.peerstore.addAddrs(peer.id, peer.addrs, const Duration(minutes: 2));
  await host.connect(peer);
}

/// Adds [peer]'s addresses to the peerstore with [ttl], skipping ourselves.
///
/// Go: `maybeAddAddrs` (`dht.go:958-964`). Two upstream guards are **not**
/// ported yet and are recorded in `doc/transpilation/PROGRESS.md`: skipping
/// peers we are already connected to (`hasValidConnectedness`, "we have
/// better ones") and `dht.filterAddrs`.
void _maybeAddAddrs(Host host, AddrInfo peer, Duration ttl) {
  if (peer.addrs.isEmpty) return;
  if (peer.id == host.id) return;
  host.peerstore.addAddrs(peer.id, peer.addrs, ttl);
}
