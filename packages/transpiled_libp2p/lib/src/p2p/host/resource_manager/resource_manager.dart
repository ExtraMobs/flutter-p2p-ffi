// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/protocol/protocol.dart';
import 'limit.dart';

final class ResourceLimitExceededException extends NetworkException {
  const ResourceLimitExceededException([
    super.message = 'resource limit exceeded',
  ]);
}

final class _Resources {
  _Resources(this.limit);
  final Limit limit;
  int streamsIn = 0,
      streamsOut = 0,
      connsIn = 0,
      connsOut = 0,
      fd = 0,
      memory = 0;

  ScopeStat stat() => ScopeStat(
    numStreamsInbound: streamsIn,
    numStreamsOutbound: streamsOut,
    numConnsInbound: connsIn,
    numConnsOutbound: connsOut,
    numFd: fd,
    memory: memory,
  );

  void memoryAdd(int amount, int priority) {
    if (amount < 0) throw ArgumentError.value(amount, 'size');
    final max = limit.memoryLimit;
    if (max != BaseLimit.unlimitedValue &&
        memory + amount > (max * (priority + 1)) ~/ 256) {
      throw const ResourceLimitExceededException();
    }
    memory += amount;
  }

  void streamAdd(Direction direction) {
    final inbound = direction == Direction.inbound;
    final next = inbound ? streamsIn + 1 : streamsOut + 1;
    if (next > limit.getStreamLimit(direction) ||
        streamsIn + streamsOut + 1 > limit.streamTotalLimit) {
      throw const ResourceLimitExceededException();
    }
    if (inbound) {
      streamsIn++;
    } else {
      streamsOut++;
    }
  }

  void streamRemove(Direction direction) {
    if (direction == Direction.inbound) {
      streamsIn = streamsIn > 0 ? streamsIn - 1 : 0;
    } else {
      streamsOut = streamsOut > 0 ? streamsOut - 1 : 0;
    }
  }

  void connAdd(Direction direction, bool useFd) {
    final inbound = direction == Direction.inbound;
    final next = inbound ? connsIn + 1 : connsOut + 1;
    if (next > limit.getConnLimit(direction) ||
        connsIn + connsOut + 1 > limit.connTotalLimit ||
        (useFd && fd + 1 > limit.fdLimit)) {
      throw const ResourceLimitExceededException();
    }
    if (inbound) {
      connsIn++;
    } else {
      connsOut++;
    }
    if (useFd) fd++;
  }

  void connRemove(Direction direction, bool useFd) {
    if (direction == Direction.inbound) {
      connsIn = connsIn > 0 ? connsIn - 1 : 0;
    } else {
      connsOut = connsOut > 0 ? connsOut - 1 : 0;
    }
    if (useFd) fd = fd > 0 ? fd - 1 : 0;
  }

  void release(ScopeStat stat) {
    memory = memory >= stat.memory ? memory - stat.memory : 0;
    streamsIn = streamsIn >= stat.numStreamsInbound
        ? streamsIn - stat.numStreamsInbound
        : 0;
    streamsOut = streamsOut >= stat.numStreamsOutbound
        ? streamsOut - stat.numStreamsOutbound
        : 0;
    connsIn = connsIn >= stat.numConnsInbound
        ? connsIn - stat.numConnsInbound
        : 0;
    connsOut = connsOut >= stat.numConnsOutbound
        ? connsOut - stat.numConnsOutbound
        : 0;
    fd = fd >= stat.numFd ? fd - stat.numFd : 0;
  }
}

class _Scope implements ResourceScope, ResourceScopeSpan {
  _Scope(this._resources, {this.owner, List<_Scope>? edges, this.scopeName})
    : _edges = edges ?? const [] {
    for (final edge in _edges) edge.refCount++;
  }

  final _Resources _resources;
  final _Scope? owner;
  List<_Scope> _edges;
  final String? scopeName;
  bool closed = false;
  int refCount = 0;
  int _spanId = 0;

  void _ensureOpen() {
    if (closed) throw errResourceScopeClosed;
  }

