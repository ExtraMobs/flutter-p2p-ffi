// Package ice agent stats structures.
library;

import 'candidate_pair_state.dart';
import 'candidatetype.dart';
import 'networktype.dart';

/// CandidatePairStats contains ICE candidate pair statistics.
class CandidatePairStats {
  final DateTime timestamp;
  final String localCandidateId;
  final String remoteCandidateId;
  final CandidatePairState state;
  final bool nominated;
  final DateTime? firstRequestTimestamp;
  final DateTime? lastRequestTimestamp;
  final DateTime? firstResponseTimestamp;
  final DateTime? lastResponseTimestamp;
  final double totalRoundTripTime;
  final double currentRoundTripTime;
  final int requestsReceived;
  final int requestsSent;
  final int responsesReceived;
  final int responsesSent;

  CandidatePairStats({
    required this.timestamp,
    required this.localCandidateId,
    required this.remoteCandidateId,
    required this.state,
    required this.nominated,
    this.firstRequestTimestamp,
    this.lastRequestTimestamp,
    this.firstResponseTimestamp,
    this.lastResponseTimestamp,
    this.totalRoundTripTime = 0.0,
    this.currentRoundTripTime = 0.0,
    this.requestsReceived = 0,
    this.requestsSent = 0,
    this.responsesReceived = 0,
    this.responsesSent = 0,
  });
}

/// CandidateStats contains ICE candidate statistics.
class CandidateStats {
  final DateTime timestamp;
  final String id;
  final NetworkType networkType;
  final String ip;
  final int port;
  final CandidateType candidateType;
  final int priority;

  CandidateStats({
    required this.timestamp,
    required this.id,
    required this.networkType,
    required this.ip,
    required this.port,
    required this.candidateType,
    required this.priority,
  });
}
