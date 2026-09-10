// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p/core/connmgr/null.go.
import '../network/network.dart';
import '../peer/peer_id.dart';
import 'manager.dart';

/// A connection manager that performs no operations.
final class NullConnMgr implements ConnManager {
  /// Creates a no-op connection manager.
  const NullConnMgr();

  @override
  void tagPeer(PeerId peer, String tag, int value) {}

  @override
  void untagPeer(PeerId peer, String tag) {}

  @override
  void upsertTag(PeerId peer, String tag, int Function(int value) upsert) {}

  @override
  TagInfo getTagInfo(PeerId peer) => TagInfo();

  @override
  void trimOpenConns() {}

  @override
  Notifiee notifiee() => globalNoopNotifiee;

  @override
  void protect(PeerId peer, String tag) {}

  @override
  bool unprotect(PeerId peer, String tag) => false;

  @override
  bool isProtected(PeerId peer, String tag) => false;

  @override
  void checkLimit(GetConnLimiter limiter) {}

  @override
  void close() {}
}
