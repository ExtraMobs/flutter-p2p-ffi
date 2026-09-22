// ignore_for_file: duplicate_ignore, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of `go-libp2p/x/rate` (`limiter.go`).
///
/// Rate limiting at a global, network-prefix and subnet level. `x/rate` has no
/// `go.mod` of its own, so it belongs to the `go-libp2p` module and lives in
/// this package.
///
/// Omissions recorded in `doc/transpilation/PROGRESS.md`:
///
///  * `sync.Once` and `sync.Mutex` (`limiter.go:51,143-144`) are not ported.
///    A Dart isolate does not preempt inside synchronous code and none of the
///    guarded regions has an `await`; the `Once` becomes a plain lazy flag.
///  * `container/heap` has no Dart counterpart, so [_BucketHeap] carries its
///    own sift-up/sift-down, keeping Go's `prefixToIndex` side table so that
///    `Upsert` can fix an element in place.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:boilerplate/net_netip/golang.dart';
// `Limit` and `Limiter` exist in both `x/time/rate` and `x/rate`. The library
// names stay faithful to upstream and the collision is resolved here, at the
// import, as `AGENTS.md` prescribes.
import 'package:transpiled_golang_x_time/transpiled_golang_x_time.dart'
    as xtime;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../core/network/network.dart';

/// Configuration of a token bucket rate limiter.
///
/// Go: `Limit` (`limiter.go:20-25`). The bucket holds [burst] tokens and
/// refills at [rps] tokens per second; over any interval of `T` seconds it
/// allows at most `T*rps + burst` events.
final class Limit {
  /// Creates a limit of [rps] requests per second with a burst of [burst].
  const Limit({this.rps = 0, this.burst = 0});

  /// Requests per second in steady state.
  final double rps;

  /// Requests allowed over [rps].
  final int burst;
}

/// A rate limit that applies to a specific network prefix.
///
/// Go: `PrefixLimit` (`limiter.go:27-31`), which embeds `Limit`; Dart has no
/// struct embedding, so the limit is a named field.
final class PrefixLimit {
  /// Creates a limit for [prefix].
  const PrefixLimit({required this.prefix, required this.limit});

  /// The network this limit applies to.
  final Prefix prefix;

  /// The limit itself.
  final Limit limit;
}

/// A rate limit that applies to every subnet of a given prefix length.
///
/// Go: `SubnetLimit` (`limiter.go:33-36`).
final class SubnetLimit {
  /// Creates a limit for subnets of [prefixLength] bits.
  const SubnetLimit({required this.prefixLength, required this.limit});

  /// The prefix length that defines a subnet.
  final int prefixLength;

  /// The limit applied to each such subnet.
  final Limit limit;
}

/// Rate limits new streams for a service, with network-prefix specific,
/// global and subnet specific limits. Use a zero [Limit] for no rate limiting.
///
/// Go: `Limiter` (`limiter.go:38-54`). State accumulates in
/// [subnetRateLimiter] and is trimmed by [SubnetLimiter.allow] on each call.
final class Limiter {
  /// Creates a limiter.
  Limiter({
    List<PrefixLimit> networkPrefixLimits = const <PrefixLimit>[],
    this.globalLimit = const Limit(),
    SubnetLimiter? subnetRateLimiter,
  }) : networkPrefixLimits = List<PrefixLimit>.of(networkPrefixLimits),
       subnetRateLimiter = subnetRateLimiter ?? SubnetLimiter();

  /// Limits for streams whose peer IP falls in a specific network.
  ///
  /// Go: `NetworkPrefixLimits` (`limiter.go:40-42`). Sorted on first use so
  /// that the narrowest prefix comes first.
  final List<PrefixLimit> networkPrefixLimits;

  /// Limit for streams whose peer IP matches none of [networkPrefixLimits].
  ///
  /// Go: `GlobalLimit` (`limiter.go:45`).
  final Limit globalLimit;

