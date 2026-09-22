// Atomic tests for `Upgrader.upgradeGatedMaListener` -- the port of
// go-libp2p's `p2p/net/upgrader/listener.go` `handleIncoming`.
//
// Level 2: real loopback TCP sockets, no external daemon.
//
// These exist because of a defect that every other test in this repository
// missed. The inbound path used to negotiate each connection inside the
// listener's own `accept()`, and the swarm called that serially, so one peer
// that opened a socket and said nothing stalled every other inbound
// connection behind it, with no timeout. On loopback, against one
// well-behaved peer and a freshly started node, that is invisible; on the
// public DHT such peers arrive continuously, and the node stopped accepting
// anyone within minutes while still looking healthy from the inside.
//
// So the test that matters here is the silent-peer one: it hangs forever
// against the old implementation and passes against the port of Go's.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  group('BasicUpgrader [Atomic Audit]', () {
    test(
      'upgradeGatedMaListener() - reports the address of the listener it wraps',
      () async {
        final transport = TcpTransport(
          upgrader: BasicUpgrader(localIdentityKey: generateEcdsaKeyPair()),
        );
        final listener = await transport.listen(
          Multiaddr.parse('/ip4/127.0.0.1/tcp/0'),
        );
        try {
          final addr = listener.multiaddr().toString();
          expect(addr, startsWith('/ip4/127.0.0.1/tcp/'));
          expect(addr, isNot(endsWith('/tcp/0')));
        } finally {
          await listener.close();
          await transport.close();
        }
      },
    );

    test(
      'upgradeGatedMaListener() - a peer that connects and never speaks does '
      'not block the connections behind it',
      () async {
        final serverKey = generateEcdsaKeyPair();
        final server = TcpTransport(
          upgrader: BasicUpgrader(localIdentityKey: serverKey),
        );
        final listener = await server.listen(
          Multiaddr.parse('/ip4/127.0.0.1/tcp/0'),
        );
        final boundAddr = listener.multiaddr();
        final serverPeer = PeerId.fromPubKey(serverKey.getPublic());
        final port = int.parse(
          boundAddr.components
              .firstWhere((c) => c.protocol.name == 'tcp')
              .value,
        );

        final silent = <Socket>[];
        final client = TcpTransport(
          upgrader: BasicUpgrader(localIdentityKey: generateEcdsaKeyPair()),
        );
        try {
          // Eight peers that complete the TCP handshake and then send nothing
          // at all -- the exact shape of traffic that took the node off the
          // network. Serial negotiation stalls on the first of these, because
          // nothing ever times it out.
          for (var i = 0; i < 8; i++) {
            silent.add(await Socket.connect('127.0.0.1', port));
          }

          final accepted = listener.accept();
          final dialled = await client
              .dial(boundAddr, serverPeer)
              .timeout(const Duration(seconds: 20));
          final inbound = await accepted.timeout(const Duration(seconds: 20));

          expect(inbound.remotePeer(), equals(dialled.localPeer()));
          await dialled.close();
          await inbound.close();
        } finally {
          for (final s in silent) {
            s.destroy();
          }
          await listener.close();
          await server.close();
          await client.close();
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'upgradeGatedMaListener() - a failed negotiation is dropped rather than '
      'surfaced from accept()',
      () async {
        final serverKey = generateEcdsaKeyPair();
        final server = TcpTransport(
          upgrader: BasicUpgrader(localIdentityKey: serverKey),
        );
        final listener = await server.listen(
          Multiaddr.parse('/ip4/127.0.0.1/tcp/0'),
        );
        final boundAddr = listener.multiaddr();
        final port = int.parse(
          boundAddr.components
              .firstWhere((c) => c.protocol.name == 'tcp')
              .value,
        );
        final serverPeer = PeerId.fromPubKey(serverKey.getPublic());

        final client = TcpTransport(
          upgrader: BasicUpgrader(localIdentityKey: generateEcdsaKeyPair()),
        );
        try {
          // Garbage where a multistream-select proposal belongs: the
          // negotiation fails, and Go's listener logs it and moves on
          // (`listener.go:117-123`) rather than failing the listener.
          final junk = await Socket.connect('127.0.0.1', port);
          junk.add(List<int>.filled(64, 0xff));
          await junk.flush();

          final accepted = listener.accept();
          final dialled = await client
              .dial(boundAddr, serverPeer)
              .timeout(const Duration(seconds: 20));
          final inbound = await accepted.timeout(const Duration(seconds: 20));

          expect(inbound.isClosed, isFalse);
          junk.destroy();
          await dialled.close();
          await inbound.close();
        } finally {
          await listener.close();
          await server.close();
          await client.close();
        }
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );

    test(
      'upgradeGatedMaListener() - accept() throws once the listener is closed',
      () async {
        final transport = TcpTransport(
          upgrader: BasicUpgrader(localIdentityKey: generateEcdsaKeyPair()),
        );
        final listener = await transport.listen(
          Multiaddr.parse('/ip4/127.0.0.1/tcp/0'),
        );
        await listener.close();
        await expectLater(
          listener.accept(),
          throwsA(isA<ListenerClosedException>()),
        );
        await transport.close();
      },
    );
  });

  group('GatedMaListener [Atomic Audit]', () {
    test(
      'accept() - hands out a raw connection that has not been negotiated',
      () async {
        final gated = _ServerSocketGatedMaListener(
          await ServerSocket.bind('127.0.0.1', 0),
        );
        try {
          final client = await Socket.connect('127.0.0.1', gated.port);
          final raw = await gated.accept().timeout(const Duration(seconds: 10));
          // A GatedMaListener is explicitly *not* allowed to negotiate: the
          // whole point of the split is that negotiation happens elsewhere,
          // concurrently. So what comes out is a plain RawConn.
          expect(raw, isA<RawConn>());
          expect(raw.isClosed, isFalse);
          await raw.close();
          client.destroy();
        } finally {
          await gated.close();
        }
      },
    );

    test('multiaddr() - reports the address being listened on', () async {
      final gated = _ServerSocketGatedMaListener(
        await ServerSocket.bind('127.0.0.1', 0),
      );
      try {
        expect(
          gated.multiaddr().toString(),
          equals('/ip4/127.0.0.1/tcp/${gated.port}'),
        );
      } finally {
        await gated.close();
      }
    });

    test(
      'close() - makes a pending accept() report the listener closed',
      () async {
        final gated = _ServerSocketGatedMaListener(
          await ServerSocket.bind('127.0.0.1', 0),
        );
        final pending = gated.accept();
        // Attach the matcher before closing: otherwise the rejection fires
        // with no handler yet and surfaces as an uncaught async error.
        final expectation = expectLater(
          pending,
          throwsA(isA<ListenerClosedException>()),
        );
        await gated.close();
        await expectation;
      },
    );
  });

  group('Upgrader [Atomic Audit]', () {
    test('upgradeGatedMaListener() - negotiates connections coming from any '
        'GatedMaListener, not just the transports\' own', () async {
      final serverKey = generateEcdsaKeyPair();
      final upgrader = BasicUpgrader(localIdentityKey: serverKey);
      final server = TcpTransport(upgrader: upgrader);
      final gated = _ServerSocketGatedMaListener(
        await ServerSocket.bind('127.0.0.1', 0),
        server,
      );
      final listener = upgrader.upgradeGatedMaListener(server, gated);

      final client = TcpTransport(
        upgrader: BasicUpgrader(localIdentityKey: generateEcdsaKeyPair()),
      );
      try {
        final accepted = listener.accept();
        final dialled = await client
            .dial(gated.multiaddr(), PeerId.fromPubKey(serverKey.getPublic()))
            .timeout(const Duration(seconds: 20));
        final inbound = await accepted.timeout(const Duration(seconds: 20));

        expect(inbound.remotePeer(), equals(dialled.localPeer()));
        await dialled.close();
        await inbound.close();
      } finally {
        await listener.close();
        await server.close();
        await client.close();
      }
    }, timeout: const Timeout(Duration(seconds: 60)));
  });
}

