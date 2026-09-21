// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/discovery/backoff/backoffcache.dart
//
// Port of go-libp2p/p2p/discovery/backoff/backoffcache.go: a [Discovery]
// decorator that caches peer results per namespace and attenuates repeated
// `findPeers` calls with a [BackoffStrategy].
//
// Go's implementation fans a single ongoing `FindPeers` query out to every
// concurrent caller via unbuffered/bounded channels plus goroutines
// (`findPeerDispatcher`/`findPeerReceiver`). Dart has no goroutines and a
// single-threaded event loop, so the same fan-out is expressed with plain
// [StreamController]s: one dispatcher subscription per namespace feeding
// zero or more listener controllers. This is a runtime adaptation, not a
// behavioral one -- every caching/backoff decision (when a query is
// considered "ongoing", when the backoff resets, what a late joiner
// receives) mirrors the Go source line for line; see the inline comments
// tying each block back to `backoffcache.go`.
//
// Go's `clock` interface (and its `realClock`) is unexported -- its only
// purpose upstream is a same-package test hook (`withClock` in
// `backoffcache_test.go`), not public API. Per AGENTS.md's "símbolos sem
// correspondente exportado devem ser privados" rule, no Dart type is
// invented for it: cache expiry is evaluated against [DateTime.now]
// directly, matching what `realClock.Now()` -- the only implementation
// ever used in production -- itself does.
import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/discovery/discovery.dart';
import '../../../core/discovery/options.dart';
import '../../../core/peer/addr_info.dart';
import '../../../core/peer/peer_id.dart';
import 'backoff.dart';

/// Mutates a [BackoffDiscovery] at construction time. Equivalent to
/// go-libp2p's `BackoffDiscoveryOption`.
typedef BackoffDiscoveryOption = void Function(BackoffDiscovery discovery);

/// Sets the buffer size for the channel fanning a single ongoing
/// [BackoffDiscovery.findPeers] query out to every simultaneous caller for
/// the same namespace. Equivalent to go-libp2p's
/// `WithBackoffDiscoverySimultaneousQueryBufferSize`.
///
/// Dart's [StreamController] fan-out has no fixed-size channel to bound --
/// listeners are never dropped for lack of buffer space -- so this setting
/// is accepted (and validated, matching Go's error behavior) for API
/// parity but does not change delivery.
BackoffDiscoveryOption withBackoffDiscoverySimultaneousQueryBufferSize(
  int size,
) {
  if (size < 0) {
    throw ArgumentError('cannot set size to be smaller than 0');
  }
  return (discovery) => discovery.parallelBufferSize = size;
}

/// Sets the size of the buffer used while a [BackoffDiscovery.findPeers]
/// query is in flight. Does not apply when the query is served from cache.
/// Equivalent to go-libp2p's `WithBackoffDiscoveryReturnedChannelSize`.
///
/// See [withBackoffDiscoverySimultaneousQueryBufferSize] for why this is a
/// no-op on delivery in the Dart port.
BackoffDiscoveryOption withBackoffDiscoveryReturnedChannelSize(int size) {
  if (size < 0) {
    throw ArgumentError('cannot set size to be smaller than 0');
  }
  return (discovery) => discovery.returnedBufferSize = size;
}

/// An implementation of [Discovery] that caches peer data and attenuates
/// repeated queries. Equivalent to go-libp2p's `BackoffDiscovery`.
class BackoffDiscovery implements Discovery {
  /// Wraps [disc], backing off subsequent [findPeers] calls for the same
  /// namespace per [stratFactory]. Equivalent to go-libp2p's
  /// `NewBackoffDiscovery`.
  BackoffDiscovery(
    this.disc,
    this.stratFactory, {
    List<BackoffDiscoveryOption> options = const [],
  }) {
    for (final option in options) {
      option(this);
    }
  }

  /// The wrapped discovery system.
  final Discovery disc;

  /// Produces the backoff strategy used for each newly seen namespace.
  final BackoffFactory stratFactory;

  /// See [withBackoffDiscoverySimultaneousQueryBufferSize].
  int parallelBufferSize = 32;

  /// See [withBackoffDiscoveryReturnedChannelSize].
  int returnedBufferSize = 32;

  final Map<String, _BackoffCache> _peerCache = {};

  @override
  Future<Duration> advertise(
    String namespace, {
    List<DiscoveryOption> options = const [],
  }) => disc.advertise(namespace, options: options);

