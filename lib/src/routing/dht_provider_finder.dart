import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../network/libp2p_host.dart';
import '../protocols/dht/dht_message.dart';
import '../protocols/dht/query_peerset.dart';

/// Kademlia DHT protocol identifier.
const String dhtProtocol = '/ipfs/kad/1.0.0';

/// Protocols offered when opening a DHT stream, WAN first then LAN.
const List<String> _kadProtocols = [dhtProtocol, '/ipfs/lan/kad/1.0.0'];

/// Queries the Kademlia DHT for providers of a Cid.
final class DhtClient implements ContentDiscovery {
  /// Creates a DHT provider finder using [router] and [bootstrapPeers].
  DhtClient({
    required this.router,
    required this.bootstrapPeers,
    this.timeout = const Duration(seconds: 10),
    this.lookupTimeout = const Duration(minutes: 1),
    this.alpha = 3,
    this.beta = 3,
    this.bucketSize = 20,
  });

  /// Router used to query DHT peers.
  final Libp2pRouter router;

  /// Initial peers from which provider lookup begins.
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

  bool _closed = false;
  final Set<NetworkStream> _activeStreams = {};

  /// Closes the DHT client, aborting in-flight queries and resetting streams.
  Future<void> close() async {
    _closed = true;
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
      onListen: () => _lookup(
        cid,
        count,
        controller,
        () => cancelled || _closed,
      ),
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
      candidates.add(AddrInfo(id: peerId, addrs: await router.getAddrs(peerId)));
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
    return peers.getClosestNInStates(bucketSize, {PeerState.queried});
  }

  Future<void> _sendAddProvider(AddrInfo peer, Uint8List msgBytes) async {
    NetworkStream? stream;
    try {
      await router.connect(peer).timeout(timeout);
      stream = await router.host.newStream(
        peer.id,
        _kadProtocols,
      ).timeout(timeout);
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
    final selfId = router.host.id;

    for (final p in bootstrapPeers) {
      if (p.id == selfId) continue;
      knownPeers[p.id] = p;
      queryPeers.tryAdd(p.id, selfId);
    }

    bool isStopped() => stop != null && stop();

    // Persists every peer the response carries and feeds the walk frontier.
    Future<void> absorb(PeerId from, DhtResponse response) async {
      for (final peer in response.closerPeers.take(2 * bucketSize)) {
        if (peer.id == selfId) continue;
        final merged = await _mergeWithPeerstore(knownPeers[peer.id], peer);
        knownPeers[peer.id] = merged;
        if (merged.addrs.isNotEmpty) {
          await router.addAddrs(merged, tempAddrTtl);
        }
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
          await router.addAddrs(complete, tempAddrTtl);
        }
        onProvider?.call(complete);
      }
    }

    while (!isCancelled() && !isStopped()) {
      if (DateTime.now().isAfter(deadline)) break;

      // Termination condition: the closest beta peers are all queried.
      final closestBeta = queryPeers.getClosestNInStates(
        beta,
        {PeerState.heard, PeerState.waiting, PeerState.queried},
      );
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
          final error = responses[i].error;
          if (error != null) onError?.call(error);
          continue;
        }
        queryPeers.setState(peerId, PeerState.queried);
        if (isCancelled()) break;
        await absorb(peerId, response);
        if (isStopped()) return queryPeers;
      }
    }

    // Kademlia follow-up: query the peers still unqueried inside the top K.
    if (!isCancelled() && !isStopped() && !DateTime.now().isAfter(deadline)) {
      final topK = queryPeers.getClosestNInStates(
        bucketSize,
        {PeerState.heard, PeerState.waiting, PeerState.queried},
      );
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
          final error = result.error;
          if (error != null) onError?.call(error);
          continue;
        }
        queryPeers.setState(peerId, PeerState.queried);
        await absorb(peerId, response);
      }
    }

    return queryPeers;
  }

  Future<AddrInfo> _mergeWithPeerstore(
    AddrInfo? known,
    AddrInfo received,
  ) async {
    final fromPeerstore = await router.getAddrs(received.id);
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

    await router.connect(peer).timeout(rpcTimeout);
    if (isCancelled()) throw StateError('DHT query cancelled');

    final stream = await router.host.newStream(
      peer.id,
      _kadProtocols,
    ).timeout(rpcTimeout);

    _activeStreams.add(stream);
    try {
      if (isCancelled()) {
        await stream.reset();
        throw StateError('DHT query cancelled');
      }
      await stream.setDeadline(DateTime.now().add(rpcTimeout));
      await stream.write(request).timeout(rpcTimeout);
      final bytes = await _readFrame(stream).timeout(rpcTimeout);
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

Future<Uint8List> _readFrame(NetworkStream stream) async {
  var length = 0;
  var shift = 0;
  for (var i = 0; i < 10; i++) {
    final byte = await stream.read(1);
    if (byte.isEmpty) {
      throw const FormatException('Unexpected EOF in DHT frame');
    }
    length |= (byte.first & 0x7f) << shift;
    if (byte.first & 0x80 == 0) {
      if (length > dhtMessageSizeMax) {
        throw const FormatException('DHT message exceeds 4 MiB');
      }
      final out = BytesBuilder(copy: false);
      while (out.length < length) {
        final chunk = await stream.read(length - out.length);
        if (chunk.isEmpty) {
          throw const FormatException('Unexpected EOF in DHT frame');
        }
        out.add(chunk);
      }
      return out.takeBytes();
    }
    shift += 7;
  }
  throw const FormatException('DHT frame varint is too long');
}
