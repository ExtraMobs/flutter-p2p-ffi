// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages, library_private_types_in_public_api
import 'dart:math';

import '../../../core/peer/peer_id.dart';
import '../../../core/protocol/protocol.dart';
import 'limit.dart';

export 'limit.dart';

final class _BaseLimitConfig {
  const _BaseLimitConfig({
    required this.baseLimit,
    required this.baseLimitIncrease,
  });

  final BaseLimit baseLimit;
  final BaseLimitIncrease baseLimitIncrease;
}

/// ScalingLimitConfig is a struct for configuring default limits.
final class ScalingLimitConfig {
  ScalingLimitConfig({
    this.systemBaseLimit = const BaseLimit(),
    this.systemLimitIncrease = const BaseLimitIncrease(),
    this.transientBaseLimit = const BaseLimit(),
    this.transientLimitIncrease = const BaseLimitIncrease(),
    this.allowlistedSystemBaseLimit = const BaseLimit(),
    this.allowlistedSystemLimitIncrease = const BaseLimitIncrease(),
    this.allowlistedTransientBaseLimit = const BaseLimit(),
    this.allowlistedTransientLimitIncrease = const BaseLimitIncrease(),
    this.serviceBaseLimit = const BaseLimit(),
    this.serviceLimitIncrease = const BaseLimitIncrease(),
    Map<String, _BaseLimitConfig>? serviceLimits,
    this.servicePeerBaseLimit = const BaseLimit(),
    this.servicePeerLimitIncrease = const BaseLimitIncrease(),
    Map<String, _BaseLimitConfig>? servicePeerLimits,
    this.protocolBaseLimit = const BaseLimit(),
    this.protocolLimitIncrease = const BaseLimitIncrease(),
    Map<ProtocolId, _BaseLimitConfig>? protocolLimits,
    this.protocolPeerBaseLimit = const BaseLimit(),
    this.protocolPeerLimitIncrease = const BaseLimitIncrease(),
    Map<ProtocolId, _BaseLimitConfig>? protocolPeerLimits,
    this.peerBaseLimit = const BaseLimit(),
    this.peerLimitIncrease = const BaseLimitIncrease(),
    Map<PeerId, _BaseLimitConfig>? peerLimits,
    this.connBaseLimit = const BaseLimit(),
    this.connLimitIncrease = const BaseLimitIncrease(),
    this.streamBaseLimit = const BaseLimit(),
    this.streamLimitIncrease = const BaseLimitIncrease(),
  }) : serviceLimits = serviceLimits != null ? Map.of(serviceLimits) : null,
       servicePeerLimits = servicePeerLimits != null
           ? Map.of(servicePeerLimits)
           : null,
       protocolLimits = protocolLimits != null ? Map.of(protocolLimits) : null,
       protocolPeerLimits = protocolPeerLimits != null
           ? Map.of(protocolPeerLimits)
           : null,
       peerLimits = peerLimits != null ? Map.of(peerLimits) : null;

  BaseLimit systemBaseLimit;
  BaseLimitIncrease systemLimitIncrease;

  BaseLimit transientBaseLimit;
  BaseLimitIncrease transientLimitIncrease;

  BaseLimit allowlistedSystemBaseLimit;
  BaseLimitIncrease allowlistedSystemLimitIncrease;

  BaseLimit allowlistedTransientBaseLimit;
  BaseLimitIncrease allowlistedTransientLimitIncrease;

  BaseLimit serviceBaseLimit;
  BaseLimitIncrease serviceLimitIncrease;
  Map<String, _BaseLimitConfig>? serviceLimits;

  BaseLimit servicePeerBaseLimit;
  BaseLimitIncrease servicePeerLimitIncrease;
  Map<String, _BaseLimitConfig>? servicePeerLimits;

  BaseLimit protocolBaseLimit;
  BaseLimitIncrease protocolLimitIncrease;
  Map<ProtocolId, _BaseLimitConfig>? protocolLimits;

  BaseLimit protocolPeerBaseLimit;
  BaseLimitIncrease protocolPeerLimitIncrease;
  Map<ProtocolId, _BaseLimitConfig>? protocolPeerLimits;

  BaseLimit peerBaseLimit;
  BaseLimitIncrease peerLimitIncrease;
  Map<PeerId, _BaseLimitConfig>? peerLimits;

  BaseLimit connBaseLimit;
  BaseLimitIncrease connLimitIncrease;

