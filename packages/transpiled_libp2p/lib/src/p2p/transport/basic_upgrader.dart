// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;
import 'dart:typed_data';

import 'package:transpiled_go_yamux/transpiled_go_yamux.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../core/crypto/key_types.dart';
import '../../core/network/network.dart';
import '../../core/peer/peer_id.dart';
import '../../core/sec/security.dart';
import '../../core/transport/transport.dart';
import '../net/swarm/swarm_stream.dart';
import '../protocol/multistream_select.dart';
import '../security/noise/transport.dart';

/// Multistream protocol ID for Yamux multiplexing.
const String goYamuxProtocolId = '/yamux/1.0.0';

/// How many fully negotiated inbound connections may sit waiting to be
/// accepted before the accept loop stops taking new sockets.
///
/// Go: `AcceptQueueLength` (`p2p/net/upgrader/upgrader.go:28`). It bounds the
/// *handoff*, not the negotiation: connections keep being negotiated in
/// parallel, and only the queue of finished ones is capped.
const int acceptQueueLength = 16;

/// How long one inbound connection may take to negotiate *and* be handed to
/// [Listener.accept], after which it is dropped.
///
/// Go: `defaultAcceptTimeout` (`p2p/net/upgrader/upgrader.go:31`), applied as
/// a single context covering both phases (`p2p/net/upgrader/listener.go:110`).
/// Unexported there, so private here.
const Duration _defaultAcceptTimeout = Duration(seconds: 15);

/// Upgraded connection offering authenticated security and multiplexing.
class UpgradedCapableConn implements CapableConn {
  UpgradedCapableConn({
    required Transport transport,
    required PeerId localPeer,
    required PeerId remotePeer,
    required PubKey remotePublicKey,
    required Multiaddr localMultiaddr,
    required Multiaddr remoteMultiaddr,
    required Direction direction,
    required YamuxSession session,
    required YamuxTransport bridge,
    ConnectionState? connectionState,
  }) : _transport = transport,
       _localPeer = localPeer,
       _remotePeer = remotePeer,
       _remotePublicKey = remotePublicKey,
       _localMultiaddr = localMultiaddr,
       _remoteMultiaddr = remoteMultiaddr,
       _direction = direction,
       _session = session,
       _bridge = bridge,
       _connectionState =
           connectionState ??
           const ConnectionState(
             streamMultiplexer: goYamuxProtocolId,
             security: noiseProtocolId,
             transport: 'tcp',
           ),
       _opened = DateTime.now();

  final Transport _transport;
  final PeerId _localPeer;
  final PeerId _remotePeer;
  final PubKey _remotePublicKey;
  final Multiaddr _localMultiaddr;
  final Multiaddr _remoteMultiaddr;
  final Direction _direction;
  final YamuxSession _session;
  final YamuxTransport _bridge;
  final ConnectionState _connectionState;
  final DateTime _opened;

  @override
  Transport transport() => _transport;

  @override
  PeerId localPeer() => _localPeer;

  @override
  PeerId remotePeer() => _remotePeer;

  @override
  PubKey remotePublicKey() => _remotePublicKey;

  @override
  ConnectionState connState() => _connectionState;

  @override
  Multiaddr localMultiaddr() => _localMultiaddr;

  @override
  Multiaddr remoteMultiaddr() => _remoteMultiaddr;

  @override
  ConnScope scope() => const NullScope();

  @override
  ConnStats stat() => ConnStats(
    direction: _direction,
    opened: _opened,
    numStreams: _session.numStreams,
  );

  @override
  bool get isClosed => _session.isClosed;

  @override
  Future<NetworkStream> openStream() async {
    final yStream = await _session.openStream();
    return SwarmStream(
      yamuxStream: yStream,
      conn: this,
      direction: Direction.outbound,
    );
  }

  @override
  Future<NetworkStream> acceptStream() async {
    final yStream = await _session.acceptStream();
    return SwarmStream(
      yamuxStream: yStream,
      conn: this,
      direction: Direction.inbound,
    );
  }

  @override
  Future<void> close() async {
    await _session.close();
    await _bridge.close();
  }
}

/// Standard [Upgrader] implementing multistream-select, Noise security, and Yamux multiplexing.
class BasicUpgrader implements Upgrader {
  BasicUpgrader({
    required this.localIdentityKey,
    this.resourceManager = const NullResourceManager(),
    List<SecureTransport>? security,
  }) : localPeerId = PeerId.fromPubKey(localIdentityKey.getPublic()),
       _security = security == null ? null : List.unmodifiable(security);

  final PrivKey localIdentityKey;
  final PeerId localPeerId;
  final ResourceManager resourceManager;
  final List<SecureTransport>? _security;

