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
