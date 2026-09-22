// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
/// Port of go-libp2p's `p2p/net/connmgr` package.
///
/// The three upstream files are one Go package sharing unexported types
/// (`config`, `segments`, `peerInfo`, `decayer`, `decayingTag`), so they are
/// one Dart library split with `part`, the same shape `transpiled_pion_sdp`
/// uses. Keeping them as separate libraries would force those types public.
///
/// Adaptations to the Dart runtime, each recorded in
/// doc/transpilation/PROGRESS.md:
///
///  * The five upstream lock families (`segment.Mutex` x256,
///    `segments.bucketsMu`, `plk`, `trimMutex`, `lastTrimMu`) discipline
///    preemptive threads. A Dart isolate does not preempt inside synchronous
///    code, and none of the regions they guard has an `await` in it, so the
///    locks have no work to do and are omitted. The 256 shards themselves are
///    reproduced.
///  * `trimMutex` + `trimCount` are the exception: that pair is not a lock but
///    a coalescer (`connmgr.go:369-381`), and it is still needed here, for a
///    reason Go does not have -- closing a connection is asynchronous, so the
///    `await` is exactly where a second `trimOpenConns` can interleave. It
///    becomes single-flight over the in-flight future.
///  * `background()` (`connmgr.go:344-367`) is a goroutine; here it is a
///    subscription to the injected clock's ticker. `refCount sync.WaitGroup`
///    and the `context` pair collapse into cancelling that subscription.
///  * `connCount atomic.Int32` is a plain `int`.
///  * `unregisterMemoryWatcher` (`connmgr.go:54`) is omitted: it is a dead
///    field upstream, never assigned, read only defensively in `Close`.
library;

import 'dart:async';
import 'dart:developer' as dev;

import 'package:transpiled_clock/transpiled_clock.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/connmgr/decay.dart' as core;
import '../../../core/connmgr/manager.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';

part 'decay.dart';
part 'options.dart';

/// A connection manager that trims connections down to the low watermark when
/// the count rises above the high watermark.
///
/// Go: `BasicConnMgr` (`connmgr.go:30-55`).
class BasicConnMgr implements ConnManager, core.Decayer {
  /// Creates a connection manager.
  ///
  /// [low] and [hi] are the watermarks governing the number of connections
  /// that will be maintained. When the peer count exceeds the high watermark,
  /// as many peers will be pruned -- and their connections terminated -- until
  /// the low watermark remains.
  ///
  /// Go: `NewConnManager` (`connmgr.go:111-151`), whose defaults are a one
  /// minute grace period, a ten second silence period, and the real clock.
  factory BasicConnMgr(
    int low,
    int hi, [
    List<Option> options = const <Option>[],
  ]) {
    final cfg = _Config(
      highWater: hi,
      lowWater: low,
      gracePeriod: const Duration(minutes: 1),
      silencePeriod: const Duration(seconds: 10),
      clock: Clock(),
    );
    for (final o in options) {
      o._apply(cfg);
    }
    cfg.decayer ??= DecayerCfg().withDefaults();
    return BasicConnMgr._(cfg);
  }

  BasicConnMgr._(this._cfg) {
    _decayer = _Decayer(_cfg.decayer!, this);
    _background();
  }

  final _Config _cfg;
  final _Segments _segments = _Segments();

  /// Go: the `protected` map (`connmgr.go:39`).
  final Map<PeerId, Set<String>> _protected = <PeerId, Set<String>>{};

  late final _Decayer _decayer;

  int _connCount = 0;
  DateTime _lastTrim = DateTime.fromMicrosecondsSinceEpoch(0, isUtc: true);
  Future<void>? _trimInFlight;
  StreamSubscription<DateTime>? _backgroundTicker;
  Ticker? _ticker;
  bool _closed = false;

  /// The high watermark, above which [_background] trims.
  int get _highWater => _cfg.highWater;

