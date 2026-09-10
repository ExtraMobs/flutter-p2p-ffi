// ignore_for_file: public_member_api_docs, unused_field

import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

import 'peermanager.dart';

abstract class Gauge {
  void inc();
  void dec();
}

class BroadcastControl {

  BroadcastControl({
    this.enable = false,
    this.host,
    this.maxPeers = 0,
    this.localPeers = false,
    this.peeredPeers = false,
    this.maxRandomPeers = 0,
    this.sendToPendingPeers = false,
    this.skipGauge,
  });
  bool enable;
  dynamic
  host; // host.Host is not available here, using dynamic or we can skip if not needed
  int maxPeers;
  bool localPeers;
  bool peeredPeers;
  int maxRandomPeers;
  bool sendToPendingPeers;
  Gauge? skipGauge;

  bool needHost() {
    return maxPeers != 0 && !localPeers && !peeredPeers;
  }
}

class PeerWantManager {

  PeerWantManager(this._wantGauge, this._wantBlockGauge, this._bcastControl) {
    if (_bcastControl.enable) {
      if (_bcastControl.host == null && _bcastControl.needHost()) {
        throw Exception('Host missing from BroadcastControl');
      }
    }
  }
  final Map<PeerId, PeerWant> _peerWants = {};
  final Map<Cid, Map<PeerId, void>> _wantPeers = {};
  final Set<Cid> _broadcastWants = {};

  final Gauge _wantGauge;
  final Gauge _wantBlockGauge;

  final BroadcastControl _bcastControl;
  final Map<PeerId, void> _bcastTargets = {};
  final Map<PeerId, void> _remotePeers = {};

  void addPeer(PeerQueue peerQueue, PeerId p) {
    if (_peerWants.containsKey(p)) {
      return;
    }

    _peerWants[p] = PeerWant(
      wantBlocks: {},
      wantHaves: {},
      peerQueue: peerQueue,
    );

    if (_broadcastWants.isNotEmpty) {
      peerQueue.addBroadcastWantHaves(_broadcastWants.toList());
    }
  }

  void removePeer(PeerId p) {
    final pws = _peerWants[p];
    if (pws == null) {
      return;
    }

    for (final c in pws.wantBlocks) {
      _reverseIndexRemove(c, p);
      final peerCounts = _wantPeerCounts(c);
      if (peerCounts.wantBlock == 0) {
        _wantBlockGauge.dec();
      }
      if (!peerCounts.wanted()) {
        _wantGauge.dec();
      }
    }

    for (final c in pws.wantHaves) {
      _reverseIndexRemove(c, p);
      final peerCounts = _wantPeerCounts(c);
      if (!peerCounts.wanted()) {
        _wantGauge.dec();
      }
    }

    _peerWants.remove(p);
    _remotePeers.remove(p);
    _bcastTargets.remove(p);
  }

  void broadcastWantHaves(List<Cid> wantHaves) {
    bool reduce = false;
    int maxPeers = 0;
    int randosToSend = 0;

    if (_bcastControl.enable) {
      if (_bcastControl.maxPeers == 0) {
        return;
      }
      reduce = true;
      maxPeers = _bcastControl.maxPeers;
      randosToSend = _bcastControl.maxRandomPeers;
    }

    final unsent = <Cid>[];
    for (final c in wantHaves) {
      if (_broadcastWants.contains(c)) {
        continue;
      }
      _broadcastWants.add(c);
      unsent.add(c);

      if (!_wantPeers.containsKey(c)) {
        _wantGauge.inc();
      }
    }

    if (unsent.isEmpty) {
      return;
    }

    for (final entry in _peerWants.entries) {
      final p = entry.key;
      final pws = entry.value;
      bool sentRando = false;

      if (reduce && _skipBroadcast(p, pws.peerQueue)) {
        if (randosToSend == 0) {
          _bcastControl.skipGauge?.inc();
          continue;
        }
        sentRando = true;
      }

      final peerUnsent = <Cid>[];
      for (final c in unsent) {
        if (!pws.wantBlocks.contains(c) && !pws.wantHaves.contains(c)) {
          peerUnsent.add(c);
        }
      }

      if (peerUnsent.isEmpty) {
        continue;
      }

      pws.peerQueue.addBroadcastWantHaves(peerUnsent);

      if (sentRando) {
        randosToSend--;
      }

      if (maxPeers > 0) {
        maxPeers--;
        if (maxPeers == 0) {
          break;
        }
      }
    }
  }

  bool _skipBroadcast(PeerId peerID, PeerQueue peerQueue) {
    if (_bcastTargets.containsKey(peerID)) {
      return false;
    }

    if (!_bcastControl.localPeers && _isLocalPeer(peerID)) {
      _bcastTargets[peerID] = null;
      return false;
    }

    if (!_bcastControl.peeredPeers) {
      // Assuming host has conn manager logic, simplified here since we can't fully mock it
      // if (connMgr != null && connMgr.isProtected(peerID, 'peering')) {
      //   _bcastTargets[peerID] = null;
      //   return false;
      // }
    }

    if (_bcastControl.sendToPendingPeers && peerQueue.hasMessage()) {
      return false;
    }

    return true;
  }

  void markBroadcastTarget(PeerId peerID) {
    _bcastTargets[peerID] = null;
  }

  bool _isLocalPeer(PeerId peerID) {
    if (_remotePeers.containsKey(peerID)) {
      return false;
    }
    // Simplified since we don't have multiformats/manet and host implementation available in this scope
    _remotePeers[peerID] = null;
    return false;
  }

