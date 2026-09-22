import 'package:transpiled_libp2p/transpiled_libp2p.dart';

/// State of a peer during one Kademlia lookup.
enum PeerState {
  /// Discovered but not queried.
  heard,

  /// Query currently in flight.
  waiting,

  /// Query completed successfully.
  queried,

  /// Dial or query failed.
  unreachable,
}

/// Tracks peers by XOR distance and query state.
///
/// Dart adaptation of go-libp2p-kad-dht's `qpeerset.QueryPeerset`.
class QueryPeerset {
  /// Creates an empty set ordered relative to [target].
  QueryPeerset(this.target, this.compareDistance);

  /// Lookup target.
  final PeerId target;

  /// Compares two peers by distance to a target.
  final int Function(PeerId target, PeerId a, PeerId b) compareDistance;
  final Map<PeerId, _QueryPeerState> _peers = {};

  /// Adds [peer] in [PeerState.heard], returning false when already present.
  bool tryAdd(PeerId peer, PeerId referredBy) {
    if (_peers.containsKey(peer)) return false;
    _peers[peer] = _QueryPeerState(referredBy);
    return true;
  }

  /// Changes the state of a known [peer].
  void setState(PeerId peer, PeerState state) {
    final entry = _peers[peer];
    if (entry == null) throw StateError('peer is not in the query peerset');
    entry.state = state;
  }

  /// Returns the current state of [peer].
  PeerState getState(PeerId peer) {
    final entry = _peers[peer];
    if (entry == null) throw StateError('peer is not in the query peerset');
    return entry.state;
  }

  /// Returns the peer that referred [peer].
  PeerId getReferrer(PeerId peer) {
    final entry = _peers[peer];
    if (entry == null) throw StateError('peer is not in the query peerset');
    return entry.referredBy;
  }

  /// Returns at most [count] closest peers in any requested state.
  List<PeerId> getClosestNInStates(int count, Set<PeerState> states) {
    final peers = [
      for (final entry in _peers.entries)
        if (states.contains(entry.value.state)) entry.key,
    ]..sort((a, b) => compareDistance(target, a, b));
    return peers.take(count).toList();
  }

  /// Returns all closest peers in any requested state.
  List<PeerId> getClosestInStates(Set<PeerState> states) =>
      getClosestNInStates(_peers.length, states);

  /// Number of peers not queried yet.
  int get numHeard => getClosestInStates({PeerState.heard}).length;

  /// Number of queries currently in flight.
  int get numWaiting => getClosestInStates({PeerState.waiting}).length;
}

class _QueryPeerState {
  _QueryPeerState(this.referredBy);

  final PeerId referredBy;
  PeerState state = PeerState.heard;
}