  /// Trims connections down to the low watermark, ignoring the silence period,
  /// the grace period and protected status. It prioritises closing unprotected
  /// connections; if after closing all of those the count is still above the
  /// low watermark, it closes protected ones.
  ///
  /// Go: `ForceTrim` (`connmgr.go:157-182`). It has no caller inside go-libp2p
  /// either: it is public API for an embedder reacting to memory pressure.
  Future<void> forceTrim() async {
    final connCount = _connCount;
    var target = connCount - _cfg.lowWater;
    if (target < 0) {
      dev.log(
        'low on memory, but we only have a few connections: '
        'num=$connCount low_watermark=${_cfg.lowWater}',
        name: 'connmgr',
      );
      return;
    }
    dev.log(
      'low on memory, closing connections: count=$target',
      name: 'connmgr',
    );

    for (final c in _getConnsToCloseEmergency(target)) {
      await c.closeWithError(connGarbageCollected);
    }

    _lastTrim = _cfg.clock.now();
  }

  /// Closes the manager, stopping the background trim and the decayer.
  ///
  /// Go: `Close` (`connmgr.go:184-194`). It does not close connections.
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_backgroundTicker?.cancel());
    _ticker?.stop();
    _decayer.close();
  }

  /// Protects [id] from pruning under [tag].
  ///
  /// Protection is not refcounted: N calls with the same tag are undone by one
  /// [unprotect].
  ///
  /// Go: `Protect` (`connmgr.go:196-206`).
  @override
  void protect(PeerId id, String tag) {
    _protected.putIfAbsent(id, () => <String>{}).add(tag);
  }

  /// Removes protection under [tag], reporting whether [id] remains protected
  /// by another tag.
  ///
  /// Go: `Unprotect` (`connmgr.go:208-221`).
  @override
  bool unprotect(PeerId id, String tag) {
    final tags = _protected[id];
    if (tags == null) return false;
    tags.remove(tag);
    if (tags.isEmpty) {
      _protected.remove(id);
      return false;
    }
    return true;
  }

  /// Reports whether [id] is protected. An empty [tag] asks whether any
  /// protection at all is held.
  ///
  /// Go: `IsProtected` (`connmgr.go:223-238`).
  @override
  bool isProtected(PeerId id, String tag) {
    final tags = _protected[id];
    if (tags == null) return false;
    if (tag.isEmpty) return true;
    return tags.contains(tag);
  }

  /// Throws when the high watermark exceeds [systemLimit]'s connection limit.
  ///
  /// Go: `CheckLimit` (`connmgr.go:240-249`), which returns an anonymous
  /// `fmt.Errorf`. There is no named error type upstream to port, so this
  /// raises Dart's own [StateError] with the same message rather than
  /// inventing a public exception.
  @override
  void checkLimit(GetConnLimiter systemLimit) {
    if (_cfg.highWater > systemLimit.getConnLimit()) {
      throw StateError(
        'conn manager high watermark limit: ${_cfg.highWater}, '
        'exceeds the system connection limit of: ${systemLimit.getConnLimit()}',
      );
    }
  }

  /// Closes the connections of as many peers as needed to bring the peer count
  /// down to the low watermark, skipping peers still inside their grace period
  /// and peers that are protected.
  ///
  /// Concurrent calls coalesce into one trim: a caller arriving while a trim is
  /// running awaits that trim and returns, which is the observable behaviour of
  /// the `trimMutex`/`trimCount` generation counter upstream
  /// (`connmgr.go:369-381`).
  ///
  /// Go: `TrimOpenConns` (`connmgr.go:337-342`). Unlike upstream this returns a
  /// future, because "blocks until a trim is completed" is spelled that way in
  /// Dart and closing a connection is asynchronous here.
  @override
  Future<void> trimOpenConns() => _doTrim();

  /// Go: `doTrim` (`connmgr.go:369-381`).
  Future<void> _doTrim() {
    final inFlight = _trimInFlight;
    if (inFlight != null) return inFlight;
    final started = _trim().whenComplete(() {
      _lastTrim = _cfg.clock.now();
      _trimInFlight = null;
    });
    return _trimInFlight = started;
  }

  /// Go: `background` (`connmgr.go:344-367`).
  void _background() {
    var interval = Duration(microseconds: _cfg.gracePeriod.inMicroseconds ~/ 2);
    if (_cfg.silencePeriod != Duration.zero) {
      interval = _cfg.silencePeriod;
    }
    final ticker = _cfg.clock.ticker(interval);
    _ticker = ticker;
    _backgroundTicker = ticker.c.listen((_) {
      if (_closed) return;
      if (_connCount < _highWater) return;
      // Upstream calls trim() directly here, not doTrim(), so a background
      // tick neither updates lastTrim nor takes part in the coalescing.
      unawaited(_trim());
    });
  }

  /// Go: `trim` (`connmgr.go:384-390`).
  Future<void> _trim() async {
    for (final c in _getConnsToClose()) {
      await c.closeWithError(connGarbageCollected);
    }
  }

  /// Go: `getConnsToCloseEmergency` (`connmgr.go:392-458`).
  ///
  /// Unlike [_getConnsToClose] this ignores both the grace period and the
  /// silence period, and sorts by *more* streams first, because the goal is to
  /// free memory rather than to preserve useful connections.
  List<Conn> _getConnsToCloseEmergency(int target) {
    var candidates = <_PeerInfo>[];
    for (final s in _segments.buckets) {
      for (final entry in s.peers.entries) {
        if (_protected.containsKey(entry.key)) continue;
        candidates.add(entry.value);
      }
    }

    _sortByValueAndStreams(candidates, sortByMoreStreams: true);

    final selected = <Conn>[];
    for (final inf in candidates) {
      if (target <= 0) break;
      selected.addAll(inf.conns.keys);
      target -= inf.conns.length;
    }
    if (selected.length >= target) {
      // We found enough connections that were not protected.
      //
      // Upstream bug preserved deliberately: `target` has already been
      // decremented by the loop above and is typically <= 0 by now, so this
      // check is almost always true and the protected pass below almost never
      // runs (`connmgr.go:425-428`). Porting the intent instead of the code
      // would change behaviour against a real peer.
      return selected;
    }

    // We didn't find enough unprotected connections, so we have no choice but
    // to kill some protected ones.
    candidates = <_PeerInfo>[];
    for (final s in _segments.buckets) {
      candidates.addAll(s.peers.values);
    }
    _sortByValueAndStreams(candidates, sortByMoreStreams: true);
    for (final inf in candidates) {
      if (target <= 0) break;
      selected.addAll(inf.conns.keys);
      target -= inf.conns.length;
    }
    return selected;
  }

  /// Go: `getConnsToClose` (`connmgr.go:462-537`).
  List<Conn> _getConnsToClose() {
    if (_cfg.lowWater == 0 || _cfg.highWater == 0) {
      // disabled
      return const <Conn>[];
    }

    if (_connCount <= _cfg.lowWater) {
      return const <Conn>[];
    }

    final candidates = <_PeerInfo>[];
    var ncandidates = 0;
    final gracePeriodStart = _cfg.clock.now().subtract(_cfg.gracePeriod);

    for (final s in _segments.buckets) {
      for (final entry in s.peers.entries) {
        if (_protected.containsKey(entry.key)) {
          // skip over protected peer.
          continue;
        }
        final inf = entry.value;
        if (inf.firstSeen.isAfter(gracePeriodStart)) {
          // skip peers in the grace period.
          continue;
        }
        candidates.add(inf);
        ncandidates += inf.conns.length;
      }
    }

    if (ncandidates < _cfg.lowWater) {
      // We have too many connections but fewer than lowWater connections out
      // of the grace period. Trimming now would kill potentially useful
      // connections.
      return const <Conn>[];
    }

    _sortByValueAndStreams(candidates, sortByMoreStreams: false);

    // Note that the target is relative to the number of *candidate*
    // connections, not to connCount: protected peers and peers inside their
    // grace period are not part of this arithmetic.
    var target = ncandidates - _cfg.lowWater;
    final selected = <Conn>[];

    for (final inf in candidates) {
      if (target <= 0) break;
      final s = _segments.get(inf.id);
      if (inf.conns.isEmpty && inf.temp) {
        // A temporary entry for early tags that has gone past the grace period
        // and still holds no connections: prune it, without counting it
        // against the target.
        s.peers.remove(inf.id);
      } else {
        selected.addAll(inf.conns.keys);
        target -= inf.conns.length;
      }
    }

    return selected;
  }

  /// Returns the tag information associated with [p], or `null` when [p] is
  /// unknown.
  ///
  /// The returned [TagInfo] is a copy. Decaying tags are folded into the same
  /// `tags` map by name, and connections are keyed by remote multiaddr string
  /// -- not by connection identity, which is how [_PeerInfo.conns] keys them.
  ///
  /// Go: `GetTagInfo` (`connmgr.go:541-567`).
  @override
  TagInfo? getTagInfo(PeerId p) {
    final pi = _segments.get(p).peers[p];
    if (pi == null) return null;

    final tags = <String, int>{...pi.tags};
    for (final entry in pi.decaying.entries) {
      tags[entry.key.name()] = entry.value.value;
    }
    final conns = <String, DateTime>{};
    for (final entry in pi.conns.entries) {
      conns[entry.key.remoteMultiaddr().toString()] = entry.value;
    }

    return TagInfo(
      firstSeen: pi.firstSeen,
      value: pi.value,
      tags: tags,
      conns: conns,
    );
  }

  /// Associates [tag] with [val] for [p].
  ///
  /// The write is idempotent in the cached total: it replaces the previous
  /// value for the tag rather than adding to it.
  ///
  /// Go: `TagPeer` (`connmgr.go:570-580`).
  @override
  void tagPeer(PeerId p, String tag, int val) {
    final s = _segments.get(p);
    final pi = s.tagInfoFor(p, _cfg.clock.now());
    pi.value += val - (pi.tags[tag] ?? 0);
    pi.tags[tag] = val;
  }

  /// Disassociates [tag] from [p]. Unknown peers are ignored, and a peer left
  /// with no tags is *not* removed.
  ///
  /// Go: `UntagPeer` (`connmgr.go:583-597`).
  @override
  void untagPeer(PeerId p, String tag) {
    final pi = _segments.get(p).peers[p];
    if (pi == null) {
      dev.log(
        'tried to remove tag from untracked peer: peer=$p tag=$tag',
        name: 'connmgr',
      );
      return;
    }
    pi.value -= pi.tags[tag] ?? 0;
    pi.tags.remove(tag);
  }

  /// Inserts or updates [tag] for [p], handing the current value to [upsert].
  ///
  /// Go: `UpsertTag` (`connmgr.go:600-611`). Upstream runs the callback while
  /// holding the segment lock, so a callback that re-enters the connection
  /// manager deadlocks there; here there is no lock to deadlock on, but the
  /// callback is still expected to be a pure arithmetic step.
  @override
  void upsertTag(PeerId p, String tag, int Function(int value) upsert) {
    final s = _segments.get(p);
    final pi = s.tagInfoFor(p, _cfg.clock.now());
    final oldval = pi.tags[tag] ?? 0;
    final newval = upsert(oldval);
    pi.value += newval - oldval;
    pi.tags[tag] = newval;
  }

  /// Returns the configuration and status data for this connection manager.
  ///
  /// Go: `GetInfo` (`connmgr.go:632-647`).
  CmInfo getInfo() => CmInfo(
    highWater: _cfg.highWater,
    lowWater: _cfg.lowWater,
    lastTrim: _lastTrim,
    gracePeriod: _cfg.gracePeriod,
    connCount: _connCount,
  );

  /// Returns the sink through which the network informs this manager of
  /// connection events. Only `connected` and `disconnected` are acted on.
  ///
  /// Go: `Notifee` (`connmgr.go:649-651`), which converts the manager itself to
  /// a `cmNotifee`. Dart has no such conversion, so this is a small private
  /// class holding a reference back.
  @override
  Notifiee notifiee() => _CmNotifee(this);

  /// Registers a decaying tag.
  ///
  /// Go: `RegisterDecayingTag`, promoted from the embedded `*decayer`
  /// (`decay.go:101-134`).
  @override
  core.DecayingTag registerDecayingTag(
    String name,
    Duration interval,
    core.DecayFn decayFn,
    core.BumpFn bumpFn,
  ) => _decayer.registerDecayingTag(name, interval, decayFn, bumpFn);
}

