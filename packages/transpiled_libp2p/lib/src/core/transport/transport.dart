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
///
/// Go: `manet.Conn`, which is a `net.Conn` and deliberately *not* a
/// `network.Conn` -- a raw socket has no libp2p identity, no streams and no
/// scope.
abstract interface class RawConn implements ConnMultiaddrs, StreamReadWriter {
  Transport transport();
  @override
  Future<Uint8List> read([int? maxLength]);
  @override
  Future<void> write(Uint8List data);
  Future<void> close();
  bool get isClosed;
}

/// A connection that offers basic security, multiplexing, and endpoint addressing.
///
/// Go: `transport.CapableConn` (`core/transport/transport.go:28-36`), which
/// embeds `network.MuxedConn`, `ConnSecurity`, `ConnMultiaddrs` and
/// `ConnScoper` -- and is *not* a `network.Conn`. The swarm-level connection
/// is `SwarmConn`, which wraps one of these.
abstract interface class CapableConn
    implements ConnSecurity, ConnMultiaddrs, ConnScoper, ConnStat {
  Transport transport();
  Future<MuxedStream> openStream();
  Future<MuxedStream> acceptStream();
  Future<void> close();

  /// Closes the connection, sending [errorCode] to the peer where the
  /// transport supports it; otherwise identical to [close].
  ///
  /// Go: `network.MuxedConn.CloseWithError` (`core/network/mux.go:20`).
  Future<void> closeWithError(ConnErrorCode errorCode);

  bool get isClosed;
}

/// A listener that accepts incoming raw or secured connections.
abstract interface class Listener {
  Future<CapableConn> accept();
  Future<void> close();
  Multiaddr multiaddr();
}

/// Hands out raw inbound connections that have already passed the connection
/// gater, for an [Upgrader] to negotiate.
///
/// Go: `transport.GatedMaListener` (`core/transport/transport.go:171-183`).
/// Its `Accept` returns a `network.ConnManagementScope` alongside the
/// connection; that is dropped here, because this port does not open resource
/// manager scopes on the listen path.
///
/// The point of the split is that accepting a socket and negotiating it are
/// separate jobs. A listener that negotiates inside its own `accept` can only
/// ever handle one handshake at a time, and a single peer that connects and
/// then says nothing stalls every other inbound connection behind it.
abstract interface class GatedMaListener {
  /// The next raw inbound connection, unnegotiated.
  Future<RawConn> accept();

  /// Stops listening and releases the underlying socket.
  Future<void> close();

  /// The address being listened on.
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
  /// Upgrades a raw socket into a secured, multiplexed connection.
  ///
  /// Go: `Upgrader.Upgrade` (`core/transport/transport.go:168`), which takes a
  /// `manet.Conn` -- a raw socket, never a `network.Conn`.
  Future<CapableConn> upgrade(RawConn conn, Direction dir, PeerId peer);

  /// Wraps [listener] into a full libp2p [Listener] that negotiates inbound
  /// connections concurrently, with a timeout and bounded backpressure.
  ///
  /// Go: `Upgrader.UpgradeGatedMaListener`
  /// (`core/transport/transport.go:165`), implemented by
  /// `p2p/net/upgrader/listener.go`. Go's deprecated `UpgradeListener` is not
  /// ported, since nothing here needs the ungated form.
  Listener upgradeGatedMaListener(
    Transport transport,
    GatedMaListener listener,
  );
}
