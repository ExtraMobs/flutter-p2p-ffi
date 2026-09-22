import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_kbucket/transpiled_libp2p_kbucket.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import 'dht_message.dart';
import 'dht_provider_finder.dart' show dhtProtocol, lanDhtProtocol;
import 'dht_provider_manager.dart';

/// How long an inbound DHT stream may sit idle before it is reset.
///
/// Go: `dhtStreamIdleTimeout` (`go-libp2p-kad-dht/dht_net.go:20`), armed as a
/// `time.AfterFunc` for the life of the stream and pushed forward after every
/// message (`:43`, `:96`). Without it a peer can open a stream, send nothing,
/// and hold the resources behind it indefinitely -- which on a public DHT is
/// not a hypothetical.
const Duration dhtStreamIdleTimeout = Duration(minutes: 1);

/// What mode the DHT should operate in.
///
/// Go: `ModeOpt` (`go-libp2p-kad-dht/dht_options.go:26-37`). Kubo's default is
/// [auto], and that default is load control before any limit exists: a node
/// that is not publicly reachable never takes server traffic at all, which is
/// why most of the network never has to defend itself against it.
enum ModeOpt {
  /// Switches between client and server from `EvtLocalReachabilityChanged`.
  auto,

  /// Client only; never answers incoming queries.
  client,

  /// Server; answers incoming queries unconditionally.
  server,

  /// Like [auto], but serves while reachability is still unknown.
  autoServer,
}

/// Serves the Kademlia DHT protocol (`/ipfs/kad/1.0.0` and
/// `/ipfs/lan/kad/1.0.0`), answering `FIND_NODE`, `GET_PROVIDERS`,
/// `ADD_PROVIDER` and `PING` from [routingTable] and [providerStore].
///
/// go-libp2p-kad-dht doesn't split client and server into separate Go types
/// (both live on `IpfsDHT`); this port keeps the split this codebase already
/// established with [DhtClient] (see PROGRESS.md), so `DhtServer` covers
/// `handlers.go` and the response-writing half of `dht_net.go`.
final class DhtServer {
  /// Creates a server answering DHT requests over [host] from
  /// [routingTable], storing `ADD_PROVIDER` records in [providerStore].
  DhtServer({
    required this.host,
    required this.routingTable,
    this.bucketSize = 20,
    ProviderManager? providerStore,
    this.mode = ModeOpt.autoServer,
  }) : providerStore = providerStore ?? ProviderManager();

  /// Host used to reach peers and their addresses.
  ///
  /// Go: `IpfsDHT.host` (`dht.go:105`), held directly rather than behind an
  /// adapter.
  final Host host;

  /// Live routing table queried to answer FIND_NODE / GET_PROVIDERS.
  final RoutingTable routingTable;

  /// Kademlia bucket size (K), default 20.
  final int bucketSize;

  /// Provider records received via ADD_PROVIDER, served by GET_PROVIDERS.
  final ProviderManager providerStore;

  /// Whether this node serves DHT queries, and what decides it.
  ///
  /// Defaults to [ModeOpt.autoServer], **not** to Kubo's [ModeOpt.auto], and
  /// the difference is forced by a gap rather than chosen. Under
  /// [ModeOpt.auto] a node serves only once AutoNAT reports a public address;
  /// this port has no AutoNAT worth the name -- `p2p/host/autonat/autonat.dart`
  /// is a 69-line status holder against 1849 lines of protocol upstream,
  /// nothing probes a peer, and `setReachability` has no caller -- so
  /// reachability would stay `unknown` forever and the DHT would never serve.
  ///
  /// Under permanently unknown reachability Go's own semantics make
  /// [ModeOpt.autoServer] serve and [ModeOpt.auto] not
  /// (`subscriber_notifee.go:108-113`), so this default is exactly today's
  /// behaviour, expressed in upstream's vocabulary instead of hard-coded. The
  /// day AutoNAT is ported the node starts reacting on its own, and switching
  /// the default to [ModeOpt.auto] becomes a one-word change.
  final ModeOpt mode;

  /// Whether the server protocol handlers are registered right now.
  bool get isServing => _serving;

