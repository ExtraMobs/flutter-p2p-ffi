// Atomic tests (nivel_2: real UDP loopback sockets, no external daemon) for
// the public symbols added to `packages/transpiled_quic_go/lib/src/
// server_handshake.dart`: `QuicServerCertificate`, `QuicServer` and
// `QuicServerClosedException`.
//
// The handshake here never validates a CertificateVerify signature -- only
// the Finished MAC, derived from the transcript, is checked (see the file's
// own doc comment on `_handleClientHandshake`) -- so the certificates below
// are dummy DER/signature bytes rather than real X.509 certificates. That
// mirrors production usage (a real ECDSA signer, per `quic_transport.dart`)
// only in shape, not in cryptographic content, which this layer does not
// itself require.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_quic_go/transpiled_quic_go.dart';

QuicServerCertificate _serverCertificate({int signatureAlgorithm = 0x0403}) =>
    QuicServerCertificate(
      der: Uint8List.fromList([1, 2, 3, 4, 5]),
      sign: (_) async => Uint8List.fromList([6, 7, 8]),
      signatureAlgorithm: signatureAlgorithm,
    );

QuicClientCertificate _clientCertificate() => QuicClientCertificate(
  der: Uint8List.fromList([9, 8, 7]),
  sign: (_) async => Uint8List.fromList([1, 1, 1]),
);

/// Binds a [QuicServer] on loopback and pumps its own socket into it by
/// hand, exactly as a real shared-socket owner (go-libp2p's
/// `p2p/transport/quic/listener.go`, or this repo's `_QuicListener`) is
/// expected to: `QuicServer` never subscribes to the socket itself.
Future<(RawDatagramSocket, QuicServer)> _bindServer({
  required List<String> nextProtos,
  bool requestClientCertificate = false,
  bool enableDatagrams = false,
}) async {
  final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
  final server = QuicServer(
    socket: socket,
    certificate: _serverCertificate(),
    nextProtos: nextProtos,
    requestClientCertificate: requestClientCertificate,
    enableDatagrams: enableDatagrams,
  );
  socket.listen((event) {
    if (event == RawSocketEvent.read) {
      final dg = socket.receive();
      if (dg != null) server.handleDatagram(dg);
    }
  });
  return (socket, server);
}

/// Dials [serverSocket] over a fresh loopback client socket, returning the
/// established connection and the client's own ephemeral port (so tests can
/// check it against the accepted connection's own getters).
Future<(QuicConn, int)> _dialServer(
  RawDatagramSocket serverSocket, {
  required List<String> nextProtos,
  QuicClientCertificate? certificate,
}) async {
  final clientSocket = await RawDatagramSocket.bind(
    InternetAddress.loopbackIPv4,
    0,
  );
  final conn = await dial(
    socket: clientSocket,
    remoteAddress: InternetAddress.loopbackIPv4,
    remotePort: serverSocket.port,
    tlsConfig: QuicTlsConfig(nextProtos: nextProtos, certificate: certificate),
  );
  return (conn, clientSocket.port);
}

