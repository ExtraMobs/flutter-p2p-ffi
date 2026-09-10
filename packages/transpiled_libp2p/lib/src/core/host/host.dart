// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../connmgr/manager.dart';
import '../event/bus.dart';
import '../network/network.dart';
import '../peer/addr_info.dart';
import '../peer/peer_id.dart';
import '../peerstore/peerstore.dart';
import '../protocol/protocol.dart';

/// AddrsFactory functions can be passed to a Host to override
/// addresses returned by Addrs.
typedef AddrsFactory = List<Multiaddr> Function(List<Multiaddr> addrs);

/// InfoFromHost returns an [AddrInfo] with the Host's ID and all of its Addrs.
AddrInfo infoFromHost(Host h) => AddrInfo(id: h.id, addrs: h.addrs);

/// Host is an object participating in a p2p network, which
/// implements protocols or provides services. It handles
/// requests like a Server, and issues requests like a Client.
abstract interface class Host {
  /// Local peer ID of this host.
  PeerId get id;

  /// Repository of peer addresses, keys, and metadata.
  Peerstore get peerstore;

  /// Listen addresses of the host.
  List<Multiaddr> get addrs;

  /// Network interface of the host.
  Network get network;

  /// Protocol multiplexer routing streams to protocol handlers.
  ProtocolSwitch get mux;

  /// Ensures a connection exists to the specified peer.
  Future<void> connect(AddrInfo pi, {NetworkContext context = NetworkContext.empty});

  /// Sets the protocol stream handler.
  void setStreamHandler(ProtocolId pid, StreamHandler handler);

  /// Sets the protocol stream handler with a protocol matching function.
  void setStreamHandlerMatch(ProtocolId pid, bool Function(ProtocolId) match, StreamHandler handler);

  /// Removes the protocol stream handler for [pid].
  void removeStreamHandler(ProtocolId pid);

  /// Opens a new stream to peer [p] with preferred protocols [pids].
  Future<NetworkStream> newStream(PeerId p, List<ProtocolId> pids, {NetworkContext context = NetworkContext.empty});

  /// Closes the host, shutting down its network and services.
  Future<void> close();

  /// Returns the connection manager.
  ConnManager get connManager;

  /// Returns the event bus.
  Bus get eventBus;
}
