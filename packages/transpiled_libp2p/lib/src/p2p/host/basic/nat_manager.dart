import 'dart:async';
import 'dart:io';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/network/network.dart';
import '../../net/nat/nat.dart' as nat;

/// Interface for managing NAT devices (UPnP / NAT-PMP) and port mappings.
abstract interface class NatManager {
  /// Returns the external multiaddr mapped for a given local listening [addr].
  Multiaddr? getMapping(Multiaddr addr);

  /// Indicates whether a NAT device (gateway) was discovered on the network.
  bool get hasDiscoveredNat;

  /// Starts the NAT manager background synchronization.
  Future<void> start();

  /// Closes the NAT manager and removes all registered port mappings.
  Future<void> close();
}

/// Interface for a NAT gateway client (UPnP or NAT-PMP).
abstract interface class NatGateway {
  /// Attempts to discover a NAT device on the local network.
  Future<bool> discover();

  /// Retrieves the external IP address from the gateway.
  Future<String?> getExternalIp();

  /// Adds a port mapping on the gateway router.
  Future<int?> addPortMapping({
    required String protocol,
    required int internalPort,
    int? externalPort,
    Duration lifetime = const Duration(hours: 1),
  });

  /// Removes a port mapping from the gateway router.
  Future<void> removePortMapping({
    required String protocol,
    required int internalPort,
  });

  /// Closes the gateway connection and cleans up mappings.
  Future<void> close();
}

/// Default NAT gateway client using the official libp2p NAT traversal (UPnP).
class Libp2pNatGateway implements NatGateway {
  Libp2pNatGateway({this.discoveryTimeout = const Duration(seconds: 4)});

  final Duration discoveryTimeout;
  nat.Nat? _nat;
  InternetAddress? _extIp;

  @override
  Future<bool> discover() async {
    try {
      _nat = await nat.discoverNat(discoveryTimeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> getExternalIp() async {
    if (_nat == null) return null;
    return _extIp?.address;
  }

  @override
  Future<int?> addPortMapping({
    required String protocol,
    required int internalPort,
    int? externalPort,
    Duration lifetime = const Duration(hours: 1),
  }) async {
    if (_nat == null) return null;
    try {
      final extPort = await _nat!.addMapping(protocol, internalPort);
      final mapping = _nat!.getMapping(protocol, internalPort);
      if (mapping != null) {
        _extIp = mapping.$1;
      }
      return extPort;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removePortMapping({
    required String protocol,
    required int internalPort,
  }) async {
    if (_nat == null) return;
    try {
      await _nat!.removeMapping(protocol, internalPort);
    } catch (_) {}
  }

  @override
  Future<void> close() async {
    await _nat?.close();
    _nat = null;
  }
}

/// Default in-memory simulated gateway client for local networks and testing.
class SimulatedNatGateway implements NatGateway {
  SimulatedNatGateway({
    this.externalIp = '203.0.113.1',
    this.shouldDiscover = true,
  });

  final String externalIp;
  final bool shouldDiscover;
  final Map<String, int> _mappings = {};

  @override
  Future<bool> discover() async => shouldDiscover;

  @override
  Future<String?> getExternalIp() async => shouldDiscover ? externalIp : null;

  @override
  Future<int?> addPortMapping({
    required String protocol,
    required int internalPort,
    int? externalPort,
    Duration lifetime = const Duration(hours: 1),
  }) async {
    if (!shouldDiscover) return null;
    final ext = externalPort ?? internalPort;
    _mappings['$protocol:$internalPort'] = ext;
    return ext;
  }

  @override
  Future<void> removePortMapping({
    required String protocol,
    required int internalPort,
  }) async {
    _mappings.remove('$protocol:$internalPort');
  }

  @override
  Future<void> close() async {
    _mappings.clear();
  }
}

/// Standard NAT Manager listening to network changes and maintaining UPnP / NAT-PMP port mappings.
class BasicNatManager implements NatManager {
  BasicNatManager({
    required Network network,
    NatGateway? gateway,
    this.syncInterval = const Duration(seconds: 30),
  }) : _network = network,
       _gateway = gateway ?? Libp2pNatGateway();

  final Network _network;
  final NatGateway _gateway;
  final Duration syncInterval;

  bool _discovered = false;
  bool _closed = false;
  Timer? _syncTimer;

  final Map<String, Multiaddr> _mappings = {};

  @override
  bool get hasDiscoveredNat => _discovered;

  bool get isClosed => _closed;

  @override
  Multiaddr? getMapping(Multiaddr addr) {
    return _mappings[addr.toString()];
  }

  @override
  Future<void> start() async {
    if (_closed) return;
    _discovered = await _gateway.discover();
    if (_discovered) {
      await _sync();
      _syncTimer = Timer.periodic(syncInterval, (_) => _sync());
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _syncTimer?.cancel();
    _syncTimer = null;

    for (final entry in _mappings.entries) {
      try {
        final parsed = Multiaddr.parse(entry.key);
        final port = _extractPort(parsed);
        final proto = _extractProtocol(parsed);
        if (port != null && proto != null) {
          await _gateway.removePortMapping(protocol: proto, internalPort: port);
        }
      } catch (_) {}
    }
    _mappings.clear();
    await _gateway.close();
  }

  Future<void> _sync() async {
    if (!_discovered || _closed) return;

    final externalIp = await _gateway.getExternalIp();
    if (externalIp == null) return;

    final listenAddrs = _network.listenAddresses();
    for (final addr in listenAddrs) {
      final key = addr.toString();
      if (_mappings.containsKey(key)) continue;

      final port = _extractPort(addr);
      final proto = _extractProtocol(addr);
      if (port != null && proto != null) {
        final extPort = await _gateway.addPortMapping(
          protocol: proto,
          internalPort: port,
        );
        if (extPort != null) {
          try {
            final mapped = Multiaddr.parse('/ip4/$externalIp/$proto/$extPort');
            _mappings[key] = mapped;
          } catch (_) {}
        }
      }
    }
  }

  int? _extractPort(Multiaddr addr) {
    for (final c in addr.components) {
      if (c.protocol.name == 'tcp' || c.protocol.name == 'udp') {
        return int.tryParse(c.value);
      }
    }
    return null;
  }

  String? _extractProtocol(Multiaddr addr) {
    for (final p in addr.protocols) {
      if (p.name == 'tcp') return 'tcp';
      if (p.name == 'udp') return 'udp';
    }
    return null;
  }
}
