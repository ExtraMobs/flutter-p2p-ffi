import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_kbucket/transpiled_libp2p_kbucket.dart';

import '../../network/libp2p_host.dart';
import '../../routing/dht_provider_finder.dart'
    show dhtProtocol, lanDhtProtocol;
import 'dht_message.dart';
import 'dht_provider_manager.dart';

/// Serves the Kademlia DHT protocol (`/ipfs/kad/1.0.0` and
/// `/ipfs/lan/kad/1.0.0`), answering `FIND_NODE`, `GET_PROVIDERS`,
/// `ADD_PROVIDER` and `PING` from [routingTable] and [providerStore].
///
/// go-libp2p-kad-dht doesn't split client and server into separate Go types
/// (both live on `IpfsDHT`); this port keeps the split this codebase already
/// established with [DhtClient] (see PROGRESS.md), so `DhtServer` covers
/// `handlers.go` and the response-writing half of `dht_net.go`.
final class DhtServer {
  /// Creates a server answering DHT requests over [router] from
  /// [routingTable], storing `ADD_PROVIDER` records in [providerStore].
  DhtServer({
    required this.router,
    required this.routingTable,
    this.bucketSize = 20,
    ProviderManager? providerStore,
  }) : providerStore = providerStore ?? ProviderManager();

  /// Router used to reach the local host and its peerstore.
  final Libp2pRouter router;

  /// Live routing table queried to answer FIND_NODE / GET_PROVIDERS.
  final RoutingTable routingTable;

  /// Kademlia bucket size (K), default 20.
  final int bucketSize;

  /// Provider records received via ADD_PROVIDER, served by GET_PROVIDERS.
  final ProviderManager providerStore;

  /// Registers the inbound DHT stream handlers for the WAN and LAN protocol
  /// IDs. Equivalent to go-libp2p-kad-dht's `moveToServerMode`, minus the
  /// client/server mode toggle: this node always serves once online (see
  /// PROGRESS.md).
  void start() {
    for (final proto in const [dhtProtocol, lanDhtProtocol]) {
      router.host.setStreamHandler(proto, (stream) => _handleStream(stream));
    }
  }

  Future<void> _handleStream(NetworkStream stream) async {
    PeerId? from;
    try {
      final conn = stream.conn();
      if (conn case final ConnSecurity sec) {
        from = sec.remotePeer();
      }
    } catch (_) {}
    if (from == null) {
      try {
        await stream.reset();
      } catch (_) {}
      return;
    }

    // Mirrors go-libp2p-kad-dht's handleNewMessage: a stream may carry
    // several requests before the remote closes it.
    var resetOnExit = false;
    try {
      while (!stream.isClosed) {
        final Uint8List frameBytes;
        try {
          frameBytes = await readDhtFrame(stream);
        } on FormatException {
          // Clean or unexpected EOF ends the read loop. This port doesn't
          // distinguish the two (unlike Go's io.EOF-vs-other-error split),
          // so both close gracefully rather than reset -- a hardened
          // version would reset specifically on a frame truncated mid-read.
          break;
        }
        final request = DhtRequest.fromBytes(frameBytes);
        final response = await _dispatch(from, request);
        if (response != null) {
          await stream.write(frameDhtMessage(response));
        }
      }
    } catch (_) {
      resetOnExit = true;
    }
    try {
      if (resetOnExit) {
        await stream.reset();
      } else {
        await stream.close();
      }
    } catch (_) {}
  }

  Future<Uint8List?> _dispatch(PeerId from, DhtRequest request) async {
    switch (request.type) {
      case 4: // FIND_NODE
        return _handleFindNode(from, request);
      case 3: // GET_PROVIDERS
        return _handleGetProviders(from, request);
      case 2: // ADD_PROVIDER
        await _handleAddProvider(from, request);
        return null;
      case 5: // PING
        return encodeDhtResponse(
          type: request.type,
          key: request.key,
          clusterLevelRaw: request.clusterLevelRaw,
        );
      default:
        throw FormatException('unsupported DHT message type ${request.type}');
    }
  }

