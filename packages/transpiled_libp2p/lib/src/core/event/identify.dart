// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: duplicate_ignore, public_member_api_docs

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../network/network.dart';
import '../peer/peer_id.dart';
import '../protocol/protocol.dart';
import '../record/envelope.dart';

final class EvtPeerIdentificationCompleted {
  const EvtPeerIdentificationCompleted({
    required this.peer,
    required this.conn,
    this.listenAddrs = const [],
    this.protocols = const [],
    this.signedPeerRecord,
    this.agentVersion = '',
    this.protocolVersion = '',
    required this.observedAddr,
  });
  final PeerId peer;
  final Conn conn;
  final List<Multiaddr> listenAddrs;
  final List<ProtocolId> protocols;
  final Envelope? signedPeerRecord;
  final String agentVersion;
  final String protocolVersion;
  final Multiaddr observedAddr;
}

final class EvtPeerIdentificationFailed {
  const EvtPeerIdentificationFailed({required this.peer, required this.reason});
  final PeerId peer;
  final Object reason;
}
