import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';

/// BlockPresenceManager keeps track of which peers have indicated that they
/// have or explicitly don't have a block
class BlockPresenceManager {
  // Map of Cid -> (PeerId string -> bool)
  final Map<Cid, Map<String, bool>> _presence = {};

  /// ReceiveFrom is called when a peer sends us information about which blocks
  /// it has and does not have
  void receiveFrom(PeerId p, List<Cid> haves, List<Cid> dontHaves) {
    final peerStr = p.toString();
    for (final c in haves) {
      _updateBlockPresence(peerStr, c, true);
    }
    for (final c in dontHaves) {
      _updateBlockPresence(peerStr, c, false);
    }
  }

  void _updateBlockPresence(String p, Cid c, bool present) {
    final ps = _presence[c];
    if (ps == null) {
      _presence[c] = {p: present};
      return;
    }

    // Make sure not to change HAVE to DONT_HAVE
    final has = ps[p];
    if (has != null && has) {
      return;
    }
    ps[p] = present;
  }

  /// PeerHasBlock indicates whether the given peer has sent a HAVE for the given
  /// cid
  bool peerHasBlock(PeerId p, Cid c) {
    final ps = _presence[c];
    if (ps == null) return false;
    return ps[p.toString()] ?? false;
  }

  /// PeerDoesNotHaveBlock indicates whether the given peer has sent a DONT_HAVE
  /// for the given cid
  bool peerDoesNotHaveBlock(PeerId p, Cid c) {
    final ps = _presence[c];
    if (ps == null) return false;
    final have = ps[p.toString()];
    return have != null && !have;
  }

  /// Filters the keys such that all the given peers have received a DONT_HAVE
  /// for a key.
  /// This allows us to know if we've exhausted all possibilities of finding
  /// the key with the peers we know about.
  List<Cid> allPeersDoNotHaveBlock(List<PeerId> peers, List<Cid> ks) {
    if (_presence.isEmpty) {
      return [];
    }

    final res = <Cid>[];
    for (final c in ks) {
      if (_allDontHave(peers, c)) {
        res.add(c);
      }
    }
    return res;
  }

  bool _allDontHave(List<PeerId> peers, Cid c) {
    // Check if we know anything about the cid's block presence
    final ps = _presence[c];
    if (ps == null || ps.isEmpty) {
      return false;
    }

    // Check if we explicitly know that all the given peers do not have the cid
    for (final p in peers) {
      final has = ps[p.toString()];
      if (has == null || has) {
        return false;
      }
    }
    return true;
  }

  /// RemoveKeys cleans up the given keys from the block presence map
  void removeKeys(List<Cid> ks) {
    if (ks.isEmpty) return;

    for (final c in ks) {
      _presence.remove(c);
    }
  }

  /// RemovePeer removes the given peer from every cid key in the presence map.
  void removePeer(PeerId p) {
    final peerStr = p.toString();
    final keysToRemove = <Cid>[];
    
    for (final entry in _presence.entries) {
      final pm = entry.value;
      pm.remove(peerStr);
      if (pm.isEmpty) {
        keysToRemove.add(entry.key);
      }
    }
    
    for (final k in keysToRemove) {
      _presence.remove(k);
    }
  }

  /// HasKey indicates whether the BlockPresenceManager is tracking the given key
  /// (used by the tests)
  bool hasKey(Cid c) {
    return _presence.containsKey(c);
  }
}
