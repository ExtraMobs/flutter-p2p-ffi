// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/timecache/last_seen_cache.dart
//
// Port of go-libp2p-pubsub's timecache/last_seen_cache.go: a TimeCache
// that extends an entry's expiry whenever it's added or checked.
import 'dart:async';

import 'time_cache.dart';
import 'util.dart';

/// A [TimeCache] that extends the expiry of a seen id whenever it's
/// touched by [add] or [has]. Equivalent to go-libp2p-pubsub's
/// `LastSeenCache` (its `sync.Mutex` isn't ported -- see
/// `first_seen_cache.dart`'s header for why).
class LastSeenCache implements TimeCache {
  /// Creates the cache. [sweepInterval] defaults to
  /// [backgroundSweepInterval], overridable for testing.
  LastSeenCache(this._ttl, [Duration sweepInterval = backgroundSweepInterval]) {
    _sweepTimer = startBackgroundSweep(_entries, sweepInterval);
  }

  final Map<String, DateTime> _entries = {};
  final Duration _ttl;
  late final Timer _sweepTimer;

  @override
  void done() => _sweepTimer.cancel();

  @override
  bool add(String id) {
    final existed = _entries.containsKey(id);
    _entries[id] = DateTime.now().add(_ttl);
    return !existed;
  }

  @override
  bool has(String id) {
    final existed = _entries.containsKey(id);
    if (existed) {
      _entries[id] = DateTime.now().add(_ttl);
    }
    return existed;
  }
}