/// Holds the configuration for [BasicConnMgr] as well as status data.
///
/// Go: `CmInfo` (`connmgr.go:614-629`).
class CmInfo {
  /// Creates a status snapshot.
  CmInfo({
    required this.lowWater,
    required this.highWater,
    required this.lastTrim,
    required this.gracePeriod,
    required this.connCount,
  });

  /// The low watermark.
  final int lowWater;

  /// The high watermark.
  final int highWater;

  /// When the last trim was triggered.
  final DateTime lastTrim;

  /// The configured grace period.
  final Duration gracePeriod;

  /// The current connection count.
  final int connCount;
}

/// One shard of the peer table.
///
/// Go: `segment` (`connmgr.go:62-65`). Its embedded mutex is omitted; see this
/// library's doc comment.
class _Segment {
  final Map<PeerId, _PeerInfo> peers = <PeerId, _PeerInfo>{};

  /// Go: `tagInfoFor` (`connmgr.go:89-105`). Lazily creates a temporary entry
  /// so that tags arriving before the `Connected` notification are buffered.
  _PeerInfo tagInfoFor(PeerId p, DateTime now) =>
      peers.putIfAbsent(p, () => _PeerInfo(id: p, firstSeen: now, temp: true));
}

/// The 256 shards of the peer table.
///
/// Go: `segments` (`connmgr.go:67-74`). The sharding exists upstream to reduce
/// lock contention across threads; it has nothing to relieve in a single
/// isolate and is reproduced for structural fidelity with the upstream, with
/// the locks left out.
class _Segments {
  final List<_Segment> buckets = List<_Segment>.generate(
    256,
    (_) => _Segment(),
    growable: false,
  );

