// Package ice CandidateType implementation.
library;

/// CandidateType represents the type of candidate.
enum CandidateType {
  unspecified,
  host,
  serverReflexive,
  peerReflexive,
  relay;

  String string() {
    switch (this) {
      case CandidateType.host:
        return 'host';
      case CandidateType.serverReflexive:
        return 'srflx';
      case CandidateType.peerReflexive:
        return 'prflx';
      case CandidateType.relay:
        return 'relay';
      case CandidateType.unspecified:
        return 'Unknown candidate type';
    }
  }

  int preference() {
    switch (this) {
      case CandidateType.host:
        return 126;
      case CandidateType.peerReflexive:
        return 110;
      case CandidateType.serverReflexive:
        return 100;
      case CandidateType.relay:
      case CandidateType.unspecified:
        return 0;
    }
  }

  @override
  String toString() => string();
}
