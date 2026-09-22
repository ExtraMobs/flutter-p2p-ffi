// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/crypto/proto_varint.dart';
import '../../../core/event/bus.dart';
import '../../../core/event/identify.dart';
import '../../../core/host/host.dart';
import '../../../core/network/network.dart';
import '../../../core/protocol/protocol.dart';
import '../multistream_select.dart';
import 'pb/identify_message.dart';

const ProtocolId id = '/ipfs/id/1.0.0';
const ProtocolId idPush = '/ipfs/id/push/1.0.0';
const Duration defaultTimeout = Duration(seconds: 5);
const String serviceName = 'libp2p.identify';

abstract interface class IdService {
  factory IdService({
    required Host host,
    String userAgent,
    String protocolVersion,
  }) = _IdService;

  void identifyConn(Conn c);
  Future<void> identifyWait(Conn c);
  void start();
  Future<void> close();
}

class _IdService implements IdService {
  _IdService({
    required this.host,
    this.userAgent = 'dart-ipfs/0.1.0',
    this.protocolVersion = 'ipfs/0.1.0',
  });

  final Host host;
  final String userAgent;
  final String protocolVersion;

  final Map<Conn, Completer<void>> _identifying = {};
  Emitter? _emitter;
  bool _started = false;
  bool _closed = false;

  Future<Emitter> _getEmitter() async {
    return _emitter ??= await host.eventBus.emitter(
      EvtPeerIdentificationCompleted,
    );
  }

  @override
  void start() {
    if (_started) return;
    _started = true;
    host.setStreamHandler(id, _handleIdentify);
    host.setStreamHandler(idPush, _handleIdentifyPush);
  }

  Future<void> _handleIdentify(NetworkStream stream) async {
    try {
      final localAddrs = host.addrs
          .map((a) => Uint8List.fromList(a.toBytes()))
          .toList();
      final protocols = host.mux.protocols();
      final pubKey = host.peerstore.pubKey(host.id);
      // Observed address so the other side is informed of their "public"
      // address, at least in relation to us. id.go:638-649
      // (createBaseIdentifyResponse).
      final connAddrs = stream.conn();

      final msg = Identify(
        publicKey: pubKey,
        listenAddrs: localAddrs,
        protocols: protocols,
        agentVersion: userAgent,
        protocolVersion: protocolVersion,
        observedAddr: Uint8List.fromList(connAddrs.remoteMultiaddr().toBytes()),
      );

      final payload = msg.marshal();
      final varintLen = encodeProtoVarint(payload.length);
      await stream.write(Uint8List.fromList([...varintLen, ...payload]));
      await stream.close();
    } catch (_) {
      await stream.resetWithError(streamProtocolViolation);
    }
  }

  Future<void> _handleIdentifyPush(NetworkStream stream) async {
    // identify push updates remote peer's details
  }

  @override
  void identifyConn(Conn c) {
    if (_closed) return;
    identifyWait(c);
  }

  @override
  Future<void> identifyWait(Conn c) async {
    if (_closed) return;
    final existing = _identifying[c];
    if (existing != null) {
      return existing.future;
    }

    final completer = Completer<void>();
    _identifying[c] = completer;

    try {
      final remote = c.remotePeer();
      final observedAddr = await _requestObservedAddr(c);
      // Emit completed event when peer identification is observed
      final em = await _getEmitter();
      em.emit(
        EvtPeerIdentificationCompleted(
          peer: remote,
          conn: c,
          listenAddrs: host.peerstore.addrs(remote),
          protocols: host.peerstore.getProtocols(remote),
          agentVersion: userAgent,
          protocolVersion: protocolVersion,
          observedAddr: observedAddr,
        ),
      );
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
    } finally {
      _identifying.remove(c);
    }
  }

  /// Opens the identify stream on [c] as the requester, reads the peer's
  /// Identify message, and extracts the `observedAddr` field they reported
  /// back about us. id.go:448-459 (`identifyConn` opening the stream) and
  /// id.go:749-753 (`consumeMessage` parsing `ObservedAddr`).
  ///
  /// Returns [Multiaddr.empty] -- matching Go's `obsAddr = nil` -- on any
  /// failure to open the stream, negotiate the protocol, read the message,
  /// or parse the reported address, so a malformed/missing report never
  /// fails identification itself, only observed-address collection.
  Future<Multiaddr> _requestObservedAddr(Conn c) async {
    NetworkStream? stream;
    try {
      stream = await c.newStream();
      await stream.setProtocol(id);
      await selectOutbound(stream, const [id]);
      final bytes = await _readDelimited(stream);
      if (bytes == null) return Multiaddr.empty;
      final msg = Identify.unmarshal(bytes);
      final raw = msg.observedAddr;
      if (raw == null) return Multiaddr.empty;
      return Multiaddr.fromBytes(raw);
    } catch (_) {
      try {
        await stream?.reset();
      } catch (_) {}
      return Multiaddr.empty;
    } finally {
      try {
        await stream?.close();
      } catch (_) {}
    }
  }

  /// Reads one varint-length-prefixed protobuf message off [stream].
  /// Equivalent role to id.go's `pbio.NewDelimitedReader` read in
  /// `handleIdentifyResponse` (id.go:512-567), scoped here to a single
  /// message since `_handleIdentify` writes exactly one.
  static Future<Uint8List?> _readDelimited(NetworkStream stream) async {
    final firstByte = await stream.read(1);
    if (firstByte.isEmpty) return null;
    var len = firstByte[0] & 0x7f;
    var shift = 7;
    if ((firstByte[0] & 0x80) != 0) {
      while (true) {
        final b = await stream.read(1);
        if (b.isEmpty) return null;
        len |= (b[0] & 0x7f) << shift;
        if ((b[0] & 0x80) == 0) break;
        shift += 7;
      }
    }
    if (len == 0) return Uint8List(0);
    final buf = <int>[];
    while (buf.length < len) {
      final chunk = await stream.read(len - buf.length);
      if (chunk.isEmpty) break;
      buf.addAll(chunk);
    }
    return Uint8List.fromList(buf);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    host.removeStreamHandler(id);
    host.removeStreamHandler(idPush);
    for (final c in _identifying.values) {
      if (!c.isCompleted) {
        c.completeError(StateError('IdentifyService closed'));
      }
    }
    _identifying.clear();
    await _emitter?.close();
  }
}
