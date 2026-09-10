// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/crypto/key_types.dart';
import '../../../core/crypto/proto_varint.dart';
import '../../../core/event/bus.dart';
import '../../../core/event/identify.dart';
import '../../../core/host/host.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/peerstore/peerstore.dart';
import '../../../core/protocol/protocol.dart';
import '../../../core/record/envelope.dart';
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
    return _emitter ??= await host.eventBus.emitter(EvtPeerIdentificationCompleted);
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
      final localAddrs = host.addrs.map((a) => Uint8List.fromList(a.toBytes())).toList();
      final protocols = host.mux.protocols();
      final pubKey = host.peerstore.pubKey(host.id);

      final msg = Identify(
        publicKey: pubKey,
        listenAddrs: localAddrs,
        protocols: protocols,
        agentVersion: userAgent,
        protocolVersion: protocolVersion,
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
      final sec = c is ConnSecurity ? (c as ConnSecurity) : null;
      if (sec != null) {
        final remote = sec.remotePeer();
        // Emit completed event when peer identification is observed
        final em = await _getEmitter();
        em.emit(EvtPeerIdentificationCompleted(
          peer: remote,
          conn: c,
          listenAddrs: host.peerstore.addrs(remote),
          protocols: host.peerstore.getProtocols(remote),
          agentVersion: userAgent,
          protocolVersion: protocolVersion,
          observedAddr: host.addrs.isNotEmpty ? host.addrs.first : Multiaddr.empty,
        ));
      }
      completer.complete();
    } catch (e, st) {
      completer.completeError(e, st);
    } finally {
      _identifying.remove(c);
    }
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