  /// Per-subnet limiter consulted before the global bucket.
  ///
  /// Go: `SubnetRateLimiter` (`limiter.go:47`).
  final SubnetLimiter subnetRateLimiter;

  bool _initialised = false;
  late xtime.Limiter _globalBucket;
  late List<xtime.Limiter> _networkPrefixBuckets;

  /// Go: `init` (`limiter.go:56-75`), whose `sync.Once` is a plain flag here.
  void _init() {
    if (_initialised) return;
    _initialised = true;

    _globalBucket = globalLimit.rps == 0
        ? xtime.Limiter(xtime.Limit.inf, 0)
        : xtime.Limiter(xtime.Limit(globalLimit.rps), globalLimit.burst);

    // Sort such that the widest prefix (smallest bit count) is last.
    networkPrefixLimits.sort((a, b) => b.prefix.bits - a.prefix.bits);

    _networkPrefixBuckets = <xtime.Limiter>[
      for (final limit in networkPrefixLimits)
        if (limit.limit.rps == 0)
          xtime.Limiter(xtime.Limit.inf, 0)
        else
          xtime.Limiter(xtime.Limit(limit.limit.rps), limit.limit.burst),
    ];
  }

  /// Wraps a stream handler so that streams beyond the limits are reset.
  ///
  /// Go: `Limit` (`limiter.go:77-95`), named `limitHandler` here because a
  /// method may not share its class's name in Dart.
  void Function(NetworkStream) limitHandler(
    void Function(NetworkStream) handler,
  ) {
    _init();
    return (stream) {
      final ip = _toIp(stream.conn().remoteMultiaddr());
      final addr = ip == null ? const Addr.zero() : Addr.tryFromSlice(ip);
      if (!allow(addr ?? const Addr.zero())) {
        unawaited(stream.resetWithError(streamRateLimited));
        return;
      }
      handler(stream);
    };
  }

  /// Whether a request from [ipAddr] is within the configured limits.
  ///
  /// Go: `Allow` (`limiter.go:97-131`). Buckets are checked from the most
  /// specific to the least, because the underlying limiter has no way to
  /// return a token: checking the global bucket first would let requests that
  /// the specific bucket rejects still consume global tokens.
  bool allow(Addr ipAddr) {
    _init();

    var isWithinNetworkPrefix = false;
    for (var i = 0; i < networkPrefixLimits.length; i++) {
      if (networkPrefixLimits[i].prefix.contains(ipAddr)) {
        if (!_networkPrefixBuckets[i].allow()) return false;
        isWithinNetworkPrefix = true;
      }
    }
    if (isWithinNetworkPrefix) return true;

    if (!subnetRateLimiter.allow(ipAddr, DateTime.now())) return false;
    return _globalBucket.allow();
  }
}

/// Rate limits requests per IP subnet.
///
/// Go: `SubnetLimiter` (`limiter.go:133-148`).
final class SubnetLimiter {
  /// Creates a subnet limiter.
  SubnetLimiter({
    List<SubnetLimit> ipv4SubnetLimits = const <SubnetLimit>[],
    List<SubnetLimit> ipv6SubnetLimits = const <SubnetLimit>[],
    this.gracePeriod = Duration.zero,
  }) : ipv4SubnetLimits = List<SubnetLimit>.of(ipv4SubnetLimits),
       ipv6SubnetLimits = List<SubnetLimit>.of(ipv6SubnetLimits);

  /// Per-subnet limits for peers with IPv4 addresses.
  final List<SubnetLimit> ipv4SubnetLimits;

  /// Per-subnet limits for peers with IPv6 addresses.
  final List<SubnetLimit> ipv6SubnetLimits;

  /// How long to keep a full bucket before discarding it.
  ///
  /// Go: `GracePeriod` (`limiter.go:141`). Keeping a bucket around avoids
  /// reallocating it for a peer that comes back.
  final Duration gracePeriod;

  bool _initialised = false;
  late List<_BucketHeap> _ipv4Heaps;
  late List<_BucketHeap> _ipv6Heaps;