  @override
  Stream<AddrInfo> findPeers(
    String namespace, {
    List<DiscoveryOption> options = const [],
  }) {
    final opts = DiscoveryOptions()..apply(options);

    // Setup cache if we don't have one yet.
    final cache = _peerCache.putIfAbsent(
      namespace,
      () => _BackoffCache(stratFactory()),
    );

    final timeExpired =
        cache.nextDiscover == null ||
        DateTime.now().isAfter(cache.nextDiscover!);

    // If it's not yet time to search again and no search is in progress,
    // return cached peers.
    if (!(timeExpired || cache.ongoing)) {
      final prev = cache.prevPeers.values.toList(growable: false);
      final chLen = opts.limit == 0
          ? prev.length
          : (opts.limit > prev.length ? prev.length : opts.limit);
      return Stream.fromIterable(prev.take(chLen));
    }

    // If a request is not already in progress, start one.
    if (!cache.ongoing) {
      cache.ongoing = true;
      cache.startDispatch(disc.findPeers(namespace, options: options));
    }

    // Setup a receiver for the ongoing (or just-started) request.
    return cache.subscribe(opts.limit);
  }
}

/// Per-namespace cache state and in-flight query fan-out. Equivalent to
/// go-libp2p's private `backoffCache`.
class _BackoffCache {
  _BackoffCache(this.strat);

  final BackoffStrategy strat;

  DateTime? nextDiscover;
  Map<PeerId, AddrInfo> prevPeers = {};
  Map<PeerId, AddrInfo> peers = {};
  bool ongoing = false;

  final List<_CacheListener> _listeners = [];

  /// Subscribes to the underlying discovery [source] for this namespace.
  /// Equivalent to go-libp2p's `findPeerDispatcher` goroutine.
  void startDispatch(Stream<AddrInfo> source) {
    peers = {};
    source.listen(
      (ai) {
        AddrInfo sendAi;
        final prevAi = peers[ai.id];
        if (prevAi != null) {
          final merged = _mergeAddrInfos(prevAi, ai);
          if (merged == null) return;
          sendAi = merged;
        } else {
          sendAi = ai;
        }
        peers[ai.id] = sendAi;

        for (final listener in _listeners) {
          listener.emit(sendAi);
        }
      },
      onDone: _finishDispatch,
      onError: (Object error, StackTrace stackTrace) {
        for (final listener in _listeners) {
          listener.addError(error, stackTrace);
        }
        _finishDispatch();
      },
    );
  }

  void _finishDispatch() {
    // If the peer addresses have changed, reset the backoff.
    if (_checkUpdates(prevPeers, peers)) {
      strat.reset();
      prevPeers = peers;
    }
    nextDiscover = DateTime.now().add(strat.delay());

    ongoing = false;
    peers = {};

    for (final listener in _listeners) {
      listener.close();
    }
    _listeners.clear();
  }

  /// Registers a new listener on the ongoing (or just-started) query.
  /// Equivalent to go-libp2p's `findPeerReceiver` goroutine, plus the
  /// snapshot of already-known peers it seeds `rcvPeers` with.
  Stream<AddrInfo> subscribe(int limit) {
    final listener = _CacheListener(limit);
    // Seed with peers already discovered this round, delivered in full
    // regardless of [limit] -- matches Go's unconditional `rcvPeers` flush.
    // Future peers (delivered via [emit]) are gated by [limit], matching
    // Go's `sendingChs[evtCh] = options.Limit` countdown.
    for (final ai in peers.values) {
      listener.controller.add(ai);
    }
    _listeners.add(listener);
    return listener.controller.stream;
  }
}

/// One caller's view onto an in-flight query. Equivalent to go-libp2p's
/// `sendingChs` entry (the channel plus its remaining-sends countdown).
class _CacheListener {
  _CacheListener(this._remaining);

  int _remaining;
  final StreamController<AddrInfo> controller = StreamController<AddrInfo>();

  void emit(AddrInfo ai) {
    if (_remaining > 0) {
      controller.add(ai);
      _remaining--;
    }
  }

  void addError(Object error, StackTrace stackTrace) =>
      controller.addError(error, stackTrace);

  void close() => controller.close();
}

/// Combines the address sets of two [AddrInfo]s for the same peer, or
/// returns `null` if [newAi] adds nothing new. Equivalent to go-libp2p's
/// private `mergeAddrInfos`.
AddrInfo? _mergeAddrInfos(AddrInfo prevAi, AddrInfo newAi) {
  final seen = <String>{};
  final combined = <Multiaddr>[];
  void addAddrs(Iterable<Multiaddr> addrs) {
    for (final addr in addrs) {
      if (seen.add(addr.toString())) combined.add(addr);
    }
  }

  addAddrs(prevAi.addrs);
  addAddrs(newAi.addrs);

  if (combined.length > prevAi.addrs.length) {
    return AddrInfo(id: prevAi.id, addrs: combined);
  }
  return null;
}

/// Reports whether [update] differs from [orig] in a way that should reset
/// backoff. Equivalent to go-libp2p's private `checkUpdates`.
bool _checkUpdates(Map<PeerId, AddrInfo> orig, Map<PeerId, AddrInfo> update) {
  if (orig.length != update.length) return true;
  for (final entry in update.entries) {
    final prevAi = orig[entry.key];
    if (prevAi == null) return true;
    if (_mergeAddrInfos(prevAi, entry.value) != null) return true;
  }
  return false;
}
