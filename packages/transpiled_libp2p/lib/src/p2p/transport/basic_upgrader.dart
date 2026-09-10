// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_go_yamux/transpiled_go_yamux.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../core/crypto/key_types.dart';
import '../../core/network/network.dart';
import '../../core/peer/peer_id.dart';
import '../../core/protocol/protocol.dart';
import '../../core/transport/transport.dart';
import '../net/swarm/swarm_stream.dart';
import '../protocol/multistream_select.dart';
import '../security/noise/noise_framing.dart';
import '../security/noise/noise_handshake_payload.dart';
import '../security/noise/noise_state.dart';

/// Multistream protocol ID for Noise security.
const String noiseProtocolId = '/noise';

/// Multistream protocol ID for Yamux multiplexing.
const String goYamuxProtocolId = '/yamux/1.0.0';

/// Upgraded connection offering authenticated security and multiplexing.
class UpgradedCapableConn implements CapableConn {
  UpgradedCapableConn({
    required Transport transport,
    required PeerId localPeer,
    required PeerId remotePeer,
    required PubKey remotePublicKey,
    required Multiaddr localMultiaddr,
    required Multiaddr remoteMultiaddr,
    required Direction direction,
    required YamuxSession session,
    required YamuxTransport bridge,
  })  : _transport = transport,
        _localPeer = localPeer,
        _remotePeer = remotePeer,
        _remotePublicKey = remotePublicKey,
        _localMultiaddr = localMultiaddr,
        _remoteMultiaddr = remoteMultiaddr,
        _direction = direction,
        _session = session,
        _bridge = bridge,
        _opened = DateTime.now();

  final Transport _transport;
  final PeerId _localPeer;
  final PeerId _remotePeer;
  final PubKey _remotePublicKey;
  final Multiaddr _localMultiaddr;
  final Multiaddr _remoteMultiaddr;
  final Direction _direction;
  final YamuxSession _session;
  final YamuxTransport _bridge;
  final DateTime _opened;

  @override
  Transport transport() => _transport;

  @override
  PeerId localPeer() => _localPeer;

  @override
  PeerId remotePeer() => _remotePeer;

  @override
  PubKey remotePublicKey() => _remotePublicKey;

  @override
  ConnectionState connState() => ConnectionState(
        streamMultiplexer: goYamuxProtocolId,
        security: noiseProtocolId,
        transport: 'tcp',
      );

  @override
  Multiaddr localMultiaddr() => _localMultiaddr;

  @override
  Multiaddr remoteMultiaddr() => _remoteMultiaddr;

  @override
  ConnScope scope() => const NullScope();

  @override
  ConnStats stat() => ConnStats(
        direction: _direction,
        opened: _opened,
        numStreams: _session.numStreams,
      );

  @override
  bool get isClosed => _session.isClosed;

  @override
  Future<NetworkStream> openStream() async {
    final yStream = await _session.openStream();
    return SwarmStream(
      yamuxStream: yStream,
      conn: this,
      direction: Direction.outbound,
    );
  }

  @override
  Future<NetworkStream> acceptStream() async {
    final yStream = await _session.acceptStream();
    return SwarmStream(
      yamuxStream: yStream,
      conn: this,
      direction: Direction.inbound,
    );
  }

  @override
  Future<void> close() async {
    await _session.close();
    await _bridge.close();
  }
}

/// Standard [Upgrader] implementing multistream-select, Noise security, and Yamux multiplexing.
class BasicUpgrader implements Upgrader {
  BasicUpgrader({
    required this.localIdentityKey,
    this.resourceManager = const NullResourceManager(),
  }) : localPeerId = PeerId.fromPubKey(localIdentityKey.getPublic());

  final PrivKey localIdentityKey;
  final PeerId localPeerId;
  final ResourceManager resourceManager;

