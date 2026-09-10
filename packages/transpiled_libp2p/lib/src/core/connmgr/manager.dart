// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p/core/connmgr/manager.go.
import '../network/network.dart';
import '../peer/peer_id.dart';
import 'decay.dart';

/// Returns the decayer implemented by [manager] and whether it supports
/// decaying tags. Equivalent to go-libp2p's `SupportsDecay` type assertion.
(Decayer?, bool) supportsDecay(ConnManager manager) =>
    manager is Decayer ? (manager as Decayer, true) : (null, false);

/// Tracks connections and associates metadata and protection tags with peers.
///
/// `context.Context` is omitted because Dart's Future/Stream lifecycle is the
/// cancellation mechanism used by this package. Go errors are represented by
/// exceptions thrown by implementations.
abstract interface class ConnManager {
  /// Associates [value] with [tag] for [peer].
  void tagPeer(PeerId peer, String tag, int value);

  /// Removes [tag] from [peer].
  void untagPeer(PeerId peer, String tag);

  /// Updates or inserts [tag], passing its current value to [upsert].
  void upsertTag(PeerId peer, String tag, int Function(int value) upsert);

  /// Returns metadata for [peer], or `null` when no metadata exists.
  TagInfo? getTagInfo(PeerId peer);

  /// Trims open connections according to the manager's policy.
  void trimOpenConns();

  /// Returns the network callback receiver used by this manager.
  Notifiee notifiee();

  /// Protects [peer] from pruning under [tag].
  void protect(PeerId peer, String tag);

  /// Removes protection under [tag] and reports whether another protection
  /// still remains.
  bool unprotect(PeerId peer, String tag);

  /// Reports whether [peer] is protected. An empty [tag] checks all tags.
  bool isProtected(PeerId peer, String tag);

  /// Throws when the manager exceeds [limiter]'s connection limit.
  void checkLimit(GetConnLimiter limiter);

  /// Closes the manager.
  void close();
}

/// Metadata associated with one peer by a connection manager.
class TagInfo {
  /// Creates metadata. The epoch is Dart's closest zero value for Go's
  /// `time.Time`.
  TagInfo({
    DateTime? firstSeen,
    this.value = 0,
    Map<String, int>? tags,
    Map<String, DateTime>? conns,
  }) : firstSeen =
           firstSeen ?? DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true),
       tags = tags ?? {},
       conns = conns ?? {};

  /// When this peer was first seen.
  DateTime firstSeen;

  /// Aggregate tag value.
  int value;

  /// Numerical values by tag identifier.
  final Map<String, int> tags;

  /// Connection identifiers and their creation times.
  final Map<String, DateTime> conns;
}

/// Supplies a component's total connection limit.
abstract interface class GetConnLimiter {
  /// Returns the total connection limit.
  int getConnLimit();
}