  void sendWants(PeerId p, List<Cid> wantBlocks, List<Cid> wantHaves) {
    final pws = _peerWants[p];
    if (pws == null) {
      return;
    }

    final fltWantBlks = <Cid>[];
    for (final c in wantBlocks) {
      if (pws.wantBlocks.contains(c)) {
        continue;
      }

      final peerCounts = _wantPeerCounts(c);
      if (peerCounts.wantBlock == 0) {
        _wantBlockGauge.inc();
      }
      if (!peerCounts.wanted()) {
        _wantGauge.inc();
      }

      pws.wantHaves.remove(c);
      pws.wantBlocks.add(c);
      fltWantBlks.add(c);
      _reverseIndexAdd(c, p);
    }

    final fltWantHvs = <Cid>[];
    for (final c in wantHaves) {
      if (_broadcastWants.contains(c)) {
        continue;
      }

      if (!pws.wantBlocks.contains(c) && !pws.wantHaves.contains(c)) {
        final peerCounts = _wantPeerCounts(c);
        if (!peerCounts.wanted()) {
          _wantGauge.inc();
        }

        pws.wantHaves.add(c);
        fltWantHvs.add(c);
        _reverseIndexAdd(c, p);
      }
    }

    pws.peerQueue.addWants(fltWantBlks, fltWantHvs);
  }

  void sendCancels(List<Cid> cancelKs) {
    if (cancelKs.isEmpty) {
      return;
    }

    final peerCounts = <Cid, WantPeerCnts>{};
    var broadcastCancels = <Cid>[];

    for (final c in cancelKs) {
      final counts = _wantPeerCounts(c);
      peerCounts[c] = counts;
      if (counts.isBroadcast) {
        broadcastCancels.add(c);
      }
    }

    void send(PeerWant pws) {
      var toCancel = List<Cid>.from(broadcastCancels);

      for (final c in cancelKs) {
        if (!pws.wantBlocks.contains(c) && !pws.wantHaves.contains(c)) {
          continue;
        }

        pws.wantBlocks.remove(c);
        pws.wantHaves.remove(c);

        if (!_broadcastWants.contains(c)) {
          toCancel.add(c);
        }
      }

      if (toCancel.isNotEmpty) {
        pws.peerQueue.addCancels(toCancel);
      }
    }

    void clearWantsForCID(Cid c) {
      final peerCnts = peerCounts[c]!;
      if (peerCnts.wantBlock > 0) {
        _wantBlockGauge.dec();
      }
      if (peerCnts.wanted()) {
        _wantGauge.dec();
      }
      _wantPeers.remove(c);
    }

    if (broadcastCancels.isNotEmpty) {
      for (final pws in _peerWants.values) {
        send(pws);
      }

      for (final c in broadcastCancels) {
        _broadcastWants.remove(c);
      }

      for (final c in cancelKs) {
        clearWantsForCID(c);
      }
    } else {
      for (final c in cancelKs) {
        final peers = _wantPeers[c];
        if (peers != null) {
          for (final p in peers.keys) {
            final pws = _peerWants[p];
            if (pws != null) {
              send(pws);
            }
          }
        }
        clearWantsForCID(c);
      }
    }
  }

  WantPeerCnts _wantPeerCounts(Cid c) {
    int blockCount = 0;
    int haveCount = 0;

    final peers = _wantPeers[c];
    if (peers != null) {
      for (final p in peers.keys) {
        final pws = _peerWants[p];
        if (pws != null) {
          if (pws.wantBlocks.contains(c)) {
            blockCount++;
          } else if (pws.wantHaves.contains(c)) {
            haveCount++;
          }
        }
      }
    }

    return WantPeerCnts(
      wantBlock: blockCount,
      wantHave: haveCount,
      isBroadcast: _broadcastWants.contains(c),
    );
  }

  bool _reverseIndexAdd(Cid c, PeerId p) {
    var peers = _wantPeers[c];
    bool isNew = false;
    if (peers == null) {
      peers = {};
      _wantPeers[c] = peers;
      isNew = true;
    } else if (!peers.containsKey(p)) {
      isNew = true;
    }
    peers[p] = null;
    return isNew;
  }

  void _reverseIndexRemove(Cid c, PeerId p) {
    final peers = _wantPeers[c];
    if (peers != null) {
      peers.remove(p);
      if (peers.isEmpty) {
        _wantPeers.remove(c);
      }
    }
  }

  List<Cid> getWantBlocks() {
    final res = <Cid>{};
    for (final pws in _peerWants.values) {
      res.addAll(pws.wantBlocks);
    }
    return res.toList();
  }

  List<Cid> getWantHaves() {
    final res = <Cid>{};
    for (final pws in _peerWants.values) {
      res.addAll(pws.wantHaves);
    }
    res.addAll(_broadcastWants);
    return res.toList();
  }

  List<Cid> getWants() {
    final res = <Cid>[..._broadcastWants];
    for (final c in _wantPeers.keys) {
      if (_broadcastWants.contains(c)) {
        continue;
      }
      res.add(c);
    }
    return res;
  }
}

class PeerWant {

  PeerWant({
    required this.wantBlocks,
    required this.wantHaves,
    required this.peerQueue,
  });
  final Set<Cid> wantBlocks;
  final Set<Cid> wantHaves;
  final PeerQueue peerQueue;
}

class WantPeerCnts {

  WantPeerCnts({
    required this.wantBlock,
    required this.wantHave,
    required this.isBroadcast,
  });
  final int wantBlock;
  final int wantHave;
  final bool isBroadcast;

  bool wanted() {
    return wantBlock > 0 || wantHave > 0 || isBroadcast;
  }
}