  @override
  Listener upgradeGatedMaListener(
    Transport transport,
    GatedMaListener listener,
  ) {
    // [transport] is unused, and kept for signature parity with Go, which
    // hands it to `upgrader.Upgrade` (`listener.go:110`). Here `upgrade`
    // reads the transport back off the connection itself.
    return _UpgradedListener(
      upgrader: this,
      gated: listener,
      resourceManager: resourceManager,
    );
  }

  @override
  Future<CapableConn> upgrade(Conn conn, Direction dir, PeerId peer) async {
    if (conn is CapableConn) {
      return conn;
    }
    final rawConn = conn is RawConn ? conn : _GenericRawConn(conn);
    final rawAdapter = _RawStreamAdapter(rawConn);

    // Upstream upgrader.setupSecurity negotiates the configured transports.
    // Omitting the list preserves this runtime's existing Noise default.
    final security = _security ?? [NoiseTransport(privKey: localIdentityKey)];
    final ids = security.map((transport) => transport.id()).toList();
    if (ids.isEmpty) throw StateError('No security transports configured');
    final selected = dir == Direction.outbound
        ? await selectOutbound(rawAdapter, ids)
        : await selectInbound(rawAdapter, ids);
    final transport = security.firstWhere((value) => value.id() == selected);
    final secured = dir == Direction.outbound
        ? await transport.secureOutbound(rawConn, peer)
        : await transport.secureInbound(rawConn, peer);
    try {
      final state = secured.connState();
      var muxer = state.streamMultiplexer;
      if (!state.usedEarlyMuxerNegotiation) {
        muxer = dir == Direction.outbound
            ? await selectOutbound(secured, const [goYamuxProtocolId])
            : await selectInbound(secured, const [goYamuxProtocolId]);
      }
      if (muxer != goYamuxProtocolId) {
        throw StateError('Unsupported negotiated multiplexer: $muxer');
      }
      final bridge = _SecureYamuxTransport(secured);
      return UpgradedCapableConn(
        transport: rawConn.transport(),
        localPeer: secured.localPeer(),
        remotePeer: secured.remotePeer(),
        remotePublicKey: secured.remotePublicKey(),
        localMultiaddr: rawConn.localMultiaddr(),
        remoteMultiaddr: rawConn.remoteMultiaddr(),
        direction: dir,
        session: YamuxSession(bridge, isClient: dir == Direction.outbound),
        bridge: bridge,
        connectionState: ConnectionState(
          streamMultiplexer: muxer,
          security: selected,
          transport:
              rawConn.remoteMultiaddr().components.any(
                (c) => c.protocol.name == 'ws' || c.protocol.name == 'wss',
              )
              ? 'websocket'
              : 'tcp',
          usedEarlyMuxerNegotiation: state.usedEarlyMuxerNegotiation,
        ),
      );
    } catch (_) {
      await secured.close();
      rethrow;
    }
  }
}

/// Bridges an authenticated byte stream to the existing yamux runtime.
class _SecureYamuxTransport implements YamuxTransport {
  _SecureYamuxTransport(this._conn) {
    unawaited(_pump());
  }

  final SecureConn _conn;
  final _input = StreamController<List<int>>();
  bool _closed = false;

  @override
  Stream<List<int>> get input => _input.stream;

  Future<void> _pump() async {
    try {
      while (!_closed) {
        final bytes = await _conn.read();
        if (bytes.isEmpty) break;
        if (!_closed) _input.add(bytes);
      }
    } catch (error, stack) {
      if (!_closed) _input.addError(error, stack);
    } finally {
      unawaited(_input.close());
    }
  }

  @override
  Future<void> write(Uint8List bytes) {
    if (_closed) throw StateError('Yamux transport is closed');
    return _conn.write(bytes);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _conn.close();
    unawaited(_input.close());
  }
}

class _RawStreamAdapter implements StreamReadWriter {
  _RawStreamAdapter(this._raw);
  final RawConn _raw;

  @override
  Future<Uint8List> read([int? maxLength]) => _raw.read(maxLength);

  @override
  Future<void> write(Uint8List data) => _raw.write(data);
}

class _GenericRawConn implements RawConn {
  _GenericRawConn(this._conn);
  final Conn _conn;

  @override
  Transport transport() {
    final conn = _conn;
    if (conn is RawConn) return conn.transport();
    if (conn is CapableConn) return conn.transport();
    throw StateError('No transport associated with conn');
  }

  @override
  Multiaddr localMultiaddr() {
    final conn = _conn;
    if (conn is RawConn) return conn.localMultiaddr();
    if (conn is CapableConn) return conn.localMultiaddr();
    return Multiaddr.empty;
  }

  @override
  Multiaddr remoteMultiaddr() {
    final conn = _conn;
    if (conn is RawConn) return conn.remoteMultiaddr();
    if (conn is CapableConn) return conn.remoteMultiaddr();
    return Multiaddr.empty;
  }

