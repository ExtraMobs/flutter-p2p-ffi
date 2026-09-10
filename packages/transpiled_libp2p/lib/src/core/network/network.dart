// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
// ignore_for_file: duplicate_ignore, public_member_api_docs

import 'dart:typed_data';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../crypto/key_types.dart';
import '../peer/peer_id.dart';
import '../protocol/protocol.dart';

const messageSizeMax = 1 << 22;

/// Metadata propagated with dialing and stream-opening operations.
///
/// This is the narrow Dart equivalent of the `context.Context` values owned
/// by go-libp2p's `core/network/context.go`. It deliberately carries no
/// cancellation mechanism: callers use normal Future/Stream cancellation.
final class NetworkContext {
  const NetworkContext({
    this.forceDirectDialReason,
    this.simultaneousConnectClientReason,
    this.simultaneousConnectServerReason,
    this.noDialReason,
    this.dialPeerTimeout,
    this.allowLimitedConnReason,
    this.connManagementScope,
  });

  static const empty = NetworkContext();

  final String? forceDirectDialReason;
  final String? simultaneousConnectClientReason;
  final String? simultaneousConnectServerReason;
  final String? noDialReason;
  final Duration? dialPeerTimeout;
  final String? allowLimitedConnReason;
  final ConnManagementScope? connManagementScope;

  NetworkContext copyWith({
    String? forceDirectDialReason,
    String? simultaneousConnectClientReason,
    String? simultaneousConnectServerReason,
    String? noDialReason,
    Duration? dialPeerTimeout,
    String? allowLimitedConnReason,
    ConnManagementScope? connManagementScope,
  }) => NetworkContext(
    forceDirectDialReason: forceDirectDialReason ?? this.forceDirectDialReason,
    simultaneousConnectClientReason:
        simultaneousConnectClientReason ?? this.simultaneousConnectClientReason,
    simultaneousConnectServerReason:
        simultaneousConnectServerReason ?? this.simultaneousConnectServerReason,
    noDialReason: noDialReason ?? this.noDialReason,
    dialPeerTimeout: dialPeerTimeout ?? this.dialPeerTimeout,
    allowLimitedConnReason:
        allowLimitedConnReason ?? this.allowLimitedConnReason,
    connManagementScope: connManagementScope ?? this.connManagementScope,
  );
}

/// Default timeout for one [Dialer.dialPeer] call.
Duration dialPeerTimeout = const Duration(seconds: 60);

NetworkContext withForceDirectDial(NetworkContext context, String reason) =>
    context.copyWith(forceDirectDialReason: reason);

(bool forceDirect, String reason) getForceDirectDial(NetworkContext context) {
  final reason = context.forceDirectDialReason;
  return reason == null ? (false, '') : (true, reason);
}

NetworkContext withSimultaneousConnect(
  NetworkContext context,
  bool isClient,
  String reason,
) => isClient
    ? context.copyWith(simultaneousConnectClientReason: reason)
    : context.copyWith(simultaneousConnectServerReason: reason);

(bool simultaneousConnect, bool isClient, String reason) getSimultaneousConnect(
  NetworkContext context,
) {
  final clientReason = context.simultaneousConnectClientReason;
  if (clientReason != null) return (true, true, clientReason);
  final serverReason = context.simultaneousConnectServerReason;
  return serverReason == null
      ? (false, false, '')
      : (true, false, serverReason);
}

NetworkContext withNoDial(NetworkContext context, String reason) =>
    context.copyWith(noDialReason: reason);

(bool noDial, String reason) getNoDial(NetworkContext context) {
  final reason = context.noDialReason;
  return reason == null ? (false, '') : (true, reason);
}

Duration getDialPeerTimeout(NetworkContext context) =>
    context.dialPeerTimeout ?? dialPeerTimeout;

NetworkContext withDialPeerTimeout(NetworkContext context, Duration timeout) =>
    context.copyWith(dialPeerTimeout: timeout);

NetworkContext withAllowLimitedConn(NetworkContext context, String reason) =>
    context.copyWith(allowLimitedConnReason: reason);

@Deprecated('Use withAllowLimitedConn instead.')
NetworkContext withUseTransient(NetworkContext context, String reason) =>
    withAllowLimitedConn(context, reason);

(bool allowLimitedConn, String reason) getAllowLimitedConn(
  NetworkContext context,
) {
  final reason = context.allowLimitedConnReason;
  return reason == null ? (false, '') : (true, reason);
}

