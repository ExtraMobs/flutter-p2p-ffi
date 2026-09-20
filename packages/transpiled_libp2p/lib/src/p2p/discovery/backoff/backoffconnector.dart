// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// lib/src/p2p/discovery/backoff/backoffconnector.dart
//
// Port of go-libp2p/p2p/discovery/backoff/backoffconnector.go: dials peers
// discovered from a stream, backing off recently-attempted ones.
import 'dart:async';

import '../../../core/host/host.dart';
import '../../../core/peer/addr_info.dart';
import '../../../core/peer/peer_id.dart';
import 'backoff.dart';

/// A utility to connect to peers, but only if not already recently
/// attempted. Equivalent to go-libp2p's `BackoffConnector`.
class BackoffConnector {
  /// Creates a [BackoffConnector] dialing through [host]. [cacheSize]
  /// bounds how many peers' backoff state is remembered (a
  /// `TwoQueueCache`-sized LRU in Go; see [_LruCache]); [connectionTryDuration]
  /// is how long each connection attempt is given before giving up;
  /// [backoff] describes the per-peer backoff strategy used after a
  /// previous connection attempt. Equivalent to go-libp2p's
  /// `NewBackoffConnector`.
  BackoffConnector(
    this._host,
    int cacheSize,
    this._connTryDuration,
    this._backoff,
  ) : _cache = _LruCache(cacheSize < 1 ? 1 : cacheSize) {
    if (cacheSize <= 0) {
      throw ArgumentError.value(cacheSize, 'cacheSize', 'must be positive');
    }
  }

  final Host _host;
  final Duration _connTryDuration;
  final BackoffFactory _backoff;
  final _LruCache<PeerId, _ConnCacheData> _cache;

  /// Attempts to connect to peers from [peerStream] as they arrive, unless
  /// within their backoff period. Since this dials as soon as it learns
  /// about a peer, callers should keep [peerStream]'s delivery rate
  /// manageable. Equivalent to go-libp2p's `BackoffConnector.Connect`; Go's
  /// `context.Context` cancellation is replaced by cancelling the
  /// subscription feeding [peerStream], matching this module's Future/Stream
  /// cancellation idiom (see `core/discovery/discovery.dart`).
  Future<void> connect(Stream<AddrInfo> peerStream) async {
    await for (final pi in peerStream) {
      if (pi.id == _host.id || pi.id.isEmpty) continue;

      final now = DateTime.now();
      final cached = _cache.get(pi.id);
      if (cached != null) {
        if (now.isBefore(cached.nextTry)) continue;
        cached.nextTry = now.add(cached.strategy.delay());
      } else {
        final data = _ConnCacheData(_backoff());
        data.nextTry = now.add(data.strategy.delay());
        _cache.put(pi.id, data);
      }

      unawaited(
        _host.connect(pi).timeout(_connTryDuration).catchError((Object _) {}),
      );
    }
  }
}

/// Per-peer backoff bookkeeping. Equivalent to go-libp2p's private
/// `connCacheData`.
class _ConnCacheData {
  _ConnCacheData(this.strategy);
  final BackoffStrategy strategy;
  late DateTime nextTry;
}

/// A minimal fixed-capacity least-recently-used cache.
///
/// Go's `BackoffConnector` uses `hashicorp/golang-lru`'s `TwoQueueCache`, a
/// third-party dependency of go-libp2p itself with its own `go.mod`
/// boundary and no Dart port anywhere in this repo. Per this project's
/// precedent for out-of-boundary dependencies too narrow to justify a
/// dedicated package (`p2p/discovery/mdns/mdns.dart`'s treatment of
/// `zeroconf`/`miekg/dns`), a plain LRU replaces the full 2Q algorithm here:
/// both are internal cache-eviction policies, and nothing in
/// [BackoffConnector]'s public contract (which peers get backed off, for
/// how long) is observable through the eviction *policy* -- only through
/// [nextTry] scheduling, which this preserves exactly. Only eviction order
/// once [cacheSize] entries are exceeded can differ from 2Q's.
class _LruCache<K, V> {
  _LruCache(this._capacity);

  final int _capacity;
  final Map<K, V> _entries = {};

  V? get(K key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    _entries[key] = value; // Move to most-recently-used.
    return value;
  }

  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    if (_entries.length > _capacity) {
      _entries.remove(_entries.keys.first);
    }
  }
}
