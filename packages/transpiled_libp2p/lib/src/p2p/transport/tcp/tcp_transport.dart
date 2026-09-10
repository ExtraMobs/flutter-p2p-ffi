// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/transport/transport.dart';

/// TCP implementation of [Transport] and [DialUpdater].
class TcpTransport implements Transport, DialUpdater {
  TcpTransport({
    required this.upgrader,
    this.resourceManager = const NullResourceManager(),
    this.connectTimeout = const Duration(seconds: 15),
  });

  final Upgrader upgrader;
  final ResourceManager resourceManager;
  final Duration connectTimeout;
  final List<Listener> _listeners = [];
  bool _closed = false;

  @override
  bool canDial(Multiaddr addr) => _extractTcpEndpoint(addr) != null;

  @override
  Future<CapableConn> dial(Multiaddr addr, PeerId peer) async {
    if (_closed) throw StateError('TcpTransport is closed');
    final endpoint = _extractTcpEndpoint(addr);
    if (endpoint == null) {
      throw ArgumentError('Address $addr is not a valid TCP multiaddr');
    }

    final (host, port) = endpoint;
    final socket = await Socket.connect(host, port, timeout: connectTimeout);
    final rawConn = _TcpRawConn(
      socket: socket,
      transport: this,
      targetRemoteAddr: addr,
    );
    try {
      return await upgrader.upgrade(rawConn, Direction.outbound, peer);
    } catch (err) {
      await rawConn.close();
      rethrow;
    }
  }

  @override
  Stream<DialUpdate> dialWithUpdates(Multiaddr addr, PeerId peer) async* {
    yield DialUpdate(kind: 'start', addr: addr);
    try {
      final conn = await dial(addr, peer);
      yield DialUpdate(kind: 'success', addr: addr, conn: conn);
    } catch (err) {
      yield DialUpdate(
        kind: 'error',
        addr: addr,
        err: err is Exception ? err : Exception(err.toString()),
      );
      rethrow;
    }
  }

  @override
  Future<Listener> listen(Multiaddr addr) async {
    if (_closed) throw StateError('TcpTransport is closed');
    final endpoint = _extractTcpEndpoint(addr);
    if (endpoint == null) {
      throw ArgumentError('Address $addr is not a valid TCP multiaddr');
    }

    final (host, port) = endpoint;
    final serverSocket = await ServerSocket.bind(host, port);
    final listener = _TcpListener(
      serverSocket: serverSocket,
      transport: this,
      upgrader: upgrader,
    );
    _listeners.add(listener);
    return listener;
  }

  @override
  List<int> protocols() => const [4, 6];

  @override
  bool proxy() => false;

  Future<void> close() async {
    _closed = true;
    for (final l in _listeners.toList()) {
      await l.close();
    }
    _listeners.clear();
  }

  static (String, int)? _extractTcpEndpoint(Multiaddr addr) {
    String? host;
    int? port;
    for (final c in addr.components) {
      final name = c.protocol.name;
      if (name == 'ip4' || name == 'ip6' || name == 'dns' || name == 'dns4' || name == 'dns6') {
        host = c.value;
      } else if (name == 'tcp') {
        port = int.tryParse(c.value);
      }
    }
    if (host != null && port != null) {
      return (host, port);
    }
    return null;
  }
}

class _TcpRawConn implements RawConn {
  _TcpRawConn({
    required Socket socket,
    required Transport transport,
    Multiaddr? targetRemoteAddr,
  })  : _socket = socket,
        _transport = transport,
        _targetRemoteAddr = targetRemoteAddr {
    _subscription = _socket.listen(
      (data) {
        _buffer.addAll(data);
        final waiting = _completer;
        if (waiting != null && !waiting.isCompleted) {
          waiting.complete();
        }
      },
      onError: (Object err) {
        _isClosed = true;
        final waiting = _completer;
        if (waiting != null && !waiting.isCompleted) {
          waiting.completeError(err);
        }
      },
      onDone: () {
        _isClosed = true;
        final waiting = _completer;
        if (waiting != null && !waiting.isCompleted) {
          waiting.complete();
        }
      },
      cancelOnError: true,
    );
  }

  final Socket _socket;
  final Transport _transport;
  final Multiaddr? _targetRemoteAddr;
  StreamSubscription<Uint8List>? _subscription;
  final List<int> _buffer = [];
  Completer<void>? _completer;
  bool _isClosed = false;