@Deprecated('Use getAllowLimitedConn instead.')
(bool useTransient, String reason) getUseTransient(NetworkContext context) =>
    getAllowLimitedConn(context);

enum Direction { unknown, inbound, outbound }

extension DirectionText on Direction {
  String get text => switch (this) {
    Direction.unknown => 'Unknown',
    Direction.inbound => 'Inbound',
    Direction.outbound => 'Outbound',
  };
}

enum Connectedness {
  notConnected,
  connected,
  canConnect,
  cannotConnect,
  limited,
}

extension ConnectednessText on Connectedness {
  String get text => switch (this) {
    Connectedness.notConnected => 'NotConnected',
    Connectedness.connected => 'Connected',
    Connectedness.canConnect => 'CanConnect',
    Connectedness.cannotConnect => 'CannotConnect',
    Connectedness.limited => 'Limited',
  };
}

enum Reachability { unknown, public_, private_ }

extension ReachabilityText on Reachability {
  String get text => switch (this) {
    Reachability.unknown => 'Unknown',
    Reachability.public_ => 'Public',
    Reachability.private_ => 'Private',
  };
}

/// Type of NAT device discovered by libp2p's NAT classification.
enum NatDeviceType { unknown, endpointIndependent, endpointDependent }

extension NatDeviceTypeText on NatDeviceType {
  String get text => switch (this) {
    NatDeviceType.unknown => 'Unknown',
    NatDeviceType.endpointIndependent => 'Endpoint Independent',
    NatDeviceType.endpointDependent => 'Endpoint Dependent',
  };
}

@Deprecated('Use NatDeviceType.endpointIndependent instead.')
const natDeviceTypeCone = NatDeviceType.endpointIndependent;
@Deprecated('Use NatDeviceType.endpointDependent instead.')
const natDeviceTypeSymmetric = NatDeviceType.endpointDependent;

/// Transport protocol for which a NAT type was determined.
enum NatTransportProtocol { udp, tcp }

extension NatTransportProtocolText on NatTransportProtocol {
  String get text => switch (this) {
    NatTransportProtocol.udp => 'UDP',
    NatTransportProtocol.tcp => 'TCP',
  };
}

/// Connection close code carried by transports that support it.
typedef ConnErrorCode = int;

const connNoError = 0;
const connProtocolNegotiationFailed = 0x1000;
const connResourceLimitExceeded = 0x1001;
const connRateLimited = 0x1002;
const connProtocolViolation = 0x1003;
const connSupplanted = 0x1004;
const connGarbageCollected = 0x1005;
const connShutdown = 0x1006;
const connGated = 0x1007;
const connCodeOutOfRange = 0x1008;

/// Stream reset code carried by transports that support it.
typedef StreamErrorCode = int;

const streamNoError = 0;
const streamProtocolNegotiationFailed = 0x1001;
const streamResourceLimitExceeded = 0x1002;
const streamRateLimited = 0x1003;
const streamProtocolViolation = 0x1004;
const streamSupplanted = 0x1005;
const streamGarbageCollected = 0x1006;
const streamShutdown = 0x1007;
const streamGated = 0x1008;
const streamCodeOutOfRange = 0x1009;

/// Thrown when reading or writing a reset stream.
class StreamResetException implements Exception {
  const StreamResetException();
  @override
  String toString() => 'stream reset';
}

const errReset = StreamResetException();

/// Details of a stream reset, equivalent to Go's `StreamException`.
final class StreamException implements Exception {
  factory StreamException({
    required StreamErrorCode errorCode,
    required bool remote,
    Object? transportError,
  }) {
    _validateCode(errorCode);
    return StreamException._(
      errorCode: errorCode,
      remote: remote,
      transportError: transportError,
    );
  }

  StreamException._({
    required this.errorCode,
    required this.remote,
    this.transportError,
  });

  final StreamErrorCode errorCode;
  final bool remote;
  final Object? transportError;

  bool matches(StreamException other) =>
      errorCode == other.errorCode && remote == other.remote;

  List<Object> get causes => [errReset, ?transportError];

  @override
  String toString() {
    final side = remote ? 'remote' : 'local';
    final prefix =
        'stream reset ($side): code: 0x${errorCode.toRadixString(16)}';
    return transportError == null
        ? prefix
        : '$prefix: transport error: $transportError';
  }
}