  BaseLimit streamBaseLimit;
  BaseLimitIncrease streamLimitIncrease;

  void addServiceLimit(String svc, BaseLimit base, BaseLimitIncrease inc) {
    serviceLimits ??= <String, _BaseLimitConfig>{};
    serviceLimits![svc] = _BaseLimitConfig(
      baseLimit: base,
      baseLimitIncrease: inc,
    );
  }

  void addProtocolLimit(
    ProtocolId proto,
    BaseLimit base,
    BaseLimitIncrease inc,
  ) {
    protocolLimits ??= <ProtocolId, _BaseLimitConfig>{};
    protocolLimits![proto] = _BaseLimitConfig(
      baseLimit: base,
      baseLimitIncrease: inc,
    );
  }

  void addPeerLimit(PeerId p, BaseLimit base, BaseLimitIncrease inc) {
    peerLimits ??= <PeerId, _BaseLimitConfig>{};
    peerLimits![p] = _BaseLimitConfig(baseLimit: base, baseLimitIncrease: inc);
  }

  void addServicePeerLimit(String svc, BaseLimit base, BaseLimitIncrease inc) {
    servicePeerLimits ??= <String, _BaseLimitConfig>{};
    servicePeerLimits![svc] = _BaseLimitConfig(
      baseLimit: base,
      baseLimitIncrease: inc,
    );
  }

  void addProtocolPeerLimit(
    ProtocolId proto,
    BaseLimit base,
    BaseLimitIncrease inc,
  ) {
    protocolPeerLimits ??= <ProtocolId, _BaseLimitConfig>{};
    protocolPeerLimits![proto] = _BaseLimitConfig(
      baseLimit: base,
      baseLimitIncrease: inc,
    );
  }

  ConcreteLimitConfig scale(int memory, int numFD) {
    final lc = ConcreteLimitConfig(
      system: _scale(systemBaseLimit, systemLimitIncrease, memory, numFD),
      transient: _scale(
        transientBaseLimit,
        transientLimitIncrease,
        memory,
        numFD,
      ),
      allowlistedSystem: _scale(
        allowlistedSystemBaseLimit,
        allowlistedSystemLimitIncrease,
        memory,
        numFD,
      ),
      allowlistedTransient: _scale(
        allowlistedTransientBaseLimit,
        allowlistedTransientLimitIncrease,
        memory,
        numFD,
      ),
      serviceDefault: _scale(
        serviceBaseLimit,
        serviceLimitIncrease,
        memory,
        numFD,
      ),
      servicePeerDefault: _scale(
        servicePeerBaseLimit,
        servicePeerLimitIncrease,
        memory,
        numFD,
      ),
      protocolDefault: _scale(
        protocolBaseLimit,
        protocolLimitIncrease,
        memory,
        numFD,
      ),
      protocolPeerDefault: _scale(
        protocolPeerBaseLimit,
        protocolPeerLimitIncrease,
        memory,
        numFD,
      ),
      peerDefault: _scale(peerBaseLimit, peerLimitIncrease, memory, numFD),
      conn: _scale(connBaseLimit, connLimitIncrease, memory, numFD),
      stream: _scale(streamBaseLimit, connLimitIncrease, memory, numFD),
    );
    if (serviceLimits != null) {
      final map = <String, BaseLimit>{};
      for (final entry in serviceLimits!.entries) {
        map[entry.key] = _scale(
          entry.value.baseLimit,
          entry.value.baseLimitIncrease,
          memory,
          numFD,
        );
      }
      lc.service = map;
    }
    if (protocolLimits != null) {
      final map = <ProtocolId, BaseLimit>{};
      for (final entry in protocolLimits!.entries) {
        map[entry.key] = _scale(
          entry.value.baseLimit,
          entry.value.baseLimitIncrease,
          memory,
          numFD,
        );
      }
      lc.protocol = map;
    }
    if (peerLimits != null) {
      final map = <PeerId, BaseLimit>{};
      for (final entry in peerLimits!.entries) {
        map[entry.key] = _scale(
          entry.value.baseLimit,
          entry.value.baseLimitIncrease,
          memory,
          numFD,
        );
      }
      lc.peer = map;
    }
    if (servicePeerLimits != null) {
      final map = <String, BaseLimit>{};
      for (final entry in servicePeerLimits!.entries) {
        map[entry.key] = _scale(
          entry.value.baseLimit,
          entry.value.baseLimitIncrease,
          memory,
          numFD,
        );
      }
      lc.servicePeer = map;
    }
    if (protocolPeerLimits != null) {
      final map = <ProtocolId, BaseLimit>{};
      for (final entry in protocolPeerLimits!.entries) {
        map[entry.key] = _scale(
          entry.value.baseLimit,
          entry.value.baseLimitIncrease,
          memory,
          numFD,
        );
      }
      lc.protocolPeer = map;
    }
    return lc;
  }

