import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  group('PeerIdMismatchException [Atomic Audit]', () {
    test('toString() - preserves the upstream identity mismatch diagnostic', () {
      final expected = PeerId(value: Uint8List.fromList([1, 2, 3]));
      final actual = PeerId(value: Uint8List.fromList([4, 5, 6]));
      final error = PeerIdMismatchException(expected: expected, actual: actual);
      expect(error.expected, same(expected));
      expect(error.actual, same(actual));
      expect(error.toString(),
          'peer id mismatch: expected $expected, but remote key matches $actual');
    });
  });

  group('SecureTransport [Atomic Audit]', () {
    final transport = _MockSecureTransport();
    final raw = _MockRawConn();
    final peer = PeerId(value: Uint8List.fromList([7, 8, 9]));

    test('id() - returns security protocol identifier', () {
      expect(transport.id(), '/sec/1.0.0');
    });

    test('secureInbound() - authenticates incoming connection', () async {
      final conn = await transport.secureInbound(raw, peer);
      expect(conn.remotePeer(), peer);
    });

    test('secureOutbound() - authenticates outgoing connection', () async {
      final conn = await transport.secureOutbound(raw, peer);
      expect(conn.remotePeer(), peer);
    });
  });

  group('NoiseTransport [Atomic Audit]', () {
    test('id() - returns security protocol identifier', () async {
      final key = await generateEd25519KeyPair();
      final transport = NoiseTransport(privKey: key);
      expect(transport.id(), equals('/noise'));
      expect(transport.protocolId, equals('/noise'));
      expect(transport.localPeer, equals(PeerId.fromPubKey(key.getPublic())));
    });

    test('secureOutbound() - completes Noise handshake as initiator and exchanges data', () async {
      final clientKey = await generateEd25519KeyPair();
      final serverKey = await generateEd25519KeyPair();
      final clientPeer = PeerId.fromPubKey(clientKey.getPublic());
      final serverPeer = PeerId.fromPubKey(serverKey.getPublic());

      final clientTransport = NoiseTransport(privKey: clientKey);
      final serverTransport = NoiseTransport(privKey: serverKey);

      final (clientRaw, serverRaw) = _createDuplexPipePair();

      final results = await Future.wait([
        clientTransport.secureOutbound(clientRaw, serverPeer),
        serverTransport.secureInbound(serverRaw, clientPeer),
      ]);

      final clientConn = results[0];
      final serverConn = results[1];

      expect(clientConn.localPeer(), equals(clientPeer));
      expect(clientConn.remotePeer(), equals(serverPeer));
      expect(clientConn.remotePublicKey().raw(), equals(serverKey.getPublic().raw()));
      expect(clientConn.connState().security, equals('/noise'));
      expect(clientConn.isClosed, isFalse);

      final msg = utf8.encode('hello noise from client');
      await clientConn.write(Uint8List.fromList(msg));
      final received = await serverConn.read();
      expect(utf8.decode(received), equals('hello noise from client'));

      await clientConn.close();
      expect(clientConn.isClosed, isTrue);
      await serverConn.close();
    });

    test('secureInbound() - completes Noise handshake as responder and exchanges data', () async {
      final clientKey = await generateEd25519KeyPair();
      final serverKey = await generateEd25519KeyPair();
      final clientPeer = PeerId.fromPubKey(clientKey.getPublic());
      final serverPeer = PeerId.fromPubKey(serverKey.getPublic());

      final clientTransport = NoiseTransport(privKey: clientKey);
      final serverTransport = NoiseTransport(privKey: serverKey);

      final (clientRaw, serverRaw) = _createDuplexPipePair();

      final results = await Future.wait([
        clientTransport.secureOutbound(clientRaw, serverPeer),
        serverTransport.secureInbound(serverRaw, clientPeer),
      ]);

      final clientConn = results[0];
      final serverConn = results[1];

      expect(serverConn.localPeer(), equals(serverPeer));
      expect(serverConn.remotePeer(), equals(clientPeer));
      expect(serverConn.remotePublicKey().raw(), equals(clientKey.getPublic().raw()));

      final msg = utf8.encode('hello noise from server');
      await serverConn.write(Uint8List.fromList(msg));
      final received = await clientConn.read();
      expect(utf8.decode(received), equals('hello noise from server'));

      await clientConn.close();
      await serverConn.close();
    });
  });
}

