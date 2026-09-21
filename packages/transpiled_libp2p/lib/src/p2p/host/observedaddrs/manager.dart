// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
//
// Port of go-libp2p's `p2p/host/observedaddrs` (manager.go). Maps a
// connection's local (listen) thin-waist multiaddr to the externally
// observed multiaddr that peers reported back to us over that connection,
// so a node behind NAT can discover and advertise its own public address
// without a fixed `announceAddresses` override.
import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/event/bus.dart';
import '../../../core/event/identify.dart';
import '../../../core/network/network.dart';
import '../../../core/transport/transport.dart';
import '../basic/basic_host.dart';

/// Minimum number of distinct observers required for an observed address to
/// be considered activated. We may not advertise this address even if we
/// have this many observations if better-observed addresses are available.
///
/// Mirrors Go's exported, mutable `var ActivationThresh = 4`
/// (manager.go:27); kept mutable and public for the same reason Go's tests
/// override it directly.
int activationThresh = 4;

/// Number of transports that share the same thin waist (tcp, ws, wss),
/// (quic, webtransport, webrtc-direct). manager.go:80-82.
const int _observerSetCacheSize = 10;

/// How many of the best-observed external addresses are returned per local
/// thin waist address, both from [Manager.addrsFor] and [Manager.addrs].
/// manager.go:40.
const int _maxExternalThinWaistAddrsPerLocalAddr = 3;

/// A multiaddr split into its thin waist (`/{ip4,ip6}/{tcp,udp}`) prefix and
/// the remaining components. manager.go:42-45 (`thinWaist`).
final class _ThinWaist {
  const _ThinWaist({required this.addr, required this.tw, required this.rest});
  final Multiaddr addr;
  final Multiaddr tw;
  final Multiaddr rest;
}

/// Splits [a] into its thin waist and rest, or returns `null` if [a] does
/// not start with `/{ip4,ip6}/{tcp,udp}`. manager.go:49-57 (`thinWaistForm`);
/// the Go sentinel `errTW` becomes a `null` return since this is a private,
/// non-throwing helper with a single boolean-shaped outcome.
_ThinWaist? _thinWaistForm(Multiaddr a) {
  if (a.components.length < 2) return null;
  final c0 = a.components[0].protocol.code;
  final c1 = a.components[1].protocol.code;
  final validHead = c0 == Protocols.ip4 || c0 == Protocols.ip6;
  final validNext = c1 == Protocols.tcp || c1 == Protocols.udp;
  if (!validHead || !validNext) return null;
  return _ThinWaist(
    addr: a,
    tw: Multiaddr(a.components.sublist(0, 2)),
    rest: Multiaddr(a.components.sublist(2)),
  );
}

/// The raw address bytes of the first `ip4`/`ip6` component, skipping a
/// leading `ip6zone`, or `null` if [a] doesn't start with an IP component.
/// Private stand-in for go-multiaddr/net's `ToIP`, which is not yet ported
/// to `packages/transpiled_multiaddr` (out of this change's file scope); see
/// the divergence note in PROGRESS.md.
List<int>? _toIpBytes(Multiaddr a) {
  for (final c in a.components) {
    if (c.protocol.code == Protocols.ip6zone) continue;
    if (c.protocol.code == Protocols.ip4 || c.protocol.code == Protocols.ip6) {
      return c.valueBytes;
    }
    return null;
  }
  return null;
}

bool _isIpv4MappedIp6(List<int> ip6) {
  for (var i = 0; i < 10; i++) {
    if (ip6[i] != 0) return false;
  }
  return ip6[10] == 0xff && ip6[11] == 0xff;
}