/// Details of a connection close, equivalent to Go's `ConnException`.
final class ConnException implements Exception {
  factory ConnException({
    required ConnErrorCode errorCode,
    required bool remote,
    Object? transportError,
  }) {
    _validateCode(errorCode);
    return ConnException._(
      errorCode: errorCode,
      remote: remote,
      transportError: transportError,
    );
  }

  ConnException._({
    required this.errorCode,
    required this.remote,
    this.transportError,
  });

  final ConnErrorCode errorCode;
  final bool remote;
  final Object? transportError;

  bool matches(ConnException other) =>
      errorCode == other.errorCode && remote == other.remote;

  List<Object> get causes => [errReset, ?transportError];

  @override
  String toString() {
    final side = remote ? 'remote' : 'local';
    final prefix =
        'connection closed ($side): code: 0x${errorCode.toRadixString(16)}';
    return transportError == null
        ? prefix
        : '$prefix: transport error: $transportError';
  }
}

void _validateCode(int value) {
  if (value < 0 || value > 0xffffffff) {
    throw RangeError.range(value, 0, 0xffffffff, 'errorCode');
  }
}

class NetworkException implements Exception {
  const NetworkException(this.message);
  final String message;
  @override
  String toString() => message;
}

final class TemporaryNetworkException extends NetworkException {
  const TemporaryNetworkException(super.message);
  bool get isTemporary => true;
  bool get isTimeout => false;
}

const errNoRemoteAddrs = NetworkException('no remote addresses');
const errNoConn = NetworkException('no usable connection to peer');
const errLimitedConn = NetworkException('limited connection to peer');
@Deprecated('Use errLimitedConn instead.')
const errTransientConn = errLimitedConn;
const errResourceLimitExceeded = TemporaryNetworkException(
  'resource limit exceeded',
);
const errResourceScopeClosed = NetworkException('resource scope closed');

/// Negotiated protocols and transport for a connection.
final class ConnectionState {
  const ConnectionState({
    this.streamMultiplexer = '',
    this.security = '',
    this.transport = '',
    this.usedEarlyMuxerNegotiation = false,
  });

  final ProtocolId streamMultiplexer;
  final ProtocolId security;
  final String transport;
  final bool usedEarlyMuxerNegotiation;
}

class Stats {
  const Stats({
    required this.direction,
    required this.opened,
    this.limited = false,
    this.extra = const {},
  });
  final Direction direction;
  final DateTime opened;
  final bool limited;
  final Map<Object?, Object?> extra;
}

final class ConnStats extends Stats {
  const ConnStats({
    required super.direction,
    required super.opened,
    super.limited,
    super.extra,
    this.numStreams = 0,
  });
  final int numStreams;
}

final class AddrDelay {
  const AddrDelay(this.addr, this.delay);
  final Multiaddr addr;
  final Duration delay;
}

typedef DialRanker = List<AddrDelay> Function(List<Multiaddr> addresses);

/// Minimum read-write contract needed for stream I/O and protocol negotiation.
abstract interface class StreamReadWriter {
  Future<Uint8List> read([int? maxLength]);
  Future<void> write(Uint8List data);
}

/// A libp2p stream contract.
///
/// Named `NetworkStream` because Dart's own `Stream` is the native async
/// stream type used throughout this package.
abstract interface class NetworkStream implements StreamReadWriter {
  String get id;
  ProtocolId protocol();
  Future<void> setProtocol(ProtocolId id);
  Stats stat();
  Conn conn();
  StreamScope scope();
  Future<void> resetWithError(StreamErrorCode errorCode);

  bool get isClosed;
  @override
  Future<Uint8List> read([int? maxLength]);
  @override
  Future<void> write(Uint8List data);
  Future<void> close();
  Future<void> reset();
  Future<void> closeWrite();
  Future<void> closeRead();
  Future<void> setDeadline(DateTime? time);
  Future<void> setReadDeadline(DateTime? time);
  Future<void> setWriteDeadline(DateTime? time);
}

typedef StreamHandler = void Function(NetworkStream stream);

/// Resolves the DNS components of a multiaddr.
abstract interface class MultiaddrDnsResolver {
  Future<List<Multiaddr>> resolveDnsAddr(
    NetworkContext context,
    PeerId expectedPeerId,
    Multiaddr multiaddr,
    int recursionLimit,
    int outputLimit,
  );

