// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/crypto/key_types.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/sec/security.dart';
import '../../../core/transport/transport.dart';
import 'noise_framing.dart';
import 'noise_handshake_payload.dart';
import 'noise_state.dart';

/// Multistream protocol ID for Noise security.
const String id = '/noise';

/// Multistream protocol ID for Noise security.
const String noiseProtocolId = id;

/// Defines the application payload smuggled as Noise handshake early data,
/// and how to consume the other side's, per go-libp2p's
/// `noise.EarlyDataHandler`. Installed on a [NoiseTransport] via its
/// `initiatorEarlyDataHandler`/`responderEarlyDataHandler` constructor
/// parameters, the Dart equivalent of go-libp2p's functional
/// `EarlyData(initiator, responder)` session option -- a transport (e.g.
/// WebTransport) that needs to run Noise over a stream and prove control of
/// its TLS certificates supplies one of these to carry
/// `webtransport_certhashes` through the handshake.
abstract interface class NoiseEarlyDataHandler {
  /// For the initiator, called before sending the third handshake message.
  /// For the responder, called before sending the second one. Returns the
  /// extensions to embed in that message's payload, or `null` to send none.
  NoiseExtensions? send(RawConn insecure, PeerId remote);

  /// For the initiator, called once the second handshake message -- and
  /// thus the responder's extensions -- has been received and
  /// authenticated. For the responder, called once the third message (the
  /// initiator's extensions) has been received and authenticated. Throwing
  /// aborts the handshake, mirroring go-libp2p returning a non-nil error
  /// from `Received`.
  Future<void> received(RawConn insecure, NoiseExtensions? extensions);
}

/// Noise XX security transport for libp2p.
class NoiseTransport implements SecureTransport {
  NoiseTransport({
    required this.privKey,
    this.muxers = const ['/yamux/1.0.0'],
    this.protocolId = noiseProtocolId,
    this.initiatorEarlyDataHandler,
    this.responderEarlyDataHandler,
    this.prologue,
  }) : localPeer = PeerId.fromPubKey(privKey.getPublic());

  final PrivKey privKey;
  final PeerId localPeer;
  final List<String> muxers;
  final String protocolId;
  final Uint8List? prologue;

  /// Early-data handler used when this transport is the handshake
  /// initiator, or `null` to send/expect no extensions. Mirrors
  /// go-libp2p's `EarlyData` initiator argument.
  final NoiseEarlyDataHandler? initiatorEarlyDataHandler;

  /// Early-data handler used when this transport is the handshake
  /// responder, or `null`. Mirrors go-libp2p's `EarlyData` responder
  /// argument.
  final NoiseEarlyDataHandler? responderEarlyDataHandler;

  @override
  String id() => protocolId;