  void _reserveForChild(ScopeStat stat) {
    _ensureOpen();
    _resources.memoryAdd(stat.memory, reservationPriorityAlways);
    try {
      for (var i = 0; i < stat.numStreamsInbound; i++) {
        _resources.streamAdd(Direction.inbound);
      }
      for (var i = 0; i < stat.numStreamsOutbound; i++) {
        _resources.streamAdd(Direction.outbound);
      }
      var remainingFd = stat.numFd;
      for (var i = 0; i < stat.numConnsInbound; i++) {
        final fd = remainingFd > 0;
        _resources.connAdd(Direction.inbound, fd);
        if (fd) remainingFd--;
      }
      for (var i = 0; i < stat.numConnsOutbound; i++) {
        final fd = remainingFd > 0;
        _resources.connAdd(Direction.outbound, fd);
        if (fd) remainingFd--;
      }
      if (remainingFd != 0) throw StateError('invalid child statistics');
    } catch (_) {
      _resources.release(stat);
      rethrow;
    }
  }

  void _releaseForChild(ScopeStat stat) {
    if (!closed) _resources.release(stat);
  }

  void _releaseEdges(ScopeStat stat) {
    for (final edge in _edges) edge._releaseForChild(stat);
  }

  @override
  void reserveMemory(int size, int priority) {
    _ensureOpen();
    _resources.memoryAdd(size, priority);
    try {
      _reserveMemoryEdges(size, priority);
    } catch (_) {
      _resources.memory -= size;
      rethrow;
    }
  }

  void _reserveMemoryEdges(int size, int priority) {
    if (owner != null) {
      owner!.reserveMemory(size, priority);
      return;
    }
    final done = <_Scope>[];
    try {
      for (final edge in _edges) {
        edge._ensureOpen();
        edge._resources.memoryAdd(size, priority);
        done.add(edge);
      }
    } catch (_) {
      for (final edge in done.reversed) {
        edge._resources.memory = edge._resources.memory >= size
            ? edge._resources.memory - size
            : 0;
      }
      rethrow;
    }
  }

  @override
  void releaseMemory(int size) {
    if (closed) return;
    _resources.memory = _resources.memory >= size
        ? _resources.memory - size
        : 0;
    if (owner != null) {
      owner!.releaseMemory(size);
    } else {
      for (final edge in _edges) edge._releaseMemoryForChild(size);
    }
  }

  void _releaseMemoryForChild(int size) {
    if (!closed) {
      _resources.memory = _resources.memory >= size
          ? _resources.memory - size
          : 0;
    }
  }

  @override
  ScopeStat stat() => _resources.stat();

  @override
  ResourceScopeSpan beginSpan() {
    _ensureOpen();
    refCount++;
    return _Scope(
      _Resources(_resources.limit),
      owner: this,
      scopeName: '${scopeName ?? ''}.span-${++_spanId}',
    );
  }

  @override
  void done() {
    if (closed) return;
    final current = stat();
    if (owner != null) {
      owner!._releaseResources(current);
      owner!.refCount = owner!.refCount > 0 ? owner!.refCount - 1 : 0;
    } else {
      _releaseEdges(current);
      for (final edge in _edges)
        edge.refCount = edge.refCount > 0 ? edge.refCount - 1 : 0;
    }
    _resources.release(current);
    closed = true;
  }

  void _releaseResources(ScopeStat current) {
    if (closed) return;
    _resources.release(current);
    if (owner != null) {
      owner!._releaseResources(current);
    } else {
      _releaseEdges(current);
    }
  }

  void addStream(Direction direction) {
    _ensureOpen();
    _resources.streamAdd(direction);
    try {
      _reserveStreamEdges(direction);
    } catch (_) {
      _resources.streamRemove(direction);
      rethrow;
    }
  }

  void _reserveStreamEdges(Direction direction) {
    if (owner != null) {
      owner!.addStream(direction);
      return;
    }
    final done = <_Scope>[];
    try {
      for (final edge in _edges) {
        edge._ensureOpen();
        edge._resources.streamAdd(direction);
        done.add(edge);
      }
    } catch (_) {
      for (final edge in done.reversed) edge._resources.streamRemove(direction);
      rethrow;
    }
  }

