// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// Port of go-libp2p/core/connmgr/decay.go.
import '../peer/peer_id.dart';

/// Computes a decayed score and whether the tag value should be removed.
typedef DecayFn = ({int after, bool remove}) Function(DecayingValue value);

/// Computes a new score after applying [delta].
typedef BumpFn = int Function(DecayingValue value, int delta);

/// Decayer is implemented by connection managers supporting decaying tags.
abstract interface class Decayer {
  /// Registers a named decaying tag, throwing if the name already exists.
  DecayingTag registerDecayingTag(
    String name,
    Duration interval,
    DecayFn decayFn,
    BumpFn bumpFn,
  );

  /// Closes the decayer.
  void close();
}

/// A long-lived handle for one decaying tag.
abstract interface class DecayingTag {
  /// The tag name.
  String name();

  /// The effective tick interval.
  Duration interval();

  /// Queues a score bump for [peer].
  void bump(PeerId peer, int delta);

  /// Queues removal of this tag's value for [peer].
  void remove(PeerId peer);

  /// Closes this tag and removes it from the manager.
  void close();
}

/// The value passed to a [DecayFn] or [BumpFn].
class DecayingValue {
  /// Creates a decaying value snapshot.
  DecayingValue({
    required this.tag,
    required this.peer,
    required this.added,
    required this.lastVisit,
    required this.value,
  });

  /// The tag this value belongs to.
  final DecayingTag tag;

  /// The associated peer.
  final PeerId peer;

  /// When this value was first added.
  final DateTime added;

  /// When this value was last visited.
  final DateTime lastVisit;

  /// Current score.
  final int value;
}
