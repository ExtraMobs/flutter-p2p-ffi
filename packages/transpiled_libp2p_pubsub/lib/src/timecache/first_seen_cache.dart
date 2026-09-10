// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/timecache/first_seen_cache.dart
//
// Port of go-libp2p-pubsub's timecache/first_seen_cache.go: a TimeCache
// that only marks expiry when an entry is first added.
import 'dart:async';

import 'time_cache.dart';
import 'util.dart';

/// A [TimeCache] that only marks the expiry of an id when first added.
/// Equivalent to go-libp2p-pubsub's `FirstSeenCache`. Go guards its map
/// with a `sync.RWMutex`; not ported, since Dart's single-isolate
/// cooperative model never runs two pieces of synchronous logic
/// concurrently and nothing here `await`s mid-mutation (same rationale
/// already used for `go-libp2p-kbucket`'s `RoutingTable`).
class FirstSeenCache implements TimeCache {
  /// Creates the cache. [sweepInterval] defaults to
  /// [backgroundSweepInterval], overridable for testing.
  FirstSeenCache(this._ttl, [Duration sweepInterval = backgroundSweepInterval]) {
    _sweepTimer = startBackgroundSweep(_entries, sweepInterval);
  }

  final Map<String, DateTime> _entries = {};
  final Duration _ttl;
  late final Timer _sweepTimer;

  @override
  void done() => _sweepTimer.cancel();

  @override
  bool has(String id) => _entries.containsKey(id);

  @override
  bool add(String id) {
    if (_entries.containsKey(id)) return false;
    _entries[id] = DateTime.now().add(_ttl);
    return true;
  }
}