  @override
  Future<CapableConn> upgrade(Conn conn, Direction dir, PeerId peer) async {
    final rawConn = conn is RawConn ? conn : _GenericRawConn(conn);
    final rawAdapter = _RawStreamAdapter(rawConn);

    // 1. Negotiate security protocol (/noise)
    if (dir == Direction.outbound) {
      await selectOutbound(rawAdapter, const [noiseProtocolId]);
    } else {
      await selectInbound(rawAdapter, const [noiseProtocolId]);
    }

    // 2. Perform Noise XX handshake
    final localStatic = await generateNoiseKeyPair();
    final hs = await HandshakeState.initialize(
      initiator: dir == Direction.outbound,
      staticKeyPair: localStatic,
    );

    Uint8List? remotePayloadBytes;
    (CipherState, CipherState)? splitStates;

    if (dir == Direction.outbound) {
      // msg 0: -> e
      final (m0, _) = await hs.writeMessage(Uint8List(0));
      await _writeFramed(rawAdapter, m0);

      // msg 1: <- e, ee, s, es + remote identity payload
      final m1 = await _readFramed(rawAdapter);
      final (p1, _) = await hs.readMessage(m1);
      remotePayloadBytes = p1;

      // msg 2: -> s, se + our identity payload
      final ourPayload = await generateNoiseHandshakePayload(
        localIdentityKey: localIdentityKey,
        localNoiseStaticPublicKey: localStatic.publicKeyBytes,
      );
      final (m2, s) = await hs.writeMessage(ourPayload);
      await _writeFramed(rawAdapter, m2);
      splitStates = s;
    } else {
      // msg 0: <- e
      final m0 = await _readFramed(rawAdapter);
      await hs.readMessage(m0);

      // msg 1: -> e, ee, s, es + our identity payload
      final ourPayload = await generateNoiseHandshakePayload(
        localIdentityKey: localIdentityKey,
        localNoiseStaticPublicKey: localStatic.publicKeyBytes,
      );
      final (m1, _) = await hs.writeMessage(ourPayload);
      await _writeFramed(rawAdapter, m1);

      // msg 2: <- s, se + remote identity payload
      final m2 = await _readFramed(rawAdapter);
      final (p2, s) = await hs.readMessage(m2);
      remotePayloadBytes = p2;
      splitStates = s;
    }

    if (splitStates == null) {
      throw StateError('Noise handshake did not produce split cipher states');
    }
    final remoteStatic = hs.remoteStaticKey;
    if (remoteStatic == null) {
      throw StateError('Noise handshake completed without remote static key');
    }

    final remoteIdentity = await verifyNoiseHandshakePayload(remotePayloadBytes, remoteStatic);
    if (peer.value.isNotEmpty && remoteIdentity.peerId != peer) {
      throw StateError('Authenticated peer ID mismatch: expected $peer, got ${remoteIdentity.peerId}');
    }

    final (cs1, cs2) = splitStates;
    final (encState, decState) = dir == Direction.outbound ? (cs1, cs2) : (cs2, cs1);

    // 4. Negotiate muxer protocol (/yamux/1.0.0) over Noise
    final negStream = _NoiseNegotiationStream(rawConn, encState, decState);
    if (dir == Direction.outbound) {
      await selectOutbound(negStream, const [goYamuxProtocolId]);
    } else {
      await selectInbound(negStream, const [goYamuxProtocolId]);
    }

    // 5. Start Yamux session over transport with leftover bytes
    final bridge = _NoiseYamuxTransport(
      rawConn,
      encState,
      decState,
      initialBytes: negStream.buffer,
    );
    final session = YamuxSession(
      bridge,
      isClient: dir == Direction.outbound,
    );

    return UpgradedCapableConn(
      transport: rawConn.transport(),
      localPeer: localPeerId,
      remotePeer: remoteIdentity.peerId,
      remotePublicKey: remoteIdentity.publicKey,
      localMultiaddr: rawConn.localMultiaddr(),
      remoteMultiaddr: rawConn.remoteMultiaddr(),
      direction: dir,
      session: session,
      bridge: bridge,
    );
  }

  static Future<void> _writeFramed(StreamReadWriter stream, Uint8List message) async {
    final framed = Uint8List(2 + message.length);
    framed[0] = (message.length >> 8) & 0xff;
    framed[1] = message.length & 0xff;
    framed.setAll(2, message);
    await stream.write(framed);
  }

  static Future<Uint8List> _readFramed(StreamReadWriter stream) async {
    final lenBytes = await _readExact(stream, 2);
    final len = (lenBytes[0] << 8) | lenBytes[1];
    if (len == 0) return Uint8List(0);
    return _readExact(stream, len);
  }

