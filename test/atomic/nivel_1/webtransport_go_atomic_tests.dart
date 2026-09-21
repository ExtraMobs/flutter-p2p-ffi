// Atomic tests for the public symbols of `transpiled_webtransport_go` that
// `webtransport_go_server_atomic_tests.dart` does not already cover:
// `DialException`, `Dialer.dial`, `isWebTransportProtocol`,
// `isValidSessionId`, `SessionClosedException`, `Session` and
// `SessionStream`.
//
// `Session`/`SessionStream` are exercised directly over a pair of real
// `QuicConn`s on loopback UDP, the same rig
// `webtransport_go_server_atomic_tests.dart` uses for `Server`/`Dialer`
// (`_ConnPair`, duplicated here because it is private there and cannot be
// imported). Going through `Session`'s public constructor skips the HTTP/3
// Extended CONNECT dance entirely -- appropriate here, since none of these
// symbols perform it -- and `Dialer.dial` gets its own pairing against a real
// `Server` for the one test that does.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
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

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

/// A pair of `QuicConn`s wired over two real loopback UDP sockets, each able
/// to send frames the other can decrypt and process.
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

/// A pair of [Session]s sharing session id [sessionId] over a fresh
/// [_ConnPair], built straight from `Session`'s public constructor so the
/// HTTP/3 Extended CONNECT handshake -- irrelevant to what `Session` and
/// `SessionStream` themselves do -- never has to run.
class _SessionPair {
  _SessionPair._(this.pair, this.client, this.server);

  static Future<_SessionPair> create({int sessionId = 0}) async {
    final pair = await _ConnPair.create();
    final client = Session(
      conn: pair.client,
      sessionId: sessionId,
      requestStream: pair.client.openStream(),
    );
    final server = Session(
      conn: pair.server,
      sessionId: sessionId,
      requestStream: pair.server.openStream(),
    );
    return _SessionPair._(pair, client, server);
  }

  final _ConnPair pair;
  final Session client;
  final Session server;

  Future<void> dispose() async {
    await client.close();
    await pair.dispose();
  }
}