  /// Go: `get` (`connmgr.go:76-78`), indexing on the last byte of the peer id.
  _Segment get(PeerId p) => buckets[p.value.last];

  /// Go: `countPeers` (`connmgr.go:80-87`).
  int countPeers() {
    var count = 0;
    for (final seg in buckets) {
      count += seg.peers.length;
    }
    return count;
  }
}

/// Metadata for a given peer.
///
/// Go: `peerInfo` (`connmgr.go:252-263`).
class _PeerInfo {
  _PeerInfo({required this.id, required this.firstSeen, this.temp = false});

  final PeerId id;

  /// Value for each tag.
  final Map<String, int> tags = <String, int>{};

  /// Decaying tags.
  final Map<_DecayingTag, core.DecayingValue> decaying =
      <_DecayingTag, core.DecayingValue>{};

  /// Cached sum of all tag values, static and decaying alike.
  int value = 0;

  /// Whether this is a temporary entry holding early tags and awaiting
  /// connections.
  bool temp;

  /// Start time of each connection, keyed by connection identity -- which is
  /// what `map[network.Conn]time.Time` means upstream.
  final Map<Conn, DateTime> conns = <Conn, DateTime>{};

  /// When we began tracking this peer.
  DateTime firstSeen;
}

/// Sorts [p] by value and stream count, putting the most prunable peer first.
///
/// Go: `peerInfos.SortByValueAndStreams` (`connmgr.go:271-327`). The tie-break
/// order, strongest first: temporary entries, then lower total tag value, then
/// fewer streams when one side has none, then inbound before outbound, and
/// finally stream count in the direction [sortByMoreStreams] asks for.
void _sortByValueAndStreams(
  List<_PeerInfo> p, {
  required bool sortByMoreStreams,
}) {
  (bool, int) incomingAndStreams(Map<Conn, DateTime> m) {
    var incoming = false;
    var numStreams = 0;
    for (final c in m.keys) {
      final stat = c.stat();
      if (stat.direction == Direction.inbound) incoming = true;
      numStreams += stat.numStreams;
    }
    return (incoming, numStreams);
  }

  p.sort((left, right) {
    // temporary peers are preferred for pruning.
    if (left.temp != right.temp) return left.temp ? -1 : 1;
    // otherwise, compare by value.
    if (left.value != right.value) return left.value < right.value ? -1 : 1;

    final (leftIncoming, leftStreams) = incomingAndStreams(left.conns);
    final (rightIncoming, rightStreams) = incomingAndStreams(right.conns);

    // prefer closing inactive connections (no streams open)
    if (rightStreams != leftStreams &&
        (leftStreams == 0 || rightStreams == 0)) {
      return leftStreams < rightStreams ? -1 : 1;
    }
    // incoming connections are preferred for pruning
    if (leftIncoming != rightIncoming) return leftIncoming ? -1 : 1;

    if (leftStreams == rightStreams) return 0;
    if (sortByMoreStreams) {
      // prune connections with a higher number of streams first
      return rightStreams < leftStreams ? -1 : 1;
    }
    return leftStreams < rightStreams ? -1 : 1;
  });
}

