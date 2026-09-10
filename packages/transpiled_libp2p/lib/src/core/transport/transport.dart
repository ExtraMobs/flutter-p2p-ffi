// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../network/network.dart';
import '../peer/peer_id.dart';

/// Thrown when an operation is performed on a closed listener.
class ListenerClosedException implements Exception {
  const ListenerClosedException();

  @override
  String toString() => 'listener closed';
}

const errListenerClosed = ListenerClosedException();

/// A raw network connection before security and multiplexing upgrade.
abstract interface class RawConn implements Conn, ConnMultiaddrs, StreamReadWriter {
  Transport transport();
  @override
  Future<Uint8List> read([int? maxLength]);
  @override
  Future<void> write(Uint8List data);
  Future<void> close();
  bool get isClosed;
}

/// A connection that offers basic security, multiplexing, and endpoint addressing.
abstract interface class CapableConn
    implements Conn, ConnSecurity, ConnMultiaddrs, ConnScoper, ConnStat {
  Transport transport();
  Future<NetworkStream> openStream();
  Future<NetworkStream> acceptStream();
  Future<void> close();
  bool get isClosed;
}

/// A listener that accepts incoming raw or secured connections.
abstract interface class Listener {
  Future<CapableConn> accept();
  Future<void> close();
  Multiaddr multiaddr();
}

/// Represents any device or network protocol by which you can dial and accept connections.
abstract interface class Transport {
  Future<CapableConn> dial(Multiaddr addr, PeerId peer);
  bool canDial(Multiaddr addr);
  Future<Listener> listen(Multiaddr addr);
  List<int> protocols();
  bool proxy();
}

/// A network with methods for managing transports.
abstract interface class TransportNetwork implements Network {
  void addTransport(Transport transport);
}

/// Carries update events during dial progress.
class DialUpdate {
  const DialUpdate({
    required this.kind,
    required this.addr,
    this.conn,
    this.err,
  });

  final String kind;
  final Multiaddr addr;
  final CapableConn? conn;
  final Exception? err;
}

/// Provides updates on in-progress dials.
abstract interface class DialUpdater {
  Stream<DialUpdate> dialWithUpdates(Multiaddr addr, PeerId peer);
}

/// Upgrades an underlying raw network connection or listener into a full libp2p connection.
abstract interface class Upgrader {
  Future<CapableConn> upgrade(Conn conn, Direction dir, PeerId peer);
}
