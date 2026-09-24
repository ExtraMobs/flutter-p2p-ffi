// Package ice CandidatePairState implementation.
library;

/// CandidatePairState represents the state of a CandidatePair.
enum CandidatePairState {
  waiting,
  inProgress,
  succeeded,
  failed;

  String string() {
    switch (this) {
      case CandidatePairState.waiting:
        return 'waiting';
      case CandidatePairState.inProgress:
        return 'in-progress';
      case CandidatePairState.succeeded:
        return 'succeeded';
      case CandidatePairState.failed:
        return 'failed';
    }
  }

  @override
  String toString() => string();
}
