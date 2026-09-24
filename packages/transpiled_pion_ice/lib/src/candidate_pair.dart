// Package ice CandidatePair implementation.
library;

import 'candidate.dart';
import 'candidate_pair_state.dart';

/// CandidatePair is a combination of a local and remote candidate.
class CandidatePair {
  final Candidate local;
  final Candidate remote;
  CandidatePairState state;
  bool nominated;
  bool nominateOnBindingSuccess;

  CandidatePair({
    required this.local,
    required this.remote,
    this.state = CandidatePairState.waiting,
    this.nominated = false,
    this.nominateOnBindingSuccess = false,
  });

  /// priority computes candidate pair priority per RFC 5245 Section 5.7.2.
  int priority({bool controlling = true}) {
    final g = controlling ? local.priority() : remote.priority();
    final d = controlling ? remote.priority() : local.priority();
    // pair priority = 2^32*MIN(G,D) + 2*MAX(G,D) + (G>D?1:0)
    final min = g < d ? g : d;
    final max = g > d ? g : d;
    return (min << 32) + (2 * max) + (g > d ? 1 : 0);
  }

  String string() {
    return 'prio ${priority()} (local, prio ${local.priority()}) ${local.string()} <-> ${remote.string()} (remote, prio ${remote.priority()}), state: ${state.string()}, nominated: $nominated';
  }

  @override
  String toString() => string();
}
