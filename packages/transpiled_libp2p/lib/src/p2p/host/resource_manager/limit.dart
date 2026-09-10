// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/protocol/protocol.dart';

typedef LimitVal = int;
typedef LimitVal64 = int;

const LimitVal defaultLimit = 0;
const LimitVal unlimited = -1;
const LimitVal blockAllLimit = -2;
const LimitVal64 defaultLimit64 = 0;
const LimitVal64 unlimited64 = -1;
const LimitVal64 blockAllLimit64 = -2;

/// A resource limit, equivalent to go-libp2p's `rcmgr.Limit`.
abstract interface class Limit {
  int get memoryLimit;
  int getStreamLimit(Direction direction);
  int get streamTotalLimit;
  int getConnLimit(Direction direction);
  int get connTotalLimit;
  int get fdLimit;

  int getMemoryLimit() => memoryLimit;
  int getStreamTotalLimit() => streamTotalLimit;
  int getConnTotalLimit() => connTotalLimit;
  int getFdLimit() => fdLimit;
}

/// Concrete limits for streams, connections, file descriptors and memory.
final class BaseLimit implements Limit {
  const BaseLimit({
    this.streams = 0,
    this.streamsInbound = 0,
    this.streamsOutbound = 0,
    this.conns = 0,
    this.connsInbound = 0,
    this.connsOutbound = 0,
    this.fd = 0,
    this.memory = 0,
  });

  final int streams;
  final int streamsInbound;
  final int streamsOutbound;
  final int conns;
  final int connsInbound;
  final int connsOutbound;
  final int fd;
  final int memory;

  static const unlimitedValue = 1 << 60;

  const BaseLimit.unlimited()
    : streams = unlimitedValue,
      streamsInbound = unlimitedValue,
      streamsOutbound = unlimitedValue,
      conns = unlimitedValue,
      connsInbound = unlimitedValue,
      connsOutbound = unlimitedValue,
      fd = unlimitedValue,
      memory = unlimitedValue;

  const BaseLimit.blockAll()
    : streams = 0,
      streamsInbound = 0,
      streamsOutbound = 0,
      conns = 0,
      connsInbound = 0,
      connsOutbound = 0,
      fd = 0,
      memory = 0;

  @override
  int get memoryLimit => memory;

  @override
  int getStreamLimit(Direction direction) =>
      direction == Direction.inbound ? streamsInbound : streamsOutbound;

  @override
  int get streamTotalLimit => streams;

  @override
  int getConnLimit(Direction direction) =>
      direction == Direction.inbound ? connsInbound : connsOutbound;

  @override
  int get connTotalLimit => conns;

  @override
  int get fdLimit => fd;

  @override
  int getMemoryLimit() => memoryLimit;

  @override
  int getStreamTotalLimit() => streamTotalLimit;

  @override
  int getConnTotalLimit() => connTotalLimit;

  @override
  int getFdLimit() => fdLimit;

  BaseLimit apply(BaseLimit other) => BaseLimit(
    streams: streams == 0 ? other.streams : streams,
    streamsInbound: streamsInbound == 0 ? other.streamsInbound : streamsInbound,
    streamsOutbound: streamsOutbound == 0
        ? other.streamsOutbound
        : streamsOutbound,
    conns: conns == 0 ? other.conns : conns,
    connsInbound: connsInbound == 0 ? other.connsInbound : connsInbound,
    connsOutbound: connsOutbound == 0 ? other.connsOutbound : connsOutbound,
    fd: fd == 0 ? other.fd : fd,
    memory: memory == 0 ? other.memory : memory,
  );

  ResourceLimits toResourceLimits() => ResourceLimits(
    streams: _resourceValue(streams),
    streamsInbound: _resourceValue(streamsInbound),
    streamsOutbound: _resourceValue(streamsOutbound),
    conns: _resourceValue(conns),
    connsInbound: _resourceValue(connsInbound),
    connsOutbound: _resourceValue(connsOutbound),
    fd: _resourceValue(fd),
    memory: _resourceValue(memory),
  );

  static int _resourceValue(int value) => value == 0
      ? blockAllLimit
      : value == BaseLimit.unlimitedValue
      ? unlimited
      : value;
}

/// A partially specified set of resource limits.
final class ResourceLimits {
  const ResourceLimits({
    this.streams = defaultLimit,
    this.streamsInbound = defaultLimit,
    this.streamsOutbound = defaultLimit,
    this.conns = defaultLimit,
    this.connsInbound = defaultLimit,
    this.connsOutbound = defaultLimit,
    this.fd = defaultLimit,
    this.memory = defaultLimit64,
  });

  final LimitVal streams;
  final LimitVal streamsInbound;
  final LimitVal streamsOutbound;
  final LimitVal conns;
  final LimitVal connsInbound;
  final LimitVal connsOutbound;
  final LimitVal fd;
  final LimitVal64 memory;