void main() {
  group('QuicServer [Atomic Audit]', () {
    test('accept()/handleDatagram() - completes a full handshake, negotiating '
        'ALPN on both sides and exchanging stream data', () async {
      final (serverSocket, server) = await _bindServer(
        nextProtos: const ['x1'],
      );
      addTearDown(() async {
        await server.close();
        serverSocket.close();
      });

      final acceptFuture = server.accept();
      final (clientConn, _) = await _dialServer(
        serverSocket,
        nextProtos: const ['x1'],
      );
      final serverConn = await acceptFuture;

      expect(clientConn.negotiatedProtocol, equals('x1'));
      expect(serverConn.negotiatedProtocol, equals('x1'));
      expect(serverConn.perspective, equals(Perspective.server));
      expect(serverConn.isClosed, isFalse);

      // Opening a QUIC stream sends nothing on the wire (RFC 9000 s. 2.1):
      // the peer only learns a stream exists once a frame for it arrives.
      // So the opener must write first, then the peer's acceptStream()
      // completes.
      final clientStream = clientConn.openStream();
      final serverStreamFuture = serverConn.acceptStream();
      clientStream.write(Uint8List.fromList(utf8.encode('ping')));
      final serverStream = await serverStreamFuture;
      expect(utf8.decode(await serverStream.read()), equals('ping'));

      serverStream.write(Uint8List.fromList(utf8.encode('pong')));
      expect(utf8.decode(await clientStream.read()), equals('pong'));

      await clientConn.close();
      await serverConn.close();
    });

    test('requestClientCertificate: true - server sees the client certificate '
        'chain', () async {
      final (serverSocket, server) = await _bindServer(
        nextProtos: const ['x1'],
        requestClientCertificate: true,
      );
      addTearDown(() async {
        await server.close();
        serverSocket.close();
      });
      expect(server.requestClientCertificate, isTrue);

      final acceptFuture = server.accept();
      final (clientConn, _) = await _dialServer(
        serverSocket,
        nextProtos: const ['x1'],
        certificate: _clientCertificate(),
      );
      final serverConn = await acceptFuture;

      expect(serverConn.peerCertificates, isNotEmpty);
      expect(
        serverConn.peerCertificates.single,
        orderedEquals(const [9, 8, 7]),
      );

      await clientConn.close();
      await serverConn.close();
    });

    test('requestClientCertificate: false - completes with an empty peer '
        'certificate chain', () async {
      final (serverSocket, server) = await _bindServer(
        nextProtos: const ['x1'],
      );
      addTearDown(() async {
        await server.close();
        serverSocket.close();
      });
      expect(server.requestClientCertificate, isFalse);
      expect(server.enableDatagrams, isFalse);

      final acceptFuture = server.accept();
      final (clientConn, _) = await _dialServer(
        serverSocket,
        nextProtos: const ['x1'],
      );
      final serverConn = await acceptFuture;

      expect(serverConn.peerCertificates, isEmpty);

      await clientConn.close();
      await serverConn.close();
    });

    test('accept() - the accepted connection reports the endpoint it was '
        'dialled from', () async {
      final (serverSocket, server) = await _bindServer(
        nextProtos: const ['x1'],
      );
      addTearDown(() async {
        await server.close();
        serverSocket.close();
      });

      final acceptFuture = server.accept();
      final (clientConn, clientPort) = await _dialServer(
        serverSocket,
        nextProtos: const ['x1'],
      );
      final serverConn = await acceptFuture;

      expect(serverConn.remoteAddress, equals(InternetAddress.loopbackIPv4));
      expect(serverConn.remotePort, equals(clientPort));
      expect(clientConn.remotePort, equals(serverSocket.port));
    });

    test(
      'close() - fails a pending accept() with QuicServerClosedException',
      () async {
        final (serverSocket, server) = await _bindServer(
          nextProtos: const ['x1'],
        );
        addTearDown(() => serverSocket.close());

        final acceptFuture = server.accept();
        // Attach the matcher before closing: `close()` completes the pending
        // accept's error synchronously, and a future with no listener yet
        // when that happens is reported as an unhandled error instead of
        // being caught by the matcher below.
        final expectation = expectLater(
          acceptFuture,
          throwsA(isA<QuicServerClosedException>()),
        );
        await server.close();
        await expectation;
      },
    );

    test(
      'close() - accept() throws QuicServerClosedException afterwards',
      () async {
        final (serverSocket, server) = await _bindServer(
          nextProtos: const ['x1'],
        );
        addTearDown(() => serverSocket.close());

        await server.close();
        expect(
          () => server.accept(),
          throwsA(isA<QuicServerClosedException>()),
        );
      },
    );

    test('close() - closes every connection it had accepted', () async {
      final (serverSocket, server) = await _bindServer(
        nextProtos: const ['x1'],
      );
      addTearDown(() => serverSocket.close());

      final acceptFuture = server.accept();
      final (clientConn, _) = await _dialServer(
        serverSocket,
        nextProtos: const ['x1'],
      );
      final serverConn = await acceptFuture;
      expect(serverConn.isClosed, isFalse);

      await server.close();
      expect(serverConn.isClosed, isTrue);
      await clientConn.close();
    });

    test('handleDatagram() - drops a garbage datagram without crashing, and '
        'still accepts a real handshake afterwards', () async {
      final (serverSocket, server) = await _bindServer(
        nextProtos: const ['x1'],
      );
      addTearDown(() async {
        await server.close();
        serverSocket.close();
      });

      final probe = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(probe.close);

      // A long-header first byte with no valid QUIC structure behind it:
      // too short to hold a connection-ID length, token or payload length.
      probe.send(
        Uint8List.fromList([0xc0, 0, 0, 0, 1, 0]),
        InternetAddress.loopbackIPv4,
        serverSocket.port,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final acceptFuture = server.accept();
      final (clientConn, _) = await _dialServer(
        serverSocket,
        nextProtos: const ['x1'],
      );
      final serverConn = await acceptFuture;
      expect(serverConn.negotiatedProtocol, equals('x1'));

      await clientConn.close();
      await serverConn.close();
    });
  });

  group('QuicServerClosedException [Atomic Audit]', () {
    test('QuicServerClosedException() - default message', () {
      const error = QuicServerClosedException();
      expect(error.message, equals('QUIC server is closed'));
    });

    test('QuicServerClosedException() - custom message', () {
      const error = QuicServerClosedException('nope');
      expect(error.message, equals('nope'));
    });

    test('toString() - includes the message', () {
      const error = QuicServerClosedException('nope');
      expect(error.toString(), equals('QuicServerClosedException: nope'));
    });
  });
}
