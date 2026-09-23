// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import '../../../core/event/bus.dart';
import '../../../core/event/identify.dart';
import '../../../core/event/reachability.dart';
import '../../../core/host/host.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import 'interface.dart';
import 'options.dart';

export 'dialpolicy.dart';
export 'interface.dart';
export 'options.dart';

const int maxConfidence = 3;

/// A simple AutoNat implementation when a fixed reachability status is desired.
class StaticAutoNat implements AutoNat {
  StaticAutoNat({required this.reachability});

  final Reachability reachability;

  @override
  Reachability status() => reachability;

  @override
  Future<void> close() async {}
}

/// AmbientAutoNat determines NAT reachability using dial-backs from peers.
/// Implements full AutoNAT v1 state machine matching go-libp2p/p2p/host/autonat.
class AmbientAutoNat implements AutoNat, Notifiee {
  AmbientAutoNat({
    Host? host,
    AutoNatConfig? config,
    Client? client,
    Reachability initialReachability = Reachability.unknown,
  }) : _host = host,
       config = config ?? (host != null ? AutoNatConfig(host: host) : null),
       _client = client ?? (host != null ? Client(host: host) : null),
       _status = initialReachability {
    if (host != null) {
      _init();
    }
  }

  Host? _host;
  Host? get host => _host;
  set host(Host? h) {
    if (h == null || _host == h) return;
    _host = h;
    config ??= AutoNatConfig(host: h);
    _client ??= Client(host: h);
    _init();
  }

  AutoNatConfig? config;
  Client? _client;

  Reachability _status;
  int _confidence = 0;
  int get confidence => _confidence;

  DateTime? lastInbound;
  DateTime? lastProbe;
  final Map<String, DateTime> recentProbes = <String, DateTime>{};
  int pendingProbes = 0;
  final Set<String> ourAddrs = <String>{};

  bool _closed = false;
  Timer? _timer;
  Emitter? _emitter;
  Subscription? _sub;

  void _init() {
    final h = _host;
    if (h == null) return;
    checkAddrs();
    // Subscribe to identification events
    try {
      _sub = h.eventBus.subscribe(EvtPeerIdentificationCompleted);
      _sub?.out().listen((dynamic event) {
        if (_closed) return;
        if (event is EvtPeerIdentificationCompleted) {
          if (event.protocols.any((p) => p == autoNatProto)) {
            _reschedule(forceProbe: true);
          }
        }
      });
    } catch (_) {}

    final cfg = config;
    final bootDelay = cfg?.bootDelay ?? const Duration(seconds: 15);
    _timer = Timer(bootDelay, () => _runProbeLoop(false));
  }

  Future<Emitter?> _getEmitter() async {
    final h = _host;
    if (h == null) return null;
    return _emitter ??= await h.eventBus.emitter(EvtLocalReachabilityChanged);
  }

  @override
  Reachability status() => _status;

  /// Updates reachability and emits EvtLocalReachabilityChanged if changed.
  Future<void> setReachability(Reachability newStatus) async {
    if (_closed || _status == newStatus) return;
    _status = newStatus;
    try {
      final em = await _getEmitter();
      await em?.emit(EvtLocalReachabilityChanged(reachability: newStatus));
    } catch (_) {}
  }

  /// Emits the current reachability status on the event bus.
  Future<void> emitStatus() async {
    if (_closed) return;
    try {
      final em = await _getEmitter();
      await em?.emit(EvtLocalReachabilityChanged(reachability: _status));
    } catch (_) {}
  }

  /// Updates NAT status and confidence based on observation, per autonat.go:315-373.
  void recordObservation(Reachability observation) {
    final currentStatus = _status;

    if (observation == Reachability.public_) {
      var changed = false;
      if (currentStatus != Reachability.public_) {
        // Aggressively switch to public from other states ignoring confidence
        _confidence = 0;
        _status = Reachability.public_;
        changed = true;
      } else if (_confidence < maxConfidence) {
        _confidence++;
      }
      if (changed) {
        emitStatus();
      }
    } else if (observation == Reachability.private_) {
      if (currentStatus != Reachability.private_) {
        if (_confidence > 0) {
          _confidence--;
        } else {
          // Flip to private once confidence reached 0
          _confidence = 0;
          _status = Reachability.private_;
          emitStatus();
        }
      } else if (_confidence < maxConfidence) {
        _confidence++;
      }
    } else if (_confidence > 0) {
      // Don't just flip to unknown, reduce confidence first
      _confidence--;
    } else {
      _status = Reachability.unknown;
      if (currentStatus != Reachability.unknown) {
        emitStatus();
      }
    }
  }

  /// Updates current status based on dial response.
  void handleDialResponse(Object? dialErr) {
    Reachability observation;
    if (dialErr == null) {
      observation = Reachability.public_;
    } else if (isDialError(dialErr)) {
      observation = Reachability.private_;
    } else {
      observation = Reachability.unknown;
    }
    recordObservation(observation);
  }