  @override
  Future<Uint8List> read([int? maxLength]) {
    final conn = _conn;
    if (conn is RawConn) return conn.read(maxLength);
    return Future.value(Uint8List(0));
  }

  @override
  Future<void> write(Uint8List data) {
    final conn = _conn;
    if (conn is RawConn) return conn.write(data);
    return Future.value();
  }

  @override
  Future<void> close() {
    final conn = _conn;
    if (conn is RawConn) return conn.close();
    return Future.value();
  }

  @override
  bool get isClosed {
    final conn = _conn;
    return conn is RawConn ? conn.isClosed : false;
  }
}

/// A negotiated connection parked in the handoff queue, with the timer that
/// drops it if nothing accepts it in time.
class _PendingConn {
  _PendingConn(this.conn);

  final CapableConn conn;
  Timer? timer;
}

/// Turns a [GatedMaListener] into a full libp2p [Listener], negotiating
/// inbound connections concurrently.
///
/// Go: the unexported `listener` of `p2p/net/upgrader/listener.go`, whose
/// `handleIncoming` (`:63-147`) is what this reproduces. Three properties of
/// that loop matter, and the absence of any of them is enough to take a node
/// off the network while it still looks healthy from the inside:
///
/// * **Negotiation is concurrent.** Go spawns a goroutine per connection
///   (`listener.go:106`); here each upgrade is started and deliberately not
///   awaited by the accept loop. Negotiating inline instead serialises every
///   inbound connection behind the slowest one.
/// * **Every upgrade is on a clock.** Go gives it `acceptTimeout`
///   (`listener.go:110`), 15 seconds. Without it, one peer that opens a socket
///   and never speaks blocks that slot forever -- and on the public DHT such
///   peers arrive continuously.
/// * **Failures are dropped, not raised.** Go logs at debug and closes the
///   connection (`listener.go:117-123`); a failed handshake with one peer is
///   not a failure of the listener, and must not reach [accept].
///
/// The backpressure is subtler than it looks: `threshold` counts connections
/// that are *already negotiated and still undelivered*, and the accept loop
/// waits on it (`listener.go:98`). It therefore throttles how far ahead of the
/// consumer this listener runs, and never limits how many handshakes proceed
/// at once.
class _UpgradedListener implements Listener {
  _UpgradedListener({
    required Upgrader upgrader,
    required GatedMaListener gated,
    required ResourceManager resourceManager,
  }) : _upgrader = upgrader,
       _gated = gated,
       _resourceManager = resourceManager {
    unawaited(_handleIncoming());
  }

  final Upgrader _upgrader;
  final GatedMaListener _gated;

  /// Decides whether there is room for one more inbound connection.
  ///
  /// Go asks this in the gated listener, before the raw connection is ever
  /// handed over: `gatedMaListener.Accept` calls
  /// `rcmgr.OpenConnection(DirInbound, true, conn.RemoteMultiaddr())` and
  /// closes the connection when it is refused
  /// (`p2p/net/upgrader/listener.go:195-210`). This port has no separate
  /// gated wrapper, so the question is asked here, at the one place both
  /// transports funnel through.
  final ResourceManager _resourceManager;

  /// Negotiated connections waiting for [accept] to take them. Go: the
  /// unbuffered `incoming` channel (`upgrader.go:128`).
  final Queue<_PendingConn> _incoming = Queue<_PendingConn>();

  /// Callers blocked in [accept] with nothing to hand them yet.
  final Queue<Completer<CapableConn>> _waiters =
      Queue<Completer<CapableConn>>();

  /// Go: `threshold.count` -- negotiated but not yet accepted.
  int _undelivered = 0;
  Completer<void>? _belowThreshold;

  bool _closed = false;
  Object? _error;

  @override
  Multiaddr multiaddr() => _gated.multiaddr();

  @override
  Future<CapableConn> accept() async {
    while (true) {
      while (_incoming.isNotEmpty) {
        final pending = _incoming.removeFirst();
        pending.timer?.cancel();
        _release();
        // Go: "Could have been sitting there for a while"
        // (`listener.go:157`) -- the peer may have gone away meanwhile.
        if (!pending.conn.isClosed) return pending.conn;
      }
      if (_closed) {
        final error = _error;
        if (error != null && error is! ListenerClosedException) throw error;
        throw const ListenerClosedException();
      }
      final waiter = Completer<CapableConn>();
      _waiters.add(waiter);
      final conn = await waiter.future;
      if (!conn.isClosed) return conn;
    }
  }

