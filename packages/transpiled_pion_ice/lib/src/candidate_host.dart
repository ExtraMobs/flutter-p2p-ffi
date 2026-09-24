// Package ice CandidateHost implementation.
library;

import 'package:boilerplate/fixed_types/golang.dart' as Golang;
import 'candidatetype.dart';
import 'networktype.dart';
import 'tcptype.dart';
import 'candidate.dart';

/// CandidateHostConfig is the config required to create a new CandidateHost.
class CandidateHostConfig {
  final String candidateId;
  final String network;
  final String address;
  final Golang.Uint16 port;
  final int component;
  final int priority;
  final String foundation;
  final TcpType tcpType;
  final bool isLocationTracked;

  const CandidateHostConfig({
    this.candidateId = '',
    this.network = 'udp',
    this.address = '',
    required this.port,
    this.component = 1,
    this.priority = 0,
    this.foundation = '',
    this.tcpType = TcpType.unspecified,
    this.isLocationTracked = false,
  });
}

/// CandidateHost is a candidate of type host.
class CandidateHost extends CandidateBase {
  final String network;
  final bool isLocationTracked;

  CandidateHost(CandidateHostConfig config)
    : network = config.network,
      isLocationTracked = config.isLocationTracked,
      super(
        id: config.candidateId.isNotEmpty
            ? config.candidateId
            : 'host_${config.address}_${config.port.toBigInt()}',
        address: config.address,
        port: config.port,
        candidateType: CandidateType.host,
        networkType: config.network.contains('6')
            ? (config.network.contains('tcp')
                  ? NetworkType.tcp6
                  : NetworkType.udp6)
            : (config.network.contains('tcp')
                  ? NetworkType.tcp4
                  : NetworkType.udp4),
        component: config.component,
        tcpType: config.tcpType,
        foundationOverride: config.foundation,
        priorityOverride: config.priority,
      );
}