  /// Go: `init` (`limiter.go:150-173`).
  void _init() {
    if (_initialised) return;
    _initialised = true;

    // Smaller prefix length, i.e. largest subnet, last.
    ipv4SubnetLimits.sort((a, b) => b.prefixLength - a.prefixLength);
    ipv6SubnetLimits.sort((a, b) => b.prefixLength - a.prefixLength);

    _ipv4Heaps = <_BucketHeap>[
      for (var i = 0; i < ipv4SubnetLimits.length; i++) _BucketHeap(),
    ];
    _ipv6Heaps = <_BucketHeap>[
      for (var i = 0; i < ipv6SubnetLimits.length; i++) _BucketHeap(),
    ];
  }

  /// Whether a request from [ipAddr] is within the per-subnet limits at [now].
  ///
  /// Go: `Allow` (`limiter.go:175-217`).
  ///
  /// Upstream behaviour preserved deliberately: when a later subnet's bucket
  /// is empty this returns false **after** earlier buckets have already spent
  /// a token, and those tokens are not refunded.
  bool allow(Addr ipAddr, DateTime now) {
    _init();
    _cleanUp(now);

    final subnetLimits = ipAddr.is4 ? ipv4SubnetLimits : ipv6SubnetLimits;
    final heaps = ipAddr.is4 ? _ipv4Heaps : _ipv6Heaps;

    for (var i = 0; i < subnetLimits.length; i++) {
      final limit = subnetLimits[i];
      final Prefix prefix;
      try {
        prefix = ipAddr.prefix(limit.prefixLength);
      } on ArgumentError {
        // Go: "we have a ipaddr this shouldn't happen".
        return false;
      }
      if (!prefix.isValid) return false;

      var bucket = heaps[i].get(prefix);
      bucket ??= _PrefixBucketWithExpiry(
        prefix: prefix,
        bucket: xtime.Limiter(xtime.Limit(limit.limit.rps), limit.limit.burst),
        expiry: now,
      );

      if (!bucket.bucket.allow()) {
        // Bucket is empty; its expiry was set correctly the last time it
        // allowed a request.
        return false;
      }
      bucket.expiry = _fullAt(bucket.bucket, now).add(gracePeriod);
      heaps[i].upsert(bucket);
    }
    return true;
  }

  /// Drops buckets that have expired by [now].
  ///
  /// Go: `cleanUp` (`limiter.go:219-227`), which is unexported, so this is
  /// private too.
  void _cleanUp(DateTime now) {
    for (final h in _ipv4Heaps) {
      h.expire(now);
    }
    for (final h in _ipv6Heaps) {
      h.expire(now);
    }
  }
}

/// The instant at which [bucket] will be full again.
///
/// Go: `tokenBucket.FullAt` (`limiter.go:229-240`), a method on a struct that
/// exists only to add this one behaviour to `*rate.Limiter`; here it is a
/// private function over the limiter itself, since Dart has no embedding.
DateTime _fullAt(xtime.Limiter bucket, DateTime now) {
  final tokensNeeded = bucket.burst.toDouble() - bucket.tokensAt(now);
  final refillRate = bucket.limit.value;
  final etaMicros =
      (tokensNeeded / refillRate) * Duration.microsecondsPerSecond;
  if (!etaMicros.isFinite) return now.add(xtime.infDuration);
  return now.add(Duration(microseconds: etaMicros.truncate()));
}

/// A token bucket keyed by prefix, with the instant it will be full.
///
/// Go: `prefixBucketWithExpiry` (`limiter.go:242-248`).
final class _PrefixBucketWithExpiry {
  _PrefixBucketWithExpiry({
    required this.prefix,
    required this.bucket,
    required this.expiry,
  });

  final Prefix prefix;
  final xtime.Limiter bucket;
  DateTime expiry;
}

