// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../../core/host/host.dart';
import '../../../../core/network/network.dart';
import '../../../../core/peer/addr_info.dart';
import '../../../../core/peer/peer_id.dart';
import '../proto/protocol.dart';
import 'reservation.dart';

/// Circuit Relay v2 client implementation.
class Client {
  Client({required this.host});

  final Host host;
  bool _started = false;
  bool _closed = false;

  bool get isStarted => _started;
  bool get isClosed => _closed;

  void start() {
    if (_started || _closed) return;
    _started = true;
    host.setStreamHandler(protoIDv2Stop, _handleStop);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _started = false;
    host.removeStreamHandler(protoIDv2Stop);
  }

  void _handleStop(NetworkStream stream) {
    // Handling inbound relayed connection via stop protocol
  }

  /// Checks if a multiaddr represents a circuit address (/p2p-circuit).
  bool canDial(Multiaddr a) {
    return a.protocols.any((p) => p.name == 'p2p-circuit');
  }

  /// Reserves a slot on a relay peer.
  Future<Reservation> reserveSlot(AddrInfo relay) {
    return reserve(host, relay);
  }
}
