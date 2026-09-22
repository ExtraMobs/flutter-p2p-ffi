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
    final socket = await RawSocket.connect(host, port, timeout: connectTimeout);
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
    final serverSocket = await RawServerSocket.bind(host, port);
    // The socket listener only hands out raw connections; negotiating them is
    // the upgrader's job, and it does so concurrently. Go wires it the same
    // way -- `tcp.Transport.Listen` returns
    // `upgrader.UpgradeGatedMaListener(t, upgrader.GateMaListener(list))`
    // rather than negotiating inside its own `Accept`.
    final listener = upgrader.upgradeGatedMaListener(
      this,
      _TcpListener(serverSocket: serverSocket, transport: this),
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
      if (name == 'ip4' ||
          name == 'ip6' ||
          name == 'dns' ||
          name == 'dns4' ||
          name == 'dns6') {
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

/// A TCP connection with `net.Conn` semantics, built on [RawSocket].
///
/// Deliberately **not** built on `Socket`. `Socket` is an `IOSink`, and
/// `IOSink.add` is fire and forget: when the peer resets the connection the
/// failure is raised inside the sink's own stream subscription, reaching the
/// root zone through `_RootZone.runUnaryGuarded`. It does not travel back to
/// the `write` that queued the bytes, and it does not travel through
/// `Socket.done` either -- both were tried. An unhandled asynchronous error
/// terminates the isolate, so one peer resetting took the whole node down,
/// which is what happened repeatedly under public DHT traffic.
///
/// Go has no such hazard, because `net.Conn.Write` returns `(n, err)` to its
/// caller. [RawSocket.write] is the one dart:io API with that shape: it is
/// synchronous, it returns how many bytes the kernel accepted, and it throws
/// to the caller. Everything below exists to rebuild `net.Conn` on top of it
/// -- which also means this class owns the partial-write loop and the
/// backpressure that `IOSink` used to hide.
class _TcpRawConn implements RawConn {
  _TcpRawConn({
    required RawSocket socket,
    required Transport transport,
    Multiaddr? targetRemoteAddr,
  }) : _socket = socket,
       _transport = transport,
       _targetRemoteAddr = targetRemoteAddr {
    _socket.readEventsEnabled = true;
    _socket.writeEventsEnabled = false;
    _subscription = _socket.listen(
      _onEvent,
      onError: (Object error) => _fail(error),
      onDone: () => _fail(null),
    );
  }

  final RawSocket _socket;
  final Transport _transport;
  final Multiaddr? _targetRemoteAddr;
  StreamSubscription<RawSocketEvent>? _subscription;

  final BytesBuilder _buffer = BytesBuilder(copy: false);
  Completer<void>? _readable;
  Completer<void>? _writable;
  bool _isClosed = false;

  void _onEvent(RawSocketEvent event) {
    switch (event) {
      case RawSocketEvent.read:
        // `available()` can report zero while the event is still delivered;
        // `read` then answers null and there is simply nothing to buffer.
        final chunk = _socket.read();
        if (chunk != null && chunk.isNotEmpty) {
          _buffer.add(chunk);
          _wake(_readable);
          _readable = null;
        }
      case RawSocketEvent.write:
        // dart:io delivers this once and clears the flag, so a writer that
        // still has bytes left re-arms it on the next pass.
        _wake(_writable);
        _writable = null;
      case RawSocketEvent.readClosed:
        _fail(null);
      case RawSocketEvent.closed:
        _fail(null);
    }
  }

  /// Marks the connection dead and releases whoever is waiting on it.
  ///
  /// [error] is the socket's own failure when there was one; a clean remote
  /// close passes null, and a reader then sees end of stream rather than an
  /// exception, matching what `net.Conn` reports as `io.EOF`.
  void _fail(Object? error) {
    _isClosed = true;
    final readable = _readable;
    final writable = _writable;
    _readable = null;
    _writable = null;
    _wake(readable);
    // Completed normally, deliberately, and never with an error: the writer
    // parked here may already have walked away, because yamux abandons a
    // write once `connectionWriteTimeout` elapses
    // (`go-yamux/session.go:583-590`). Completing an abandoned completer with
    // an error raises it with nobody listening, and an unhandled asynchronous
    // error kills the isolate -- the very failure this class exists to
    // prevent. The write loop re-checks `isClosed` after waking and throws
    // from inside the caller's own chain instead, where a handler exists.
    _wake(writable);
  }

  static void _wake(Completer<void>? completer) {
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  @override
  Transport transport() => _transport;

  @override
  Multiaddr localMultiaddr() {
    final ipProto = _socket.address.type == InternetAddressType.IPv6
        ? 'ip6'
        : 'ip4';
    return Multiaddr.parse(
      '/$ipProto/${_socket.address.address}/tcp/${_socket.port}',
    );
  }

  @override
  Multiaddr remoteMultiaddr() {
    if (_targetRemoteAddr != null) return _targetRemoteAddr!;
    final ipProto = _socket.remoteAddress.type == InternetAddressType.IPv6
        ? 'ip6'
        : 'ip4';
    return Multiaddr.parse(
      '/$ipProto/${_socket.remoteAddress.address}/tcp/${_socket.remotePort}',
    );
  }

  @override
  Future<Uint8List> read([int? maxLength]) async {
    while (_buffer.isEmpty && !_isClosed) {
      final waiter = _readable ??= Completer<void>();
      await waiter.future;
    }
    if (_buffer.isEmpty) return Uint8List(0);
    final pending = _buffer.takeBytes();
    if (maxLength == null || maxLength <= 0 || maxLength >= pending.length) {
      return pending;
    }
    // Hand back what was asked for and keep the tail for the next read, in
    // the order it arrived.
    _buffer.add(Uint8List.sublistView(pending, maxLength));
    return Uint8List.sublistView(pending, 0, maxLength);
  }

  // Go's net.Conn tolerates concurrent calls from different goroutines; a
  // single RawSocket does not, and a half-written buffer interleaved with
  // another writer's bytes would corrupt the stream. Serialising restores the
  // Go semantics.
  Future<void> _pending = Future<void>.value();

  Future<void> _serialized(Future<void> Function() action) {
    final result = _pending.then((_) => action());
    _pending = result.then((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<void> write(Uint8List data) => _serialized(() async {
    if (_isClosed) throw const SocketException('TCP connection is closed');
    var offset = 0;
    while (offset < data.length) {
      final int written;
      try {
        written = _socket.write(data, offset, data.length - offset);
      } on SocketException {
        // Exactly what `net.Conn.Write` does: the error goes to the caller.
        // Nothing here reaches the root zone, so a peer that resets can no
        // longer take the isolate with it.
        _isClosed = true;
        rethrow;
      }
      offset += written;
      if (offset < data.length) {
        // The kernel buffer is full. `IOSink` hid this behind its own queue;
        // here it is explicit, and it is the same wait Go's blocking
        // `Write` does inside the runtime.
        if (_isClosed) {
          throw const SocketException('TCP connection closed while writing');
        }
        _socket.writeEventsEnabled = true;
        final waiter = _writable ??= Completer<void>();
        await waiter.future;
        if (_isClosed) {
          throw const SocketException('TCP connection closed while writing');
        }
      }
    }
  });

  @override
  Future<void> close() => _serialized(() async {
    if (_isClosed) return;
    _isClosed = true;
    _fail(null);
    await _subscription?.cancel();
    _subscription = null;
    await _socket.close();
  });

  @override
  bool get isClosed => _isClosed;
}

/// Hands out raw inbound TCP connections, one per accepted socket.
///
/// Go: the `manet.Listener` that `tcp.Transport.Listen` wraps. It deliberately
/// does **not** negotiate: doing that here would serialise every inbound
/// connection behind the slowest handshake, which is what this port used to do
/// (see `_UpgradedListener` in `basic_upgrader.dart`).
class _TcpListener implements GatedMaListener {
  _TcpListener({
    required RawServerSocket serverSocket,
    required Transport transport,
  }) : _serverSocket = serverSocket,
       _transport = transport {
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

  final RawServerSocket _serverSocket;
  final Transport _transport;
  StreamSubscription<RawSocket>? _subscription;
  final List<RawSocket> _pendingSockets = [];
  Completer<void>? _completer;
  bool _closed = false;

  @override
  Future<RawConn> accept() async {
    while (_pendingSockets.isEmpty && !_closed) {
      _completer = Completer<void>();
      await _completer!.future;
      _completer = null;
    }
    if (_closed && _pendingSockets.isEmpty) {
      throw const ListenerClosedException();
    }
    return _TcpRawConn(
      socket: _pendingSockets.removeAt(0),
      transport: _transport,
    );
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _serverSocket.close();
    for (final s in _pendingSockets) {
      // RawSocket has no `destroy`; closing it releases the descriptor just
      // the same, and these were never handed to anyone.
      unawaited(s.close());
    }
    _pendingSockets.clear();
  }

  @override
  Multiaddr multiaddr() {
    final ipProto = _serverSocket.address.type == InternetAddressType.IPv6
        ? 'ip6'
        : 'ip4';
    return Multiaddr.parse(
      '/$ipProto/${_serverSocket.address.address}/tcp/${_serverSocket.port}',
    );
  }
}
