// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';

import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

import '../../../core/event/bus.dart';
import '../../../core/event/network.dart';
import '../../../core/network/network.dart';
import '../../../core/peer/peer_id.dart';
import '../../../core/peerstore/peerstore.dart';
import '../../../core/transport/transport.dart';
import '../../host/eventbus/basic.dart';
import '../../host/peerstore/pstoremem/peerstore.dart';

/// Standard libp2p network implementation managing transports, listeners,
/// peer connections, and stream dispatch.
class Swarm implements TransportNetwork {
  Swarm({
    required this.localPeer,
    Peerstore? peerstore,
    this.resourceManager = const NullResourceManager(),
    Bus? eventBus,
    List<Transport>? transports,
  })  : peerstore = peerstore ?? MemoryPeerstore(),
        eventBus = eventBus ?? BasicBus() {
    if (transports != null) {
      _transports.addAll(transports);
    }
  }

  @override
  final PeerId localPeer;

  @override
  final Peerstore peerstore;

  @override
  final ResourceManager resourceManager;

  final Bus eventBus;
  final List<Transport> _transports = [];
  final List<Listener> _listeners = [];
  final Map<PeerId, List<CapableConn>> _connections = {};
  final List<Notifiee> _notifiees = [];
  StreamHandler? _streamHandler;
  bool _closed = false;

  @override
  void addTransport(Transport transport) {
    if (!_transports.contains(transport)) {
      _transports.add(transport);
    }
  }

  @override
  void setStreamHandler(StreamHandler handler) {
    _streamHandler = handler;
  }

  @override
  Future<void> listen(List<Multiaddr> addresses) async {
    if (_closed) throw StateError('Swarm is closed');
    for (final addr in addresses) {
      Transport? matchingTransport;
      for (final t in _transports) {
        if (t.canDial(addr)) {
          matchingTransport = t;
          break;
        }
      }
      if (matchingTransport == null) continue;
      final listener = await matchingTransport.listen(addr);
      _listeners.add(listener);
      _startAcceptLoop(listener);
      for (final n in _notifiees.toList()) {
        n.listen(this, listener.multiaddr());
      }
    }
  }

  void _startAcceptLoop(Listener listener) async {
    while (!_closed) {
      try {
        final conn = await listener.accept();
        _addConnection(conn);
      } on ListenerClosedException {
        break;
      } catch (_) {
        if (_closed) break;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  }

  void _addConnection(CapableConn conn) {
    final remote = conn.remotePeer();
    final list = _connections.putIfAbsent(remote, () => <CapableConn>[]);
    list.add(conn);

    peerstore.addAddrs(remote, [conn.remoteMultiaddr()], tempAddrTtl);
    for (final n in _notifiees.toList()) {
      n.connected(this, conn);
    }
    eventBus.emitter(EvtPeerConnectednessChanged).then((e) => e.emit(EvtPeerConnectednessChanged(peer: remote, connectedness: Connectedness.connected)));

    _startIncomingStreamsLoop(conn);
  }

  void _startIncomingStreamsLoop(CapableConn conn) async {
    while (!_closed && !conn.isClosed) {
      try {
        final stream = await conn.acceptStream();
        final handler = _streamHandler;
        if (handler != null) {
          unawaited(Future.sync(() => handler(stream)));
        }
      } catch (_) {
        break;
      }
    }
    _removeConnection(conn);
  }

  void _removeConnection(CapableConn conn) {
    final remote = conn.remotePeer();
    final list = _connections[remote];
    if (list != null) {
      list.remove(conn);
      if (list.isEmpty) {
        _connections.remove(remote);
        eventBus.emitter(EvtPeerConnectednessChanged).then((e) => e.emit(EvtPeerConnectednessChanged(peer: remote, connectedness: Connectedness.notConnected)));
      }
    }
    for (final n in _notifiees.toList()) {
      n.disconnected(this, conn);
    }
  }

  @override
  Future<CapableConn> dialPeer(NetworkContext context, PeerId peer) async {
    if (_closed) throw StateError('Swarm is closed');
    final existing = _connections[peer];
    if (existing != null && existing.isNotEmpty) {
      for (final conn in existing) {
        if (!conn.isClosed) return conn;
      }
    }

    final addrs = peerstore.addrs(peer);
    if (addrs.isEmpty) {
      throw errNoRemoteAddrs;
    }

    Object? lastError;
    for (final addr in addrs) {
      for (final t in _transports) {
        if (!t.canDial(addr)) continue;
        try {
          final conn = await t.dial(addr, peer);
          _addConnection(conn);
          return conn;
        } catch (err) {
          lastError = err;
        }
      }
    }
    throw StateError('Failed to dial peer $peer on addresses $addrs: $lastError');
  }

  @override
  Future<NetworkStream> newStream(NetworkContext context, PeerId peer) async {
    if (_closed) throw StateError('Swarm is closed');
    final conn = await dialPeer(context, peer);
    return conn.openStream();
  }

  @override
  List<Multiaddr> listenAddresses() => [for (final l in _listeners) l.multiaddr()];

  @override
  Future<List<Multiaddr>> interfaceListenAddresses() async => listenAddresses();

  @override
  Connectedness connectedness(PeerId peer) {
    final list = _connections[peer];
    if (list != null && list.any((c) => !c.isClosed)) {
      return Connectedness.connected;
    }
    if (peerstore.addrs(peer).isNotEmpty) {
      return Connectedness.canConnect;
    }
    return Connectedness.notConnected;
  }

  @override
  List<PeerId> peers() => _connections.keys.toList();

  @override
  List<Conn> conns() {
    final res = <Conn>[];
    for (final list in _connections.values) {
      res.addAll(list);
    }
    return res;
  }

  @override
  List<Conn> connsToPeer(PeerId peer) => List.unmodifiable(_connections[peer] ?? const []);

  @override
  Future<void> closePeer(PeerId peer) async {
    final list = _connections.remove(peer);
    if (list != null) {
      for (final c in list) {
        await c.close();
      }
    }
  }

  @override
  bool canDial(PeerId peer, Multiaddr address) {
    for (final t in _transports) {
      if (t.canDial(address)) return true;
    }
    return false;
  }

  @override
  void notify(Notifiee notifiee) {
    if (!_notifiees.contains(notifiee)) {
      _notifiees.add(notifiee);
    }
  }

  @override
  void stopNotify(Notifiee notifiee) {
    _notifiees.remove(notifiee);
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final l in _listeners.toList()) {
      await l.close();
    }
    _listeners.clear();

    for (final list in _connections.values.toList()) {
      for (final c in list.toList()) {
        await c.close();
      }
    }
    _connections.clear();
  }
}