  bool _serving = false;
  Subscription? _reachability;
  StreamSubscription<Object>? _events;

  /// Brings the server up in the mode [mode] asks for.
  ///
  /// Go: `IpfsDHT` decides this at construction and then keeps it current from
  /// the event bus (`subscriber_notifee.go:32-76`). Reachability starts
  /// unknown, so [ModeOpt.auto] starts as a **client** and only begins serving
  /// once AutoNAT reports a public address -- which is the point. Answering
  /// `/ipfs/kad/1.0.0` makes the whole network dial this node continuously; a
  /// node that cannot be reached from outside has no business inviting that
  /// traffic, and a node that can needs the rest of the defences in place
  /// before it does.
  void start() {
    switch (mode) {
      case ModeOpt.client:
        return;
      case ModeOpt.server:
        _moveToServerMode();
      case ModeOpt.autoServer:
        _moveToServerMode();
        _watchReachability();
      case ModeOpt.auto:
        _watchReachability();
    }
  }

  /// Stops serving and releases the reachability subscription.
  Future<void> close() async {
    await _events?.cancel();
    _events = null;
    await _reachability?.close();
    _reachability = null;
    if (_serving) _moveToClientMode();
  }

  void _watchReachability() {
    final sub = host.eventBus.subscribe(EvtLocalReachabilityChanged);
    _reachability = sub;
    _events = sub.out().listen((event) {
      if (event is EvtLocalReachabilityChanged) {
        _handleLocalReachabilityChangedEvent(event);
      }
    });
  }

  /// Go: `handleLocalReachabilityChangedEvent`
  /// (`subscriber_notifee.go:102-126`).
  void _handleLocalReachabilityChangedEvent(EvtLocalReachabilityChanged e) {
    final target = switch (e.reachability) {
      Reachability.private_ => false,
      Reachability.unknown => mode == ModeOpt.autoServer,
      Reachability.public_ => true,
    };
    _setMode(serving: target);
  }

  /// Go: `setMode` (`dht.go:788-808`), which is a no-op when the mode already
  /// matches.
  void _setMode({required bool serving}) {
    if (serving == _serving) return;
    if (serving) {
      _moveToServerMode();
    } else {
      _moveToClientMode();
    }
  }

  /// Go: `moveToServerMode` (`dht.go:810-816`).
  void _moveToServerMode() {
    for (final proto in const [dhtProtocol, lanDhtProtocol]) {
      host.setStreamHandler(proto, (stream) => _handleStream(stream));
    }
    _serving = true;
  }

  /// Go: `moveToClientMode` (`dht.go:823-843`), which also resets the inbound
  /// streams still open on those protocols. Resetting them is not done here:
  /// this port's `Network` exposes no way to enumerate the streams of a
  /// connection, so the handlers are withdrawn and the streams already in
  /// flight are left to finish. Recorded in `doc/transpilation/PROGRESS.md`.
  void _moveToClientMode() {
    for (final proto in const [dhtProtocol, lanDhtProtocol]) {
      host.removeStreamHandler(proto);
    }
    _serving = false;
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

    // Go arms this before the read loop and stops it on the way out
    // (`dht_net.go:43-44`); every message received pushes it forward.
    var idle = Timer(dhtStreamIdleTimeout, () => unawaited(stream.reset()));

    // Mirrors go-libp2p-kad-dht's handleNewMessage: a stream may carry
    // several requests before the remote closes it.
    var resetOnExit = false;
    try {
      while (!stream.isClosed) {
        // Go checks the mode on every iteration and stops serving the moment
        // it leaves server mode (`dht_net.go:47-50`), rather than letting a
        // stream opened while serving outlive the switch.
        if (!_serving) break;
        final Uint8List frameBytes;
        try {
          frameBytes = await readDhtFrame(stream);
          idle.cancel();
          idle = Timer(dhtStreamIdleTimeout, () => unawaited(stream.reset()));
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
    idle.cancel();
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
      final addrs = _addrsFor(host, id);
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
      closerPeers.add(AddrInfo(id: id, addrs: _addrsFor(host, id)));
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
    final selfId = host.id;
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
