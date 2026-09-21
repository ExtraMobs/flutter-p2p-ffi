// Atomic tests (nivel_2: real UDP loopback sockets, no external daemon) for
// the public symbols added to `packages/transpiled_quic_go/lib/src/`:
// `connection.dart`, `client_handshake.dart` and the new
// `maxDatagramFrameSize` transport parameter in `transport_parameters.dart`.
//
// These files are not yet re-exported by the package barrel
// (`transpiled_quic_go.dart`), so they are imported directly from `src/`,
// which is why `implementation_imports` is expected here.
// ignore_for_file: implementation_imports
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_quic_go/src/client_handshake.dart';
import 'package:transpiled_quic_go/src/connection.dart';
import 'package:transpiled_quic_go/src/frames.dart';
import 'package:transpiled_quic_go/src/header.dart';
import 'package:transpiled_quic_go/src/initial_aead.dart';
import 'package:transpiled_quic_go/src/transport_parameters.dart';

/// Builds a [QuicPacketCipher] from an arbitrary 32-byte secret, mirroring
/// what `client_handshake.dart`'s private `_cipherFor` does for real 1-RTT
/// secrets.
QuicPacketCipher _cipherFor(Uint8List secret) {
  final (key, iv, hpKey) = computeKeyAndIv(secret);
  return QuicPacketCipher(key: key, iv: iv, hp: AesHeaderProtector(hpKey));
}

Uint8List _secret(int fill) => Uint8List(32)..fillRange(0, 32, fill);

Uint8List _cid(int fill) => Uint8List(8)..fillRange(0, 8, fill);

/// A pair of QuicConn wired over two real loopback UDP sockets, each able to
/// send frames the other can decrypt and process.
class _ConnPair {
  _ConnPair._(this.client, this.server);

