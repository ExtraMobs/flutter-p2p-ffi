// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/bitswap/client/wantlist/wantlist.dart
//
// Port of boxo/bitswap/client/wantlist/wantlist.go: the set of keys a
// given peer wants, tracked by a bitswap client.
import 'package:transpiled_cid/transpiled_cid.dart';

import 'want_type.dart';

/// An entry in a want list: a Cid, its priority, and whether the full
/// block or just a "have" is wanted. Equivalent to go-boxo's
/// `wantlist.Entry`.
class Entry {
  /// Creates an entry.
  const Entry({
    required this.cid,
    required this.priority,
    required this.wantType,
  });

  /// Creates a reference-tracked entry wanting the full block. Equivalent to
  /// go-boxo's `NewRefEntry`.
  factory Entry.ref(Cid cid, int priority) =>
      Entry(cid: cid, priority: priority, wantType: WantType.block);

  /// The wanted content.
  final Cid cid;

  /// This entry's priority (higher sorts first in [Wantlist.entries]).
  final int priority;

  /// Whether the full block or just a "have" is wanted.
  final WantType wantType;
}

/// A raw list of wanted blocks and their priorities. Equivalent to
/// go-boxo's `wantlist.Wantlist`. Go guards nothing here with a mutex
/// (callers are expected to synchronize); this port carries that same
/// expectation forward unchanged.
class Wantlist {
  final Map<Cid, Entry> _set = {};

  // Re-computing this can get expensive, so it's memoized -- matches
  // go-boxo's own `cached` field and invalidation points exactly.
  List<Entry>? _cached;

  /// The number of entries in this wantlist. Equivalent to go-boxo's
  /// `Wantlist.Len`.
  int get length => _set.length;

  /// Adds an entry for [cid] at [priority], if not already present.
  /// Returns `true` if newly added. Adding a "have" want never overrides
  /// an existing "block" want. Equivalent to go-boxo's `Wantlist.Add`.
  bool add(Cid cid, int priority, WantType wantType) {
    final existing = _set[cid];
    if (existing != null &&
        (existing.wantType == WantType.block || wantType == WantType.have)) {
      return false;
    }
    _put(cid, Entry(cid: cid, priority: priority, wantType: wantType));
    return true;
  }

  /// Removes [cid] from this wantlist regardless of its want type.
  /// Equivalent to go-boxo's `Wantlist.Remove`.
  void remove(Cid cid) => _delete(cid);

  /// Removes [cid], respecting [wantType]: removing with "have" will not
  /// remove an existing "block" want. Returns `true` if actually removed.
  /// Equivalent to go-boxo's `Wantlist.RemoveType`.
  bool removeType(Cid cid, WantType wantType) {
    final existing = _set[cid];
    if (existing == null) {
      return false;
    }
    if (existing.wantType == WantType.block && wantType == WantType.have) {
      return false;
    }
    _delete(cid);
    return true;
  }

  void _delete(Cid cid) {
    _set.remove(cid);
    _cached = null;
  }

  void _put(Cid cid, Entry e) {
    _cached = null;
    _set[cid] = e;
  }

  /// Whether [cid] is in this wantlist. Equivalent to go-boxo's
  /// `Wantlist.Has`.
  bool has(Cid cid) => _set.containsKey(cid);

  /// The entry for [cid], or `null` if absent. Equivalent to go-boxo's
  /// `Wantlist.Get` (its `bool` presence flag is redundant with Dart's
  /// nullable return).
  Entry? get(Cid cid) => _set[cid];

  /// All entries, sorted by descending priority. The returned list is
  /// cached -- callers must not mutate it. Equivalent to go-boxo's
  /// `Wantlist.Entries`.
  List<Entry> entries() {
    final cached = _cached;
    if (cached != null) return cached;
    final result = _set.values.toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final unmodifiable = List<Entry>.unmodifiable(result);
    _cached = unmodifiable;
    return unmodifiable;
  }
}
