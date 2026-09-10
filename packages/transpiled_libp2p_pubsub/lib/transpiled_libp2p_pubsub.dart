// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `go-libp2p-pubsub` (partial). The core `PubSub`/`GossipSubRouter`
/// orchestration is NOT ported -- it fundamentally needs a real
/// `go-libp2p` `Host`/`Stream`/`Network`, none of which exist in this
/// transpilation yet (that layer still comes from the third-party
/// `ipfs_libp2p` package; see doc/transpilation/PROGRESS.md). Only the
/// self-contained, libp2p-Host-independent pieces are ported so far:
/// `timecache` (message-deduplication TTL caches) and
/// `partialmessages/bitmap` (a growable bitmap for chunk tracking).
library;

export 'src/partialmessages/bitmap.dart' show Bitmap;
export 'src/timecache/first_seen_cache.dart' show FirstSeenCache;
export 'src/timecache/last_seen_cache.dart' show LastSeenCache;
export 'src/timecache/time_cache.dart' show TimeCache, TimeCacheStrategy;
export 'src/timecache/util.dart'
    show backgroundSweepInterval, startBackgroundSweep, sweep;
