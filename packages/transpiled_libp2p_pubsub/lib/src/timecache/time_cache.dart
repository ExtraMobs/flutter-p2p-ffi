// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/timecache/time_cache.dart
//
// Port of go-libp2p-pubsub's timecache/time_cache.go: a cache of recently
// seen message IDs, used by pubsub to deduplicate messages.
import 'first_seen_cache.dart';
import 'last_seen_cache.dart';

/// Which expiry strategy a [TimeCache] uses. Equivalent to
/// go-libp2p-pubsub's `Strategy`.
enum TimeCacheStrategy {
  /// Expires an entry from the time it was added. Equivalent to
  /// go-libp2p-pubsub's `Strategy_FirstSeen`.
  firstSeen,

  /// Expires an entry from the last time it was touched by [TimeCache.add]
  /// or [TimeCache.has]. Equivalent to go-libp2p-pubsub's
  /// `Strategy_LastSeen`.
  lastSeen,
}

/// A cache of recently seen ids. Equivalent to go-libp2p-pubsub's
/// `TimeCache`.
abstract class TimeCache {
  /// Creates a [TimeCache] using the default ("first seen") strategy.
  /// Equivalent to go-libp2p-pubsub's `NewTimeCache`.
  factory TimeCache(Duration ttl) =>
      TimeCache.withStrategy(TimeCacheStrategy.firstSeen, ttl);

  /// Creates a [TimeCache] using [strategy]. Equivalent to
  /// go-libp2p-pubsub's `NewTimeCacheWithStrategy`.
  factory TimeCache.withStrategy(TimeCacheStrategy strategy, Duration ttl) {
    return switch (strategy) {
      TimeCacheStrategy.firstSeen => FirstSeenCache(ttl),
      TimeCacheStrategy.lastSeen => LastSeenCache(ttl),
    };
  }

  /// Creates a [FirstSeenCache] with an explicit sweep interval (for
  /// testing). Equivalent to go-libp2p-pubsub's
  /// `newFirstSeenCacheWithSweepInterval`.
  factory TimeCache.firstSeenWithSweepInterval(
    Duration ttl,
    Duration sweepInterval,
  ) => FirstSeenCache(ttl, sweepInterval);

  /// Creates a [LastSeenCache] with an explicit sweep interval (for
  /// testing). Equivalent to go-libp2p-pubsub's
  /// `newLastSeenCacheWithSweepInterval`.
  factory TimeCache.lastSeenWithSweepInterval(
    Duration ttl,
    Duration sweepInterval,
  ) => LastSeenCache(ttl, sweepInterval);

  /// Adds [id] into the cache if not already present. Returns `true` if
  /// newly added. Depending on the strategy, may or may not update an
  /// existing entry's expiry.
  bool add(String id);

  /// Whether [id] is in the cache. Depending on the strategy, may or may
  /// not update an existing entry's expiry.
  bool has(String id);

  /// Signals this cache is no longer needed, stopping its background
  /// sweep and releasing resources.
  void done();
}
