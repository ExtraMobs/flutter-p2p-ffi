// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p/core/connmgr/gater.go.
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../control/disconnect.dart';
import '../network/network.dart';
import '../peer/peer_id.dart';

/// Intercepts connection establishment at each lifecycle stage.
///
abstract interface class ConnectionGater {
  /// Decides whether dialing [peer] is allowed.
  bool interceptPeerDial(PeerId peer);

  /// Decides whether dialing [address] for [peer] is allowed.
  bool interceptAddrDial(PeerId peer, Multiaddr address);

  /// Decides whether an inbound connection with [connectionAddresses] is
  /// allowed.
  bool interceptAccept(ConnMultiaddrs connectionAddresses);

  /// Decides whether an authenticated connection is allowed.
  bool interceptSecured(
    Direction direction,
    PeerId peer,
    ConnMultiaddrs connectionAddresses,
  );

  /// Decides whether a fully upgraded [connection] is allowed, returning its
  /// experimental disconnect reason when rejected.
  ({bool allow, DisconnectReason reason}) interceptUpgraded(Conn connection);
}