  void removeStream(Direction direction) {
    if (closed) return;
    _resources.streamRemove(direction);
    if (owner != null) {
      owner!.removeStream(direction);
    } else {
      for (final edge in _edges) edge._removeStreamForChild(direction);
    }
  }

  void _removeStreamForChild(Direction direction) {
    if (!closed) _resources.streamRemove(direction);
  }

  void addConn(Direction direction, bool useFd) {
    _ensureOpen();
    _resources.connAdd(direction, useFd);
    final done = <_Scope>[];
    try {
      if (owner != null) {
        owner!.addConn(direction, useFd);
        return;
      }
      for (final edge in _edges) {
        edge._ensureOpen();
        edge._resources.connAdd(direction, useFd);
        done.add(edge);
      }
    } catch (_) {
      for (final edge in done.reversed)
        edge._resources.connRemove(direction, useFd);
      _resources.connRemove(direction, useFd);
      rethrow;
    }
  }

  void removeConn(Direction direction, bool useFd) {
    if (closed) return;
    _resources.connRemove(direction, useFd);
    if (owner != null) {
      owner!.removeConn(direction, useFd);
    } else {
      for (final edge in _edges) edge._removeConnForChild(direction, useFd);
    }
  }

  void _removeConnForChild(Direction direction, bool useFd) {
    if (!closed) _resources.connRemove(direction, useFd);
  }

  bool isUnused() =>
      closed ||
      (refCount == 0 &&
          _resources.stat().numStreamsInbound == 0 &&
          _resources.stat().numStreamsOutbound == 0 &&
          _resources.stat().numConnsInbound == 0 &&
          _resources.stat().numConnsOutbound == 0 &&
          _resources.stat().numFd == 0 &&
          _resources.stat().memory == 0);
}

final class _PeerScope extends _Scope implements PeerScope {
  _PeerScope(this.id, super.resources, {super.edges})
    : super(scopeName: 'peer:$id');
  final PeerId id;
  @override
  PeerId peer() => id;
}

final class _ProtocolScope extends _Scope implements ProtocolScope {
  _ProtocolScope(this.id, super.resources, {super.edges})
    : super(scopeName: 'protocol:$id');
  final ProtocolId id;
  final Map<PeerId, _Scope> _peers = {};
  @override
  ProtocolId protocol() => id;
}

final class _ServiceScope extends _Scope implements ServiceScope {
  _ServiceScope(this.id, super.resources, {super.edges})
    : super(scopeName: 'service:$id');
  final String id;
  final Map<PeerId, _Scope> _peers = {};
  @override
  String name() => id;
}