  Future<List<Multiaddr>> resolveDnsComponent(
    NetworkContext context,
    Multiaddr multiaddr,
    int outputLimit,
  );
}

/// The subset of a [Network] that can dial peers.
abstract interface class Dialer {
  /// Kept untyped until `core/peerstore.Peerstore` is ported.
  Object get peerstore;
  PeerId get localPeer;
  Future<Conn> dialPeer(NetworkContext context, PeerId peer);
  Future<void> closePeer(PeerId peer);
  Connectedness connectedness(PeerId peer);
  List<PeerId> peers();
  List<Conn> conns();
  List<Conn> connsToPeer(PeerId peer);
  void notify(Notifiee notifiee);
  void stopNotify(Notifiee notifiee);
  bool canDial(PeerId peer, Multiaddr address);
}

/// The high-level contract for listening and dialing peers.
abstract interface class Network implements Dialer {
  Future<void> close();
  void setStreamHandler(StreamHandler handler);
  Future<NetworkStream> newStream(NetworkContext context, PeerId peer);

  /// Go's variadic `Listen(...Multiaddr)` becomes an address list.
  Future<void> listen(List<Multiaddr> addresses);
  List<Multiaddr> listenAddresses();
  Future<List<Multiaddr>> interfaceListenAddresses();
  ResourceManager get resourceManager;
}

abstract interface class Conn {}

/// Security identity and negotiated state exposed by a connection.
abstract interface class ConnSecurity {
  PeerId localPeer();
  PeerId remotePeer();
  PubKey remotePublicKey();
  ConnectionState connState();
}

/// Endpoint multiaddrs exposed by a connection.
abstract interface class ConnMultiaddrs {
  Multiaddr localMultiaddr();
  Multiaddr remoteMultiaddr();
}

abstract interface class ConnStat {
  ConnStats stat();
}

abstract interface class ConnScoper {
  ConnScope scope();
}

abstract interface class Notifiee {
  void listen(Network network, Multiaddr address);
  void listenClose(Network network, Multiaddr address);
  void connected(Network network, Conn connection);
  void disconnected(Network network, Conn connection);
}

final class NotifyBundle implements Notifiee {
  NotifyBundle({
    this.listenF,
    this.listenCloseF,
    this.connectedF,
    this.disconnectedF,
  });
  final void Function(Network, Multiaddr)? listenF;
  final void Function(Network, Multiaddr)? listenCloseF;
  final void Function(Network, Conn)? connectedF;
  final void Function(Network, Conn)? disconnectedF;
  @override
  void listen(Network n, Multiaddr a) => listenF?.call(n, a);
  @override
  void listenClose(Network n, Multiaddr a) => listenCloseF?.call(n, a);
  @override
  void connected(Network n, Conn c) => connectedF?.call(n, c);
  @override
  void disconnected(Network n, Conn c) => disconnectedF?.call(n, c);
}

final class NoopNotifiee implements Notifiee {
  const NoopNotifiee();
  @override
  void listen(Network n, Multiaddr a) {}
  @override
  void listenClose(Network n, Multiaddr a) {}
  @override
  void connected(Network n, Conn c) {}
  @override
  void disconnected(Network n, Conn c) {}
}

const globalNoopNotifiee = NoopNotifiee();

const reservationPriorityLow = 101;
const reservationPriorityMedium = 152;
const reservationPriorityHigh = 203;
const reservationPriorityAlways = 255;

/// Resource accounting for one scope.
final class ScopeStat {
  const ScopeStat({
    this.numStreamsInbound = 0,
    this.numStreamsOutbound = 0,
    this.numConnsInbound = 0,
    this.numConnsOutbound = 0,
    this.numFd = 0,
    this.memory = 0,
  });

  final int numStreamsInbound;
  final int numStreamsOutbound;
  final int numConnsInbound;
  final int numConnsOutbound;
  final int numFd;
  final int memory;
}

abstract interface class ResourceScope {
  void reserveMemory(int size, int priority);
  void releaseMemory(int size);
  ScopeStat stat();
  ResourceScopeSpan beginSpan();
}

abstract interface class ResourceScopeSpan implements ResourceScope {
  void done();
}

abstract interface class ServiceScope implements ResourceScope {
  String name();
}

abstract interface class ProtocolScope implements ResourceScope {
  ProtocolId protocol();
}

