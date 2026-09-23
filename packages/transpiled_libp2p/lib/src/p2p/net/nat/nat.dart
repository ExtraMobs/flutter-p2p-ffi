// ignore_for_file: public_member_api_docs
import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';

import 'internal/nat/nat.dart' as inat;

/// Default port mapping duration (RFC 6886 recommendations).
const Duration mappingDuration = Duration(minutes: 1);

/// Time a mapping will cache an external address for.
const Duration cacheTime = Duration(seconds: 15);

/// Maximum time to wait for NAT discovery.
const Duration discoveryTimeout = Duration(seconds: 10);

/// Number of consecutive connection failures before triggering rediscovery.
const int rediscoveryThreshold = 3;

/// Signals that no mapping exists for an address.
class NoMappingException implements Exception {
  const NoMappingException();

  @override
  String toString() => 'mapping not established';
}

class _NatEntry {
  const _NatEntry(this.protocol, this.port);

  final String protocol;
  final int port;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _NatEntry &&
          runtimeType == other.runtimeType &&
          protocol == other.protocol &&
          port == other.port;

  @override
  int get hashCode => Object.hash(protocol, port);
}

/// Service that manages address port mappings in NAT gateways.
/// Periodically renews mappings and maintains up-to-date external address.
class Nat {
  Nat(this._nat) {
    _startBackground();
  }

  inat.Nat _nat;
  bool _closed = false;
  int _consecutiveFailures = 0;
  bool _rediscovering = false;

  InternetAddress? _extAddr;
  Timer? _timer;

  final Map<_NatEntry, int> _mappings = {};

  /// Shuts down all port mappings. NAT can no longer be used.
  Future<void> close() async {
    _closed = true;
    _timer?.cancel();
    _timer = null;

    final entries = _mappings.keys.toList();
    for (final e in entries) {
      try {
        await _nat.deletePortMapping(e.protocol, e.port);
      } catch (_) {}
    }
    _mappings.clear();
  }

  /// Returns the mapped external address and port for the given local protocol and port.
  (InternetAddress, int)? getMapping(String protocol, int port) {
    if (_extAddr == null) return null;
    final extPort = _mappings[_NatEntry(protocol, port)];
    if (extPort == null || extPort == 0) return null;
    return (_extAddr!, extPort);
  }

  /// Attempts to construct a mapping on protocol and internal port.
  /// Blocks until initial mapping is established and periodically renews it.
  Future<int> addMapping(String protocol, int port) async {
    if (protocol != 'tcp' && protocol != 'udp') {
      throw ArgumentError('invalid protocol: $protocol');
    }
    if (_closed) throw StateError('NAT is closed');

    final entry = _NatEntry(protocol, port);
    final existing = _mappings[entry];
    if (existing != null && existing > 0) return existing;

    dev.log('Starting maintenance of port mapping for $protocol:$port', name: 'libp2p.nat');
    final extPort = await _establishMapping(protocol, port);
    _mappings[entry] = extPort;
    return extPort;
  }

  /// Removes an active port mapping from the gateway.
  Future<void> removeMapping(String protocol, int port) async {
    if (protocol != 'tcp' && protocol != 'udp') {
      throw ArgumentError('invalid protocol: $protocol');
    }
    final entry = _NatEntry(protocol, port);
    if (_mappings.containsKey(entry)) {
      dev.log('Stopping maintenance of port mapping for $protocol:$port', name: 'libp2p.nat');
      _mappings.remove(entry);
      await _nat.deletePortMapping(protocol, port);
      return;
    }
    throw const NoMappingException();
  }

  void _startBackground() {
    _updateExternalAddr();
    const updateInterval = Duration(seconds: 20); // 1/3 of 60s
    _timer = Timer.periodic(updateInterval, (_) async {
      if (_closed) return;
      await _renewMappings();
      await _updateExternalAddr();
    });
  }

  Future<void> _updateExternalAddr() async {
    try {
      _extAddr = await _nat.getExternalAddress();
    } catch (e) {
      dev.log('Failed to get external address: $e', name: 'libp2p.nat');
    }
  }

  Future<void> _renewMappings() async {
    final entries = _mappings.keys.toList();
    for (final e in entries) {
      if (_closed) return;
      final extPort = await _establishMapping(e.protocol, e.port);
      if (_mappings.containsKey(e)) {
        _mappings[e] = extPort;
      }
    }
  }

  Future<int> _establishMapping(String protocol, int internalPort) async {
    dev.log('Attempting port map: $protocol:$internalPort', name: 'libp2p.nat');
    const comment = 'libp2p';

    try {
      final extPort = await _nat.addPortMapping(
        protocol,
        internalPort,
        comment,
        mappingDuration,
      );
      if (extPort > 0) {
        _consecutiveFailures = 0;
        dev.log('NAT port mapping established: $protocol:$internalPort -> $extPort', name: 'libp2p.nat');
        return extPort;
      }
    } catch (err) {
      dev.log('NAT port mapping error: $err', name: 'libp2p.nat');
      _consecutiveFailures++;
      if (_consecutiveFailures >= rediscoveryThreshold && !_rediscovering) {
        _rediscovering = true;
        unawaited(_rediscoverNat());
      }
    }
    return 0;
  }

  Future<void> _rediscoverNat() async {
    dev.log('NAT rediscovery triggered due to repeated connection failures', name: 'libp2p.nat');
    try {
      final newNat = await inat.discoverGateway(discoveryTimeout);
      _nat = newNat;
      _consecutiveFailures = 0;
      await _updateExternalAddr();
      await _renewMappings();
      dev.log('NAT rediscovery successful', name: 'libp2p.nat');
    } catch (e) {
      dev.log('NAT rediscovery failed: $e', name: 'libp2p.nat');
    } finally {
      _rediscovering = false;
    }
  }
}

/// Discovers a NAT gateway device on the local network and returns an active [Nat] manager.
Future<Nat> discoverNat([
  Duration timeout = discoveryTimeout,
]) async {
  final natInstance = await inat.discoverGateway(timeout);
  return Nat(natInstance);
}
