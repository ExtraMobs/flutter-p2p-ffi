// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/host/peerstore/pstoreds/options.dart
//
// Port of go-libp2p's pstoreds/peerstore.go: `Options`, `DefaultOpts`, and
// the `clock`/`realclock` abstraction.
//
// Not ported: the GC tuning fields' background behavior (`addr_book_gc.go`,
// ~400 lines: a lookahead-indexed and a full-purge sweep algorithm). This
// datastore-backed peerstore is necessarily built differently from the Go
// original -- see pstoreds.dart's doc comment for why -- and under that
// design, [DsAddrBook] already prunes expired addresses on every access
// (mirroring `addrsRecord.clean` there), which is what "a restart preserves
// known peers" requires. A periodic background sweep only reclaims disk
// space for peers that are stored but never looked at again; it is a
// disk-usage optimization, not a correctness requirement, and is the
// explicit gap called out in PROGRESS.md for this port.

/// Configuration for a persistent peerstore. Equivalent to go-libp2p's
/// `pstoreds.Options`.
class Options {
  Options({
    this.cacheSize = 0,
    this.maxProtocols = 128,
    this.maxAddrsPerPeer = 0,
    this.gcPurgeInterval = Duration.zero,
    this.gcLookaheadInterval = Duration.zero,
    this.gcInitialDelay = Duration.zero,
    Clock? clock,
  }) : clock = clock ?? RealClock();

  /// The size of the in-memory cache. Unused by this port: [DsAddrBook],
  /// [DsKeyBook], [DsPeerMetadata] and [DsProtoBook] always keep every
  /// persisted peer's data in memory (a synchronous [Peerstore] can't be
  /// implemented as a lazy read-through cache over an async [Datastore]).
  /// Kept only for nomenclature parity with the Go upstream.
  final int cacheSize;

  /// The maximum number of protocols stored for one peer.
  final int maxProtocols;

  /// Bounds the number of unconnected addresses stored per peer. When the
  /// limit is reached, the unconnected entry with the nearest expiry is
  /// evicted before the new entry is inserted. Addresses held by a live
  /// connection (TTL >= [connectedAddrTtl]) are never evicted. A value
  /// <= 0 disables the cap.
  final int maxAddrsPerPeer;

  /// Unused: see the gap note in this file's doc comment.
  final Duration gcPurgeInterval;

  /// Unused: see the gap note in this file's doc comment.
  final Duration gcLookaheadInterval;

  /// Unused: see the gap note in this file's doc comment.
  final Duration gcInitialDelay;

  /// The time source used for address expiry. Equivalent to go-libp2p's
  /// `pstoreds.Options.Clock`.
  final Clock clock;
}

/// A time source, abstracted for testability. Equivalent to go-libp2p's
/// `pstoreds.clock` (only `Now` is ported -- `After` backed the
/// background GC timer, which this port doesn't have).
abstract class Clock {
  DateTime now();
}

/// The system clock. Equivalent to go-libp2p's `pstoreds.realclock`.
class RealClock implements Clock {
  @override
  DateTime now() => DateTime.now();
}

/// The default options for a persistent peerstore. Equivalent to
/// go-libp2p's `DefaultOpts`, minus the unported GC tuning (see this
/// file's doc comment).
///
/// * Cache size: 1024 (unused; see [Options.cacheSize]).
/// * MaxProtocols: 1024.
/// * MaxAddrsPerPeer: 64.
Options defaultOpts() => Options(
  cacheSize: 1024,
  maxProtocols: 1024,
  maxAddrsPerPeer: 64,
  gcPurgeInterval: const Duration(hours: 2),
  gcInitialDelay: const Duration(seconds: 60),
);