  @override
  Transport transport() => _transport;

  @override
  Multiaddr localMultiaddr() {
    final ipProto = _socket.address.type == InternetAddressType.IPv6 ? 'ip6' : 'ip4';
    return Multiaddr.parse('/$ipProto/${_socket.address.address}/tcp/${_socket.port}');
  }

  @override
  Multiaddr remoteMultiaddr() {
    if (_targetRemoteAddr != null) return _targetRemoteAddr!;
    final ipProto = _socket.remoteAddress.type == InternetAddressType.IPv6 ? 'ip6' : 'ip4';
    return Multiaddr.parse('/$ipProto/${_socket.remoteAddress.address}/tcp/${_socket.remotePort}');
  }

  @override
  Future<Uint8List> read([int? maxLength]) async {
    while (_buffer.isEmpty && !_isClosed) {
      _completer = Completer<void>();
      await _completer!.future;
      _completer = null;
    }
    if (_buffer.isEmpty) return Uint8List(0);
    final count = maxLength != null && maxLength > 0
        ? (maxLength < _buffer.length ? maxLength : _buffer.length)
        : _buffer.length;
    final chunk = Uint8List.fromList(_buffer.sublist(0, count));
    _buffer.removeRange(0, count);
    return chunk;
  }

  // Go's net.Conn permite chamadas concorrentes de goroutines distintas; o
  // Socket do dart:io não. IOSink.flush() marca o sink como bound enquanto está
  // em voo, então um close() concorrente a um write() pendente — ou dois writes
  // simultâneos — lançam "StreamSink is bound to a stream". Serializar restaura
  // a semântica do Go.
  Future<void> _pending = Future<void>.value();

  Future<void> _serialized(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<void> write(Uint8List data) => _serialized(() async {
        if (_isClosed) throw StateError('TCP connection is closed');
        _socket.add(data);
        await _socket.flush();
      });

  @override
  Future<void> close() => _serialized(() async {
        if (_isClosed) return;
        _isClosed = true;
        await _subscription?.cancel();
        _subscription = null;
        await _socket.close();
        _socket.destroy();
      });

  @override
  bool get isClosed => _isClosed;
}

class _TcpListener implements Listener {
  _TcpListener({
    required ServerSocket serverSocket,
    required Transport transport,
    required Upgrader upgrader,
  })  : _serverSocket = serverSocket,
        _transport = transport,
        _upgrader = upgrader {
    _subscription = _serverSocket.listen(
      (socket) {
        _pendingSockets.add(socket);
        final waiting = _completer;
        if (waiting != null && !waiting.isCompleted) {
          waiting.complete();
        }
      },
      onError: (Object err) {
        _closed = true;
        final waiting = _completer;
        if (waiting != null && !waiting.isCompleted) {
          waiting.completeError(err);
        }
      },
      onDone: () {
        _closed = true;
        final waiting = _completer;
        if (waiting != null && !waiting.isCompleted) {
          waiting.complete();
        }
      },
    );
  }

  final ServerSocket _serverSocket;
  final Transport _transport;
  final Upgrader _upgrader;
  StreamSubscription<Socket>? _subscription;
  final List<Socket> _pendingSockets = [];
  Completer<void>? _completer;
  bool _closed = false;

  @override
  Future<CapableConn> accept() async {
    while (_pendingSockets.isEmpty && !_closed) {
      _completer = Completer<void>();
      await _completer!.future;
      _completer = null;
    }
    if (_closed && _pendingSockets.isEmpty) {
      throw const ListenerClosedException();
    }
    final socket = _pendingSockets.removeAt(0);
    final rawConn = _TcpRawConn(socket: socket, transport: _transport);
    try {
      return await _upgrader.upgrade(rawConn, Direction.inbound, PeerId(value: Uint8List(0)));
    } catch (err) {
      await rawConn.close();
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _serverSocket.close();
    for (final s in _pendingSockets) {
      s.destroy();
    }
    _pendingSockets.clear();
  }

  @override
  Multiaddr multiaddr() {
    final ipProto = _serverSocket.address.type == InternetAddressType.IPv6 ? 'ip6' : 'ip4';
    return Multiaddr.parse('/$ipProto/${_serverSocket.address.address}/tcp/${_serverSocket.port}');
  }
}
