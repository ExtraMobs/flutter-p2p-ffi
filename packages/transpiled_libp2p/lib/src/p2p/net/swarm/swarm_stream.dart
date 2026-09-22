// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p's p2p/net/swarm/swarm_stream.go.

import 'dart:async';
import 'dart:typed_data';

import '../../../core/network/network.dart';
import '../../../core/protocol/protocol.dart';
import 'swarm_conn.dart';

/// The libp2p stream the swarm hands out, wrapping one [MuxedStream].
///
/// Go: `swarm.Stream` (`swarm_stream.go:20-33`). Previously this class wrapped
/// a `YamuxStream` directly and was built by the upgrader, which meant every
/// transport had to invent its own copy of the libp2p-level stream identity.
/// It now wraps whatever muxed stream a transport produced, exactly as
/// upstream wraps a `network.MuxedStream`.
class SwarmStream implements NetworkStream {
  SwarmStream({
    required MuxedStream muxedStream,
    required SwarmConn conn,
    required Direction direction,
    required int id,
    ProtocolId protocol = '',
  }) : _muxedStream = muxedStream,
       _conn = conn,
       _direction = direction,
       _id = id,
       _protocol = protocol,
       _opened = DateTime.now();

  final MuxedStream _muxedStream;
  final SwarmConn _conn;
  final Direction _direction;
  final DateTime _opened;
  final int _id;
  ProtocolId _protocol;
  DateTime? _deadline;
  DateTime? _readDeadline;
  DateTime? _writeDeadline;

  /// Go: `ID` (`swarm_stream.go:35-38`), formatted as
  /// `<conn id>-<global stream ordinal>`.
  @override
  String get id => '${_conn.id()}-$_id';

  @override
  ProtocolId protocol() => _protocol;

  @override
  Future<void> setProtocol(ProtocolId id) async {
    _protocol = id;
  }

  @override
  Stats stat() => Stats(direction: _direction, opened: _opened);

  @override
  Conn conn() => _conn;

  @override
  StreamScope scope() => const NullScope();

  @override
  Future<void> resetWithError(StreamErrorCode errorCode) async {
    _conn.removeStream(this);
    await _muxedStream.resetWithError(errorCode);
  }

  @override
  bool get isClosed => _muxedStream.isClosed;

  @override
  Future<Uint8List> read([int? maxLength]) {
    final effectiveDeadline = _readDeadline ?? _deadline;
    return _applyDeadline(_muxedStream.read(maxLength), effectiveDeadline);
  }

  @override
  Future<void> write(Uint8List data) {
    final effectiveDeadline = _writeDeadline ?? _deadline;
    return _applyDeadline(_muxedStream.write(data), effectiveDeadline);
  }

  /// Go: `Close` (`swarm_stream.go:40-49`), which deregisters the stream from
  /// its connection.
  @override
  Future<void> close() async {
    _conn.removeStream(this);
    await _muxedStream.close();
  }

  /// Go: `Reset` (`swarm_stream.go:66-75`).
  @override
  Future<void> reset() async {
    _conn.removeStream(this);
    await _muxedStream.reset();
  }

  @override
  Future<void> closeWrite() => _muxedStream.closeWrite();

  @override
  Future<void> closeRead() => _muxedStream.closeRead();

  @override
  Future<void> setDeadline(DateTime? time) async {
    _deadline = time;
  }

  @override
  Future<void> setReadDeadline(DateTime? time) async {
    _readDeadline = time;
  }

  @override
  Future<void> setWriteDeadline(DateTime? time) async {
    _writeDeadline = time;
  }

  Future<T> _applyDeadline<T>(Future<T> future, DateTime? deadline) {
    if (deadline == null) return future;
    final remaining = deadline.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      return Future<T>.error(TimeoutException('stream deadline exceeded'));
    }
    return future.timeout(remaining);
  }
}
