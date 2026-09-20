// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
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
  })  : _transport = transport,
        _localPeer = localPeer,
        _remotePeer = remotePeer,
        _remotePublicKey = remotePublicKey,
        _localMultiaddr = localMultiaddr,
        _remoteMultiaddr = remoteMultiaddr,
        _direction = direction,
        _session = session,
        _bridge = bridge,
        _connectionState = connectionState ?? const ConnectionState(
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
          transport: rawConn.remoteMultiaddr().components
              .any((c) => c.protocol.name == 'ws' || c.protocol.name == 'wss')
              ? 'websocket' : 'tcp',
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

