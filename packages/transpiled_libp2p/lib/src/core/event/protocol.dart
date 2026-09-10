// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: duplicate_ignore, public_member_api_docs

import '../peer/peer_id.dart';
import '../protocol/protocol.dart';

final class EvtPeerProtocolsUpdated {
  const EvtPeerProtocolsUpdated({
    required this.peer,
    this.added = const [],
    this.removed = const [],
  });
  final PeerId peer;
  final List<ProtocolId> added;
  final List<ProtocolId> removed;
}

final class EvtLocalProtocolsUpdated {
  const EvtLocalProtocolsUpdated({
    this.added = const [],
    this.removed = const [],
  });
  final List<ProtocolId> added;
  final List<ProtocolId> removed;
}
