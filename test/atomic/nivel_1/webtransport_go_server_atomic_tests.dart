// Atomic tests for the public symbols added to
// `packages/transpiled_webtransport_go/lib/src/server.dart`: [Server] and
// [ServerException].
//
// These exercise real HTTP/3-over-QUIC wiring on loopback UDP sockets (no
// external daemon), pairing a [Server.accept] call against a real [Dialer]
// the same way `test/atomic/nivel_2/quic_go_connection_atomic_tests.dart`
// pairs two `QuicConn`s: two sockets on `InternetAddress.loopbackIPv4`, each
// side's `QuicConn` built directly with mirror-image ciphers so that what
// one seals the other opens.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_qpack/transpiled_qpack.dart';
import 'package:transpiled_quic_go/transpiled_quic_go.dart';
import 'package:transpiled_webtransport_go/transpiled_webtransport_go.dart';

/// Builds a [QuicPacketCipher] from an arbitrary 32-byte secret, mirroring
/// what `transpiled_quic_go`'s handshake does for real 1-RTT secrets.
QuicPacketCipher _cipherFor(Uint8List secret) {
  final (key, iv, hpKey) = computeKeyAndIv(secret);
  return QuicPacketCipher(key: key, iv: iv, hp: AesHeaderProtector(hpKey));
}

Uint8List _secret(int fill) => Uint8List(32)..fillRange(0, 32, fill);

Uint8List _cid(int fill) => Uint8List(8)..fillRange(0, 8, fill);

/// A pair of `QuicConn`s wired over two real loopback UDP sockets, each able
/// to send frames the other can decrypt and process -- the harness
/// [Server.accept] and [Dialer.dial] are driven against below.
class _ConnPair {
  _ConnPair._(this.client, this.server);

  static Future<_ConnPair> create({
    String? clientNegotiatedProtocol = nextProtoH3,
    String? serverNegotiatedProtocol = nextProtoH3,
  }) async {
    final socketA = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final socketB = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );

    final aToB = _cipherFor(_secret(0x11));
    final bToA = _cipherFor(_secret(0x22));
    final aCid = _cid(0xaa);
    final bCid = _cid(0xbb);

    final client = QuicConn(
      socket: socketA,
      remoteAddress: InternetAddress.loopbackIPv4,
      remotePort: socketB.port,
      destConnectionId: bCid,
      srcConnectionId: aCid,
      sendCipher: aToB,
      receiveCipher: bToA,
      perspective: Perspective.client,
      negotiatedProtocol: clientNegotiatedProtocol,
    );
    final server = QuicConn(
      socket: socketB,
      remoteAddress: InternetAddress.loopbackIPv4,
      remotePort: socketA.port,
      destConnectionId: aCid,
      srcConnectionId: bCid,
      sendCipher: bToA,
      receiveCipher: aToB,
      perspective: Perspective.server,
      negotiatedProtocol: serverNegotiatedProtocol,
    );
    return _ConnPair._(client, server);
  }

  final QuicConn client;
  final QuicConn server;

  Future<void> dispose() async {
    await client.close();
    await server.close();
  }
}

/// Drives the client side of the HTTP/3 + Extended CONNECT handshake with
/// arbitrary request [headers], bypassing [Dialer] so a malformed or
/// feature-probing request can be sent to [Server.accept].
Future<void> _sendRawConnect(QuicConn conn, List<HeaderField> headers) async {
  conn.openUniStream().write(
    Uint8List.fromList(
      const Http3SettingsFrame(
        datagram: true,
        other: {settingsWebTransportEnabled: 1},
      ).append(appendVarInt(const [], http3StreamTypeControl)),
    ),
  );
  conn.openUniStream().write(
    appendVarInt(const [], http3StreamTypeQpackEncoder),
  );
  conn.openUniStream().write(
    appendVarInt(const [], http3StreamTypeQpackDecoder),
  );

  final encoder = Encoder();
  final block = BytesBuilder(copy: false);
  for (final field in headers) {
    block.add(encoder.writeField(field));
  }
  encoder.close();
  final headerBlock = block.takeBytes();

  conn.openStream()
    ..write(
      Uint8List.fromList(
        Http3HeadersFrame(headerBlock.length).append(const []),
      ),
    )
    ..write(headerBlock);
}