  ConcreteLimitConfig autoScale() {
    const defaultMemory = 1024 * 1024 * 1024;
    const defaultNumFd = 1024;
    return scale(defaultMemory, defaultNumFd);
  }
}

BaseLimit _scale(BaseLimit base, BaseLimitIncrease inc, int memory, int numFD) {
  var mebibytesAvailable = 0;
  if (memory > (128 << 20)) {
    mebibytesAvailable = memory >> 20;
  }
  var fd = base.fd;
  if (inc.fdFraction > 0 && numFD > 0) {
    final calculated = (inc.fdFraction * numFD).toInt();
    fd = max(calculated, base.fd);
  }
  return BaseLimit(
    streamsInbound:
        base.streamsInbound + ((inc.streamsInbound * mebibytesAvailable) >> 10),
    streamsOutbound:
        base.streamsOutbound +
        ((inc.streamsOutbound * mebibytesAvailable) >> 10),
    streams: base.streams + ((inc.streams * mebibytesAvailable) >> 10),
    connsInbound:
        base.connsInbound + ((inc.connsInbound * mebibytesAvailable) >> 10),
    connsOutbound:
        base.connsOutbound + ((inc.connsOutbound * mebibytesAvailable) >> 10),
    conns: base.conns + ((inc.conns * mebibytesAvailable) >> 10),
    memory: base.memory + ((inc.memory * mebibytesAvailable) >> 10),
    fd: fd,
  );
}

/// PartialLimitConfig holds partially configured resource limits.
final class PartialLimitConfig {
  PartialLimitConfig({
    this.system = const ResourceLimits(),
    this.transient = const ResourceLimits(),
    this.allowlistedSystem = const ResourceLimits(),
    this.allowlistedTransient = const ResourceLimits(),
    this.serviceDefault = const ResourceLimits(),
    Map<String, ResourceLimits>? service,
    this.servicePeerDefault = const ResourceLimits(),
    Map<String, ResourceLimits>? servicePeer,
    this.protocolDefault = const ResourceLimits(),
    Map<ProtocolId, ResourceLimits>? protocol,
    this.protocolPeerDefault = const ResourceLimits(),
    Map<ProtocolId, ResourceLimits>? protocolPeer,
    this.peerDefault = const ResourceLimits(),
    Map<PeerId, ResourceLimits>? peer,
    this.conn = const ResourceLimits(),
    this.stream = const ResourceLimits(),
  }) : service = service != null ? Map.of(service) : null,
       servicePeer = servicePeer != null ? Map.of(servicePeer) : null,
       protocol = protocol != null ? Map.of(protocol) : null,
       protocolPeer = protocolPeer != null ? Map.of(protocolPeer) : null,
       peer = peer != null ? Map.of(peer) : null;

  ResourceLimits system;
  ResourceLimits transient;
  ResourceLimits allowlistedSystem;
  ResourceLimits allowlistedTransient;
  ResourceLimits serviceDefault;
  Map<String, ResourceLimits>? service;
  ResourceLimits servicePeerDefault;
  Map<String, ResourceLimits>? servicePeer;
  ResourceLimits protocolDefault;
  Map<ProtocolId, ResourceLimits>? protocol;
  ResourceLimits protocolPeerDefault;
  Map<ProtocolId, ResourceLimits>? protocolPeer;
  ResourceLimits peerDefault;
  Map<PeerId, ResourceLimits>? peer;
  ResourceLimits conn;
  ResourceLimits stream;

