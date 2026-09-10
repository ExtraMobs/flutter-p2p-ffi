// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/keyspace.dart
//
// Port of go-libp2p-kbucket/keyspace's keyspace.go: a generic "key in some
// metric space" abstraction. go-libp2p-kbucket itself only actually uses
// xor.go's free functions (Xor/ZeroPrefixLen, see util.dart's
// commonPrefixLen), not this generic Key/KeySpace machinery -- ported in
// full anyway for fidelity, since callers outside this module (e.g.
// go-libp2p-kad-dht) may still reach for it directly.
import 'dart:typed_data';

/// An identifier in a [KeySpace]. Equivalent to go-libp2p-kbucket's
/// `keyspace.Key`.
class KeyspaceKey {
  /// Creates a key in [space], remembering both its [original] value and
  /// its [bytes] representation within that space.
  const KeyspaceKey({required this.space, required this.original, required this.bytes});

  /// The [KeySpace] this key belongs to.
  final KeySpace space;

  /// The original value the key was created from.
  final Uint8List original;

  /// The value of this identifier within [space].
  final Uint8List bytes;

  void _checkSameSpace(KeyspaceKey other) {
    if (!identical(space, other.space)) {
      throw StateError('keys are not in the same key space');
    }
  }

  /// Compares this key to [other] within their shared [KeySpace].
  int compareTo(KeyspaceKey other) {
    _checkSameSpace(other);
    return space.compare(this, other);
  }

  /// Whether this key equals [other] within their shared [KeySpace].
  bool keyEquals(KeyspaceKey other) {
    _checkSameSpace(other);
    return space.keyEqual(this, other);
  }

  /// This key's distance to [other] within their shared [KeySpace].
  BigInt distanceTo(KeyspaceKey other) {
    _checkSameSpace(other);
    return space.distance(this, other);
  }
}

/// An object used to do math on identifiers. Each key space has its own
/// properties and rules -- see [XorKeySpace]. Equivalent to
/// go-libp2p-kbucket's `keyspace.KeySpace`.
abstract class KeySpace {
  /// Converts [id] into a [KeyspaceKey] in this space.
  KeyspaceKey key(Uint8List id);

  /// Whether [a] and [b] are equal in this key space.
  bool keyEqual(KeyspaceKey a, KeyspaceKey b);

  /// The distance metric between [a] and [b] in this key space.
  BigInt distance(KeyspaceKey a, KeyspaceKey b);

  /// Compares [a] and [b] in this key space.
  int compare(KeyspaceKey a, KeyspaceKey b);
}

/// Sorts [toSort] by ascending distance to [center] within [space].
/// Equivalent to go-libp2p-kbucket's `keyspace.SortByDistance`.
List<KeyspaceKey> sortByDistance(
  KeySpace space,
  KeyspaceKey center,
  List<KeyspaceKey> toSort,
) {
  final withDistance = [
    for (final k in toSort) (key: k, distance: center.distanceTo(k)),
  ]..sort((a, b) => a.distance.compareTo(b.distance));
  return [for (final entry in withDistance) entry.key];
}