void main() {
  group('ServerException [Atomic Audit]', () {
    test('ServerException() - carries the message', () {
      const error = ServerException('boom');
      expect(error.message, 'boom');
    });

    test('toString() - includes the message', () {
      const error = ServerException('boom');
      expect(error.toString(), 'ServerException: boom');
    });
  });

  group('Server [Atomic Audit]', () {
    test('Server() - defaults handshakeTimeout to 10 seconds', () {
      const server = Server();
      expect(server.handshakeTimeout, const Duration(seconds: 10));
    });

    test('Server() - accepts a custom handshakeTimeout', () {
      const server = Server(handshakeTimeout: Duration(seconds: 2));
      expect(server.handshakeTimeout, const Duration(seconds: 2));
    });

    test('accept() - throws ServerException when the connection negotiated a '
        'non-h3 ALPN protocol', () async {
      final pair = await _ConnPair.create(serverNegotiatedProtocol: 'spdy/1');
      try {
        await expectLater(
          const Server().accept(conn: pair.server),
          throwsA(isA<ServerException>()),
        );
      } finally {
        await pair.dispose();
      }
    });

    test('accept() - establishes a session and exchanges data with a real '
        'Dialer', () async {
      final pair = await _ConnPair.create();
      try {
        final results = await Future.wait([
          const Server().accept(conn: pair.server),
          const Dialer().dial(
            conn: pair.client,
            authority: 'example.invalid',
            path: '/.well-known/libp2p-webtransport?type=noise',
          ),
        ]);
        final serverSession = results[0];
        final clientSession = results[1];

        expect(serverSession.sessionId, clientSession.sessionId);
        expect(serverSession.sessionId % 4, 0);
        expect(serverSession.applicationProtocol, '');
        expect(clientSession.applicationProtocol, '');

        final clientStream = clientSession.openStream();
        clientStream.write(Uint8List.fromList('ping'.codeUnits));
        final serverStream = await serverSession.acceptStream();
        final received = await serverStream.read();
        expect(String.fromCharCodes(received), 'ping');
      } finally {
        await pair.dispose();
      }
    });

    test('accept() - answers 400 and throws ServerException for a '
        'non-CONNECT method', () async {
      final pair = await _ConnPair.create();
      try {
        final serverFuture = const Server(
          handshakeTimeout: Duration(seconds: 2),
        ).accept(conn: pair.server);
        await _sendRawConnect(pair.client, const [
          HeaderField(name: ':method', value: 'GET'),
          HeaderField(name: ':protocol', value: protocolHeader),
          HeaderField(name: ':scheme', value: 'https'),
          HeaderField(name: ':authority', value: 'example.invalid'),
          HeaderField(name: ':path', value: '/'),
        ]);
        await expectLater(serverFuture, throwsA(isA<ServerException>()));
      } finally {
        await pair.dispose();
      }
    });

    test('accept() - answers 400 and throws ServerException for a bad '
        ':protocol', () async {
      final pair = await _ConnPair.create();
      try {
        final serverFuture = const Server(
          handshakeTimeout: Duration(seconds: 2),
        ).accept(conn: pair.server);
        await _sendRawConnect(pair.client, const [
          HeaderField(name: ':method', value: 'CONNECT'),
          HeaderField(name: ':protocol', value: 'not-webtransport'),
          HeaderField(name: ':scheme', value: 'https'),
          HeaderField(name: ':authority', value: 'example.invalid'),
          HeaderField(name: ':path', value: '/'),
        ]);
        await expectLater(serverFuture, throwsA(isA<ServerException>()));
      } finally {
        await pair.dispose();
      }
    });

    test('accept() - answers 404 and times out waiting for the next request '
        'when acceptPath rejects the path', () async {
      final pair = await _ConnPair.create();
      try {
        final serverFuture = const Server(
          handshakeTimeout: Duration(milliseconds: 300),
        ).accept(conn: pair.server, acceptPath: (path) => false);
        final clientFuture = const Dialer().dial(
          conn: pair.client,
          authority: 'example.invalid',
          path: '/rejected',
        );
        await expectLater(clientFuture, throwsA(isA<DialException>()));
        await expectLater(serverFuture, throwsA(isA<ServerException>()));
      } finally {
        await pair.dispose();
      }
    });

    test('accept() - selects the first protocol offered via '
        'wt-available-protocols', () async {
      final pair = await _ConnPair.create();
      try {
        final serverFuture = const Server().accept(conn: pair.server);
        await _sendRawConnect(pair.client, const [
          HeaderField(name: ':method', value: 'CONNECT'),
          HeaderField(name: ':protocol', value: protocolHeader),
          HeaderField(name: ':scheme', value: 'https'),
          HeaderField(name: ':authority', value: 'example.invalid'),
          HeaderField(name: ':path', value: '/'),
          HeaderField(
            name: wtAvailableProtocolsHeader,
            value: '"chat", "echo"',
          ),
        ]);
        final session = await serverFuture;
        expect(session.applicationProtocol, 'chat');
      } finally {
        await pair.dispose();
      }
    });
  });
}
