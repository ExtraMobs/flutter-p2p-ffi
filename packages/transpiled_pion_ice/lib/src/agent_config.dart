// Package ice AgentConfig implementation.
library;

import 'package:transpiled_pion_logging/transpiled_pion_logging.dart';
import 'package:transpiled_pion_stun/transpiled_pion_stun.dart';
import 'package:transpiled_pion_transport_v4/transpiled_pion_transport_v4.dart';
import 'candidatetype.dart';
import 'networktype.dart';

/// MulticastDnsMode controls mDNS behavior for the ICE agent.
enum MulticastDnsMode { disabled, queryOnly, queryAndGather }

/// AgentConfig collects the arguments to ice.Agent construction.
class AgentConfig {
  final List<StunUri> urls;
  final int portMin;
  final int portMax;
  final String localUfrag;
  final String localPwd;
  final MulticastDnsMode multicastDnsMode;
  final String multicastDnsHostName;
  final Duration disconnectedTimeout;
  final Duration failedTimeout;
  final Duration keepaliveInterval;
  final Duration checkInterval;
  final List<NetworkType> networkTypes;
  final List<CandidateType> candidateTypes;
  final LoggerFactory? loggerFactory;
  final int maxBindingRequests;
  final bool lite;
  final CandidateType nat1To1IpCandidateType;
  final List<String> nat1To1Ips;
  final Duration hostAcceptanceMinWait;
  final Duration srflxAcceptanceMinWait;
  final Duration prflxAcceptanceMinWait;
  final Duration relayAcceptanceMinWait;
  final Duration stunGatherTimeout;
  final dynamic net;
  final bool Function(String)? interfaceFilter;
  final bool Function(String)? ipFilter;
  final bool insecureSkipVerify;
  final dynamic tcpMux;
  final dynamic udpMux;
  final dynamic udpMuxSrflx;
  final dynamic proxyDialer;
  final bool acceptAggressiveNomination;
  final bool includeLoopback;
  final int tcpPriorityOffset;
  final bool disableActiveTcp;
  final dynamic bindingRequestHandler;
  final bool enableUseCandidateCheckPriority;

  const AgentConfig({
    this.urls = const [],
    this.portMin = 0,
    this.portMax = 0,
    this.localUfrag = '',
    this.localPwd = '',
    this.multicastDnsMode = MulticastDnsMode.disabled,
    this.multicastDnsHostName = '',
    this.disconnectedTimeout = const Duration(seconds: 5),
    this.failedTimeout = const Duration(seconds: 25),
    this.keepaliveInterval = const Duration(seconds: 2),
    this.checkInterval = const Duration(milliseconds: 200),
    this.networkTypes = const [NetworkType.udp4, NetworkType.udp6],
    this.candidateTypes = const [
      CandidateType.host,
      CandidateType.serverReflexive,
    ],
    this.loggerFactory,
    this.maxBindingRequests = 7,
    this.lite = true,
    this.nat1To1IpCandidateType = CandidateType.host,
    this.nat1To1Ips = const [],
    this.hostAcceptanceMinWait = Duration.zero,
    this.srflxAcceptanceMinWait = const Duration(milliseconds: 500),
    this.prflxAcceptanceMinWait = const Duration(milliseconds: 1000),
    this.relayAcceptanceMinWait = const Duration(milliseconds: 2000),
    this.stunGatherTimeout = const Duration(seconds: 5),
    this.net,
    this.interfaceFilter,
    this.ipFilter,
    this.insecureSkipVerify = false,
    this.tcpMux,
    this.udpMux,
    this.udpMuxSrflx,
    this.proxyDialer,
    this.acceptAggressiveNomination = false,
    this.includeLoopback = true,
    this.tcpPriorityOffset = 27,
    this.disableActiveTcp = false,
    this.bindingRequestHandler,
    this.enableUseCandidateCheckPriority = false,
  });
}