  void apply(PartialLimitConfig other) {
    system = system.apply(other.system);
    transient = transient.apply(other.transient);
    allowlistedSystem = allowlistedSystem.apply(other.allowlistedSystem);
    allowlistedTransient = allowlistedTransient.apply(
      other.allowlistedTransient,
    );
    serviceDefault = serviceDefault.apply(other.serviceDefault);
    servicePeerDefault = servicePeerDefault.apply(other.servicePeerDefault);
    protocolDefault = protocolDefault.apply(other.protocolDefault);
    protocolPeerDefault = protocolPeerDefault.apply(other.protocolPeerDefault);
    peerDefault = peerDefault.apply(other.peerDefault);
    conn = conn.apply(other.conn);
    stream = stream.apply(other.stream);

    service = _applyResourceLimitsMap(service, other.service, serviceDefault);
    servicePeer = _applyResourceLimitsMap(
      servicePeer,
      other.servicePeer,
      servicePeerDefault,
    );
    protocol = _applyResourceLimitsMap(
      protocol,
      other.protocol,
      protocolDefault,
    );
    protocolPeer = _applyResourceLimitsMap(
      protocolPeer,
      other.protocolPeer,
      protocolPeerDefault,
    );
    peer = _applyResourceLimitsMap(peer, other.peer, peerDefault);
  }

  ConcreteLimitConfig build(ConcreteLimitConfig defaults) {
    return ConcreteLimitConfig(
      system: system.build(defaults.system),
      transient: transient.build(defaults.transient),
      allowlistedSystem: allowlistedSystem.build(defaults.allowlistedSystem),
      allowlistedTransient: allowlistedTransient.build(
        defaults.allowlistedTransient,
      ),
      serviceDefault: serviceDefault.build(defaults.serviceDefault),
      servicePeerDefault: servicePeerDefault.build(defaults.servicePeerDefault),
      protocolDefault: protocolDefault.build(defaults.protocolDefault),
      protocolPeerDefault: protocolPeerDefault.build(
        defaults.protocolPeerDefault,
      ),
      peerDefault: peerDefault.build(defaults.peerDefault),
      conn: conn.build(defaults.conn),
      stream: stream.build(defaults.stream),
      service: _buildMapWithDefault(
        service,
        defaults.service,
        serviceDefault.build(defaults.serviceDefault),
      ),
      servicePeer: _buildMapWithDefault(
        servicePeer,
        defaults.servicePeer,
        servicePeerDefault.build(defaults.servicePeerDefault),
      ),
      protocol: _buildMapWithDefault(
        protocol,
        defaults.protocol,
        protocolDefault.build(defaults.protocolDefault),
      ),
      protocolPeer: _buildMapWithDefault(
        protocolPeer,
        defaults.protocolPeer,
        protocolPeerDefault.build(defaults.protocolPeerDefault),
      ),
      peer: _buildMapWithDefault(
        peer,
        defaults.peer,
        peerDefault.build(defaults.peerDefault),
      ),
    );
  }
}

Map<K, ResourceLimits>? _applyResourceLimitsMap<K>(
  Map<K, ResourceLimits>? current,
  Map<K, ResourceLimits>? other,
  ResourceLimits fallbackDefault,
) {
  if (current == null && other == null) return null;
  final res = <K, ResourceLimits>{};
  if (current != null) {
    for (final entry in current.entries) {
      final otherVal = other != null
          ? (other[entry.key] ?? fallbackDefault)
          : fallbackDefault;
      res[entry.key] = entry.value.apply(otherVal);
    }
  }
  if (other != null) {
    for (final entry in other.entries) {
      if (!res.containsKey(entry.key)) {
        res[entry.key] = entry.value;
      }
    }
  }
  return res;
}

Map<K, BaseLimit>? _buildMapWithDefault<K>(
  Map<K, ResourceLimits>? definedLimits,
  Map<K, BaseLimit>? defaults,
  BaseLimit fallbackDefault,
) {
  if (definedLimits == null && defaults == null) {
    return null;
  }
  final out = <K, BaseLimit>{};
  if (defaults != null) {
    out.addAll(defaults);
  }
  if (definedLimits != null) {
    for (final entry in definedLimits.entries) {
      final defaultForKey = out[entry.key] ?? fallbackDefault;
      out[entry.key] = entry.value.build(defaultForKey);
    }
  }
  return out;
}

/// ConcreteLimitConfig represents fully resolved concrete limits.
final class ConcreteLimitConfig {
  ConcreteLimitConfig({
    required this.system,
    required this.transient,
    required this.allowlistedSystem,
    required this.allowlistedTransient,
    required this.serviceDefault,
    Map<String, BaseLimit>? service,
    required this.servicePeerDefault,
    Map<String, BaseLimit>? servicePeer,
    required this.protocolDefault,
    Map<ProtocolId, BaseLimit>? protocol,
    required this.protocolPeerDefault,
    Map<ProtocolId, BaseLimit>? protocolPeer,
    required this.peerDefault,
    Map<PeerId, BaseLimit>? peer,
    required this.conn,
    required this.stream,
  }) : service = service != null ? Map.of(service) : null,
       servicePeer = servicePeer != null ? Map.of(servicePeer) : null,
       protocol = protocol != null ? Map.of(protocol) : null,
       protocolPeer = protocolPeer != null ? Map.of(protocolPeer) : null,
       peer = peer != null ? Map.of(peer) : null;

