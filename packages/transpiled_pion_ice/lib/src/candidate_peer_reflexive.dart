// Package ice CandidatePeerReflexive implementation.
library;

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'candidatetype.dart';
import 'networktype.dart';
import 'tcptype.dart';
import 'candidaterelatedaddress.dart';
import 'candidate.dart';

/// CandidatePeerReflexiveConfig is the config required to create a new CandidatePeerReflexive.
class CandidatePeerReflexiveConfig {
  final String candidateId;
  final String network;
  final String address;
  final Golang.Uint16 port;
  final int component;
  final int priority;
  final String foundation;
  final String relAddr;
  final int relPort;

  const CandidatePeerReflexiveConfig({
    this.candidateId = '',
    this.network = 'udp',
    this.address = '',
    required this.port,
    this.component = 1,
    this.priority = 0,
    this.foundation = '',
    this.relAddr = '',
    this.relPort = 0,
  });
}

/// CandidatePeerReflexive is a candidate of type peer reflexive.
class CandidatePeerReflexive extends CandidateBase {
  final String network;

  CandidatePeerReflexive(CandidatePeerReflexiveConfig config)
    : network = config.network,
      super(
        id: config.candidateId.isNotEmpty
            ? config.candidateId
            : 'prflx_${config.address}_${config.port.toBigInt()}',
        address: config.address,
        port: config.port,
        candidateType: CandidateType.peerReflexive,
        networkType: config.network.contains('6')
            ? (config.network.contains('tcp')
                  ? NetworkType.tcp6
                  : NetworkType.udp6)
            : (config.network.contains('tcp')
                  ? NetworkType.tcp4
                  : NetworkType.udp4),
        component: config.component,
        foundationOverride: config.foundation,
        priorityOverride: config.priority,
        relatedAddress: config.relAddr.isNotEmpty
            ? CandidateRelatedAddress(
                address: config.relAddr,
                port: config.relPort,
              )
            : null,
      );
}