  static Future<_ConnPair> create() async {
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

/// Polls [condition] until it holds, so a test can wait for a datagram that
/// the socket delivers asynchronously without sleeping a fixed amount.
Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 200; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  throw StateError('condition never became true');
}

void main() {
  group('Perspective [Atomic Audit]', () {
    test('Perspective - has exactly client and server values', () {
      expect(Perspective.values, [Perspective.client, Perspective.server]);
    });
  });

  group('ConnectionClosedException [Atomic Audit]', () {
    test('ConnectionClosedException() - default message', () {
      const error = ConnectionClosedException();
      expect(error.message, 'QUIC connection is closed');
    });

    test('ConnectionClosedException() - custom message', () {
      const error = ConnectionClosedException('gone');
      expect(error.message, 'gone');
    });

    test('toString() - includes the message', () {
      const error = ConnectionClosedException('gone');
      expect(error.toString(), 'ConnectionClosedException: gone');
    });
  });

  group('StreamResetException [Atomic Audit]', () {
    test('StreamResetException() - carries streamId and errorCode', () {
      const error = StreamResetException(7, 42);
      expect(error.streamId, 7);
      expect(error.errorCode, 42);
    });

    test('StreamResetException.toString() - describes the reset', () {
      const error = StreamResetException(7, 42);
      expect(
        error.toString(),
        'StreamResetException: stream 7 reset with code 42',
      );
    });
  });

  group('QuicConn [Atomic Audit]', () {
    test('streamIdFor() - client bidirectional starts at 0 and steps by 4', () {
      expect(
        QuicConn.streamIdFor(
          streamNumber: 0,
          initiator: Perspective.client,
          unidirectional: false,
        ),
        0,
      );
      expect(
        QuicConn.streamIdFor(
          streamNumber: 1,
          initiator: Perspective.client,
          unidirectional: false,
        ),
        4,
      );
      expect(
        QuicConn.streamIdFor(
          streamNumber: 2,
          initiator: Perspective.client,
          unidirectional: false,
        ),
        8,
      );
    });

    test(
      'streamIdFor() - client unidirectional starts at 2 and steps by 4',
      () {
        expect(
          QuicConn.streamIdFor(
            streamNumber: 0,
            initiator: Perspective.client,
            unidirectional: true,
          ),
          2,
        );
        expect(
          QuicConn.streamIdFor(
            streamNumber: 1,
            initiator: Perspective.client,
            unidirectional: true,
          ),
          6,
        );
        expect(
          QuicConn.streamIdFor(
            streamNumber: 2,
            initiator: Perspective.client,
            unidirectional: true,
          ),
          10,
        );
      },
    );

    test('streamIdFor() - server bidirectional starts at 1 and steps by 4', () {
      expect(
        QuicConn.streamIdFor(
          streamNumber: 0,
          initiator: Perspective.server,
          unidirectional: false,
        ),
        1,
      );
      expect(
        QuicConn.streamIdFor(
          streamNumber: 1,
          initiator: Perspective.server,
          unidirectional: false,
        ),
        5,
      );
      expect(
        QuicConn.streamIdFor(
          streamNumber: 2,
          initiator: Perspective.server,
          unidirectional: false,
        ),
        9,
      );
    });

    test(
      'streamIdFor() - server unidirectional starts at 3 and steps by 4',
      () {
        expect(
          QuicConn.streamIdFor(
            streamNumber: 0,
            initiator: Perspective.server,
            unidirectional: true,
          ),
          3,
        );
        expect(
          QuicConn.streamIdFor(
            streamNumber: 1,
            initiator: Perspective.server,
            unidirectional: true,
          ),
          7,
        );
        expect(
          QuicConn.streamIdFor(
            streamNumber: 2,
            initiator: Perspective.server,
            unidirectional: true,
          ),
          11,
        );
      },
    );
  });

  group('QuicConn [Atomic Audit]', () {
    test('isUnidirectional() - matches RFC 9000 section 2.1 table', () {
      // client bidi 0, client uni 2, server bidi 1, server uni 3.
      expect(QuicConn.isUnidirectional(0), isFalse);
      expect(QuicConn.isUnidirectional(1), isFalse);
      expect(QuicConn.isUnidirectional(2), isTrue);
      expect(QuicConn.isUnidirectional(3), isTrue);
      expect(QuicConn.isUnidirectional(8), isFalse);
      expect(QuicConn.isUnidirectional(10), isTrue);
    });
  });

  group('QuicConn [Atomic Audit]', () {
    test('initiatorOf() - matches RFC 9000 section 2.1 table', () {
      expect(QuicConn.initiatorOf(0), Perspective.client);
      expect(QuicConn.initiatorOf(1), Perspective.server);
      expect(QuicConn.initiatorOf(2), Perspective.client);
      expect(QuicConn.initiatorOf(3), Perspective.server);
      expect(QuicConn.initiatorOf(9), Perspective.server);
      expect(QuicConn.initiatorOf(4), Perspective.client);
    });
  });

  group('QuicConn [Atomic Audit]', () {
    test(
      'QuicConn() - exposes perspective, ownsSocket and peerCertificates',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        expect(pair.client.perspective, Perspective.client);
        expect(pair.server.perspective, Perspective.server);
        expect(pair.client.ownsSocket, isTrue);
        expect(pair.client.peerCertificates, isEmpty);
        expect(pair.client.negotiatedProtocol, isNull);
      },
    );

    test(
      'QuicConn() - carries the peerCertificates and negotiatedProtocol given to it',
      () async {
        final socket = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(socket.close);
        final cipher = _cipherFor(_secret(0x33));
        final cert = Uint8List.fromList([1, 2, 3]);
        final conn = QuicConn(
          socket: socket,
          remoteAddress: InternetAddress.loopbackIPv4,
          remotePort: socket.port,
          destConnectionId: _cid(0x01),
          srcConnectionId: _cid(0x02),
          sendCipher: cipher,
          receiveCipher: cipher,
          perspective: Perspective.client,
          peerCertificates: [cert],
          negotiatedProtocol: 'libp2p',
          ownsSocket: false,
        );
        addTearDown(conn.close);

        expect(conn.peerCertificates.single, orderedEquals([1, 2, 3]));
        expect(conn.negotiatedProtocol, 'libp2p');
        expect(conn.ownsSocket, isFalse);
        expect(
          () => conn.peerCertificates.add(Uint8List(0)),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );

    test('destConnectionId getter - returns a defensive copy', () async {
      final pair = await _ConnPair.create();
      addTearDown(pair.dispose);

      final first = pair.client.destConnectionId;
      first[0] = 0xff;
      final second = pair.client.destConnectionId;
      expect(second[0], isNot(0xff));
    });

    test('srcConnectionId getter - returns a defensive copy', () async {
      final pair = await _ConnPair.create();
      addTearDown(pair.dispose);

      final first = pair.client.srcConnectionId;
      first[0] = 0xff;
      final second = pair.client.srcConnectionId;
      expect(second[0], isNot(0xff));
    });

    test('isClosed getter - false before close(), true after', () async {
      final pair = await _ConnPair.create();
      expect(pair.client.isClosed, isFalse);
      await pair.client.close();
      expect(pair.client.isClosed, isTrue);
      await pair.server.close();
    });

    test(
      'openStreamCount - tracks locally and remotely opened streams',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        expect(pair.client.openStreamCount, 0);
        pair.client.openStream();
        expect(pair.client.openStreamCount, 1);
        pair.client.openUniStream();
        expect(pair.client.openStreamCount, 2);
      },
    );

    test(
      'openStreamCount - drops to zero once the connection is closed',
      () async {
        final pair = await _ConnPair.create();
        pair.client.openStream();
        expect(pair.client.openStreamCount, 1);
        await pair.client.close();
        expect(pair.client.openStreamCount, 0);
        await pair.server.close();
      },
    );

    test(
      'openStream() - throws ConnectionClosedException once closed',
      () async {
        final pair = await _ConnPair.create();
        await pair.client.close();
        expect(
          () => pair.client.openStream(),
          throwsA(isA<ConnectionClosedException>()),
        );
        await pair.server.close();
      },
    );

    test(
      'openStream()/acceptStream() - the peer receives a matching bidirectional stream over a real socket',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final acceptFuture = pair.server.acceptStream();
        final clientStream = pair.client.openStream();
        clientStream.write(Uint8List.fromList(utf8.encode('hello')), fin: true);

        final serverStream = await acceptFuture.timeout(
          const Duration(seconds: 5),
        );
        expect(serverStream.id, clientStream.id);
        final received = await serverStream.read().timeout(
          const Duration(seconds: 5),
        );
        expect(utf8.decode(received), 'hello');
      },
    );

    test(
      'openUniStream()/acceptUniStream() - the peer receives a matching unidirectional stream',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final acceptFuture = pair.server.acceptUniStream();
        final clientStream = pair.client.openUniStream();
        expect(QuicConn.isUnidirectional(clientStream.id), isTrue);
        clientStream.write(Uint8List.fromList(utf8.encode('uni')), fin: true);

        final serverStream = await acceptFuture.timeout(
          const Duration(seconds: 5),
        );
        expect(serverStream.id, clientStream.id);
        expect(serverStream.writable, isFalse);
        expect(serverStream.readable, isTrue);
        final received = await serverStream.read().timeout(
          const Duration(seconds: 5),
        );
        expect(utf8.decode(received), 'uni');
      },
    );

    test(
      'acceptStream() - throws ConnectionClosedException once closed',
      () async {
        final pair = await _ConnPair.create();
        await pair.client.close();
        expect(
          () => pair.client.acceptStream(),
          throwsA(isA<ConnectionClosedException>()),
        );
        await pair.server.close();
      },
    );

    test(
      'acceptUniStream() - throws ConnectionClosedException once closed',
      () async {
        final pair = await _ConnPair.create();
        await pair.client.close();
        expect(
          () => pair.client.acceptUniStream(),
          throwsA(isA<ConnectionClosedException>()),
        );
        await pair.server.close();
      },
    );

    test(
      'handleDatagram() - reassembles STREAM frames delivered out of order by offset',
      () async {
        final socket = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(socket.close);
        final cipher = _cipherFor(_secret(0x44));
        final srcId = _cid(0x55);
        final conn = QuicConn(
          socket: socket,
          remoteAddress: InternetAddress.loopbackIPv4,
          remotePort: socket.port,
          destConnectionId: _cid(0x66),
          srcConnectionId: srcId,
          sendCipher: cipher,
          receiveCipher: cipher,
          perspective: Perspective.server,
        );
        addTearDown(conn.close);

        final streamId = QuicConn.streamIdFor(
          streamNumber: 0,
          initiator: Perspective.client,
          unidirectional: false,
        );

        var pn = 0;
        Uint8List packetFor(QuicFrame frame) {
          final header = ExtendedHeader(
            isLongHeader: false,
            destConnectionId: srcId,
            packetNumber: pn++,
            packetNumberLen: 4,
          );
          return cipher.seal(header: header, payload: frame.encode());
        }

        final secondHalf = packetFor(
          StreamFrame(
            streamId: streamId,
            offset: 5,
            data: Uint8List.fromList(utf8.encode('world')),
            fin: true,
          ),
        );
        final firstHalf = packetFor(
          StreamFrame(
            streamId: streamId,
            offset: 0,
            data: Uint8List.fromList(utf8.encode('hello')),
            fin: false,
          ),
        );

        final acceptFuture = conn.acceptStream();
        conn.handleDatagram(secondHalf);
        final stream = await acceptFuture.timeout(const Duration(seconds: 2));
        // The gap at offset 0 is still open: nothing has been reassembled yet.
        expect(stream.readOffset, 0);

        conn.handleDatagram(firstHalf);
        final data = await stream.read().timeout(const Duration(seconds: 2));
        expect(utf8.decode(data), 'helloworld');
        expect(stream.readOffset, 10);
      },
    );

    test(
      'handleDatagram() - a retransmitted STREAM frame does not duplicate bytes',
      () async {
        final socket = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(socket.close);
        final cipher = _cipherFor(_secret(0x77));
        final srcId = _cid(0x88);
        final conn = QuicConn(
          socket: socket,
          remoteAddress: InternetAddress.loopbackIPv4,
          remotePort: socket.port,
          destConnectionId: _cid(0x99),
          srcConnectionId: srcId,
          sendCipher: cipher,
          receiveCipher: cipher,
          perspective: Perspective.server,
        );
        addTearDown(conn.close);

        final streamId = QuicConn.streamIdFor(
          streamNumber: 0,
          initiator: Perspective.client,
          unidirectional: false,
        );
        final header = ExtendedHeader(
          isLongHeader: false,
          destConnectionId: srcId,
          packetNumber: 0,
          packetNumberLen: 4,
        );
        final packet = cipher.seal(
          header: header,
          payload: StreamFrame(
            streamId: streamId,
            offset: 0,
            data: Uint8List.fromList(utf8.encode('hello')),
            fin: false,
          ).encode(),
        );

        final acceptFuture = conn.acceptStream();
        conn.handleDatagram(packet);
        // Retransmission/duplicate delivery of the exact same datagram.
        conn.handleDatagram(packet);

        final stream = await acceptFuture.timeout(const Duration(seconds: 2));
        expect(stream.readOffset, 5);
        final data = await stream.read().timeout(const Duration(seconds: 2));
        expect(utf8.decode(data), 'hello');
      },
    );

    test(
      'sendFrames() - a stream reset delivers StreamResetException to the peer',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final acceptFuture = pair.server.acceptStream();
        final clientStream = pair.client.openStream();
        clientStream.write(Uint8List.fromList(utf8.encode('x')));
        final serverStream = await acceptFuture.timeout(
          const Duration(seconds: 5),
        );
        await serverStream.read().timeout(const Duration(seconds: 5));

        clientStream.reset(9);
        await expectLater(
          serverStream.read(),
          throwsA(
            isA<StreamResetException>().having(
              (e) => e.errorCode,
              'errorCode',
              9,
            ),
          ),
        );
      },
    );

