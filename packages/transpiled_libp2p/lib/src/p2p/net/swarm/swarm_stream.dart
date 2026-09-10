// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_go_yamux/transpiled_go_yamux.dart';

import '../../../core/network/network.dart';
import '../../../core/protocol/protocol.dart';

/// Network stream backed by an underlying Yamux stream.
class SwarmStream implements NetworkStream {
  SwarmStream({
    required YamuxStream yamuxStream,
    required Conn conn,
    required Direction direction,
    ProtocolId protocol = '',
  })  : _yamuxStream = yamuxStream,
        _conn = conn,
        _direction = direction,
        _protocol = protocol,
        _opened = DateTime.now();

  final YamuxStream _yamuxStream;
  final Conn _conn;
  final Direction _direction;
  final DateTime _opened;
  ProtocolId _protocol;
  DateTime? _deadline;
  DateTime? _readDeadline;
  DateTime? _writeDeadline;

  @override
  String get id => _yamuxStream.id.toString();

  @override
  ProtocolId protocol() => _protocol;

  @override
  Future<void> setProtocol(ProtocolId id) async {
    _protocol = id;
  }

  @override
  Stats stat() => Stats(
        direction: _direction,
        opened: _opened,
      );

  @override
  Conn conn() => _conn;

  @override
  StreamScope scope() => const NullScope();

  @override
  Future<void> resetWithError(StreamErrorCode errorCode) => reset();

  @override
  bool get isClosed => _yamuxStream.isClosed;

  @override
  Future<Uint8List> read([int? maxLength]) {
    final effectiveDeadline = _readDeadline ?? _deadline;
    final op = _yamuxStream.read(maxLength ?? 65536).then((data) => data ?? Uint8List(0));
    return _applyDeadline(op, effectiveDeadline);
  }

  @override
  Future<void> write(Uint8List data) {
    final effectiveDeadline = _writeDeadline ?? _deadline;
    final op = _yamuxStream.write(data);
    return _applyDeadline(op, effectiveDeadline);
  }

  @override
  Future<void> close() => _yamuxStream.close();

  @override
  Future<void> reset() => _yamuxStream.reset();

  @override
  Future<void> closeWrite() => _yamuxStream.closeWrite();

  @override
  Future<void> closeRead() => _yamuxStream.closeRead();

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
