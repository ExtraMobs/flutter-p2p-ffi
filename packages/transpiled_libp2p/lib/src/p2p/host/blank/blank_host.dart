// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/connmgr/manager.dart';
import '../../../core/connmgr/null.dart';
import '../../../core/event/bus.dart';
import '../../../core/event/protocol.dart';
import '../../../core/host/host.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/addr_info.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/peerstore/peerstore.dart';
import '../../../core/protocol/protocol.dart';
import '../eventbus/basic.dart';
import '../peerstore/pstoremem/peerstore.dart';
import '../../protocol/multistream.dart';

/// BlankHost is the thinnest implementation of the [Host] interface.
class BlankHost implements Host {
  BlankHost({
    required Network network,
    ConnManager? connManager,
    Bus? eventBus,
    ProtocolSwitch? mux,
    Peerstore? peerstore,
  })  : _network = network,
        _connManager = connManager ?? const NullConnMgr(),
        _eventBus = eventBus ?? BasicBus(),
        _mux = mux ?? MultistreamMuxer(),
        _peerstore = peerstore ??
            (network.peerstore is Peerstore
                ? network.peerstore as Peerstore
                : MemoryPeerstore()) {
    _network.setStreamHandler(_handleIncomingStream);
  }

  final Network _network;
  final ConnManager _connManager;
  final Bus _eventBus;
  final ProtocolSwitch _mux;
  final Peerstore _peerstore;
  Emitter? _protocolsEmitter;

  Future<Emitter> _getProtocolsEmitter() async {
    return _protocolsEmitter ??=
        await _eventBus.emitter(EvtLocalProtocolsUpdated);
  }

  void _handleIncomingStream(NetworkStream stream) async {
    try {
      final (proto, handler) = await _mux.negotiate(stream);
      await stream.setProtocol(proto);
      await handler(proto, stream);
    } catch (_) {
      await stream.resetWithError(streamProtocolNegotiationFailed);
    }
  }

  @override
  PeerId get id => _network.localPeer;

  @override
  Peerstore get peerstore => _peerstore;

  @override
  List<Multiaddr> get addrs => _network.listenAddresses();

  @override
  Network get network => _network;

  @override
  ProtocolSwitch get mux => _mux;

  @override
  ConnManager get connManager => _connManager;

  @override
  Bus get eventBus => _eventBus;

  @override
  Future<void> connect(
    AddrInfo pi, {
    NetworkContext context = NetworkContext.empty,
  }) async {
    if (pi.addrs.isNotEmpty) {
      _peerstore.addAddrs(pi.id, pi.addrs, tempAddrTtl);
    }

    final conns = _network.connsToPeer(pi.id);
    if (conns.isNotEmpty) return;

    await _network.dialPeer(context, pi.id);
  }

  @override
  void setStreamHandler(ProtocolId pid, StreamHandler handler) {
    _mux.addHandler(pid, (proto, stream) async {
      if (stream is NetworkStream) {
        await stream.setProtocol(proto);
        handler(stream);
      }
    });
    _getProtocolsEmitter().then((emitter) {
      emitter.emit(EvtLocalProtocolsUpdated(added: [pid]));
    });
  }

  @override
  void setStreamHandlerMatch(
    ProtocolId pid,
    bool Function(ProtocolId) match,
    StreamHandler handler,
  ) {
    _mux.addHandlerWithFunc(pid, match, (proto, stream) async {
      if (stream is NetworkStream) {
        await stream.setProtocol(proto);
        handler(stream);
      }
    });
    _getProtocolsEmitter().then((emitter) {
      emitter.emit(EvtLocalProtocolsUpdated(added: [pid]));
    });
  }

  @override
  void removeStreamHandler(ProtocolId pid) {
    _mux.removeHandler(pid);
    _getProtocolsEmitter().then((emitter) {
      emitter.emit(EvtLocalProtocolsUpdated(removed: [pid]));
    });
  }

  @override
  Future<NetworkStream> newStream(
    PeerId p,
    List<ProtocolId> pids, {
    NetworkContext context = NetworkContext.empty,
  }) async {
    final stream = await _network.newStream(context, p);
    final selected = pids.isNotEmpty ? pids.first : '';
    await stream.setProtocol(selected);
    _peerstore.addProtocols(p, [selected]);
    return stream;
  }

  @override
  Future<void> close() async {
    await _network.close();
    await _peerstore.close();
  }
}