    test(
      'close() - closes every open stream with ConnectionClosedException',
      () async {
        final pair = await _ConnPair.create();
        final clientStream = pair.client.openStream();
        final serverAccept = pair.server.acceptStream();
        clientStream.write(Uint8List.fromList(utf8.encode('x')));
        await serverAccept.timeout(const Duration(seconds: 5));

        await pair.client.close();
        expect(
          () => clientStream.read(),
          throwsA(isA<ConnectionClosedException>()),
        );
        await pair.server.close();
      },
    );

    test(
      'close() - ownsSocket false leaves the underlying socket usable',
      () async {
        final socket = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        addTearDown(socket.close);
        final cipher = _cipherFor(_secret(0xaa));
        final conn = QuicConn(
          socket: socket,
          remoteAddress: InternetAddress.loopbackIPv4,
          remotePort: socket.port,
          destConnectionId: _cid(0x01),
          srcConnectionId: _cid(0x02),
          sendCipher: cipher,
          receiveCipher: cipher,
          perspective: Perspective.client,
          ownsSocket: false,
        );

        await conn.close();
        expect(
          () => socket.send(
            Uint8List(1),
            InternetAddress.loopbackIPv4,
            socket.port,
          ),
          returnsNormally,
        );
      },
    );
  });

  group('QuicStream [Atomic Audit]', () {
    test(
      'QuicStream fields - id, writable and readable reflect how the stream was opened',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final bidi = pair.client.openStream();
        expect(bidi.writable, isTrue);
        expect(bidi.readable, isTrue);

        final uni = pair.client.openUniStream();
        expect(uni.writable, isTrue);
        expect(uni.readable, isFalse);
      },
    );

    test(
      'isFinished - false until the peer\'s fin has been fully read',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final acceptFuture = pair.server.acceptStream();
        final clientStream = pair.client.openStream();
        clientStream.write(Uint8List.fromList(utf8.encode('hi')), fin: true);
        final serverStream = await acceptFuture.timeout(
          const Duration(seconds: 5),
        );

        expect(serverStream.isFinished, isFalse);
        await serverStream.read().timeout(const Duration(seconds: 5));
        // One more read drains the empty fin chunk.
        await serverStream.read().timeout(const Duration(seconds: 5));
        expect(serverStream.isFinished, isTrue);
      },
    );

    test('writeOffset - grows by the number of bytes written', () async {
      final pair = await _ConnPair.create();
      addTearDown(pair.dispose);

      final stream = pair.client.openStream();
      expect(stream.writeOffset, 0);
      stream.write(Uint8List.fromList(utf8.encode('abc')));
      expect(stream.writeOffset, 3);
      stream.write(Uint8List.fromList(utf8.encode('de')));
      expect(stream.writeOffset, 5);
    });

    test('readOffset - grows as in-order bytes are reassembled', () async {
      final pair = await _ConnPair.create();
      addTearDown(pair.dispose);

      final acceptFuture = pair.server.acceptStream();
      final clientStream = pair.client.openStream();
      clientStream.write(Uint8List.fromList(utf8.encode('abcde')));
      final serverStream = await acceptFuture.timeout(
        const Duration(seconds: 5),
      );
      await serverStream.read().timeout(const Duration(seconds: 5));
      expect(serverStream.readOffset, 5);
    });

    test(
      'read() - throws StateError on a send-only (unidirectional local) stream',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final uni = pair.client.openUniStream();
        expect(() => uni.read(), throwsA(isA<StateError>()));
      },
    );

    test(
      'read() - resolves to an empty chunk once the peer finishes',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final acceptFuture = pair.server.acceptStream();
        final clientStream = pair.client.openStream();
        clientStream.write(Uint8List(0), fin: true);
        final serverStream = await acceptFuture.timeout(
          const Duration(seconds: 5),
        );
        final chunk = await serverStream.read().timeout(
          const Duration(seconds: 5),
        );
        expect(chunk, isEmpty);
      },
    );

    test(
      'readExactly() - assembles exactly the requested number of bytes',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final acceptFuture = pair.server.acceptStream();
        final clientStream = pair.client.openStream();
        clientStream.write(Uint8List.fromList(utf8.encode('hello world')));
        final serverStream = await acceptFuture.timeout(
          const Duration(seconds: 5),
        );

        final firstFive = await serverStream
            .readExactly(5)
            .timeout(const Duration(seconds: 5));
        expect(utf8.decode(firstFive), 'hello');

        final rest = await serverStream
            .readExactly(6)
            .timeout(const Duration(seconds: 5));
        expect(utf8.decode(rest), ' world');
      },
    );

    test(
      'readExactly() - throws when the peer finishes before enough bytes arrive',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final acceptFuture = pair.server.acceptStream();
        final clientStream = pair.client.openStream();
        clientStream.write(Uint8List.fromList(utf8.encode('ab')), fin: true);
        final serverStream = await acceptFuture.timeout(
          const Duration(seconds: 5),
        );

        await expectLater(
          serverStream.readExactly(10),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'write() - throws StateError on a receive-only (unidirectional remote) stream',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final acceptFuture = pair.server.acceptUniStream();
        pair.client.openUniStream().write(Uint8List.fromList(utf8.encode('x')));
        final serverStream = await acceptFuture.timeout(
          const Duration(seconds: 5),
        );

        expect(
          () => serverStream.write(Uint8List.fromList(utf8.encode('y'))),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'write() - throws StateError once already closed for writing',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final stream = pair.client.openStream();
        stream.write(Uint8List(0), fin: true);
        expect(
          () => stream.write(Uint8List.fromList(utf8.encode('late'))),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'write() - throws ConnectionClosedException once the connection is closed',
      () async {
        final pair = await _ConnPair.create();
        final stream = pair.client.openStream();
        await pair.client.close();
        expect(
          () => stream.write(Uint8List.fromList(utf8.encode('x'))),
          throwsA(isA<ConnectionClosedException>()),
        );
        await pair.server.close();
      },
    );

    test(
      'closeWrite() - sends a fin so the peer observes end of stream',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final acceptFuture = pair.server.acceptStream();
        final clientStream = pair.client.openStream();
        clientStream.write(Uint8List.fromList(utf8.encode('a')));
        clientStream.closeWrite();
        final serverStream = await acceptFuture.timeout(
          const Duration(seconds: 5),
        );

        final data = await serverStream.read().timeout(
          const Duration(seconds: 5),
        );
        expect(utf8.decode(data), 'a');
        final empty = await serverStream.read().timeout(
          const Duration(seconds: 5),
        );
        expect(empty, isEmpty);
        expect(serverStream.isFinished, isTrue);
      },
    );

    test('closeWrite() - is a no-op when already closed for writing', () async {
      final pair = await _ConnPair.create();
      addTearDown(pair.dispose);

      final stream = pair.client.openStream();
      stream.closeWrite();
      // Second call must not throw despite _writeClosed already being true.
      expect(stream.closeWrite, returnsNormally);
    });

    test(
      'reset() - the peer observes a StreamResetException with the given code',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);

        final acceptFuture = pair.server.acceptStream();
        final clientStream = pair.client.openStream();
        clientStream.write(Uint8List.fromList(utf8.encode('x')));
        final serverStream = await acceptFuture.timeout(
          const Duration(seconds: 5),
        );
        await serverStream.read().timeout(const Duration(seconds: 5));

        clientStream.reset(17);
        await expectLater(
          serverStream.read(),
          throwsA(
            isA<StreamResetException>()
                .having((e) => e.errorCode, 'errorCode', 17)
                .having((e) => e.streamId, 'streamId', serverStream.id),
          ),
        );
      },
    );

    test('reset() - is a no-op once the stream has already failed', () async {
      final pair = await _ConnPair.create();
      addTearDown(pair.dispose);

      final stream = pair.client.openStream();
      stream.reset(1);
      // Second reset on an already-failed stream must not throw.
      expect(() => stream.reset(2), returnsNormally);
    });
  });

  group('HandshakeException [Atomic Audit]', () {
    test('HandshakeException() - carries the message', () {
      const error = HandshakeException('bad Finished');
      expect(error.message, 'bad Finished');
    });

    test('toString() - includes the message', () {
      const error = HandshakeException('bad Finished');
      expect(error.toString(), 'HandshakeException: bad Finished');
    });
  });

  group('QuicClientCertificate [Atomic Audit]', () {
    test(
      'QuicClientCertificate() - exposes der, sign and default signatureAlgorithm',
      () async {
        Future<Uint8List> sign(Uint8List message) async => Uint8List(0);
        final der = Uint8List.fromList([9, 9, 9]);
        final cert = QuicClientCertificate(der: der, sign: sign);

        expect(cert.der, orderedEquals([9, 9, 9]));
        expect(cert.signatureAlgorithm, 0x0403);
        expect(identical(cert.sign, sign), isTrue);
      },
    );

    test(
      'QuicClientCertificate() - accepts an explicit signatureAlgorithm',
      () {
        final cert = QuicClientCertificate(
          der: Uint8List(0),
          sign: (message) async => Uint8List(0),
          signatureAlgorithm: 0x0807,
        );
        expect(cert.signatureAlgorithm, 0x0807);
      },
    );
  });

  group('QuicTlsConfig [Atomic Audit]', () {
    test(
      'QuicTlsConfig() - exposes nextProtos and defaults the rest to null',
      () {
        const config = QuicTlsConfig(nextProtos: ['libp2p']);
        expect(config.nextProtos, ['libp2p']);
        expect(config.verifyPeerCertificate, isNull);
        expect(config.certificate, isNull);
        expect(config.serverName, isNull);
      },
    );

    test(
      'QuicTlsConfig() - carries verifyPeerCertificate, certificate and serverName',
      () {
        Future<void> verify(List<Uint8List> chain) async {}
        final cert = QuicClientCertificate(
          der: Uint8List(0),
          sign: (message) async => Uint8List(0),
        );
        final config = QuicTlsConfig(
          nextProtos: const ['h3'],
          verifyPeerCertificate: verify,
          certificate: cert,
          serverName: 'example.com',
        );
        expect(identical(config.verifyPeerCertificate, verify), isTrue);
        expect(identical(config.certificate, cert), isTrue);
        expect(config.serverName, 'example.com');
      },
    );
  });

  group('dial() [Atomic Audit]', () {
    test(
      'dial() - throws TimeoutException when no QUIC server answers',
      () async {
        final socket = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        // Bind and immediately close a socket to obtain a loopback UDP port
        // nothing is listening on, so the handshake gets no reply at all.
        final probe = await RawDatagramSocket.bind(
          InternetAddress.loopbackIPv4,
          0,
        );
        final deadPort = probe.port;
        probe.close();

        try {
          await expectLater(
            dial(
              socket: socket,
              remoteAddress: InternetAddress.loopbackIPv4,
              remotePort: deadPort,
              tlsConfig: const QuicTlsConfig(nextProtos: ['libp2p']),
              handshakeTimeout: const Duration(milliseconds: 300),
            ),
            throwsA(isA<TimeoutException>()),
          );
        } finally {
          socket.close();
        }
      },
    );
  });

  group('TransportParameters.maxDatagramFrameSize [Atomic Audit]', () {
    test('maxDatagramFrameSize - defaults to zero (datagrams unsupported)', () {
      final params = TransportParameters();
      expect(params.maxDatagramFrameSize, 0);
    });

    test(
      'maxDatagramFrameSize - round-trips through marshal() and unmarshal()',
      () {
        final params = TransportParameters(maxDatagramFrameSize: 65535);
        final bytes = params.marshal();
        final parsed = TransportParameters.unmarshal(bytes);
        expect(parsed.maxDatagramFrameSize, 65535);
      },
    );

    test('maxDatagramFrameSize - omitted from the wire when zero', () {
      final params = TransportParameters();
      final bytes = params.marshal();
      final parsed = TransportParameters.unmarshal(bytes);
      expect(parsed.maxDatagramFrameSize, 0);
    });
  });

  group('paramMaxDatagramFrameSize [Atomic Audit]', () {
    test('paramMaxDatagramFrameSize - matches RFC 9221 section 3 id 0x20', () {
      expect(paramMaxDatagramFrameSize, 0x20);
    });
  });

  group('QuicConn [Atomic Audit]', () {
    test(
      'remoteAddress - reports the endpoint the connection sends to',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);
        {
          expect(
            pair.client.remoteAddress,
            equals(InternetAddress.loopbackIPv4),
          );
          expect(
            pair.server.remoteAddress,
            equals(InternetAddress.loopbackIPv4),
          );
        }
      },
    );

    test(
      'remotePort - reports the peer port the connection sends to',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);
        {
          // Each side sends to the other's socket, so the ports are crossed.
          expect(pair.client.remotePort, isPositive);
          expect(pair.server.remotePort, isPositive);
          expect(pair.client.remotePort, isNot(equals(pair.server.remotePort)));
        }
      },
    );

    test('closeReason - is null while the connection is open', () async {
      final pair = await _ConnPair.create();
      addTearDown(pair.dispose);
      {
        expect(pair.client.closeReason, isNull);
      }
    });

    test(
      'closeReason - is null when this side closed the connection',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);
        {
          await pair.client.close();
          expect(pair.client.isClosed, isTrue);
          expect(pair.client.closeReason, isNull);
        }
      },
    );

    test(
      'closeReason - carries the error code and reason the peer sent',
      () async {
        final pair = await _ConnPair.create();
        addTearDown(pair.dispose);
        {
          pair.server.sendFrames([
            const ConnectionCloseFrame(
              isApplicationError: true,
              errorCode: 0x109,
              reasonPhrase: 'missing QUIC Datagram support',
            ),
          ]);
          await _until(() => pair.client.isClosed);

          final reason = pair.client.closeReason;
          expect(reason, isNotNull);
          expect(reason, contains('application'));
          expect(reason, contains('0x109'));
          expect(reason, contains('missing QUIC Datagram support'));
        }
      },
    );

    test('closeReason - is what a later operation reports instead of a bare '
        '"connection is closed"', () async {
      final pair = await _ConnPair.create();
      addTearDown(pair.dispose);
      {
        pair.server.sendFrames([
          const ConnectionCloseFrame(
            isApplicationError: false,
            errorCode: 0x0a,
            frameType: 0x06,
            reasonPhrase: 'bad CRYPTO frame',
          ),
        ]);
        await _until(() => pair.client.isClosed);

        expect(
          () => pair.client.openStream(),
          throwsA(
            isA<ConnectionClosedException>().having(
              (e) => e.message,
              'message',
              allOf(contains('transport'), contains('bad CRYPTO frame')),
            ),
          ),
        );
      }
    });

    test('isUnidirectional() - reads bit 0x2 of the stream id', () {
      // RFC 9000 s. 2.1: bit 0x2 is the directionality bit.
      expect(QuicConn.isUnidirectional(0), isFalse); // client bidi
      expect(QuicConn.isUnidirectional(1), isFalse); // server bidi
      expect(QuicConn.isUnidirectional(2), isTrue); // client uni
      expect(QuicConn.isUnidirectional(3), isTrue); // server uni
      expect(QuicConn.isUnidirectional(6), isTrue);
      expect(QuicConn.isUnidirectional(9), isFalse);
    });

    test('initiatorOf() - reads bit 0x1 of the stream id', () {
      // RFC 9000 s. 2.1: an even stream id was opened by the client.
      expect(QuicConn.initiatorOf(0), equals(Perspective.client));
      expect(QuicConn.initiatorOf(2), equals(Perspective.client));
      expect(QuicConn.initiatorOf(1), equals(Perspective.server));
      expect(QuicConn.initiatorOf(3), equals(Perspective.server));
    });
  });
}