  static Future<Uint8List> _readExact(StreamReadWriter stream, int length) async {
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

class _RawStreamAdapter implements StreamReadWriter {
  _RawStreamAdapter(this._raw);
  final RawConn _raw;

  @override
  Future<Uint8List> read([int? maxLength]) => _raw.read(maxLength);

  @override
  Future<void> write(Uint8List data) => _raw.write(data);
}

class _GenericRawConn implements RawConn {
  _GenericRawConn(this._conn);
  final Conn _conn;

  @override
  Transport transport() {
    if (_conn is RawConn) return (_conn as RawConn).transport();
    if (_conn is CapableConn) return (_conn as CapableConn).transport();
    throw StateError('No transport associated with conn');
  }

  @override
  Multiaddr localMultiaddr() {
    if (_conn is ConnMultiaddrs) return (_conn as ConnMultiaddrs).localMultiaddr();
    return Multiaddr.empty;
  }

  @override
  Multiaddr remoteMultiaddr() {
    if (_conn is ConnMultiaddrs) return (_conn as ConnMultiaddrs).remoteMultiaddr();
    return Multiaddr.empty;
  }

  @override
  Future<Uint8List> read([int? maxLength]) {
    if (_conn is RawConn) return (_conn as RawConn).read(maxLength);
    return Future.value(Uint8List(0));
  }

  @override
  Future<void> write(Uint8List data) {
    if (_conn is RawConn) return (_conn as RawConn).write(data);
    return Future.value();
  }

  @override
  Future<void> close() {
    if (_conn is RawConn) return (_conn as RawConn).close();
    return Future.value();
  }

  @override
  bool get isClosed => _conn is RawConn ? (_conn as RawConn).isClosed : false;
}

class _NoiseNegotiationStream implements StreamReadWriter {
  _NoiseNegotiationStream(this._raw, this._encState, this._decState);

  final RawConn _raw;
  final CipherState _encState;
  final CipherState _decState;
  final List<int> buffer = [];

  @override
  Future<Uint8List> read([int? maxLength]) async {
    while (buffer.isEmpty && !_raw.isClosed) {
      final lenBytes = await _readExactRaw(2);
      if (lenBytes.isEmpty) break;
      final frameLen = (lenBytes[0] << 8) | lenBytes[1];
      if (frameLen == 0) continue;
      final ciphertext = await _readExactRaw(frameLen);
      if (ciphertext.length < frameLen) break;
      final plaintext = await decryptFrame(_decState, ciphertext);
      buffer.addAll(plaintext);
    }
    if (buffer.isEmpty) return Uint8List(0);
    final count = maxLength != null && maxLength > 0
        ? (maxLength < buffer.length ? maxLength : buffer.length)
        : buffer.length;
    final chunk = Uint8List.fromList(buffer.sublist(0, count));
    buffer.removeRange(0, count);
    return chunk;
  }

  Future<Uint8List> _readExactRaw(int length) async {
    final b = BytesBuilder(copy: false);
    while (b.length < length && !_raw.isClosed) {
      final chunk = await _raw.read(length - b.length);
      if (chunk.isEmpty) break;
      b.add(chunk);
    }
    return b.toBytes();
  }

  @override
  Future<void> write(Uint8List data) async {
    final frames = await encryptFrames(_encState, data);
    for (final frame in frames) {
      await _raw.write(frame);
    }
  }
}

class _NoiseYamuxTransport implements YamuxTransport {
  _NoiseYamuxTransport(
    this._raw,
    this._encState,
    this._decState, {
    List<int>? initialBytes,
  }) {
    if (initialBytes != null && initialBytes.isNotEmpty) {
      _inputController.add(Uint8List.fromList(initialBytes));
    }
    _startPump();
  }

  final RawConn _raw;
  final CipherState _encState;
  final CipherState _decState;
  final StreamController<List<int>> _inputController = StreamController<List<int>>();
  bool _closed = false;

  @override
  Stream<List<int>> get input => _inputController.stream;

  void _startPump() async {
    try {
      while (!_closed && !_raw.isClosed) {
        final lenBytes = await _readExactRaw(2);
        if (lenBytes.isEmpty) break;
        final frameLen = (lenBytes[0] << 8) | lenBytes[1];
        if (frameLen == 0) continue;

        final ciphertext = await _readExactRaw(frameLen);
        if (ciphertext.length < frameLen) break;

        final plaintext = await decryptFrame(_decState, ciphertext);
        if (!_inputController.isClosed) {
          _inputController.add(plaintext);
        }
      }
    } catch (err) {
      if (!_inputController.isClosed) {
        _inputController.addError(err);
      }
    } finally {
      if (!_inputController.isClosed) {
        await _inputController.close();
      }
    }
  }

  Future<Uint8List> _readExactRaw(int length) async {
    final buffer = BytesBuilder(copy: false);
    while (buffer.length < length && !_closed) {
      final chunk = await _raw.read(length - buffer.length);
      if (chunk.isEmpty) break;
      buffer.add(chunk);
    }
    return buffer.toBytes();
  }

  @override
  Future<void> write(Uint8List bytes) async {
    if (_closed) throw StateError('Yamux transport is closed');
    final frames = await encryptFrames(_encState, bytes);
    for (final frame in frames) {
      await _raw.write(frame);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_inputController.isClosed) {
      await _inputController.close();
    }
    await _raw.close();
  }
}
