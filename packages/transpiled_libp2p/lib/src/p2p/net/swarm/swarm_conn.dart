// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p's p2p/net/swarm/swarm_conn.go.
//
// This is the layer the Dart port was missing: upstream, a
// `transport.CapableConn` is not a `network.Conn`. The swarm wraps each
// transport connection in a `swarm.Conn`, and that wrapper is what carries the
// connection id, the set of open streams and the ability to close with an
// error code. Without it the `Conn` interface had nothing to declare, which is
// why it sat empty.

import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/crypto/key_types.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/transport/transport.dart';
import 'swarm.dart';
import 'swarm_stream.dart';

/// Thrown when a stream is opened on a connection that is already closed.
///
/// Go: `ErrConnClosed` (`swarm_conn.go:20`).
class ConnClosedException implements Exception {
  const ConnClosedException();

  @override
  String toString() => 'connection closed';
}

/// The connection type used by the swarm, wrapping one [CapableConn].
///
/// Go: `swarm.Conn` (`swarm_conn.go:25-38`), which is the `network.Conn`
/// implementation the rest of libp2p sees.
class SwarmConn implements Conn {
  SwarmConn({required CapableConn conn, required Swarm swarm, required int id})
    : _conn = conn,
      _swarm = swarm,
      _id = id;

  final CapableConn _conn;
  final Swarm _swarm;
  final int _id;

  /// Go: the `streams` field (`swarm_conn.go:33-36`). A `Set` keyed by identity
  /// is the Dart equivalent of the upstream `map[*Stream]struct{}`.
  final Set<SwarmStream> _streams = <SwarmStream>{};

  bool _closed = false;

  /// The transport connection underneath. Used by the swarm to reconcile the
  /// wrapper with what a transport handed it.
  CapableConn get capableConn => _conn;

  @override
  String id() {
    // Go: `<first 10 chars of peer id>-<global conn ordinal>`
    // (`swarm_conn.go:50-53`).
    final remote = _conn.remotePeer().toString();
    final prefix = remote.length <= 10 ? remote : remote.substring(0, 10);
    return '$prefix-$_id';
  }

  @override
  Future<NetworkStream> newStream() async {
    if (_closed) throw const ConnClosedException();
    final muxed = await _conn.openStream();
    return _addStream(muxed, Direction.outbound);
  }

  /// Registers an inbound stream that the swarm's accept loop just took off
  /// this connection.
  ///
  /// Go: `addStream` with `network.DirInbound` (`swarm_conn.go:240-273`).
  SwarmStream adoptInboundStream(MuxedStream muxed) =>
      _addStream(muxed, Direction.inbound);

  /// Go: `addStream` (`swarm_conn.go:240-273`).
  SwarmStream _addStream(MuxedStream muxed, Direction direction) {
    if (_closed) throw const ConnClosedException();
    final stream = SwarmStream(
      muxedStream: muxed,
      conn: this,
      direction: direction,
      id: _swarm.nextStreamId(),
    );
    _streams.add(stream);
    return stream;
  }

  /// Go: `removeStream` (`swarm_conn.go:111-117`).
  void removeStream(SwarmStream stream) {
    _streams.remove(stream);
  }

  @override
  List<NetworkStream> getStreams() =>
      List<NetworkStream>.unmodifiable(_streams);

  @override
  bool get isClosed => _closed || _conn.isClosed;

  @override
  Future<void> close() => _doClose(0);

  @override
  Future<void> closeWithError(ConnErrorCode errorCode) => _doClose(errorCode);

  /// Go: `doClose` (`swarm_conn.go:73-110`), guarded by `closeOnce`
  /// (`swarm_conn.go:59-64`).
  Future<void> _doClose(ConnErrorCode errorCode) async {
    if (_closed) return;
    _closed = true;

    _swarm.removeConn(this);

    // Prevent new streams from opening, then reset the ones still registered.
    final streams = _streams.toList();
    _streams.clear();

    if (errorCode != 0) {
      await _conn.closeWithError(errorCode);
    } else {
      await _conn.close();
    }

    for (final s in streams) {
      await s.reset();
    }

    _swarm.notifyDisconnected(this);
  }

  @override
  PeerId localPeer() => _conn.localPeer();

  @override
  PeerId remotePeer() => _conn.remotePeer();

  @override
  PubKey remotePublicKey() => _conn.remotePublicKey();

  @override
  ConnectionState connState() => _conn.connState();

  @override
  Multiaddr localMultiaddr() => _conn.localMultiaddr();

  @override
  Multiaddr remoteMultiaddr() => _conn.remoteMultiaddr();

  @override
  ConnScope scope() => _conn.scope();

  /// Go: `Stat` (`swarm_conn.go:207-211`). `numStreams` is the size of the
  /// registered stream set, which is what upstream keeps `stat.NumStreams` in
  /// step with through `addStream`/`removeStream`.
  @override
  ConnStats stat() {
    final inner = _conn.stat();
    return ConnStats(
      direction: inner.direction,
      opened: inner.opened,
      limited: inner.limited,
      extra: inner.extra,
      numStreams: _streams.length,
    );
  }

  @override
  String toString() {
    // Go: `String` (`swarm_conn.go:158-167`).
    return '<swarm.Conn[${_conn.transport().runtimeType}] '
        '${_conn.localMultiaddr()} (${_conn.localPeer()}) <-> '
        '${_conn.remoteMultiaddr()} (${_conn.remotePeer()})>';
  }
}