/// A heap of buckets ordered by expiry. A full bucket is indistinguishable
/// from a new one, so it is dropped once it expires.
///
/// Go: `bucketHeap` (`limiter.go:250-322`), which implements `heap.Interface`
/// over `container/heap`. Dart has no such package, so the sift operations are
/// here; `_prefixToIndex` is Go's own side table, kept so that [upsert] can
/// fix an element in place instead of rebuilding.
final class _BucketHeap {
  final List<_PrefixBucketWithExpiry> _buckets = <_PrefixBucketWithExpiry>[];
  final Map<Prefix, int> _prefixToIndex = <Prefix, int>{};

  int get length => _buckets.length;

  /// Go: `Upsert` (`limiter.go:260-268`).
  void upsert(_PrefixBucketWithExpiry b) {
    final existing = _prefixToIndex[b.prefix];
    if (existing != null) {
      _buckets[existing] = b;
      _fix(existing);
      return;
    }
    _push(b);
  }

  /// Go: `Get` (`limiter.go:270-276`), which returns the zero value when the
  /// prefix is absent; this returns null.
  _PrefixBucketWithExpiry? get(Prefix prefix) {
    final i = _prefixToIndex[prefix];
    return i == null ? null : _buckets[i];
  }

  /// Go: `Expire` (`limiter.go:278-287`).
  void expire(DateTime expiry) {
    while (_buckets.isNotEmpty) {
      final oldest = _buckets.first;
      if (oldest.expiry.isAfter(expiry)) break;
      _pop();
    }
  }

  bool _less(int i, int j) => _buckets[i].expiry.isBefore(_buckets[j].expiry);

  void _swap(int i, int j) {
    final tmp = _buckets[i];
    _buckets[i] = _buckets[j];
    _buckets[j] = tmp;
    _prefixToIndex[_buckets[i].prefix] = i;
    _prefixToIndex[_buckets[j].prefix] = j;
  }

  void _push(_PrefixBucketWithExpiry item) {
    _buckets.add(item);
    _prefixToIndex[item.prefix] = _buckets.length - 1;
    _siftUp(_buckets.length - 1);
  }

  void _pop() {
    _swap(0, _buckets.length - 1);
    final item = _buckets.removeLast();
    _prefixToIndex.remove(item.prefix);
    if (_buckets.isNotEmpty) _siftDown(0);
  }

  void _fix(int i) {
    if (!_siftDown(i)) _siftUp(i);
  }

  void _siftUp(int j) {
    var child = j;
    while (child > 0) {
      final parent = (child - 1) ~/ 2;
      if (!_less(child, parent)) break;
      _swap(parent, child);
      child = parent;
    }
  }

  bool _siftDown(int i0) {
    var i = i0;
    while (true) {
      final left = 2 * i + 1;
      if (left >= _buckets.length) break;
      var j = left;
      final right = left + 1;
      if (right < _buckets.length && _less(right, left)) j = right;
      if (!_less(j, i)) break;
      _swap(i, j);
      i = j;
    }
    return i > i0;
  }
}

/// The raw bytes of the first `ip4`/`ip6` component of [a], skipping a leading
/// `ip6zone`, or null when [a] does not start with an IP component.
///
/// Go: `manet.ToIP` (`go-multiaddr/net/convert.go:138-152`). That function
/// belongs to the `go-multiaddr` module and is still not ported there --
/// `p2p/host/observedaddrs/manager.dart` carries the same stand-in, and the
/// gap is recorded in `doc/transpilation/PROGRESS.md`. It cannot simply move
/// to `transpiled_multiaddr` as-is: returning Go's `net.IP` would pull
/// `boilerplate/net`, and with it `dart:io`, into a package the audit keeps
/// platform-agnostic for web and Wasm.
Uint8List? _toIp(Multiaddr a) {
  for (final c in a.components) {
    if (c.protocol.code == Protocols.ip6zone) continue;
    if (c.protocol.code == Protocols.ip4 || c.protocol.code == Protocols.ip6) {
      return Uint8List.fromList(c.valueBytes);
    }
    return null;
  }
  return null;
}
