// Atomic tests for the Noise handshake payload's `extensions` field
// (go-libp2p's `pb.NoiseExtensions`, field 4 of `pb.NoiseHandshakePayload`)
// and the `EarlyDataHandler` machinery that carries it through the
// handshake, per `p2p/security/noise/session_transport.go` and
// `p2p/security/noise/handshake.go` in the upstream fixed at
// `doc/transpilation/UPSTREAM_LOCK.md`.
//
// Covers: `NoiseExtensions`, the field-4-aware
// `generateNoiseHandshakePayload`/`verifyNoiseHandshakePayload`, the
// `NoiseEarlyDataHandler` abstraction, and `NoiseTransport`'s
// `initiatorEarlyDataHandler`/`responderEarlyDataHandler` wiring.
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/src/p2p/security/noise/noise_handshake_payload.dart';
import 'package:transpiled_libp2p/src/p2p/security/noise/transport.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

void main() {
  group('NoiseExtensions [Atomic Audit]', () {
    test('NoiseExtensions() - defaults both fields to empty lists', () {
      final ext = NoiseExtensions();
      expect(ext.webtransportCerthashes, isEmpty);
      expect(ext.streamMuxers, isEmpty);
    });

    test(
      'NoiseExtensions() - stores the given certhashes and stream muxers',
      () {
        final certhash1 = Uint8List.fromList([1, 2, 3]);
        final certhash2 = Uint8List.fromList([4, 5, 6, 7]);
        final ext = NoiseExtensions(
          webtransportCerthashes: [certhash1, certhash2],
          streamMuxers: ['/yamux/1.0.0', '/mplex/6.7.0'],
        );
        expect(ext.webtransportCerthashes, [certhash1, certhash2]);
        expect(ext.streamMuxers, ['/yamux/1.0.0', '/mplex/6.7.0']);
      },
    );
  });

  group('generateNoiseHandshakePayload/verifyNoiseHandshakePayload [Atomic Audit]', () {
    test(
      'generateNoiseHandshakePayload() - omits field 4 entirely when extensions '
      'is null, producing the exact same bytes with or without the parameter '
      '(non-regression: this must match the pre-extensions 2-field wire format '
      'that already interoperates with real Kubo over TCP)',
      () async {
        final key = await generateEd25519KeyPair();
        final staticPub = Uint8List.fromList(List.generate(32, (i) => i));

        final withoutArg = await generateNoiseHandshakePayload(
          localIdentityKey: key,
          localNoiseStaticPublicKey: staticPub,
        );
        final withExplicitNull = await generateNoiseHandshakePayload(
          localIdentityKey: key,
          localNoiseStaticPublicKey: staticPub,
          extensions: null,
        );
        expect(withoutArg, equals(withExplicitNull));

        // Walk the protobuf tags by hand and confirm only fields 1 and 2
        // are present -- no tag with field number 4.
        final fieldNumbers = _topLevelFieldNumbers(withoutArg);
        expect(fieldNumbers, containsAll([1, 2]));
        expect(fieldNumbers, isNot(contains(4)));
      },
    );

    test(
      'generateNoiseHandshakePayload()/verifyNoiseHandshakePayload() - round-trips '
      'a NoiseExtensions with two certhashes and two stream muxers through field 4',
      () async {
        final key = await generateEd25519KeyPair();
        final staticPub = Uint8List.fromList(List.generate(32, (i) => i + 1));
        final ext = NoiseExtensions(
          webtransportCerthashes: [
            Uint8List.fromList([0xaa, 0xbb]),
            Uint8List.fromList([0xcc, 0xdd, 0xee]),
          ],
          streamMuxers: ['/yamux/1.0.0', '/mplex/6.7.0'],
        );

        final payload = await generateNoiseHandshakePayload(
          localIdentityKey: key,
          localNoiseStaticPublicKey: staticPub,
          extensions: ext,
        );
        expect(_topLevelFieldNumbers(payload), containsAll([1, 2, 4]));

        final identity = await verifyNoiseHandshakePayload(payload, staticPub);
        expect(identity.peerId, equals(PeerId.fromPubKey(key.getPublic())));
        final decoded = identity.extensions;
        expect(decoded, isNotNull);
        expect(decoded!.webtransportCerthashes.length, 2);
        expect(decoded.webtransportCerthashes[0], [0xaa, 0xbb]);
        expect(decoded.webtransportCerthashes[1], [0xcc, 0xdd, 0xee]);
        expect(decoded.streamMuxers, ['/yamux/1.0.0', '/mplex/6.7.0']);
      },
    );

    test(
      'verifyNoiseHandshakePayload() - returns null extensions when field 4 is absent',
      () async {
        final key = await generateEd25519KeyPair();
        final staticPub = Uint8List.fromList(List.generate(32, (i) => 2 * i));
        final payload = await generateNoiseHandshakePayload(
          localIdentityKey: key,
          localNoiseStaticPublicKey: staticPub,
        );
        final identity = await verifyNoiseHandshakePayload(payload, staticPub);
        expect(identity.extensions, isNull);
      },
    );

    test(
      'verifyNoiseHandshakePayload() - skips an unknown field (field 7, varint '
      'wire type) instead of throwing, like a real protobuf parser',
      () async {
        final key = await generateEd25519KeyPair();
        final staticPub = Uint8List.fromList(
          List.generate(32, (i) => 3 * i % 251),
        );
        final payload = await generateNoiseHandshakePayload(
          localIdentityKey: key,
          localNoiseStaticPublicKey: staticPub,
        );
        // Append an unknown field: tag = (7 << 3) | 0 = 56 (varint wire
        // type), value = 42 (single-byte varint).
        final tampered = Uint8List.fromList([...payload, 56, 42]);

        final identity = await verifyNoiseHandshakePayload(tampered, staticPub);
        expect(identity.peerId, equals(PeerId.fromPubKey(key.getPublic())));
        expect(identity.extensions, isNull);
      },
    );

    test(
      'verifyNoiseHandshakePayload() - throws FormatException on a genuinely '
      'invalid wire type (3, start-group)',
      () async {
        final key = await generateEd25519KeyPair();
        final staticPub = Uint8List.fromList(List.generate(32, (i) => i));
        final payload = await generateNoiseHandshakePayload(
          localIdentityKey: key,
          localNoiseStaticPublicKey: staticPub,
        );
        // tag = (7 << 3) | 3 = 59 (start-group wire type): invalid here.
        final tampered = Uint8List.fromList([...payload, 59]);

        await expectLater(
          verifyNoiseHandshakePayload(tampered, staticPub),
          throwsA(isA<FormatException>()),
        );
      },
    );
  });

  group('NoiseTransport with NoiseEarlyDataHandler [Atomic Audit]', () {
    test('NoiseTransport() - stores initiatorEarlyDataHandler and '
        'responderEarlyDataHandler, defaulting to null', () async {
      final key = await generateEd25519KeyPair();
      final plain = NoiseTransport(privKey: key);
      expect(plain.initiatorEarlyDataHandler, isNull);
      expect(plain.responderEarlyDataHandler, isNull);

      final handler = _RecordingEarlyDataHandler();
      final withHandlers = NoiseTransport(
        privKey: key,
        initiatorEarlyDataHandler: handler,
        responderEarlyDataHandler: handler,
      );
      expect(withHandlers.initiatorEarlyDataHandler, same(handler));
      expect(withHandlers.responderEarlyDataHandler, same(handler));
    });

    test(
      'NoiseEarlyDataHandler.send() - returns the configured NoiseExtensions '
      'for the given peer',
      () {
        final peer = PeerId(value: Uint8List.fromList([9, 9, 9]));
        final ext = NoiseExtensions(streamMuxers: ['/yamux/1.0.0']);
        final handler = _RecordingEarlyDataHandler(toSend: ext);
        final raw = _createDuplexPipePair().$1;

        final result = handler.send(raw, peer);
        expect(result, same(ext));
        expect(handler.sendCalled, isTrue);
      },
    );

    test('secureOutbound()/secureInbound() - exchange NoiseExtensions via '
        'NoiseEarlyDataHandler.send()/received() in the correct handshake '
        'messages (initiator receives in msg 1->its Received, sends in msg 2; '
        'responder sends in msg 1, receives in msg 2->its Received)', () async {
      final clientKey = await generateEd25519KeyPair();
      final serverKey = await generateEd25519KeyPair();
      final clientPeer = PeerId.fromPubKey(clientKey.getPublic());
      final serverPeer = PeerId.fromPubKey(serverKey.getPublic());

      final clientHandler = _RecordingEarlyDataHandler(
        toSend: NoiseExtensions(streamMuxers: ['/from-client']),
      );
      final serverHandler = _RecordingEarlyDataHandler(
        toSend: NoiseExtensions(streamMuxers: ['/from-server']),
      );

      final clientTransport = NoiseTransport(
        privKey: clientKey,
        initiatorEarlyDataHandler: clientHandler,
      );
      final serverTransport = NoiseTransport(
        privKey: serverKey,
        responderEarlyDataHandler: serverHandler,
      );

      final (clientRaw, serverRaw) = _createDuplexPipePair();
      final results = await Future.wait([
        clientTransport.secureOutbound(clientRaw, serverPeer),
        serverTransport.secureInbound(serverRaw, clientPeer),
      ]);

      // The client's handler received what the server's handler sent,
      // and vice versa.
      expect(clientHandler.lastReceived?.streamMuxers, ['/from-server']);
      expect(serverHandler.lastReceived?.streamMuxers, ['/from-client']);

      await results[0].close();
      await results[1].close();
    });

    test(
      'NoiseEarlyDataHandler.received() - throwing inside the initiator\'s '
      'handler aborts secureOutbound() before message 2 is ever sent',
      () async {
        final clientKey = await generateEd25519KeyPair();
        final serverKey = await generateEd25519KeyPair();
        final clientPeer = PeerId.fromPubKey(clientKey.getPublic());
        final serverPeer = PeerId.fromPubKey(serverKey.getPublic());

        final abortingHandler = _RecordingEarlyDataHandler(
          receivedError: StateError('reject remote extensions'),
        );
        final clientTransport = NoiseTransport(
          privKey: clientKey,
          initiatorEarlyDataHandler: abortingHandler,
        );
        final serverTransport = NoiseTransport(privKey: serverKey);

        final (clientRaw, serverRaw) = _createDuplexPipePair();
        // Attach an error handler to the responder's future *immediately*,
        // in the same synchronous step it's created: it will fail once the
        // pipe below is closed out from under its still-pending read, and
        // only the initiator's abort (asserted below) matters to this
        // test, so that failure is swallowed rather than left to surface
        // as an unhandled async error.
        final serverDone = serverTransport
            .secureInbound(serverRaw, clientPeer)
            .then((_) {}, onError: (_) {});

        Object? clientError;
        try {
          await clientTransport.secureOutbound(clientRaw, serverPeer);
        } catch (e) {
          clientError = e;
        }
        expect(clientError, isA<StateError>());
        expect(abortingHandler.sendCalled, isFalse);

        // The initiator never wrote message 2, so the responder's read
        // would block forever; close both ends of the pipe so its pending
        // read unblocks with EOF.
        await clientRaw.close();
        await serverRaw.close();
        await serverDone;
      },
    );
  });
}