void main() {
  group('DialException [Atomic Audit]', () {
    test('toString() - includes the message', () {
      const error = DialException('boom');
      expect(error.toString(), 'DialException: boom');
    });
  });

  group('SessionClosedException [Atomic Audit]', () {
    test('toString() - includes a custom message', () {
      const error = SessionClosedException('custom reason');
      expect(error.toString(), 'SessionClosedException: custom reason');
    });

    test('toString() - defaults to a generic message', () {
      const error = SessionClosedException();
      expect(
        error.toString(),
        'SessionClosedException: WebTransport session closed',
      );
    });
  });

  group('functions - WebTransport protocol [Atomic Audit]', () {
    test('isWebTransportProtocol() - true for the current protocol header', () {
      expect(isWebTransportProtocol(protocolHeader), isTrue);
    });

    test('isWebTransportProtocol() - true for the legacy protocol header', () {
      expect(isWebTransportProtocol(protocolHeaderLegacy), isTrue);
    });

    test('isWebTransportProtocol() - false for an unrelated value', () {
      expect(isWebTransportProtocol('h2'), isFalse);
    });

    test('isValidSessionId() - true for stream ids divisible by four', () {
      expect(isValidSessionId(0), isTrue);
      expect(isValidSessionId(4), isTrue);
      expect(isValidSessionId(400), isTrue);
    });

    test('isValidSessionId() - false for stream ids not divisible by four', () {
      expect(isValidSessionId(1), isFalse);
      expect(isValidSessionId(2), isFalse);
      expect(isValidSessionId(7), isFalse);
    });
  });

  group('Dialer [Atomic Audit]', () {
    test('dial() - completes the Extended CONNECT handshake against a real '
        'Server', () async {
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

        expect(clientSession.sessionId, serverSession.sessionId);
        expect(isValidSessionId(clientSession.sessionId), isTrue);
      } finally {
        await pair.dispose();
      }
    });

    test('dial() - throws DialException when the connection negotiated a '
        'non-h3 ALPN protocol', () async {
      final pair = await _ConnPair.create(clientNegotiatedProtocol: 'spdy/1');
      try {
        await expectLater(
          const Dialer().dial(
            conn: pair.client,
            authority: 'example.invalid',
            path: '/',
          ),
          throwsA(isA<DialException>()),
        );
      } finally {
        await pair.dispose();
      }
    });
  });

  group('Session [Atomic Audit]', () {
    test('conn - returns the QuicConn given at construction', () async {
      final sessions = await _SessionPair.create();
      try {
        expect(identical(sessions.client.conn, sessions.pair.client), isTrue);
      } finally {
        await sessions.dispose();
      }
    });

    test(
      'isClosed - false right after construction, true after close()',
      () async {
        final sessions = await _SessionPair.create();
        expect(sessions.client.isClosed, isFalse);
        await sessions.dispose();
        expect(sessions.client.isClosed, isTrue);
      },
    );

    test(
      'isClosed - true once the underlying QuicConn alone is closed',
      () async {
        final sessions = await _SessionPair.create();
        try {
          await sessions.pair.client.close();
          expect(sessions.client.isClosed, isTrue);
        } finally {
          await sessions.pair.server.close();
        }
      },
    );

    test('openStream() - opens a stream the peer receives via '
        'acceptStream()', () async {
      final sessions = await _SessionPair.create();
      try {
        final clientStream = sessions.client.openStream();
        final serverStream = await sessions.server.acceptStream();
        expect(serverStream.id, clientStream.id);
      } finally {
        await sessions.dispose();
      }
    });

    test('openStream() - throws SessionClosedException once the session is '
        'closed', () async {
      final sessions = await _SessionPair.create();
      await sessions.dispose();
      expect(
        () => sessions.client.openStream(),
        throwsA(isA<SessionClosedException>()),
      );
    });

    test('openUniStream() - writes the uni-stream header signal the peer '
        'observes as a raw QUIC uni stream', () async {
      final sessions = await _SessionPair.create();
      try {
        final uniStream = sessions.client.openUniStream();
        uniStream.write(_bytes('hi'));
        final rawPeerStream = await sessions.pair.server.acceptUniStream();
        // webTransportUniStreamType (0x54) needs a 2-byte QUIC varint, since
        // it is greater than the 1-byte range's 0x3f ceiling.
        final header = await rawPeerStream.readExactly(2);
        final (signal, _) = parseVarInt(header);
        expect(signal, webTransportUniStreamType);
      } finally {
        await sessions.dispose();
      }
    });

    test('openUniStream() - throws SessionClosedException once the session '
        'is closed', () async {
      final sessions = await _SessionPair.create();
      await sessions.dispose();
      expect(
        () => sessions.client.openUniStream(),
        throwsA(isA<SessionClosedException>()),
      );
    });

    test(
      'acceptStream() - resolves once the peer opens a matching stream',
      () async {
        final sessions = await _SessionPair.create();
        try {
          final clientStream = sessions.client.openStream();
          clientStream.write(_bytes('ping'));
          final serverStream = await sessions.server.acceptStream();
          final received = await serverStream.read();
          expect(String.fromCharCodes(received), 'ping');
        } finally {
          await sessions.dispose();
        }
      },
    );

    test('acceptStream() - returns an already-arrived stream from the '
        'pending queue without waiting again', () async {
      final sessions = await _SessionPair.create();
      try {
        final clientStream = sessions.client.openStream();
        clientStream.write(_bytes('x'));
        // Give the event loop a turn so the header reaches the server side
        // and lands in the pending queue before acceptStream() is called.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        final serverStream = await sessions.server.acceptStream();
        expect(serverStream.id, clientStream.id);
      } finally {
        await sessions.dispose();
      }
    });

    test('acceptStream() - throws SessionClosedException when the session '
        'is already closed', () async {
      final sessions = await _SessionPair.create();
      await sessions.dispose();
      expect(
        () => sessions.client.acceptStream(),
        throwsA(isA<SessionClosedException>()),
      );
    });

    test('close() - fails pending acceptStream() waiters with '
        'SessionClosedException', () async {
      final sessions = await _SessionPair.create();
      final pending = sessions.server.acceptStream();
      // Attach the expectation before close() so the completer's error,
      // fired synchronously inside close(), always has a listener already
      // waiting -- otherwise it can race Dart's unhandled-error reporting.
      final expectation = expectLater(
        pending,
        throwsA(isA<SessionClosedException>()),
      );
      await sessions.server.close();
      await expectation;
      await sessions.pair.client.close();
    });

    test(
      'close() - is idempotent and closes the underlying QuicConn',
      () async {
        final sessions = await _SessionPair.create();
        await sessions.client.close();
        await sessions.client.close(); // must not throw the second time.
        expect(sessions.pair.client.isClosed, isTrue);
        await sessions.pair.server.close();
      },
    );
  });

  group('SessionStream [Atomic Audit]', () {
    test('id - matches the underlying QUIC stream id', () async {
      final sessions = await _SessionPair.create();
      try {
        final clientStream = sessions.client.openStream();
        final serverStream = await sessions.server.acceptStream();
        expect(serverStream.id, clientStream.id);
      } finally {
        await sessions.dispose();
      }
    });

    test('write() - sends data the peer receives via read()', () async {
      final sessions = await _SessionPair.create();
      try {
        final clientStream = sessions.client.openStream();
        clientStream.write(_bytes('hello'));
        final serverStream = await sessions.server.acceptStream();
        final received = await serverStream.read();
        expect(String.fromCharCodes(received), 'hello');
      } finally {
        await sessions.dispose();
      }
    });

    test(
      'read() - returns an empty list once the peer closes writing',
      () async {
        final sessions = await _SessionPair.create();
        try {
          final clientStream = sessions.client.openStream();
          clientStream.write(_bytes('a'));
          clientStream.closeWrite();
          final serverStream = await sessions.server.acceptStream();
          await serverStream.read(); // drains 'a'.
          final eof = await serverStream.read();
          expect(eof, isEmpty);
        } finally {
          await sessions.dispose();
        }
      },
    );

    test('readExactly() - leaves surplus bytes for a later read()', () async {
      final sessions = await _SessionPair.create();
      try {
        final clientStream = sessions.client.openStream();
        clientStream.write(_bytes('abcdef'));
        final serverStream = await sessions.server.acceptStream();
        final first = await serverStream.readExactly(3);
        expect(String.fromCharCodes(first), 'abc');
        final rest = await serverStream.read();
        expect(String.fromCharCodes(rest), 'def');
      } finally {
        await sessions.dispose();
      }
    });

    test(
      'readExactly() - reassembles bytes delivered across two writes',
      () async {
        final sessions = await _SessionPair.create();
        try {
          final clientStream = sessions.client.openStream();
          clientStream.write(_bytes('abc'));
          final serverStream = await sessions.server.acceptStream();
          clientStream.write(_bytes('def'));
          final bytes = await serverStream.readExactly(6);
          expect(String.fromCharCodes(bytes), 'abcdef');
        } finally {
          await sessions.dispose();
        }
      },
    );

    test('readExactly() - throws SessionClosedException when the stream '
        'ends before enough bytes arrive', () async {
      final sessions = await _SessionPair.create();
      try {
        final clientStream = sessions.client.openStream();
        clientStream.write(_bytes('ab'));
        clientStream.closeWrite();
        final serverStream = await sessions.server.acceptStream();
        await expectLater(
          serverStream.readExactly(10),
          throwsA(isA<SessionClosedException>()),
        );
      } finally {
        await sessions.dispose();
      }
    });

    test('closeWrite() - lets the peer observe end of stream after reading '
        'the remaining data', () async {
      final sessions = await _SessionPair.create();
      try {
        final clientStream = sessions.client.openStream();
        clientStream.write(_bytes('done'));
        clientStream.closeWrite();
        final serverStream = await sessions.server.acceptStream();
        final received = await serverStream.read();
        expect(String.fromCharCodes(received), 'done');
        expect(await serverStream.read(), isEmpty);
      } finally {
        await sessions.dispose();
      }
    });

    test('reset() - abandons the stream, so the peer observes '
        'StreamResetException on read()', () async {
      final sessions = await _SessionPair.create();
      try {
        final clientStream = sessions.client.openStream();
        clientStream.write(_bytes('x'));
        final serverStream = await sessions.server.acceptStream();
        await serverStream.read(); // drains 'x' so the next read() blocks.
        final pendingRead = serverStream.read();
        clientStream.reset(7);
        await expectLater(pendingRead, throwsA(isA<StreamResetException>()));
      } finally {
        await sessions.dispose();
      }
    });
  });
}