final class _StreamScope extends _Scope
    implements StreamManagementScope, StreamScope {
  _StreamScope(
    this.manager,
    this.direction,
    this._peerId,
    super.resources, {
    super.edges,
  });
  final ResourceManagerImpl manager;
  final Direction direction;
  final _PeerScope _peerId;
  _ProtocolScope? proto;
  _ServiceScope? service;
  _Scope? peerProto;
  _Scope? peerService;

  @override
  ProtocolScope? protocolScope() => proto;
  @override
  ServiceScope? serviceScope() => service;
  @override
  PeerScope peerScope() => _peerId;

  @override
  void setProtocol(ProtocolId protocol) {
    _ensureOpen();
    if (proto != null)
      throw StateError('stream scope already attached to a protocol');
    final nextProto = manager._protocol(protocol);
    final nextPeerProto = manager._protocolPeer(nextProto, _peerId.id);
    final current = stat();
    try {
      nextProto._reserveForChild(current);
      nextPeerProto._reserveForChild(current);
    } catch (_) {
      nextPeerProto._releaseForChild(current);
      nextProto._releaseForChild(current);
      nextProto.refCount = nextProto.refCount > 0 ? nextProto.refCount - 1 : 0;
      nextPeerProto.refCount = nextPeerProto.refCount > 0
          ? nextPeerProto.refCount - 1
          : 0;
      rethrow;
    }
    final old = _edges;
    final next = [_peerId, nextPeerProto, nextProto, manager._systemScopeImpl];
    _replaceEdges(old, next, owned: {nextPeerProto, nextProto});
    // The stream's resources move from transient to the protocol scopes; its
    // local counters remain unchanged.
    manager._transientScopeImpl._releaseForChild(current);
    proto = nextProto;
    peerProto = nextPeerProto;
  }

  @override
  void setService(String name) {
    _ensureOpen();
    if (service != null)
      throw StateError('stream scope already attached to a service');
    if (proto == null || peerProto == null) {
      throw StateError('stream scope not attached to a protocol');
    }
    final nextService = manager._service(name);
    final nextPeerService = manager._servicePeer(nextService, _peerId.id);
    final current = stat();
    try {
      nextService._reserveForChild(current);
      nextPeerService._reserveForChild(current);
    } catch (_) {
      nextPeerService._releaseForChild(current);
      nextService._releaseForChild(current);
      nextService.refCount = nextService.refCount > 0
          ? nextService.refCount - 1
          : 0;
      nextPeerService.refCount = nextPeerService.refCount > 0
          ? nextPeerService.refCount - 1
          : 0;
      rethrow;
    }
    final old = _edges;
    final next = [
      _peerId,
      peerProto!,
      nextPeerService,
      proto!,
      nextService,
      manager._systemScopeImpl,
    ];
    _replaceEdges(old, next, owned: {nextPeerService, nextService});
    service = nextService;
    peerService = nextPeerService;
  }

  void _replaceEdges(
    List<_Scope> old,
    List<_Scope> next, {
    Set<_Scope> owned = const {},
  }) {
    for (final edge in old) {
      if (!next.contains(edge)) {
        edge.refCount = edge.refCount > 0 ? edge.refCount - 1 : 0;
      }
    }
    for (final edge in next) {
      if (!old.contains(edge) && !owned.contains(edge)) edge.refCount++;
    }
    _edges = next;
  }
}

final class _ConnectionScope extends _Scope
    implements ConnManagementScope, ConnScope {
  _ConnectionScope(
    this.manager,
    this.direction,
    this.useFd,
    super.resources, {
    super.edges,
  });
  final ResourceManagerImpl manager;
  final Direction direction;
  final bool useFd;
  _PeerScope? peer;
  @override
  PeerScope? peerScope() => peer;
  @override
  void setPeer(PeerId id) {
    _ensureOpen();
    if (peer != null)
      throw StateError('connection scope already attached to a peer');
    final next = manager._peer(id);
    final current = stat();
    try {
      next._reserveForChild(current);
    } catch (_) {
      next.refCount = next.refCount > 0 ? next.refCount - 1 : 0;
      rethrow;
    }
    final old = _edges;
    next.refCount++; // The edge consumes a reference; the lookup reference is below.
    _edges = [next, manager._systemScopeImpl];
    for (final edge in old) {
      if (!_edges.contains(edge)) {
        edge._releaseForChild(current);
        edge.refCount = edge.refCount > 0 ? edge.refCount - 1 : 0;
      }
    }
    manager._transientScopeImpl._releaseForChild(current);
    next.refCount = next.refCount > 0 ? next.refCount - 1 : 0;
    peer = next;
  }
}

/// Minimal resource manager implementing the reusable go-libp2p accounting API.
final class ResourceManagerImpl implements ResourceManager {
  ResourceManagerImpl({Limiter? limiter})
    : limiter = limiter ?? FixedLimiter() {
    _systemScopeImpl = _Scope(
      _Resources(this.limiter.getSystemLimits()),
      scopeName: 'system',
    );
    _transientScopeImpl = _Scope(
      _Resources(this.limiter.getTransientLimits()),
      edges: [_systemScopeImpl],
      scopeName: 'transient',
    );
    _systemScopeImpl.refCount++;
    _transientScopeImpl.refCount++;
  }

  final Limiter limiter;
  late final _Scope _systemScopeImpl;
  late final _Scope _transientScopeImpl;
  ResourceScope get systemScope => _systemScopeImpl;
  ResourceScope get transientScope => _transientScopeImpl;
  final Map<PeerId, _PeerScope> _peers = {};
  final Map<ProtocolId, _ProtocolScope> _protocols = {};
  final Map<String, _ServiceScope> _services = {};
  bool closed = false;

