// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/event/bus.dart';
import '../../../core/event/reachability.dart';
import '../../../core/host/host.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/addr_info.dart';
import '../../../core/peer/peer_id.dart';
import '../../protocol/circuitv2/client/reservation.dart';

typedef PeerSourceCallback = Future<List<AddrInfo>> Function(int numPeers);

/// AutoRelay autonomously manages Circuit Relay v2 reservations for NAT traversal.
class AutoRelay {
  AutoRelay({
    Host? host,
    this.staticRelays = const [],
    this.peerSource,
    this.desiredRelays = 2,
    this.maxCandidates = 20,
    this.minCandidates = 1,
    this.bootDelay = const Duration(seconds: 5),
    this.backoff = const Duration(hours: 1),
    this.minInterval = const Duration(seconds: 30),
  }) : _host = host;

  Host? _host;
  Host get host => _host!;
  set host(Host h) => _host = h;
  final List<AddrInfo> staticRelays;
  final PeerSourceCallback? peerSource;
  final int desiredRelays;
  final int maxCandidates;
  final int minCandidates;
  final Duration bootDelay;
  final Duration backoff;
  final Duration minInterval;

  final Map<PeerId, DateTime> _backoff = {};
  final Map<PeerId, Reservation> _reservations = {};
  final List<Multiaddr> _relayAddrs = [];

  bool _started = false;
  bool _closed = false;
  Subscription? _reachabilitySub;
  Timer? _loopTimer;

  bool get isStarted => _started;
  bool get isClosed => _closed;
  List<Multiaddr> get relayAddrs => List.unmodifiable(_relayAddrs);
  int get activeReservationsCount => _reservations.length;

  /// Starts the AutoRelay daemon.
  Future<void> start() async {
    if (_started || _closed) return;
    _started = true;

    // Subscribe to reachability events
    try {
      _reachabilitySub = host.eventBus.subscribe(EvtLocalReachabilityChanged);
      _reachabilitySub?.out().listen((event) {
        if (event is EvtLocalReachabilityChanged) {
          _onReachabilityChanged(event.reachability);
        }
      });
    } catch (_) {}

    // Boot delay before initial relay discovery
    _loopTimer = Timer(bootDelay, _findAndReserveRelays);
  }

  void _onReachabilityChanged(Reachability reachability) {
    if (_closed) return;
    if (reachability == Reachability.private_ || reachability == Reachability.unknown) {
      _findAndReserveRelays();
    }
  }

  bool isPeerInBackoff(PeerId peer) {
    final expiry = _backoff[peer];
    if (expiry == null) return false;
    if (DateTime.now().isAfter(expiry)) {
      _backoff.remove(peer);
      return false;
    }
    return true;
  }

  Future<void> _findAndReserveRelays() async {
    if (_closed || !_started) return;
    if (_reservations.length >= desiredRelays) return;

    final candidates = <AddrInfo>[];

    // 1. Static relays
    for (final r in staticRelays) {
      if (!isPeerInBackoff(r.id) && !_reservations.containsKey(r.id)) {
        candidates.add(r);
      }
    }

    // 2. Peer source callback
    if (candidates.length < desiredRelays && peerSource != null) {
      try {
        final sourced = await peerSource!(desiredRelays - candidates.length);
        for (final s in sourced) {
          if (!isPeerInBackoff(s.id) && !_reservations.containsKey(s.id)) {
            candidates.add(s);
          }
        }
      } catch (_) {}
    }

    // Attempt reservations
    for (final c in candidates) {
      if (_reservations.length >= desiredRelays) break;
      try {
        final rsvp = await reserve(host, c);
        _reservations[c.id] = rsvp;

        // Construct /p2p-circuit multiaddrs
        for (final a in rsvp.addrs) {
          try {
            final circuitAddr = Multiaddr.parse('$a/p2p/${c.id}/p2p-circuit');
            if (!_relayAddrs.contains(circuitAddr)) {
              _relayAddrs.add(circuitAddr);
            }
          } catch (_) {}
        }
      } catch (_) {
        _backoff[c.id] = DateTime.now().add(backoff);
      }
    }

    // Schedule next run
    if (!_closed && _started) {
      _loopTimer?.cancel();
      _loopTimer = Timer(minInterval, _findAndReserveRelays);
    }
  }

  /// Closes and cleans up AutoRelay.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _started = false;
    _loopTimer?.cancel();
    _loopTimer = null;
    await _reachabilitySub?.close();
    _reachabilitySub = null;
    _reservations.clear();
    _relayAddrs.clear();
    _backoff.clear();
  }
}