  BaseLimit system;
  BaseLimit transient;
  BaseLimit allowlistedSystem;
  BaseLimit allowlistedTransient;
  BaseLimit serviceDefault;
  Map<String, BaseLimit>? service;
  BaseLimit servicePeerDefault;
  Map<String, BaseLimit>? servicePeer;
  BaseLimit protocolDefault;
  Map<ProtocolId, BaseLimit>? protocol;
  BaseLimit protocolPeerDefault;
  Map<ProtocolId, BaseLimit>? protocolPeer;
  BaseLimit peerDefault;
  Map<PeerId, BaseLimit>? peer;
  BaseLimit conn;
  BaseLimit stream;

  PartialLimitConfig toPartialLimitConfig() {
    return PartialLimitConfig(
      system: system.toResourceLimits(),
      transient: transient.toResourceLimits(),
      allowlistedSystem: allowlistedSystem.toResourceLimits(),
      allowlistedTransient: allowlistedTransient.toResourceLimits(),
      serviceDefault: serviceDefault.toResourceLimits(),
      service: _resourceLimitsMapFromBaseLimitMap(service),
      servicePeerDefault: servicePeerDefault.toResourceLimits(),
      servicePeer: _resourceLimitsMapFromBaseLimitMap(servicePeer),
      protocolDefault: protocolDefault.toResourceLimits(),
      protocol: _resourceLimitsMapFromBaseLimitMap(protocol),
      protocolPeerDefault: protocolPeerDefault.toResourceLimits(),
      protocolPeer: _resourceLimitsMapFromBaseLimitMap(protocolPeer),
      peerDefault: peerDefault.toResourceLimits(),
      peer: _resourceLimitsMapFromBaseLimitMap(peer),
      conn: conn.toResourceLimits(),
      stream: stream.toResourceLimits(),
    );
  }
}

Map<K, ResourceLimits>? _resourceLimitsMapFromBaseLimitMap<K>(
  Map<K, BaseLimit>? baseLimitMap,
) {
  if (baseLimitMap == null) return null;
  final out = <K, ResourceLimits>{};
  for (final entry in baseLimitMap.entries) {
    out[entry.key] = entry.value.toResourceLimits();
  }
  return out;
}