  /// Selects a connected peer suitable for dial-back probing.
  PeerId? getPeerToProbe() {
    final h = _host;
    if (h == null) return null;
    final peers = h.network.peers();
    if (peers.isEmpty) return null;

    final now = DateTime.now();
    final throttlePeriod =
        config?.throttlePeerPeriod ?? const Duration(seconds: 90);
    recentProbes.removeWhere((k, v) => now.difference(v) > throttlePeriod);

    final shuffled = List<PeerId>.from(peers)..shuffle();
    for (final p in shuffled) {
      final protos = h.peerstore.supportsProtocols(p, [autoNatProto]);
      if (protos.isEmpty) continue;

      final info = h.peerstore.peerInfo(p);
      if (config?.dialPolicy.skipPeer(info.addrs) ?? false) {
        continue;
      }
      return p;
    }
    return null;
  }

  /// Calculates probe scheduling delay matching autonat.go:263-297.
  Duration scheduleProbe(bool forceProbe) {
    final now = DateTime.now();
    final currentStatus = _status;
    final refreshInterval =
        config?.refreshInterval ?? const Duration(minutes: 15);
    final retryInterval = config?.retryInterval ?? const Duration(seconds: 90);
    var nextProbeAfter = refreshInterval;
    final receivedInbound =
        lastInbound != null &&
        lastProbe != null &&
        lastInbound!.isAfter(lastProbe!);

    if (forceProbe && currentStatus == Reachability.unknown) {
      nextProbeAfter = const Duration(seconds: 2);
    } else if (currentStatus == Reachability.unknown ||
        _confidence < maxConfidence ||
        (currentStatus != Reachability.public_ && receivedInbound)) {
      nextProbeAfter = retryInterval;
    } else if (currentStatus == Reachability.public_ && receivedInbound) {
      nextProbeAfter *= 2;
      if (nextProbeAfter > const Duration(hours: 24)) {
        nextProbeAfter = const Duration(hours: 24);
      }
    }

    final lastP = lastProbe ?? now;
    var nextProbeTime = lastP.add(nextProbeAfter);
    if (nextProbeTime.isBefore(now)) {
      nextProbeTime = now;
    }
    return nextProbeTime.difference(now);
  }

  /// Checks if addresses have changed and adjusts confidence if needed.
  bool checkAddrs() {
    final h = _host;
    if (h == null) return false;
    final currentAddrs = config?.addressFunc?.call() ?? h.addrs;
    var hasNewAddr = false;
    for (final a in currentAddrs) {
      final key = String.fromCharCodes(a.toBytes());
      if (!ourAddrs.contains(key)) {
        hasNewAddr = true;
        break;
      }
    }
    ourAddrs.clear();
    for (final a in currentAddrs) {
      if (!isPublicAddr(a)) continue;
      ourAddrs.add(String.fromCharCodes(a.toBytes()));
    }
    if (hasNewAddr && _confidence == maxConfidence) {
      _confidence--;
    }
    return hasNewAddr;
  }

  void _reschedule({bool forceProbe = false}) {
    if (_closed) return;
    _timer?.cancel();
    _timer = Timer(scheduleProbe(forceProbe), () => _runProbeLoop(forceProbe));
  }

  Future<void> _runProbeLoop(bool forceProbe) async {
    if (_closed) return;
    lastProbe = DateTime.now();
    final p = getPeerToProbe();
    if (p != null) {
      await tryProbe(p);
    }
    checkAddrs();
    _reschedule();
  }

  /// Attempts a probe to peer [p].
  Future<void> tryProbe(PeerId p) async {
    if (_closed || pendingProbes > 5) return;
    final cli = _client;
    if (cli == null) return;
    recentProbes[p.toString()] = DateTime.now();
    pendingProbes++;
    try {
      final reqTimeout = config?.requestTimeout ?? const Duration(seconds: 30);
      await cli.dialBack(p).timeout(reqTimeout);
      handleDialResponse(null);
    } catch (e) {
      if (isDialRefused(e)) {
        _reschedule(forceProbe: true);
      } else {
        handleDialResponse(e);
      }
    } finally {
      pendingProbes--;
    }
  }

  void onInboundPublicConn(Conn connection) {
    final h = _host;
    if (h == null) return;
    final localAddrs = h.addrs;
    final rAddr = connection.remoteMultiaddr();
    if (isPublicAddr(rAddr)) {
      final rIp = toIp(rAddr);
      final isLocal = localAddrs.any((a) {
        final lIp = toIp(a);
        return lIp != null && rIp != null && lIp.equal(rIp);
      });
      if (!isLocal) {
        lastInbound = DateTime.now();
      }
    }
  }

  @override
  void listen(Network network, Multiaddr address) {}

  @override
  void listenClose(Network network, Multiaddr address) {}

  @override
  void connected(Network network, Conn connection) {
    if (connection.stat().direction == Direction.inbound &&
        isPublicAddr(connection.remoteMultiaddr())) {
      onInboundPublicConn(connection);
    }
  }

  @override
  void disconnected(Network network, Conn connection) {}

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    await _sub?.close();
    _sub = null;
    await _emitter?.close();
    _emitter = null;
  }
}