class _MockSecureConn implements SecureConn {
  _MockSecureConn(this._peer);
  final PeerId _peer;
  bool _closed = false;

  @override
  Transport transport() => throw UnimplementedError();
  @override
  Multiaddr localMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
  @override
  Multiaddr remoteMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4002');
  @override
  Future<Uint8List> read([int? maxLength]) async => Uint8List(0);
  @override
  Future<void> write(Uint8List data) async {}
  @override
  Future<void> close() async {
    _closed = true;
  }
  @override
  bool get isClosed => _closed;

  @override
  PeerId localPeer() => PeerId(value: Uint8List.fromList([1]));
  @override
  PeerId remotePeer() => _peer;
  @override
  PubKey remotePublicKey() => unmarshalEd25519PublicKey(Uint8List(32));
  @override
  ConnectionState connState() => const ConnectionState();
}

class _MockSecureTransport implements SecureTransport {
  @override
  String id() => '/sec/1.0.0';

  @override
  Future<SecureConn> secureInbound(RawConn insecure, PeerId peer) async {
    return _MockSecureConn(peer);
  }

  @override
  Future<SecureConn> secureOutbound(RawConn insecure, PeerId peer) async {
    return _MockSecureConn(peer);
  }
}

class _MockRawConn implements RawConn {
  bool _closed = false;
  @override
  Transport transport() => throw UnimplementedError();
  @override
  Multiaddr localMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
  @override
  Multiaddr remoteMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4002');
  @override
  Future<Uint8List> read([int? maxLength]) async => Uint8List(0);
  @override
  Future<void> write(Uint8List data) async {}
  @override
  Future<void> close() async {
    _closed = true;
  }
  @override
  bool get isClosed => _closed;
}

class _DuplexPipeConn implements RawConn {
  _DuplexPipeConn({
    required this.localAddr,
    required this.remoteAddr,
  });

  final Multiaddr localAddr;
  final Multiaddr remoteAddr;
  late final _DuplexPipeConn other;

  final List<int> _incoming = [];
  Completer<void>? _readCompleter;
  bool _closed = false;

  void _receive(Uint8List bytes) {
    if (_closed) return;
    _incoming.addAll(bytes);
    if (_readCompleter != null && !_readCompleter!.isCompleted) {
      _readCompleter!.complete();
    }
  }

  @override
  Multiaddr localMultiaddr() => localAddr;

  @override
  Multiaddr remoteMultiaddr() => remoteAddr;

  @override
  Transport transport() => throw UnimplementedError();

  @override
  bool get isClosed => _closed;

  @override
  Future<void> close() async {
    _closed = true;
    if (_readCompleter != null && !_readCompleter!.isCompleted) {
      _readCompleter!.complete();
    }
  }

  @override
  Future<Uint8List> read([int? maxLength]) async {
    while (_incoming.isEmpty) {
      if (_closed) return Uint8List(0);
      _readCompleter = Completer<void>();
      await _readCompleter!.future;
    }
    final len = maxLength != null ? math.min(maxLength, _incoming.length) : _incoming.length;
    final res = Uint8List.fromList(_incoming.sublist(0, len));
    _incoming.removeRange(0, len);
    return res;
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_closed) throw StateError('closed');
    other._receive(data);
  }
}

(RawConn, RawConn) _createDuplexPipePair() {
  final a1 = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
  final a2 = Multiaddr.parse('/ip4/127.0.0.1/tcp/4002');
  final c1 = _DuplexPipeConn(localAddr: a1, remoteAddr: a2);
  final c2 = _DuplexPipeConn(localAddr: a2, remoteAddr: a1);
  c1.other = c2;
  c2.other = c1;
  return (c1, c2);
}
