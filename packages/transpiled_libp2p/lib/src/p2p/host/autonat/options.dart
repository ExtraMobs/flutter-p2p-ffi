// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import '../../../core/host/host.dart';
import '../../../core/network/network.dart';
import 'dialpolicy.dart';
import 'interface.dart';

/// Config holds configurable options for the autonat subsystem.
class AutoNatConfig {
  AutoNatConfig({required this.host}) : dialPolicy = DialPolicy(host: host) {
    applyDefaults();
  }

  final Host host;
  AddrFunc? addressFunc;
  DialPolicy dialPolicy;
  Network? dialer;
  bool forceReachability = false;
  Reachability reachability = Reachability.unknown;

  // client
  Duration bootDelay = const Duration(seconds: 15);
  Duration retryInterval = const Duration(seconds: 90);
  Duration refreshInterval = const Duration(minutes: 15);
  Duration requestTimeout = const Duration(seconds: 30);
  Duration throttlePeerPeriod = const Duration(seconds: 90);

  // server
  Duration dialTimeout = const Duration(seconds: 15);
  int maxPeerAddresses = 16;
  int throttleGlobalMax = 30;
  int throttlePeerMax = 3;
  Duration throttleResetPeriod = const Duration(minutes: 1);
  Duration throttleResetJitter = const Duration(seconds: 15);

  void applyDefaults() {
    bootDelay = const Duration(seconds: 15);
    retryInterval = const Duration(seconds: 90);
    refreshInterval = const Duration(minutes: 15);
    requestTimeout = const Duration(seconds: 30);
    throttlePeerPeriod = const Duration(seconds: 90);

    dialTimeout = const Duration(seconds: 15);
    maxPeerAddresses = 16;
    throttleGlobalMax = 30;
    throttlePeerMax = 3;
    throttleResetPeriod = const Duration(minutes: 1);
    throttleResetJitter = const Duration(seconds: 15);
  }
}

typedef AutoNatOption = void Function(AutoNatConfig config);

/// WithReachability overrides autonat to simply report an over-ridden reachability status.
AutoNatOption withReachability(Reachability reachability) {
  return (AutoNatConfig c) {
    c.forceReachability = true;
    c.reachability = reachability;
  };
}

/// UsingAddresses allows overriding which Addresses the AutoNAT client believes are its own.
AutoNatOption usingAddresses(AddrFunc addrFunc) {
  return (AutoNatConfig c) {
    c.addressFunc = addrFunc;
  };
}

/// WithSchedule configures how aggressively probes will be made to verify the address of the host.
AutoNatOption withSchedule(Duration retryInterval, Duration refreshInterval) {
  return (AutoNatConfig c) {
    c.retryInterval = retryInterval;
    c.refreshInterval = refreshInterval;
  };
}

/// WithoutStartupDelay removes the initial delay the NAT subsystem typically uses as a buffer.
AutoNatOption withoutStartupDelay() {
  return (AutoNatConfig c) {
    c.bootDelay = Duration.zero;
  };
}

/// WithoutThrottling indicates that this autonat service should not place restrictions on peers.
AutoNatOption withoutThrottling() {
  return (AutoNatConfig c) {
    c.throttleGlobalMax = 0;
  };
}

/// WithThrottling specifies how many peers it is willing to help ever interval.
AutoNatOption withThrottling(int amount, Duration interval) {
  return (AutoNatConfig c) {
    c.throttleGlobalMax = amount;
    c.throttleResetPeriod = interval;
    c.throttleResetJitter = interval ~/ 4;
  };
}

/// WithPeerThrottling specifies a limit for the maximum number of IP checks to an individual peer.
AutoNatOption withPeerThrottling(int amount) {
  return (AutoNatConfig c) {
    c.throttlePeerMax = amount;
  };
}

/// EnableService specifies that AutoNAT should run a service.
AutoNatOption enableService(Network dialer) {
  return (AutoNatConfig c) {
    c.dialer = dialer;
  };
}
