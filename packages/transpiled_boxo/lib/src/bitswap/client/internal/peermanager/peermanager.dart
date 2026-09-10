// ignore_for_file: public_member_api_docs, unused_field
import 'package:transpiled_boxo/src/bitswap/client/internal/messagequeue/messagequeue.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

export 'peerqueue.dart';
import 'peerqueue.dart';
import 'peerwantmanager.dart';

abstract class Session {
  int id();
  void signalAvailability(PeerId peer, bool isConnected);
}

typedef PeerQueueFactory = PeerQueue Function(PeerId p);

class PeerManager {

  PeerManager(
    this._createPeerQueue,
    BroadcastControl bcastControl,
    Gauge wantGauge,
    Gauge wantBlockGauge,
    this._bcastGauge,
  ) {
    _pwm = PeerWantManager(wantGauge, wantBlockGauge, bcastControl);
  }
  final Map<PeerId, PeerQueue> _peerQueues = {};
  late final PeerWantManager _pwm;
  final PeerQueueFactory _createPeerQueue;

  final Map<int, Session> _sessions = {};
  final Map<PeerId, Map<int, void>> _peerSessions = {};

  final Gauge _bcastGauge;

  List<PeerId> availablePeers() {
    return connectedPeers();
  }

  List<PeerId> connectedPeers() {
    return _peerQueues.keys.toList();
  }

  void connected(PeerId p) {
    final pq = _getOrCreate(p);
    _pwm.addPeer(pq, p);

    _signalAvailability(p, true);
  }

  void disconnected(PeerId p) {
    final pq = _peerQueues[p];
    if (pq == null) {
      return;
    }

    _peerQueues.remove(p);
    _pwm.removePeer(p);

    _signalAvailability(p, false);

    pq.shutdown();
  }

  void responseReceived(PeerId p, List<Cid> ks) {
    final pq = _peerQueues[p];
    if (pq != null) {
      pq.responseReceived(ks);
    }
  }

  void broadcastWantHaves(List<Cid> wantHaves) {
    _pwm.broadcastWantHaves(wantHaves);
  }

  bool sendWants(PeerId p, List<Cid> wantBlocks, List<Cid> wantHaves) {
    if (!_peerQueues.containsKey(p)) {
      return false;
    }
    _pwm.sendWants(p, wantBlocks, wantHaves);
    return true;
  }

  void sendCancels(List<Cid> cancelKs) {
    _pwm.sendCancels(cancelKs);
  }

  List<Cid> currentWants() {
    return _pwm.getWants();
  }

  List<Cid> currentWantBlocks() {
    return _pwm.getWantBlocks();
  }

  List<Cid> currentWantHaves() {
    return _pwm.getWantHaves();
  }

  PeerQueue _getOrCreate(PeerId p) {
    var pq = _peerQueues[p];
    if (pq == null) {
      pq = _createPeerQueue(p);
      if (pq is MessageQueue) {
        // In Dart, we can't easily assign bcastInc if it's a method or property,
        // assuming MessageQueue has a setter for it or we can pass it,
        // but here it's simplified. If it exists:
        // pq.bcastInc = _bcastGauge.inc;
      }
      pq.startup();
      _peerQueues[p] = pq;
    }
    return pq;
  }

  void registerSession(PeerId p, Session s) {
    _sessions.putIfAbsent(s.id(), () => s);
    _peerSessions.putIfAbsent(p, () => {});
    _peerSessions[p]![s.id()] = null;
  }

  void unregisterSession(int ses) {
    for (final p in _peerSessions.keys.toList()) {
      final sesSet = _peerSessions[p]!;
      sesSet.remove(ses);
      if (sesSet.isEmpty) {
        _peerSessions.remove(p);
      }
    }
    _sessions.remove(ses);
  }

  void markBroadcastTarget(PeerId from) {
    _pwm.markBroadcastTarget(from);
  }

  void _signalAvailability(PeerId p, bool isConnected) {
    final sesIds = _peerSessions[p];
    if (sesIds == null) {
      return;
    }
    for (final sesId in sesIds.keys) {
      final s = _sessions[sesId];
      if (s != null) {
        s.signalAvailability(p, isConnected);
      }
    }
  }
}