  @override
  Future<SecureConn> secureOutbound(RawConn insecure, PeerId peer) async {
    final localStatic = await generateNoiseKeyPair();
    final hs = await HandshakeState.initialize(
      initiator: true,
      staticKeyPair: localStatic,
      prologue: prologue,
    );

    // msg 0: -> e
    final (m0, _) = await hs.writeMessage(Uint8List(0));
    await _writeFramed(insecure, m0);

    // msg 1: <- e, ee, s, es + remote identity payload
    final m1 = await _readFramed(insecure);
    final (p1, _) = await hs.readMessage(m1);
    final remotePayloadBytes = p1;

    // The responder's `s` token in message 1 is what populates
    // remoteStaticKey -- available immediately, no need to wait for
    // message 2.
    final remoteStatic = hs.remoteStaticKey;
    if (remoteStatic == null) {
      throw StateError(
        'Noise handshake completed message 1 without remote static key',
      );
    }

    // Verify the responder's payload -- signature and, if requested, peer
    // ID -- right after reading message 1, *before* building message 2.
    // This mirrors go-libp2p's runHandshake (handshake.go): the initiator
    // calls handleRemoteHandshakePayload immediately on reading message 1,
    // and only once that succeeds does it feed the resulting extensions to
    // initiatorEarlyDataHandler.Received and then ask
    // initiatorEarlyDataHandler.Send what to put in message 2. The
    // previous version of this method verified only *after* already
    // writing message 2 to the wire, which both diverges from upstream
    // ordering and would have handed an unauthenticated remote's
    // extensions to an early-data handler after bytes had already been
    // committed to the network.
    final remoteIdentity = await verifyNoiseHandshakePayload(
      remotePayloadBytes,
      remoteStatic,
    );
    if (peer.value.isNotEmpty && remoteIdentity.peerId != peer) {
      throw StateError(
        'Authenticated peer ID mismatch: expected $peer, got ${remoteIdentity.peerId}',
      );
    }
    final earlyData = initiatorEarlyDataHandler;
    if (earlyData != null) {
      await earlyData.received(insecure, remoteIdentity.extensions);
    }

    // msg 2: -> s, se + our identity payload
    final outExtensions = earlyData?.send(insecure, remoteIdentity.peerId);
    final ourPayload = await generateNoiseHandshakePayload(
      localIdentityKey: privKey,
      localNoiseStaticPublicKey: localStatic.publicKeyBytes,
      extensions: outExtensions,
    );
    final (m2, splitStates) = await hs.writeMessage(ourPayload);
    await _writeFramed(insecure, m2);

    if (splitStates == null) {
      throw StateError('Noise handshake did not produce split cipher states');
    }

    final (encState, decState) = splitStates;
    return _NoiseConn(
      rawConn: insecure,
      localPeer: localPeer,
      remotePeer: remoteIdentity.peerId,
      remotePubKey: remoteIdentity.publicKey,
      encState: encState,
      decState: decState,
      protocolId: protocolId,
    );
  }

  @override
  Future<SecureConn> secureInbound(RawConn insecure, PeerId peer) async {
    final localStatic = await generateNoiseKeyPair();
    final hs = await HandshakeState.initialize(
      initiator: false,
      staticKeyPair: localStatic,
      prologue: prologue,
    );

    // msg 0: <- e
    final m0 = await _readFramed(insecure);
    await hs.readMessage(m0);

    // msg 1: -> e, ee, s, es + our identity payload
    final earlyData = responderEarlyDataHandler;
    final outExtensions = earlyData?.send(insecure, peer);
    final ourPayload = await generateNoiseHandshakePayload(
      localIdentityKey: privKey,
      localNoiseStaticPublicKey: localStatic.publicKeyBytes,
      extensions: outExtensions,
    );
    final (m1, _) = await hs.writeMessage(ourPayload);
    await _writeFramed(insecure, m1);

    // msg 2: <- s, se + remote identity payload
    final m2 = await _readFramed(insecure);
    final (p2, splitStates) = await hs.readMessage(m2);

    if (splitStates == null) {
      throw StateError('Noise handshake did not produce split cipher states');
    }
    final remoteStatic = hs.remoteStaticKey;
    if (remoteStatic == null) {
      throw StateError('Noise handshake completed without remote static key');
    }

    final remoteIdentity = await verifyNoiseHandshakePayload(p2, remoteStatic);
    if (peer.value.isNotEmpty && remoteIdentity.peerId != peer) {
      throw StateError(
        'Authenticated peer ID mismatch: expected $peer, got ${remoteIdentity.peerId}',
      );
    }
    if (earlyData != null) {
      await earlyData.received(insecure, remoteIdentity.extensions);
    }

    final (cs1, cs2) = splitStates;
    final (encState, decState) = (cs2, cs1);
    return _NoiseConn(
      rawConn: insecure,
      localPeer: localPeer,
      remotePeer: remoteIdentity.peerId,
      remotePubKey: remoteIdentity.publicKey,
      encState: encState,
      decState: decState,
      protocolId: protocolId,
    );
  }

  static Future<void> _writeFramed(RawConn stream, Uint8List message) async {
    final framed = Uint8List(2 + message.length);
    framed[0] = (message.length >> 8) & 0xff;
    framed[1] = message.length & 0xff;
    framed.setAll(2, message);
    await stream.write(framed);
  }