/// The sink through which the network informs [BasicConnMgr] of events.
///
/// Go: `cmNotifee` (`connmgr.go:653-656`).
class _CmNotifee implements Notifiee {
  _CmNotifee(this._cm);

  final BasicConnMgr _cm;

  /// Informs the manager that a new connection has been established.
  ///
  /// Go: `Connected` (`connmgr.go:662-697`). Note that upstream does *not*
  /// trigger a trim from here: the background ticker is the only automatic
  /// trigger.
  @override
  void connected(Network network, Conn c) {
    final id = c.remotePeer();
    final s = _cm._segments.get(id);

    var pinfo = s.peers[id];
    if (pinfo == null) {
      pinfo = _PeerInfo(id: id, firstSeen: _cm._cfg.clock.now());
      s.peers[id] = pinfo;
    } else if (pinfo.temp) {
      // The entry was created to buffer early tags before this notification
      // arrived: flip the flag and restart the grace period from the real
      // connection, not from when the tags showed up.
      pinfo.temp = false;
      pinfo.firstSeen = _cm._cfg.clock.now();
    }

    if (pinfo.conns.containsKey(c)) {
      dev.log(
        'received connected notification for conn we are already tracking: '
        'peer=$id',
        name: 'connmgr',
      );
      return;
    }

    pinfo.conns[c] = _cm._cfg.clock.now();
    _cm._connCount++;
  }

  /// Informs the manager that a connection has been closed.
  ///
  /// Go: `Disconnected` (`connmgr.go:701-726`). The whole `peerInfo` is dropped
  /// when its last connection goes, so a peer's tags do not survive a
  /// disconnect.
  @override
  void disconnected(Network network, Conn c) {
    final p = c.remotePeer();
    final s = _cm._segments.get(p);

    final cinf = s.peers[p];
    if (cinf == null) {
      dev.log(
        'received disconnected notification for peer we are not tracking: '
        'peer=$p',
        name: 'connmgr',
      );
      return;
    }
    if (!cinf.conns.containsKey(c)) {
      dev.log(
        'received disconnected notification for conn we are not tracking: '
        'peer=$p',
        name: 'connmgr',
      );
      return;
    }

    cinf.conns.remove(c);
    if (cinf.conns.isEmpty) s.peers.remove(p);
    _cm._connCount--;
  }

  /// Go: `Listen` (`connmgr.go:729`), a no-op.
  @override
  void listen(Network network, Multiaddr address) {}

  /// Go: `ListenClose` (`connmgr.go:732`), a no-op.
  @override
  void listenClose(Network network, Multiaddr address) {}
}