abstract interface class PeerScope implements ResourceScope {
  PeerId peer();
}

abstract interface class ConnManagementScope implements ResourceScopeSpan {
  PeerScope? peerScope();
  void setPeer(PeerId peer);
}

abstract interface class ConnScope implements ResourceScope {}

abstract interface class StreamManagementScope implements ResourceScopeSpan {
  ProtocolScope? protocolScope();
  void setProtocol(ProtocolId protocol);
  ServiceScope? serviceScope();
  void setService(String service);
  PeerScope peerScope();
}

abstract interface class StreamScope implements ResourceScope {
  void setService(String service);
}

typedef ResourceScopeVisitor<T extends ResourceScope> = void Function(T scope);

abstract interface class ResourceScopeViewer {
  void viewSystem(ResourceScopeVisitor<ResourceScope> visitor);
  void viewTransient(ResourceScopeVisitor<ResourceScope> visitor);
  void viewService(String service, ResourceScopeVisitor<ServiceScope> visitor);
  void viewProtocol(
    ProtocolId protocol,
    ResourceScopeVisitor<ProtocolScope> visitor,
  );
  void viewPeer(PeerId peer, ResourceScopeVisitor<PeerScope> visitor);
}

abstract interface class ResourceManager implements ResourceScopeViewer {
  ConnManagementScope openConnection(
    Direction direction,
    bool useFd,
    Multiaddr endpoint,
  );

  /// [address] is deliberately [Object]: Go accepts arbitrary `net.Addr`
  /// implementations, while Dart has no equivalent common address interface.
  bool verifySourceAddress(Object address);
  StreamManagementScope openStream(PeerId peer, Direction direction);
  void close();
}

class MissingConnManagementScopeException implements Exception {
  const MissingConnManagementScopeException();
  @override
  String toString() => 'context has no ConnManagementScope';
}

NetworkContext withConnManagementScope(
  NetworkContext context,
  ConnManagementScope scope,
) => context.copyWith(connManagementScope: scope);

ConnManagementScope unwrapConnManagementScope(NetworkContext context) =>
    context.connManagementScope ??
    (throw const MissingConnManagementScopeException());

/// No-op resource manager used for defaults and tests.
final class NullResourceManager implements ResourceManager {
  const NullResourceManager();

  @override
  void viewSystem(ResourceScopeVisitor<ResourceScope> visitor) =>
      visitor(const NullScope());
  @override
  void viewTransient(ResourceScopeVisitor<ResourceScope> visitor) =>
      visitor(const NullScope());
  @override
  void viewService(
    String service,
    ResourceScopeVisitor<ServiceScope> visitor,
  ) => visitor(const NullScope());
  @override
  void viewProtocol(
    ProtocolId protocol,
    ResourceScopeVisitor<ProtocolScope> visitor,
  ) => visitor(const NullScope());
  @override
  void viewPeer(PeerId peer, ResourceScopeVisitor<PeerScope> visitor) =>
      visitor(const NullScope());
  @override
  ConnManagementScope openConnection(
    Direction direction,
    bool useFd,
    Multiaddr endpoint,
  ) => const NullScope();
  @override
  bool verifySourceAddress(Object address) => false;
  @override
  StreamManagementScope openStream(PeerId peer, Direction direction) =>
      const NullScope();
  @override
  void close() {}
}

/// No-op resource scope used by [NullResourceManager].
final class NullScope
    implements
        ResourceScopeSpan,
        ServiceScope,
        ProtocolScope,
        PeerScope,
        ConnManagementScope,
        ConnScope,
        StreamManagementScope,
        StreamScope {
  const NullScope();

  @override
  void reserveMemory(int size, int priority) {}
  @override
  void releaseMemory(int size) {}
  @override
  ScopeStat stat() => const ScopeStat();
  @override
  ResourceScopeSpan beginSpan() => const NullScope();
  @override
  void done() {}
  @override
  String name() => '';
  @override
  ProtocolId protocol() => '';
  @override
  PeerId peer() => PeerId(value: Uint8List(0));
  @override
  PeerScope peerScope() => const NullScope();
  @override
  void setPeer(PeerId peer) {}
  @override
  ProtocolScope? protocolScope() => const NullScope();
  @override
  void setProtocol(ProtocolId protocol) {}
  @override
  ServiceScope? serviceScope() => const NullScope();
  @override
  void setService(String service) {}
}
