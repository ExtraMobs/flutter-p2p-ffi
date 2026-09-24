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
import '../autonat/autonat.dart';
import '../autorelay/autorelay.dart';
import '../eventbus/basic.dart';
import '../peerstore/pstoremem/peerstore.dart';
import '../../net/swarm/swarm.dart';
import '../../protocol/holepunch/holepunch.dart';
import '../../protocol/multistream.dart';
import '../../protocol/multistream_select.dart';
import 'nat_manager.dart';

import 'addrs_manager.dart';

export 'addrs_manager.dart'
    show AddrsManager, ObservedAddrsManager, maxObservedAddrsPerListenAddr;

/// Standard libp2p [Host] coordinating network transport, protocol multiplexing,
/// identification, NAT traversal, and autonomous relaying.
class BasicHost implements Host {
  BasicHost({
    required Network network,
    Peerstore? peerstore,
    Bus? eventBus,
    ConnManager? connManager,
    ProtocolSwitch? mux,
    AddrsFactory? addrsFactory,
    this.autoNat,
    this.autoRelay,
    this.natManager,
    this.holePunchService,
    this.observedAddrsManager,
    AddrsManager? addressManager,
  }) : _network = network,
       _peerstore =
           peerstore ??
           (network.peerstore is Peerstore
               ? network.peerstore as Peerstore
               : MemoryPeerstore()),
       _eventBus = eventBus ?? BasicBus(),
       _connManager = connManager ?? const NullConnMgr(),
       _mux = mux ?? MultistreamMuxer(),
       _addrsFactory = addrsFactory ?? ((addrs) => addrs),
       _addressManager =
           addressManager ??
           AddrsManager(
             listenAddrs: network.listenAddresses,
             addrsFactory: addrsFactory,
             observedAddrsManager: observedAddrsManager,
             natManager: natManager,
             relayAddrs: () => autoRelay?.relayAddrs ?? const <Multiaddr>[],
             interfaceAddrs: network is Swarm ? network.interfaceCache : null,
           ) {
    // Go: `basic_host.go:275-281` only subscribes the manager's notifee when
    // one was supplied; the `NullConnMgr` fallback is never registered.
    if (connManager != null) {
      _network.notify(connManager.notifiee());
    }
    _network.setStreamHandler(_handleIncomingStream);
  }

  final Network _network;
  final Peerstore _peerstore;
  final Bus _eventBus;
  final ConnManager _connManager;
  final ProtocolSwitch _mux;
  final AddrsFactory _addrsFactory;
  final AutoNat? autoNat;
  final AutoRelay? autoRelay;
  final NatManager? natManager;
  final HolePunchService? holePunchService;
  final AddrsManager _addressManager;

  /// Source of publicly observed addresses, fed by the identify protocol's
  /// `EvtPeerIdentificationCompleted.observedAddr`. See [ObservedAddrsManager].
  final ObservedAddrsManager? observedAddrsManager;
  Emitter? _protocolsEmitter;

  Future<Emitter> _getProtocolsEmitter() async {
    return _protocolsEmitter ??= await _eventBus.emitter(
      EvtLocalProtocolsUpdated,
    );
  }

  void _handleIncomingStream(NetworkStream stream) async {
    try {
      final selectedProto = await selectInbound(stream, _mux.protocols());
      await stream.setProtocol(selectedProto);
      final (proto, handler) = await _mux.negotiate(stream);
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
  List<Multiaddr> get addrs => _addressManager.addrs();

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
    try {
      final selectedProto = await selectOutbound(stream, pids);
      await stream.setProtocol(selectedProto);
      _peerstore.addProtocols(p, [selectedProto]);
      return stream;
    } catch (_) {
      await stream.resetWithError(streamProtocolNegotiationFailed);
      rethrow;
    }
  }

  @override
  Future<void> close() async {
    // Go: `basic_host.go:639-641` closes the manager first, so its background
    // trim stops before the swarm tears the connections down underneath it.
    _connManager.close();
    await holePunchService?.close();
    await natManager?.close();
    await autoRelay?.close();
    await autoNat?.close();
    await _network.close();
    await _peerstore.close();
  }
}