  bool get isDefault =>
      streams == defaultLimit &&
      streamsInbound == defaultLimit &&
      streamsOutbound == defaultLimit &&
      conns == defaultLimit &&
      connsInbound == defaultLimit &&
      connsOutbound == defaultLimit &&
      fd == defaultLimit &&
      memory == defaultLimit64;

  ResourceLimits apply(ResourceLimits other) => ResourceLimits(
    streams: streams == defaultLimit ? other.streams : streams,
    streamsInbound: streamsInbound == defaultLimit
        ? other.streamsInbound
        : streamsInbound,
    streamsOutbound: streamsOutbound == defaultLimit
        ? other.streamsOutbound
        : streamsOutbound,
    conns: conns == defaultLimit ? other.conns : conns,
    connsInbound: connsInbound == defaultLimit
        ? other.connsInbound
        : connsInbound,
    connsOutbound: connsOutbound == defaultLimit
        ? other.connsOutbound
        : connsOutbound,
    fd: fd == defaultLimit ? other.fd : fd,
    memory: memory == defaultLimit64 ? other.memory : memory,
  );

  BaseLimit build(Limit defaults) => BaseLimit(
    streams: _build(streams, defaults.streamTotalLimit),
    streamsInbound: _build(
      streamsInbound,
      defaults.getStreamLimit(Direction.inbound),
    ),
    streamsOutbound: _build(
      streamsOutbound,
      defaults.getStreamLimit(Direction.outbound),
    ),
    conns: _build(conns, defaults.connTotalLimit),
    connsInbound: _build(
      connsInbound,
      defaults.getConnLimit(Direction.inbound),
    ),
    connsOutbound: _build(
      connsOutbound,
      defaults.getConnLimit(Direction.outbound),
    ),
    fd: _build(fd, defaults.fdLimit),
    memory: _build(memory, defaults.memoryLimit),
  );

  static int _build(int value, int fallback) => switch (value) {
    defaultLimit => fallback,
    unlimited => BaseLimit.unlimitedValue,
    blockAllLimit => 0,
    _ => value,
  };
}

/// A limiter supplies limits for each resource scope.
abstract interface class Limiter {
  Limit getSystemLimits();
  Limit getTransientLimits();
  Limit getAllowlistedSystemLimits();
  Limit getAllowlistedTransientLimits();
  Limit getServiceLimits(String service);
  Limit getServicePeerLimits(String service);
  Limit getProtocolLimits(ProtocolId protocol);
  Limit getProtocolPeerLimits(ProtocolId protocol);
  Limit getPeerLimits(PeerId peer);
  Limit getStreamLimits(PeerId peer);
  Limit getConnLimits();
}

/// Fixed limiter with optional per-scope overrides.
final class FixedLimiter implements Limiter {
  FixedLimiter({
    BaseLimit? system,
    BaseLimit? transient,
    BaseLimit? service,
    BaseLimit? protocol,
    BaseLimit? peer,
    BaseLimit? stream,
    BaseLimit? conn,
    Map<String, BaseLimit>? services,
    Map<ProtocolId, BaseLimit>? protocols,
    Map<PeerId, BaseLimit>? peers,
  }) : _system = system ?? const BaseLimit.unlimited(),
       _transient = transient ?? const BaseLimit.unlimited(),
       _service = service ?? const BaseLimit.unlimited(),
       _protocol = protocol ?? const BaseLimit.unlimited(),
       _peer = peer ?? const BaseLimit.unlimited(),
       _stream =
           stream ??
           const BaseLimit(
             streams: 1,
             streamsInbound: 1,
             streamsOutbound: 1,
             memory: 16 << 20,
           ),
       _conn =
           conn ??
           const BaseLimit(
             conns: 1,
             connsInbound: 1,
             connsOutbound: 1,
             fd: 1,
             memory: 32 << 20,
           ),
       _services = services ?? const {},
       _protocols = protocols ?? const {},
       _peers = peers ?? const {};

  final BaseLimit _system;
  final BaseLimit _transient;
  final BaseLimit _service;
  final BaseLimit _protocol;
  final BaseLimit _peer;
  final BaseLimit _stream;
  final BaseLimit _conn;
  final Map<String, BaseLimit> _services;
  final Map<ProtocolId, BaseLimit> _protocols;
  final Map<PeerId, BaseLimit> _peers;

  @override
  Limit getSystemLimits() => _system;
  @override
  Limit getTransientLimits() => _transient;
  @override
  Limit getAllowlistedSystemLimits() => _system;
  @override
  Limit getAllowlistedTransientLimits() => _transient;
  @override
  Limit getServiceLimits(String service) => _services[service] ?? _service;
  @override
  Limit getServicePeerLimits(String service) => _service;
  @override
  Limit getProtocolLimits(ProtocolId protocol) =>
      _protocols[protocol] ?? _protocol;
  @override
  Limit getProtocolPeerLimits(ProtocolId protocol) => _protocol;
  @override
  Limit getPeerLimits(PeerId peer) => _peers[peer] ?? _peer;
  @override
  Limit getStreamLimits(PeerId peer) => _stream;
  @override
  Limit getConnLimits() => _conn;
}
