// Package ice agent handlers and event notifier.
library;

import 'candidate.dart';
import 'candidate_pair.dart';
import 'connection_state.dart';

/// HandlerNotifier coordinates sequential asynchronous execution of ICE callbacks.
class HandlerNotifier {
  bool _closed = false;
  void Function(ConnectionState)? onConnectionState;
  void Function(Candidate)? onCandidate;
  void Function(CandidatePair)? onSelectedCandidatePair;

  HandlerNotifier({
    this.onConnectionState,
    this.onCandidate,
    this.onSelectedCandidatePair,
  });

  void close([bool graceful = false]) {
    _closed = true;
  }

  void enqueueConnectionState(ConnectionState state) {
    if (_closed) return;
    onConnectionState?.call(state);
  }

  void enqueueCandidate(Candidate candidate) {
    if (_closed) return;
    onCandidate?.call(candidate);
  }

  void enqueueSelectedCandidatePair(CandidatePair pair) {
    if (_closed) return;
    onSelectedCandidatePair?.call(pair);
  }
}