  /// Go: `handleIncoming` (`listener.go:63-147`).
  Future<void> _handleIncoming() async {
    while (!_closed) {
      final RawConn raw;
      try {
        raw = await _gated.accept();
      } on ListenerClosedException {
        break;
      } catch (error) {
        _error = error;
        break;
      }
      // Go: `l.threshold.Wait()` (`listener.go:98`).
      await _awaitBelowThreshold();
      if (_closed) {
        await raw.close();
        break;
      }
      // Deliberately not awaited: this is the whole point of the port.
      unawaited(_negotiate(raw));
    }
    _closed = true;
    _failWaiters();
  }

  /// Negotiates one inbound connection and hands it over, on one clock that
  /// covers both. Go: the goroutine body at `listener.go:106-146`.
  Future<void> _negotiate(RawConn raw) async {
    // Admission first, negotiation second. A connection this node has no room
    // for costs nothing beyond the close; negotiating it first would spend a
    // handshake to arrive at the same answer.
    final ConnManagementScope scope;
    try {
      scope = _resourceManager.openConnection(
        Direction.inbound,
        true,
        raw.remoteMultiaddr(),
      );
    } catch (error) {
      // Go: "resource manager blocked accept of new connection"
      // (`listener.go:204`).
      dev.log(
        'resource manager blocked accept of new connection',
        name: 'upgrader',
        error: error,
      );
      await raw.close();
      return;
    }

    final elapsed = Stopwatch()..start();
    final CapableConn conn;
    try {
      conn = await _upgrader
          .upgrade(raw, Direction.inbound, PeerId(value: Uint8List(0)))
          .timeout(_defaultAcceptTimeout);
    } catch (error) {
      // Go: "Don't bother bubbling this up. We just failed to completely
      // negotiate the connection." (`listener.go:118-119`).
      dev.log('accept upgrade error', name: 'upgrader', error: error);
      scope.done();
      await raw.close();
      return;
    }
    if (_closed) {
      scope.done();
      await conn.close();
      return;
    }
    // Go keeps the scope for the life of the connection: it is handed to
    // `Upgrade`, stored on the resulting conn, and released when that conn
    // closes. This port's `Upgrade` takes no scope and `CapableConn` offers
    // no close hook, so the scope covers **negotiation only** and is released
    // on delivery.
    //
    // That is a narrower limit than upstream's, and deliberately so rather
    // than by omission: holding a scope that nothing will ever release would
    // turn the counter into a ratchet and strangle the listener after N
    // connections, which is worse than the missing limit. What is bounded is
    // how many inbound handshakes may run at once -- which is the resource a
    // DHT flood actually consumes. Recorded in
    // `doc/transpilation/PROGRESS.md`.
    scope.done();
    _deliver(conn, _defaultAcceptTimeout - elapsed.elapsed);
  }

  /// Go: `threshold.Acquire` then the `select` on `l.incoming`
  /// (`listener.go:133-145`).
  void _deliver(CapableConn conn, Duration remaining) {
    _undelivered++;
    while (_waiters.isNotEmpty) {
      final waiter = _waiters.removeFirst();
      if (waiter.isCompleted) continue;
      _release();
      waiter.complete(conn);
      return;
    }
    final pending = _PendingConn(conn);
    _incoming.add(pending);
    pending.timer = Timer(remaining.isNegative ? Duration.zero : remaining, () {
      if (!_incoming.remove(pending)) return;
      _release();
      // Go: `log.Warn("listener dropped connection due to slow accept")`
      // followed by `CloseWithError(network.ConnRateLimited)`
      // (`listener.go:141-144`).
      dev.log(
        'listener dropped connection due to slow accept',
        name: 'upgrader',
      );
      unawaited(conn.close());
    });
  }

  Future<void> _awaitBelowThreshold() async {
    while (_undelivered >= acceptQueueLength && !_closed) {
      final gate = _belowThreshold ??= Completer<void>();
      await gate.future;
    }
  }

  /// Go: `threshold.Release` (`threshold.go:30-40`).
  void _release() {
    _undelivered--;
    final gate = _belowThreshold;
    if (gate != null && !gate.isCompleted && _undelivered < acceptQueueLength) {
      _belowThreshold = null;
      gate.complete();
    }
  }

  void _failWaiters() {
    final gate = _belowThreshold;
    if (gate != null && !gate.isCompleted) {
      _belowThreshold = null;
      gate.complete();
    }
    while (_waiters.isNotEmpty) {
      final waiter = _waiters.removeFirst();
      if (!waiter.isCompleted) {
        waiter.completeError(_error ?? const ListenerClosedException());
      }
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _gated.close();
    // Go: "Drain and wait" -- everything already negotiated is closed rather
    // than leaked (`listener.go:44-48`).
    while (_incoming.isNotEmpty) {
      final pending = _incoming.removeFirst();
      pending.timer?.cancel();
      await pending.conn.close();
    }
    _failWaiters();
  }
}
