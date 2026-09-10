// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: duplicate_ignore, public_member_api_docs

import '../network/network.dart';
import '../peer/peer_id.dart';

/// Emitted when a peer's aggregate connectedness changes.
final class EvtPeerConnectednessChanged {
  const EvtPeerConnectednessChanged({
    required this.peer,
    required this.connectedness,
  });

  final PeerId peer;
  final Connectedness connectedness;
}