  _PeerScope _peer(PeerId id) {
    final scope = _peers.putIfAbsent(
      id,
      () => _PeerScope(
        id,
        _Resources(limiter.getPeerLimits(id)),
        edges: [_systemScopeImpl],
      ),
    );
    scope.refCount++;
    return scope;
  }

  _ProtocolScope _protocol(ProtocolId id) {
    final scope = _protocols.putIfAbsent(
      id,
      () => _ProtocolScope(
        id,
        _Resources(limiter.getProtocolLimits(id)),
        edges: [_systemScopeImpl],
      ),
    );
    scope.refCount++;
    return scope;
  }

  _ServiceScope _service(String id) {
    final scope = _services.putIfAbsent(
      id,
      () => _ServiceScope(
        id,
        _Resources(limiter.getServiceLimits(id)),
        edges: [_systemScopeImpl],
      ),
    );
    scope.refCount++;
    return scope;
  }

  _Scope _protocolPeer(_ProtocolScope parent, PeerId id) {
    final scope = parent._peers.putIfAbsent(
      id,
      () => _Scope(
        _Resources(limiter.getProtocolPeerLimits(parent.id)),
        scopeName: 'protocol:${parent.id}.peer:$id',
      ),
    );
    scope.refCount++;
    return scope;
  }

  _Scope _servicePeer(_ServiceScope parent, PeerId id) {
    final scope = parent._peers.putIfAbsent(
      id,
      () => _Scope(
        _Resources(limiter.getServicePeerLimits(parent.id)),
        scopeName: 'service:${parent.id}.peer:$id',
      ),
    );
    scope.refCount++;
    return scope;
  }

  @override
  void viewSystem(ResourceScopeVisitor<ResourceScope> visitor) =>
      visitor(_systemScopeImpl);
  @override
  void viewTransient(ResourceScopeVisitor<ResourceScope> visitor) =>
      visitor(_transientScopeImpl);
  @override
  void viewService(String name, ResourceScopeVisitor<ServiceScope> visitor) {
    final scope = _service(name);
    try {
      visitor(scope);
    } finally {
      scope.refCount = scope.refCount > 0 ? scope.refCount - 1 : 0;
    }
  }

  @override
  void viewProtocol(
    ProtocolId id,
    ResourceScopeVisitor<ProtocolScope> visitor,
  ) {
    final scope = _protocol(id);
    try {
      visitor(scope);
    } finally {
      scope.refCount = scope.refCount > 0 ? scope.refCount - 1 : 0;
    }
  }

  @override
  void viewPeer(PeerId id, ResourceScopeVisitor<PeerScope> visitor) {
    final scope = _peer(id);
    try {
      visitor(scope);
    } finally {
      scope.refCount = scope.refCount > 0 ? scope.refCount - 1 : 0;
    }
  }

  @override
  StreamManagementScope openStream(PeerId id, Direction direction) {
    if (closed) throw StateError('resource manager closed');
    final peer = _peer(id);
    final scope = _StreamScope(
      this,
      direction,
      peer,
      _Resources(limiter.getStreamLimits(id)),
      edges: [peer, _transientScopeImpl, _systemScopeImpl],
    );
    peer.refCount = peer.refCount > 0 ? peer.refCount - 1 : 0;
    try {
      scope.addStream(direction);
      return scope;
    } catch (_) {
      scope.done();
      rethrow;
    }
  }

  @override
  ConnManagementScope openConnection(
    Direction direction,
    bool useFd,
    Multiaddr endpoint,
  ) {
    final scope = _ConnectionScope(
      this,
      direction,
      useFd,
      _Resources(limiter.getConnLimits()),
      edges: [_transientScopeImpl, _systemScopeImpl],
    );
    try {
      scope.addConn(direction, useFd);
      return scope;
    } catch (_) {
      scope.done();
      rethrow;
    }
  }

  @override
  bool verifySourceAddress(Object address) => false;

  @override
  void close() {
    if (closed) return;
    closed = true;
    _transientScopeImpl.done();
    _systemScopeImpl.done();
  }
}