/// A [GatedMaListener] over a plain [ServerSocket], used to exercise the
/// interface contract on its own and to show that the upgrader's listener
/// accepts connections from any source, not only a transport's own.
class _ServerSocketGatedMaListener implements GatedMaListener {
  _ServerSocketGatedMaListener(this._server, [this._transport]) {
    _subscription = _server.listen((socket) {
      _pending.add(socket);
      final waiting = _waiter;
      if (waiting != null && !waiting.isCompleted) waiting.complete();
    }, onError: (Object _) {});
  }

  final ServerSocket _server;
  final Transport? _transport;
  StreamSubscription<Socket>? _subscription;
  final List<Socket> _pending = [];
  Completer<void>? _waiter;
  bool _closed = false;

  int get port => _server.port;

  @override
  Future<RawConn> accept() async {
    while (_pending.isEmpty && !_closed) {
      _waiter = Completer<void>();
      await _waiter!.future;
      _waiter = null;
    }
    if (_pending.isEmpty) throw const ListenerClosedException();
    return _SocketRawConn(_pending.removeAt(0), multiaddr(), _transport);
  }

  @override
  Multiaddr multiaddr() =>
      Multiaddr.parse('/ip4/${_server.address.address}/tcp/${_server.port}');

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final waiting = _waiter;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
    await _subscription?.cancel();
    await _server.close();
  }
}

/// The minimum [RawConn] the upgrader needs: a byte stream with addresses.
class _SocketRawConn implements RawConn {
  _SocketRawConn(this._socket, this._local, this._transport) {
    _subscription = _socket.listen(
      (chunk) {
        _buffer.addAll(chunk);
        final waiting = _waiter;
        if (waiting != null && !waiting.isCompleted) waiting.complete();
      },
      onDone: _markClosed,
      onError: (Object _) => _markClosed(),
      cancelOnError: true,
    );
  }

  final Socket _socket;
  final Multiaddr _local;
  final Transport? _transport;
  StreamSubscription<Uint8List>? _subscription;
  final List<int> _buffer = [];
  Completer<void>? _waiter;
  bool _closed = false;

  void _markClosed() {
    _closed = true;
    final waiting = _waiter;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }

  @override
  Future<Uint8List> read([int? maxLength]) async {
    while (_buffer.isEmpty && !_closed) {
      _waiter = Completer<void>();
      await _waiter!.future;
      _waiter = null;
    }
    if (_buffer.isEmpty) return Uint8List(0);
    final take = maxLength == null
        ? _buffer.length
        : (maxLength < _buffer.length ? maxLength : _buffer.length);
    final out = Uint8List.fromList(_buffer.sublist(0, take));
    _buffer.removeRange(0, take);
    return out;
  }

  @override
  Future<void> write(Uint8List data) async {
    _socket.add(data);
    await _socket.flush();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _subscription?.cancel();
    _socket.destroy();
  }

  @override
  bool get isClosed => _closed;

  @override
  Transport transport() =>
      _transport ?? (throw StateError('no transport supplied'));

  @override
  Multiaddr localMultiaddr() => _local;

  @override
  Multiaddr remoteMultiaddr() => Multiaddr.parse(
    '/ip4/${_socket.remoteAddress.address}/tcp/${_socket.remotePort}',
  );
}