  static Future<Uint8List> _readFramed(RawConn stream) async {
    final lenBytes = await _readExact(stream, 2);
    final len = (lenBytes[0] << 8) | lenBytes[1];
    if (len == 0) return Uint8List(0);
    return _readExact(stream, len);
  }

  static Future<Uint8List> _readExact(RawConn stream, int length) async {
    final buffer = BytesBuilder(copy: false);
    while (buffer.length < length) {
      final chunk = await stream.read(length - buffer.length);
      if (chunk.isEmpty) {
        throw StateError('EOF while reading framed message');
      }
      buffer.add(chunk);
    }
    return buffer.toBytes();
  }
}

class _NoiseConn implements SecureConn {
  _NoiseConn({
    required RawConn rawConn,
    required PeerId localPeer,
    required PeerId remotePeer,
    required PubKey remotePubKey,
    required CipherState encState,
    required CipherState decState,
    required String protocolId,
  }) : _rawConn = rawConn,
       _localPeer = localPeer,
       _remotePeer = remotePeer,
       _remotePubKey = remotePubKey,
       _encState = encState,
       _decState = decState,
       _protocolId = protocolId;

  final RawConn _rawConn;
  final PeerId _localPeer;
  final PeerId _remotePeer;
  final PubKey _remotePubKey;
  final CipherState _encState;
  final CipherState _decState;
  final String _protocolId;
  final BytesBuilder _readBuffer = BytesBuilder(copy: false);
  bool _closed = false;

  @override
  PeerId localPeer() => _localPeer;

  @override
  PeerId remotePeer() => _remotePeer;

  @override
  PubKey remotePublicKey() => _remotePubKey;

  @override
  ConnectionState connState() => ConnectionState(
    streamMultiplexer: '/yamux/1.0.0',
    security: _protocolId,
    transport:
        _rawConn.remoteMultiaddr().components.any(
          (c) => c.protocol.name == 'ws' || c.protocol.name == 'wss',
        )
        ? 'websocket'
        : 'tcp',
  );

  @override
  Transport transport() => _rawConn.transport();

  @override
  Multiaddr localMultiaddr() => _rawConn.localMultiaddr();

  @override
  Multiaddr remoteMultiaddr() => _rawConn.remoteMultiaddr();

  @override
  bool get isClosed => _closed || _rawConn.isClosed;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _rawConn.close();
  }

  @override
  Future<void> write(Uint8List data) async {
    if (_closed) throw StateError('connection is closed');
    final frames = await encryptFrames(_encState, data);
    for (final frame in frames) {
      await _rawConn.write(frame);
    }
  }

  @override
  Future<Uint8List> read([int? maxLength]) async {
    if (_closed) return Uint8List(0);
    while (_readBuffer.isEmpty) {
      final lenBytes = await _readExactRaw(2);
      if (lenBytes.isEmpty) break;
      final frameLen = (lenBytes[0] << 8) | lenBytes[1];
      if (frameLen == 0) continue;
      final ciphertext = await _readExactRaw(frameLen);
      if (ciphertext.length < frameLen) break;
      final plaintext = await decryptFrame(_decState, ciphertext);
      _readBuffer.add(plaintext);
    }
    if (_readBuffer.isEmpty) return Uint8List(0);
    final all = _readBuffer.takeBytes();
    if (maxLength == null || all.length <= maxLength) {
      return all;
    }
    final chunk = Uint8List.sublistView(all, 0, maxLength);
    _readBuffer.add(Uint8List.sublistView(all, maxLength));
    return chunk;
  }

  Future<Uint8List> _readExactRaw(int length) async {
    final b = BytesBuilder(copy: false);
    while (b.length < length && !_rawConn.isClosed && !_closed) {
      final chunk = await _rawConn.read(length - b.length);
      if (chunk.isEmpty) break;
      b.add(chunk);
    }
    return b.toBytes();
  }
}
