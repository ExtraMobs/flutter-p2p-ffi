// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/connmgr/manager.dart';
import '../../../core/event/bus.dart';
import '../../../core/host/host.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/addr_info.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/peerstore/peerstore.dart';
import '../../../core/protocol/protocol.dart';
import '../../../core/routing/routing.dart';

/// Expiry time for routed addresses (10 seconds, matching Go's AddressTTL).
const Duration routedAddressTtl = Duration(seconds: 10);

/// RoutedHost is a p2p [Host] that includes a routing system to discover
/// peer addresses dynamically when dialing.
class RoutedHost implements Host {
  RoutedHost({
    required Host host,
    required PeerRouting route,
  })  : _host = host,
        _route = route;

  final Host _host;
  final PeerRouting _route;

  @override
  PeerId get id => _host.id;

  @override
  Peerstore get peerstore => _host.peerstore;

  @override
  List<Multiaddr> get addrs => _host.addrs;

  @override
  Network get network => _host.network;

  @override
  ProtocolSwitch get mux => _host.mux;

  @override
  ConnManager get connManager => _host.connManager;

  @override
  Bus get eventBus => _host.eventBus;

  @override
  Future<void> connect(
    AddrInfo pi, {
    NetworkContext context = NetworkContext.empty,
  }) async {
    final (forceDirect, _) = getForceDirectDial(context);
    final (canUseLimitedConn, _) = getAllowLimitedConn(context);

    if (!forceDirect) {
      final connectedness = network.connectedness(pi.id);
      if (connectedness == Connectedness.connected ||
          (canUseLimitedConn && connectedness == Connectedness.limited)) {
        return;
      }
    }

    if (pi.addrs.isNotEmpty) {
      peerstore.addAddrs(pi.id, pi.addrs, tempAddrTtl);
    }

    var addrs = peerstore.addrs(pi.id);
    if (addrs.isEmpty) {
      try {
        final info = await _route.findPeer(pi.id);
        if (info.addrs.isNotEmpty) {
          peerstore.addAddrs(pi.id, info.addrs, routedAddressTtl);
          addrs = info.addrs;
        }
      } catch (_) {
        // Fallback: proceed to dial if possible
      }
    }

    await _host.connect(AddrInfo(id: pi.id, addrs: addrs), context: context);
  }

  @override
  void setStreamHandler(ProtocolId pid, StreamHandler handler) =>
      _host.setStreamHandler(pid, handler);

  @override
  void setStreamHandlerMatch(
    ProtocolId pid,
    bool Function(ProtocolId) match,
    StreamHandler handler,
  ) =>
      _host.setStreamHandlerMatch(pid, match, handler);

  @override
  void removeStreamHandler(ProtocolId pid) => _host.removeStreamHandler(pid);

  @override
  Future<NetworkStream> newStream(
    PeerId p,
    List<ProtocolId> pids, {
    NetworkContext context = NetworkContext.empty,
  }) async {
    // Ensure connected first
    await connect(AddrInfo(id: p), context: context);
    return _host.newStream(p, pids, context: context);
  }

  @override
  Future<void> close() => _host.close();
}