/// Returns the key identifying the peer that reported [a] as our observed
/// address: the dotted-decimal IPv4 address, or the hex of the IPv6 `/56`
/// prefix. manager.go:59-72 (`getObserver`).
///
/// Deliberate divergence: unlike Go's `ip.String()`, this does not reproduce
/// `net.IP`'s canonical text form -- it only needs to be a stable, unique
/// key per observer bucket, which byte-prefix equality already guarantees.
/// The activation/grouping decision logic itself (which bytes are compared,
/// the /56 mask) is ported verbatim.
String? _getObserver(Multiaddr a) {
  final ip = _toIpBytes(a);
  if (ip == null) return null;
  if (ip.length == 4) {
    return ip.join('.');
  }
  if (ip.length == 16) {
    if (_isIpv4MappedIp6(ip)) {
      return ip.sublist(12, 16).join('.');
    }
    // Count the /56 prefix as a single observer (net.CIDRMask(56, 128)).
    return ip
        .sublist(0, 7)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
  return null;
}

/// If [m] starts with `/ip6zone/<zone>`, returns the multiaddr from the
/// following `/ip6` component onward (or `null` if malformed); otherwise
/// returns [m] unchanged, or `null` if empty. manager.go's `net.go:zoneless`
/// equivalent (go-multiaddr/net/ip.go:121-137).
Multiaddr? _zoneless(Multiaddr m) {
  if (m.components.isEmpty) return null;
  final head = m.components.first;
  if (head.protocol.code == Protocols.ip6zone) {
    if (m.components.length < 2 ||
        m.components[1].protocol.code != Protocols.ip6) {
      return null;
    }
    return Multiaddr(m.components.sublist(1));
  }
  return m;
}

/// go-multiaddr/net's `IsIPLoopback` (ip.go:61-75): whether [m] starts with
/// a loopback IP (`127.0.0.0/8`, `::1`, or the IPv4-mapped `::ffff:127.*`).
bool _isIpLoopback(Multiaddr m) {
  final zoneless = _zoneless(m);
  if (zoneless == null || zoneless.components.isEmpty) return false;
  final head = zoneless.components.first;
  if (head.protocol.code == Protocols.ip4) {
    return head.valueBytes[0] == 127;
  }
  if (head.protocol.code == Protocols.ip6) {
    final b = head.valueBytes;
    if (_isIpv4MappedIp6(b)) return b[12] == 127;
    for (var i = 0; i < 15; i++) {
      if (b[i] != 0) return false;
    }
    return b[15] == 1;
  }
  return false;
}

/// The `64:ff9b::/96` well-known NAT64 prefix (RFC 6052), as its first 12
/// address bytes. go-multiaddr/net/private.go:56-61.
const List<int> _nat64Prefix = [0x00, 0x64, 0xff, 0x9b, 0, 0, 0, 0, 0, 0, 0, 0];

/// go-multiaddr/net's `IsNAT64IPv4ConvertedIPv6Addr` (ip.go:141-145).
bool _isNat64Ipv4ConvertedIpv6Addr(Multiaddr m) {
  if (m.components.isEmpty) return false;
  final head = m.components.first;
  if (head.protocol.code != Protocols.ip6) return false;
  final b = head.valueBytes;
  for (var i = 0; i < _nat64Prefix.length; i++) {
    if (b[i] != _nat64Prefix[i]) return false;
  }
  return true;
}

/// manager.go:599-606 (`isRelayedAddress`).
bool _isRelayedAddress(Multiaddr a) =>
    a.components.any((c) => c.protocol.code == Protocols.circuit);

/// manager.go:585-597 (`hasConsistentTransport`): whether [aTw] and [bTw]
/// share the same protocol codes, component for component.
bool _hasConsistentTransport(Multiaddr aTw, Multiaddr bTw) {
  if (aTw.components.length != bTw.components.length) return false;
  for (var i = 0; i < aTw.components.length; i++) {
    if (aTw.components[i].protocol.code != bTw.components[i].protocol.code) {
      return false;
    }
  }
  return true;
}

/// Byte-exact map key for a multiaddr, mirroring Go's `string(addr.Bytes())`
/// map keys (manager.go uses this throughout `externalAddrs`).
String _bytesKey(Multiaddr m) => String.fromCharCodes(m.toBytes());

/// The set of observers (by [_getObserver] key) that reported the same
/// externally observed thin waist address. manager.go:84-124
/// (`observerSet`).
final class _ObserverSet {
  _ObserverSet(this.observedTwAddr);

  final Multiaddr observedTwAddr;

  /// observer key -> number of connections from that observer reporting
  /// this address.
  final Map<String, int> observedBy = {};

  final Map<String, Multiaddr> _cachedMultiaddrs = {};

  /// Joins [rest] onto [observedTwAddr], caching up to
  /// [_observerSetCacheSize] results. manager.go:93-124
  /// (`observerSet.cacheMultiaddr`).
  Multiaddr cacheMultiaddr(Multiaddr rest) {
    final key = _bytesKey(rest);
    final cached = _cachedMultiaddrs[key];
    if (cached != null) return cached;
    if (_cachedMultiaddrs.length >= _observerSetCacheSize) {
      _cachedMultiaddrs.remove(_cachedMultiaddrs.keys.first);
    }
    final joined = observedTwAddr.encapsulate(rest);
    _cachedMultiaddrs[key] = joined;
    return joined;
  }
}

/// Maps our local (listen) thin waist multiaddrs to the addresses peers
/// reported observing us at, so we can discover and advertise our own
/// public address without operator-supplied `announceAddresses`.
///
/// Populated by subscribing to [EvtPeerIdentificationCompleted] on the
/// [Bus] passed at construction -- emitted by the identify protocol
/// (`p2p/protocol/identify/id.dart`) once it reads a peer's reported
/// `observedAddr` -- decoupled exactly as in Go, where `identify` emits the
/// event and `observedaddrs.Manager` independently subscribes to it.
/// manager.go:131-151 (`Manager`).
final class Manager implements ObservedAddrsManager {
  Manager._(this._listenAddrs, this._eventBus);

  /// Builds a manager whose listen addresses come from [network].
  ///
  /// manager.go:156-171 (`NewManager`). Go's `NewManager` also merges
  /// `net.InterfaceListenAddresses()` into the listen-address closure; this
  /// port's `Network.interfaceListenAddresses()` is asynchronous
  /// (`core/network/network.dart`, outside this change's file scope), so
  /// only the synchronous `listenAddresses()` is used -- the same
  /// simplification `BasicHost.addrs` already makes for the same reason.
  factory Manager(Bus eventBus, Network network) {
    return Manager._(network.listenAddresses, eventBus);
  }

  final List<Multiaddr> Function() _listenAddrs;
  final Bus _eventBus;

  /// local thin waist bytes-key -> observed thin waist bytes-key ->
  /// observer set. manager.go:147-148.
  final Map<String, Map<String, _ObserverSet>> _externalAddrs = {};

  /// The last observed thin waist multiaddr reported on each connection.
  /// manager.go:149-150.
  final Map<CapableConn, Multiaddr> _connObservedTwAddrs = {};

  Subscription? _identifySub;
  StreamSubscription<Object>? _identifyListener;
  Network? _network;
  Notifiee? _notifiee;

  /// Starts tracking observations: subscribes to identify-completion events
  /// on the eventbus and to disconnect notifications on [n]. manager.go:187
  /// -215 (`Start`).
  ///
  /// Deliberate gap: Go's `eventHandler` also runs a periodic (1 minute)
  /// NAT-device-type classification and emits `EvtNATDeviceTypeChanged`.
  /// That event type does not exist yet in this port's `core/event/`, which
  /// is outside this change's file scope (owned by a parallel agent), so
  /// the NAT-type ticker is not ported here. It has no bearing on the F.3
  /// acceptance criterion (self-discovery of the public address via
  /// [addrsFor]/[addrs]).
  void start(Network n) {
    final notifiee = NotifyBundle(disconnectedF: (_, c) => _removeConn(c));
    _notifiee = notifiee;
    _network = n;
    n.notify(notifiee);

    final sub = _eventBus.subscribe(EvtPeerIdentificationCompleted);
    _identifySub = sub;
    _identifyListener = sub.out().listen((event) {
      if (event is EvtPeerIdentificationCompleted) {
        _maybeRecordObservation(event.conn, event.observedAddr);
      }
    });
  }

  /// Returns all activated observed addresses associated with the given
  /// (resolved) listen address [addr]. manager.go:217-236 (`AddrsFor`).
  @override
  List<Multiaddr> addrsFor(Multiaddr addr) {
    final tw = _thinWaistForm(addr);
    if (tw == null) return const [];
    final sets = _getTopExternalAddrs(_bytesKey(tw.tw), activationThresh);
    return [for (final s in sets) s.cacheMultiaddr(tw.rest)];
  }

  /// Returns all observed addresses with at least [minObservers] observers.
  /// If [minObservers] is `<= 0`, [activationThresh] is used instead.
  /// manager.go:270-287 (`Addrs`).
  @override
  List<Multiaddr> addrs(int minObservers) {
    final effective = minObservers <= 0 ? activationThresh : minObservers;
    final m = <String, List<_ObserverSet>>{
      for (final localTwStr in _externalAddrs.keys)
        localTwStr: _getTopExternalAddrs(localTwStr, effective),
    };
    return _appendInferredAddrs(m, <Multiaddr>[]);
  }

  /// Infers the external address for listen addresses that share a thin
  /// waist with an already-observed one (e.g. a QUIC observation implies
  /// the same public address for a co-located WebTransport listener).
  /// manager.go:238-268 (`appendInferredAddrs`).
  List<Multiaddr> _appendInferredAddrs(
    Map<String, List<_ObserverSet>>? twToObserverSets,
    List<Multiaddr> addrs,
  ) {
    final map =
        twToObserverSets ??
        {
          for (final localTwStr in _externalAddrs.keys)
            localTwStr: _getTopExternalAddrs(localTwStr, activationThresh),
        };
    final seenTws = <String>{};
    for (final a in _listenAddrs()) {
      if (!seenTws.add(_bytesKey(a))) continue;
      final t = _thinWaistForm(a);
      if (t == null) continue;
      for (final s in map[_bytesKey(t.tw)] ?? const <_ObserverSet>[]) {
        addrs.add(s.cacheMultiaddr(t.rest));
      }
    }
    return addrs;
  }

  /// The top (by observer count, ties broken by address) up to
  /// [_maxExternalThinWaistAddrsPerLocalAddr] observer sets for
  /// [localTwStr] with at least [minObservers] observers. manager.go:289
  /// -309 (`getTopExternalAddrs`).
  List<_ObserverSet> _getTopExternalAddrs(String localTwStr, int minObservers) {
    final sets = <_ObserverSet>[
      for (final v
          in _externalAddrs[localTwStr]?.values ?? const <_ObserverSet>[])
        if (v.observedBy.length >= minObservers) v,
    ];
    sets.sort((a, b) {
      final diff = b.observedBy.length - a.observedBy.length;
      if (diff != 0) return diff;
      return a.observedTwAddr.compareTo(b.observedTwAddr);
    });
    final n = sets.length < _maxExternalThinWaistAddrsPerLocalAddr
        ? sets.length
        : _maxExternalThinWaistAddrsPerLocalAddr;
    return sets.sublist(0, n);
  }

  void _maybeRecordObservation(Conn conn, Multiaddr observed) {
    final c = conn is CapableConn ? conn : null;
    if (c == null) return;
    final decision = _shouldRecordObservation(c, observed);
    if (decision == null) return;
    _recordObservationUnlocked(c, decision.$1, decision.$2);
  }

  /// Applies the same observation-acceptance conditional as Go's
  /// `shouldRecordObservation` (manager.go:364-420): rejects loopback,
  /// NAT64-converted, and relayed observed addresses; requires the
  /// connection's local address to be one of our listen addresses; and
  /// requires the observed and local thin waists to share transport
  /// protocols.
  (_ThinWaist, _ThinWaist)? _shouldRecordObservation(
    CapableConn conn,
    Multiaddr observed,
  ) {
    if (observed.components.isEmpty) return null;
    if (_isIpLoopback(observed)) return null;
    if (_isNat64Ipv4ConvertedIpv6Addr(observed)) return null;
    if (_isRelayedAddress(observed)) return null;

    final localTw = _thinWaistForm(conn.localMultiaddr());
    if (localTw == null) return null;

    final listenTws = <Multiaddr>[
      for (final a in _listenAddrs())
        if (_thinWaistForm(a) case final t?) t.tw,
    ];
    if (!listenTws.contains(localTw.tw)) return null;

    final observedTw = _thinWaistForm(observed);
    if (observedTw == null) return null;
    if (!_hasConsistentTransport(localTw.tw, observedTw.tw)) return null;

    return (localTw, observedTw);
  }

  /// manager.go:434-458 (`recordObservationUnlocked`).
  void _recordObservationUnlocked(
    CapableConn conn,
    _ThinWaist localTw,
    _ThinWaist observedTw,
  ) {
    if (conn.isClosed) return;
    final localTwStr = _bytesKey(localTw.tw);
    final observer = _getObserver(conn.remoteMultiaddr());
    if (observer == null) return;

    final prevObservedTwAddr = _connObservedTwAddrs[conn];
    if (prevObservedTwAddr != null) {
      if (prevObservedTwAddr == observedTw.tw) return;
      _removeExternalAddrsUnlocked(
        observer,
        localTwStr,
        _bytesKey(prevObservedTwAddr),
      );
    }
    _connObservedTwAddrs[conn] = observedTw.tw;
    _addExternalAddrsUnlocked(
      observedTw.tw,
      observer,
      localTwStr,
      _bytesKey(observedTw.tw),
    );
  }

  /// manager.go:460-475 (`removeExternalAddrsUnlocked`).
  void _removeExternalAddrsUnlocked(
    String observer,
    String localTwStr,
    String observedTwStr,
  ) {
    final byLocal = _externalAddrs[localTwStr];
    final s = byLocal?[observedTwStr];
    if (byLocal == null || s == null) return;
    final remaining = (s.observedBy[observer] ?? 0) - 1;
    if (remaining <= 0) {
      s.observedBy.remove(observer);
    } else {
      s.observedBy[observer] = remaining;
    }
    if (s.observedBy.isEmpty) {
      byLocal.remove(observedTwStr);
    }
    if (byLocal.isEmpty) {
      _externalAddrs.remove(localTwStr);
    }
  }

  /// manager.go:477-490 (`addExternalAddrsUnlocked`).
  void _addExternalAddrsUnlocked(
    Multiaddr observedTwAddr,
    String observer,
    String localTwStr,
    String observedTwStr,
  ) {
    final byLocal = _externalAddrs.putIfAbsent(localTwStr, () => {});
    final s = byLocal.putIfAbsent(
      observedTwStr,
      () => _ObserverSet(observedTwAddr),
    );
    s.observedBy[observer] = (s.observedBy[observer] ?? 0) + 1;
  }

  /// manager.go:492-516 (`removeConn`), invoked on the disconnect notifee.
  void _removeConn(Conn conn) {
    final c = conn is CapableConn ? conn : null;
    if (c == null) return;
    final observedTwAddr = _connObservedTwAddrs.remove(c);
    if (observedTwAddr == null) return;

    final localTw = _thinWaistForm(c.localMultiaddr());
    if (localTw == null) return;
    final observer = _getObserver(c.remoteMultiaddr());
    if (observer == null) return;

    _removeExternalAddrsUnlocked(
      observer,
      _bytesKey(localTw.tw),
      _bytesKey(observedTwAddr),
    );
  }

  /// Stops tracking: unregisters the disconnect notifee and cancels the
  /// identify-completion subscription. manager.go:578-583 (`Close`).
  ///
  /// No orphaned timers or subscriptions are left running: unlike Go, which
  /// waits on a `sync.WaitGroup` for its two goroutines to exit, this port
  /// has no background goroutine/channel worker to wait on -- see the
  /// [start] divergence note on why the bounded worker channel isn't
  /// ported (Dart's single-threaded event loop processes each event
  /// synchronously in the subscription callback, so there is no concurrent
  /// producer to bound).
  Future<void> close() async {
    final notifiee = _notifiee;
    final net = _network;
    if (notifiee != null && net != null) {
      net.stopNotify(notifiee);
    }
    await _identifyListener?.cancel();
    await _identifySub?.close();
  }
}