  /// Fields a FIND_NODE request. Equivalent to `handleFindPeer`
  /// (`handlers.go:133`): closestPeersToQuery -> closestPeersToQuery ->
  /// this._closestPeersToQuery (dht.go:759); peerstore.AddrInfos ->
  /// [Libp2pRouter.getAddrs] (go-libp2p's `peerstore`, transpiled_libp2p).
  Future<Uint8List> _handleFindNode(PeerId from, DhtRequest request) async {
    if (request.key.isEmpty) {
      throw const FormatException('handleFindPeer with empty key');
    }
    // Raw, non-validating cast -- matches Go's `peer.ID(pmes.GetKey())`,
    // which never fails since peer.ID is just a byte-string alias.
    final targetId = PeerId(value: request.key);

    var candidates = _closestPeersToQuery(request.key, from, bucketSize);
    // Per IPFS Kademlia DHT spec: FIND_PEER always includes the target
    // (self, requester or not, if known) at the front of the response.
    if (candidates.isEmpty || candidates.first != targetId) {
      candidates = [targetId, ...candidates];
    }

    final withAddrs = <AddrInfo>[];
    for (final id in candidates) {
      final addrs = await router.getAddrs(id);
      if (addrs.isNotEmpty) withAddrs.add(AddrInfo(id: id, addrs: addrs));
    }
    return encodeDhtResponse(
      type: request.type,
      clusterLevelRaw: request.clusterLevelRaw,
      closerPeers: withAddrs,
    );
  }

  /// Fields a GET_PROVIDERS request. Equivalent to `handleGetProviders`
  /// (`handlers.go:176`): closestPeersToQuery -> this._closestPeersToQuery
  /// (dht.go:759); `dht.providerStore.GetProviders` (records package, no
  /// dedicated packages/transpiled_* -- see PROGRESS.md) ->
  /// [ProviderManager.getProviders]; `appendFittingProviderPeers`
  /// (handlers.go:226) -> the budget loop below.
  Future<Uint8List> _handleGetProviders(PeerId from, DhtRequest request) async {
    if (request.key.length > 80) {
      throw const FormatException('handleGetProviders key size too large');
    }
    if (request.key.isEmpty) {
      throw const FormatException('handleGetProviders key is empty');
    }

    final closest = _closestPeersToQuery(request.key, from, bucketSize);
    final closerPeers = <AddrInfo>[];
    for (final id in closest) {
      closerPeers.add(AddrInfo(id: id, addrs: await router.getAddrs(id)));
    }

    final base = encodeDhtResponse(
      type: request.type,
      key: request.key,
      clusterLevelRaw: request.clusterLevelRaw,
      closerPeers: closerPeers,
    );
    var size = base.length;
    final fitting = <AddrInfo>[];
    for (final provider in providerStore.getProviders(request.key)) {
      final record = encodePeerRecord(id: provider.id, addrs: provider.addrs);
      // A repeated embedded message adds its tag (1 byte, field 9 fits in a
      // single-byte tag), a length prefix and its bytes.
      final contribution = 1 + _varintSize(record.length) + record.length;
      if (size + contribution > dhtMessageSizeMax) break;
      size += contribution;
      fitting.add(provider);
    }

    return encodeDhtResponse(
      type: request.type,
      key: request.key,
      clusterLevelRaw: request.clusterLevelRaw,
      closerPeers: closerPeers,
      providerPeers: fitting,
    );
  }

  /// Fields an ADD_PROVIDER request. Equivalent to `handleAddProvider`
  /// (`handlers.go:238`): `dht.providerStore.AddProvider` ->
  /// [ProviderManager.addProvider].
  Future<void> _handleAddProvider(PeerId from, DhtRequest request) async {
    if (request.key.length > 80) {
      throw const FormatException('handleAddProvider key size too large');
    }
    if (request.key.isEmpty) {
      throw const FormatException('handleAddProvider key is empty');
    }

    var success = false;
    for (final provider in request.providerPeers) {
      if (provider.id != from) {
        // Not from the originator -- ignore per spec (unsigned records).
        continue;
      }
      if (provider.addrs.isEmpty) continue;
      providerStore.addProvider(request.key, provider);
      success = true;
    }
    if (!success) {
      throw const FormatException('handleAddProvider no valid provider');
    }
  }

  /// The [count] peers from [routingTable] closest to raw [key], filtering
  /// out self and [from]. Equivalent to `closestPeersToQuery`
  /// (`dht.go:759`).
  List<PeerId> _closestPeersToQuery(Uint8List key, PeerId from, int count) {
    final target = Uint8List.fromList(sha256.convert(key).bytes);
    final nearest = routingTable.nearestPeers(target, count + 1);
    final selfId = router.host.id;
    final filtered = <PeerId>[];
    for (final p in nearest) {
      if (p == selfId) continue;
      if (p == from) continue;
      filtered.add(p);
      if (filtered.length >= count) break;
    }
    return filtered;
  }
}

int _varintSize(int value) {
  var v = value;
  var n = 1;
  while (v >= 0x80) {
    v >>= 7;
    n++;
  }
  return n;
}