/// DefaultLimits are the limits used by default limiter constructors.
final defaultLimits = ScalingLimitConfig(
  systemBaseLimit: const BaseLimit(
    connsInbound: 64,
    connsOutbound: 128,
    conns: 128,
    streamsInbound: 64 * 16,
    streamsOutbound: 128 * 16,
    streams: 128 * 16,
    memory: 128 << 20,
    fd: 256,
  ),
  systemLimitIncrease: const BaseLimitIncrease(
    connsInbound: 64,
    connsOutbound: 128,
    conns: 128,
    streamsInbound: 64 * 16,
    streamsOutbound: 128 * 16,
    streams: 128 * 16,
    memory: 1 << 30,
    fdFraction: 1.0,
  ),
  transientBaseLimit: const BaseLimit(
    connsInbound: 32,
    connsOutbound: 64,
    conns: 64,
    streamsInbound: 128,
    streamsOutbound: 256,
    streams: 256,
    memory: 32 << 20,
    fd: 64,
  ),
  transientLimitIncrease: const BaseLimitIncrease(
    connsInbound: 16,
    connsOutbound: 32,
    conns: 32,
    streamsInbound: 128,
    streamsOutbound: 256,
    streams: 256,
    memory: 128 << 20,
    fdFraction: 0.25,
  ),
  allowlistedSystemBaseLimit: const BaseLimit(
    connsInbound: 64,
    connsOutbound: 128,
    conns: 128,
    streamsInbound: 64 * 16,
    streamsOutbound: 128 * 16,
    streams: 128 * 16,
    memory: 128 << 20,
    fd: 256,
  ),
  allowlistedSystemLimitIncrease: const BaseLimitIncrease(
    connsInbound: 64,
    connsOutbound: 128,
    conns: 128,
    streamsInbound: 64 * 16,
    streamsOutbound: 128 * 16,
    streams: 128 * 16,
    memory: 1 << 30,
    fdFraction: 1.0,
  ),
  allowlistedTransientBaseLimit: const BaseLimit(
    connsInbound: 32,
    connsOutbound: 64,
    conns: 64,
    streamsInbound: 128,
    streamsOutbound: 256,
    streams: 256,
    memory: 32 << 20,
    fd: 64,
  ),
  allowlistedTransientLimitIncrease: const BaseLimitIncrease(
    connsInbound: 16,
    connsOutbound: 32,
    conns: 32,
    streamsInbound: 128,
    streamsOutbound: 256,
    streams: 256,
    memory: 128 << 20,
    fdFraction: 0.25,
  ),
  serviceBaseLimit: const BaseLimit(
    streamsInbound: 1024,
    streamsOutbound: 4096,
    streams: 4096,
    memory: 64 << 20,
  ),
  serviceLimitIncrease: const BaseLimitIncrease(
    streamsInbound: 512,
    streamsOutbound: 2048,
    streams: 2048,
    memory: 128 << 20,
  ),
  servicePeerBaseLimit: const BaseLimit(
    streamsInbound: 128,
    streamsOutbound: 256,
    streams: 256,
    memory: 16 << 20,
  ),
  servicePeerLimitIncrease: const BaseLimitIncrease(
    streamsInbound: 4,
    streamsOutbound: 8,
    streams: 8,
    memory: 4 << 20,
  ),
  protocolBaseLimit: const BaseLimit(
    streamsInbound: 512,
    streamsOutbound: 2048,
    streams: 2048,
    memory: 64 << 20,
  ),
  protocolLimitIncrease: const BaseLimitIncrease(
    streamsInbound: 256,
    streamsOutbound: 512,
    streams: 512,
    memory: 164 << 20,
  ),
  protocolPeerBaseLimit: const BaseLimit(
    streamsInbound: 64,
    streamsOutbound: 128,
    streams: 256,
    memory: 16 << 20,
  ),
  protocolPeerLimitIncrease: const BaseLimitIncrease(
    streamsInbound: 4,
    streamsOutbound: 8,
    streams: 16,
    memory: 4,
  ),
  peerBaseLimit: const BaseLimit(
    connsInbound: 8,
    connsOutbound: 8,
    conns: 8,
    streamsInbound: 256,
    streamsOutbound: 512,
    streams: 512,
    memory: 64 << 20,
    fd: 4,
  ),
  peerLimitIncrease: const BaseLimitIncrease(
    streamsInbound: 128,
    streamsOutbound: 256,
    streams: 256,
    memory: 128 << 20,
    fdFraction: 1.0 / 64,
  ),
  connBaseLimit: const BaseLimit(
    connsInbound: 1,
    connsOutbound: 1,
    conns: 1,
    fd: 1,
    memory: 32 << 20,
  ),
  connLimitIncrease: const BaseLimitIncrease(),
  streamBaseLimit: const BaseLimit(
    streamsInbound: 1,
    streamsOutbound: 1,
    streams: 1,
    memory: 16 << 20,
  ),
  streamLimitIncrease: const BaseLimitIncrease(),
);

const infiniteBaseLimit = BaseLimit(
  streams: BaseLimit.unlimitedValue,
  streamsInbound: BaseLimit.unlimitedValue,
  streamsOutbound: BaseLimit.unlimitedValue,
  conns: BaseLimit.unlimitedValue,
  connsInbound: BaseLimit.unlimitedValue,
  connsOutbound: BaseLimit.unlimitedValue,
  fd: BaseLimit.unlimitedValue,
  memory: BaseLimit.unlimitedValue,
);

final infiniteLimits = ConcreteLimitConfig(
  system: infiniteBaseLimit,
  transient: infiniteBaseLimit,
  allowlistedSystem: infiniteBaseLimit,
  allowlistedTransient: infiniteBaseLimit,
  serviceDefault: infiniteBaseLimit,
  servicePeerDefault: infiniteBaseLimit,
  protocolDefault: infiniteBaseLimit,
  protocolPeerDefault: infiniteBaseLimit,
  peerDefault: infiniteBaseLimit,
  conn: infiniteBaseLimit,
  stream: infiniteBaseLimit,
);