/// Reads every top-level protobuf field number out of [bytes], per the
/// varint-tag scheme `pb.NoiseHandshakePayload` uses. Used only to assert
/// which fields a generated payload does (or doesn't) carry.
List<int> _topLevelFieldNumbers(Uint8List bytes) {
  final numbers = <int>[];
  var offset = 0;
  while (offset < bytes.length) {
    var tag = 0;
    var shift = 0;
    while (true) {
      final b = bytes[offset++];
      tag |= (b & 0x7f) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
    }
    final fieldNumber = tag >> 3;
    final wireType = tag & 0x7;
    numbers.add(fieldNumber);
    if (wireType == 2) {
      var length = 0;
      shift = 0;
      while (true) {
        final b = bytes[offset++];
        length |= (b & 0x7f) << shift;
        if ((b & 0x80) == 0) break;
        shift += 7;
      }
      offset += length;
    } else if (wireType == 0) {
      while ((bytes[offset++] & 0x80) != 0) {}
    } else {
      throw StateError('unexpected wire type $wireType in test helper');
    }
  }
  return numbers;
}

/// An [NoiseEarlyDataHandler] that records what it received, always sends
/// [toSend] (or nothing), and optionally throws [receivedError] from
/// `received()` to exercise handshake abort.
class _RecordingEarlyDataHandler implements NoiseEarlyDataHandler {
  _RecordingEarlyDataHandler({this.toSend, this.receivedError});

  final NoiseExtensions? toSend;
  final Object? receivedError;
  NoiseExtensions? lastReceived;
  bool sendCalled = false;

  @override
  NoiseExtensions? send(RawConn insecure, PeerId remote) {
    sendCalled = true;
    return toSend;
  }

  @override
  Future<void> received(RawConn insecure, NoiseExtensions? extensions) async {
    lastReceived = extensions;
    final err = receivedError;
    if (err != null) throw err;
  }
}

class _DuplexPipeConn implements RawConn {
  _DuplexPipeConn({required this.localAddr, required this.remoteAddr});

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
    final len = maxLength != null
        ? math.min(maxLength, _incoming.length)
        : _incoming.length;
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
  final a1 = Multiaddr.parse('/ip4/127.0.0.1/tcp/4101');
  final a2 = Multiaddr.parse('/ip4/127.0.0.1/tcp/4102');
  final c1 = _DuplexPipeConn(localAddr: a1, remoteAddr: a2);
  final c2 = _DuplexPipeConn(localAddr: a2, remoteAddr: a1);
  c1.other = c2;
  c2.other = c1;
  return (c1, c2);
}
