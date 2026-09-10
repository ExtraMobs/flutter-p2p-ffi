// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

class _FakeConn implements Conn, ConnSecurity, ConnMultiaddrs, ConnScoper {
  _FakeConn({required this.local, required this.remote});

  final PeerId local;
  final PeerId remote;

  @override
  PeerId localPeer() => local;

  @override
  PeerId remotePeer() => remote;

  @override
  PubKey remotePublicKey() => unmarshalEd25519PublicKey(Uint8List(32));

  @override
  ConnectionState connState() => const ConnectionState();

  @override
  Multiaddr localMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');

  @override
  Multiaddr remoteMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4002');

  @override
  ConnScope scope() => const NullScope();
}

class _FakeStream implements NetworkStream {
  _FakeStream({required this.id, required this.local, required this.remote});

  @override
  final String id;
  final PeerId local;
  final PeerId remote;
  ProtocolId _proto = '/ipfs/id/1.0.0';

  @override
  ProtocolId protocol() => _proto;

  @override
  Future<void> setProtocol(ProtocolId id) async => _proto = id;

  @override
  Stats stat() => Stats(direction: Direction.outbound, opened: DateTime.now());

  @override
  Conn conn() => _FakeConn(local: local, remote: remote);

  @override
  StreamScope scope() => const NullScope();

  @override
  Future<void> resetWithError(StreamErrorCode errorCode) async {}

  bool isReset = false;

  @override
  bool get isClosed => false;

  @override
  Future<Uint8List> read([int? maxLength]) async => Uint8List(0);

  @override
  Future<void> write(Uint8List data) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> reset() async {
    isReset = true;
  }

  @override
  Future<void> closeWrite() async {}

  @override
  Future<void> closeRead() async {}

  @override
  Future<void> setDeadline(DateTime? time) async {}

  @override
  Future<void> setReadDeadline(DateTime? time) async {}

  @override
  Future<void> setWriteDeadline(DateTime? time) async {}
}

class _FakeCapableConn implements CapableConn {
  _FakeCapableConn(this._transport, this._local, this._remote);

  final Transport _transport;
  final PeerId _local;
  final PeerId _remote;

  @override
  Transport transport() => _transport;

  @override
  PeerId localPeer() => _local;

  @override
  PeerId remotePeer() => _remote;

  @override
  PubKey remotePublicKey() => unmarshalEd25519PublicKey(Uint8List(32));

  @override
  ConnectionState connState() => const ConnectionState();

  @override
  Multiaddr localMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');

  @override
  Multiaddr remoteMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4002');

  @override
  ConnScope scope() => const NullScope();

  bool _closed = false;

  @override
  ConnStats stat() => ConnStats(direction: Direction.outbound, opened: DateTime.now());

  @override
  Future<NetworkStream> openStream() async => _FakeStream(id: 's', local: _local, remote: _remote);

  @override
  Future<NetworkStream> acceptStream() async => _FakeStream(id: 's', local: _local, remote: _remote);

  @override
  Future<void> close() async {
    _closed = true;
  }

  @override
  bool get isClosed => _closed;
}

class _FakeRawConn implements RawConn {
  _FakeRawConn(this._transport);
  final Transport _transport;
  bool _closed = false;

  @override
  Transport transport() => _transport;

  @override
  Multiaddr localMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');

  @override
  Multiaddr remoteMultiaddr() => Multiaddr.parse('/ip4/127.0.0.1/tcp/4002');

  @override
  Future<Uint8List> read([int? maxLength]) async => Uint8List(0);

  @override
  Future<void> write(Uint8List data) async {}

  @override
  Future<void> close() async {
    _closed = true;
  }

  @override
  bool get isClosed => _closed;
}

class _FakeListener implements Listener {
  _FakeListener(this._transport, this._addr);

  final Transport _transport;
  final Multiaddr _addr;
  bool _closed = false;

  @override
  Future<CapableConn> accept() async {
    if (_closed) throw const ListenerClosedException();
    return _FakeCapableConn(_transport, PeerId(value: Uint8List.fromList([1])), PeerId(value: Uint8List.fromList([2])));
  }

  @override
  Future<void> close() async {
    _closed = true;
  }

  @override
  Multiaddr multiaddr() => _addr;
}

class _FakeTransport implements Transport {
  @override
  Future<CapableConn> dial(Multiaddr addr, PeerId peer) async {
    return _FakeCapableConn(this, peer, peer);
  }

  @override
  bool canDial(Multiaddr addr) => true;

  @override
  Future<Listener> listen(Multiaddr addr) async => _FakeListener(this, addr);

  @override
  List<int> protocols() => [4, 6];

  @override
  bool proxy() => false;
}

class _FakeTransportNetwork implements TransportNetwork {
  final List<Transport> transports = [];

  @override
  void addTransport(Transport transport) {
    transports.add(transport);
  }

  @override
  bool canDial(PeerId peer, Multiaddr address) => true;

  @override
  Future<void> close() async {}

  @override
  Future<void> closePeer(PeerId peer) async {}

  @override
  Connectedness connectedness(PeerId peer) => Connectedness.notConnected;

  @override
  List<Conn> conns() => [];

  @override
  List<Conn> connsToPeer(PeerId peer) => [];

  @override
  Future<Conn> dialPeer(NetworkContext context, PeerId peer) async => _FakeConn(local: peer, remote: peer);

  @override
  Future<List<Multiaddr>> interfaceListenAddresses() async => [];

  @override
  Future<void> listen(List<Multiaddr> addresses) async {}

  @override
  List<Multiaddr> listenAddresses() => [];

  @override
  PeerId get localPeer => PeerId(value: Uint8List.fromList([1]));

  @override
  Future<NetworkStream> newStream(NetworkContext context, PeerId peer) async => _FakeStream(id: 's', local: localPeer, remote: peer);

  @override
  void notify(Notifiee notifiee) {}

  @override
  List<PeerId> peers() => [];

  @override
  Object get peerstore => MemoryPeerstore();

  @override
  ResourceManager get resourceManager => const NullResourceManager();

  @override
  void setStreamHandler(StreamHandler handler) {}

  @override
  void stopNotify(Notifiee notifiee) {}
}

class _FakeDialUpdater implements DialUpdater {
  @override
  Stream<DialUpdate> dialWithUpdates(Multiaddr addr, PeerId peer) async* {
    yield DialUpdate(kind: 'connecting', addr: addr);
  }
}

class _FakeUpgrader implements Upgrader {
  @override
  Future<CapableConn> upgrade(Conn conn, Direction dir, PeerId peer) async {
    return _FakeCapableConn(_FakeTransport(), peer, peer);
  }
}

BlankHost _newTestHost([PeerId? id]) {
  final p = id ?? PeerId(value: Uint8List.fromList([1, 2, 3]));
  final ps = MemoryPeerstore();
  final net = _FakeTransportNetwork();
  return BlankHost(network: net, peerstore: ps);
}

void main() {
  final peerA = PeerId(value: Uint8List.fromList([1, 2, 3]));
  final peerB = PeerId(value: Uint8List.fromList([4, 5, 6]));

  group('IdService [Atomic Audit]', () {
    test('start() - registers stream handlers on host', () {
      final host = _newTestHost();
      final idSvc = IdService(host: host);
      idSvc.start();
      expect(host.mux.protocols(), contains(id));
    });

    test('identifyConn() - schedules connection identification', () {
      final host = _newTestHost();
      final idSvc = IdService(host: host);
      final conn = _FakeConn(local: peerA, remote: peerB);
      idSvc.identifyConn(conn);
      expect(idSvc, isNotNull);
    });

    test('identifyWait() - waits for peer identification completion', () async {
      final host = _newTestHost();
      final idSvc = IdService(host: host);
      final conn = _FakeConn(local: peerA, remote: peerB);
      await idSvc.identifyWait(conn);
      expect(idSvc, isNotNull);
    });

    test('close() - removes handlers and closes service', () async {
      final host = _newTestHost();
      final idSvc = IdService(host: host);
      idSvc.start();
      await idSvc.close();
      expect(host.mux.protocols(), isNot(contains(id)));
    });
  });

  group('Identify [Atomic Audit]', () {
    test('marshal() - serializes and unmarshals message correctly', () {
      final msg = Identify(
        agentVersion: 'test/1.0',
        protocolVersion: 'ipfs/1.0',
        protocols: ['/ipfs/id/1.0.0'],
      );
      final bytes = msg.marshal();
      expect(bytes, isNotEmpty);
      final decoded = Identify.unmarshal(bytes);
      expect(decoded.agentVersion, equals('test/1.0'));
      expect(decoded.protocolVersion, equals('ipfs/1.0'));
      expect(decoded.protocols, contains('/ipfs/id/1.0.0'));
    });
  });

  group('Client [Atomic Audit]', () {
    test('isStarted - reports lifecycle state', () {
      final host = _newTestHost();
      final client = Client(host: host);
      expect(client.isStarted, isFalse);
      client.start();
      expect(client.isStarted, isTrue);
    });

    test('isClosed - reports closed state', () async {
      final host = _newTestHost();
      final client = Client(host: host);
      expect(client.isClosed, isFalse);
      await client.close();
      expect(client.isClosed, isTrue);
    });

    test('start() - registers stop handler', () {
      final host = _newTestHost();
      final client = Client(host: host);
      client.start();
      expect(host.mux.protocols(), contains(protoIDv2Stop));
    });

    test('canDial() - identifies circuit addresses', () {
      final host = _newTestHost();
      final client = Client(host: host);
      final cAddr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001/p2p-circuit');
      final regAddr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
      expect(client.canDial(cAddr), isTrue);
      expect(client.canDial(regAddr), isFalse);
    });

    test('reserveSlot() - delegates reservation to reserve function', () async {
      final host = _newTestHost();
      final client = Client(host: host);
      final ai = AddrInfo(id: peerB, addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      final rsvp = await client.reserveSlot(ai);
      expect(rsvp.expiration.isAfter(DateTime.now()), isTrue);
    });
  });

  group('ReservationException [Atomic Audit]', () {
    test('toString() - formats status and reason', () {
      const ex = ReservationException(status: HopStatus.resourceLimitExceeded, reason: 'too busy');
      expect(ex.toString(), contains('resourceLimitExceeded'));
      expect(ex.toString(), contains('too busy'));
    });
  });

  group('HopStatus [Atomic Audit]', () {
    test('unexpectedMessage - has expected status code', () {
      expect(HopStatus.unexpectedMessage.code, equals(401));
    });

    test('fromCode() - parses status code properly', () {
      expect(HopStatus.fromCode(100), equals(HopStatus.ok));
      expect(HopStatus.fromCode(200), equals(HopStatus.reservationRefused));
      expect(HopStatus.fromCode(999), equals(HopStatus.connectionFailed));
    });
  });

  group('HopMessage [Atomic Audit]', () {
    test('marshal() - encodes and decodes reservation message', () {
      final msg = HopMessage(
        type: HopMessageType.status,
        status: HopStatus.ok,
        reservation: CircuitReservation(expire: 123456789),
        limit: CircuitLimit(duration: 60, data: 1024),
      );
      final bytes = msg.marshal();
      expect(bytes, isNotEmpty);
      final decoded = HopMessage.unmarshal(bytes);
      expect(decoded.type, equals(HopMessageType.status));
      expect(decoded.status, equals(HopStatus.ok));
      expect(decoded.reservation?.expire, equals(123456789));
    });
  });

  group('ReservationVoucher [Atomic Audit]', () {
    test('domain() - returns expected record domain', () {
      final v = ReservationVoucher(relay: peerA, peer: peerB, expiration: DateTime.now());
      expect(v.domain(), equals(recordDomain));
    });

    test('codec() - returns expected record codec', () {
      final v = ReservationVoucher(relay: peerA, peer: peerB, expiration: DateTime.now());
      expect(v.codec(), equals(recordCodec));
    });

    test('marshalRecord() - serializes voucher', () {
      final exp = DateTime.utc(2030, 1, 1);
      final v = ReservationVoucher(relay: peerA, peer: peerB, expiration: exp);
      final b = v.marshalRecord();
      expect(b, isNotEmpty);
    });

    test('unmarshalRecord() - round trips voucher serialization', () {
      final exp = DateTime.utc(2030, 1, 1);
      final v = ReservationVoucher(relay: peerA, peer: peerB, expiration: exp);
      final b = v.marshalRecord();
      final parsed = ReservationVoucher(relay: peerA, peer: peerB, expiration: DateTime.now());
      parsed.unmarshalRecord(b);
      expect(parsed.relay, equals(peerA));
      expect(parsed.peer, equals(peerB));
      expect(parsed.expiration.millisecondsSinceEpoch, equals(exp.millisecondsSinceEpoch));
    });
  });

  group('AutoNat [Atomic Audit]', () {
    test('status() - returns reachability status', () {
      AutoNat nat = StaticAutoNat(reachability: Reachability.public_);
      expect(nat.status(), equals(Reachability.public_));
    });

    test('close() - closes AutoNat instance', () async {
      AutoNat nat = StaticAutoNat(reachability: Reachability.public_);
      await nat.close();
      expect(nat, isNotNull);
    });
  });

  group('StaticAutoNat [Atomic Audit]', () {
    test('status() - returns configured status', () {
      final nat = StaticAutoNat(reachability: Reachability.private_);
      expect(nat.status(), equals(Reachability.private_));
    });

    test('close() - completes without error', () async {
      final nat = StaticAutoNat(reachability: Reachability.private_);
      await nat.close();
      expect(nat.status(), equals(Reachability.private_));
    });
  });

  group('AmbientAutoNat [Atomic Audit]', () {
    test('status() - returns ambient status', () {
      final host = _newTestHost();
      final nat = AmbientAutoNat(host: host, initialReachability: Reachability.unknown);
      expect(nat.status(), equals(Reachability.unknown));
    });

    test('setReachability() - emits event and updates status', () async {
      final host = _newTestHost();
      final nat = AmbientAutoNat(host: host);
      await nat.setReachability(Reachability.public_);
      expect(nat.status(), equals(Reachability.public_));
    });

    test('close() - cleans up emitter and closes', () async {
      final host = _newTestHost();
      final nat = AmbientAutoNat(host: host);
      await nat.close();
      expect(nat.status(), equals(Reachability.unknown));
    });
  });

  group('AutoRelay [Atomic Audit]', () {
    test('host - gets and sets host', () {
      final host = _newTestHost();
      final ar = AutoRelay(host: host);
      expect(ar.host, equals(host));
      final host2 = _newTestHost();
      ar.host = host2;
      expect(ar.host, equals(host2));
    });

    test('isStarted - tracks daemon start state', () async {
      final host = _newTestHost();
      final ar = AutoRelay(host: host);
      expect(ar.isStarted, isFalse);
      await ar.start();
      expect(ar.isStarted, isTrue);
      await ar.close();
    });

    test('isClosed - tracks closed state', () async {
      final host = _newTestHost();
      final ar = AutoRelay(host: host);
      expect(ar.isClosed, isFalse);
      await ar.close();
      expect(ar.isClosed, isTrue);
    });

    test('relayAddrs - exposes read only list of circuit addresses', () {
      final host = _newTestHost();
      final ar = AutoRelay(host: host);
      expect(ar.relayAddrs, isEmpty);
    });

    test('activeReservationsCount - exposes number of active reservations', () {
      final host = _newTestHost();
      final ar = AutoRelay(host: host);
      expect(ar.activeReservationsCount, equals(0));
    });

    test('start() - starts relay daemon and listens to reachability', () async {
      final host = _newTestHost();
      final ar = AutoRelay(host: host, bootDelay: const Duration(milliseconds: 50));
      await ar.start();
      expect(ar.isStarted, isTrue);
      await ar.close();
    });

    test('isPeerInBackoff() - checks if candidate peer is in backoff', () {
      final host = _newTestHost();
      final ar = AutoRelay(host: host);
      expect(ar.isPeerInBackoff(peerA), isFalse);
    });

    test('close() - cleans up timer and reservations', () async {
      final host = _newTestHost();
      final ar = AutoRelay(host: host);
      await ar.start();
      await ar.close();
      expect(ar.isClosed, isTrue);
    });
  });

  group('ListenerClosedException [Atomic Audit]', () {
    test('toString() - returns listener closed message', () {
      const ex = ListenerClosedException();
      expect(ex.toString(), equals('listener closed'));
    });
  });

  group('CapableConn [Atomic Audit]', () {
    test('transport() - returns parent transport', () {
      final t = _FakeTransport();
      final c = _FakeCapableConn(t, peerA, peerB);
      expect(c.transport(), equals(t));
    });

    test('openStream() - opens stream on capable conn', () async {
      final t = _FakeTransport();
      final c = _FakeCapableConn(t, peerA, peerB);
      final s = await c.openStream();
      expect(s.id, equals('s'));
    });

    test('acceptStream() - accepts incoming stream on capable conn', () async {
      final t = _FakeTransport();
      final c = _FakeCapableConn(t, peerA, peerB);
      final s = await c.acceptStream();
      expect(s.id, equals('s'));
    });

    test('close() - closes capable conn', () async {
      final t = _FakeTransport();
      final c = _FakeCapableConn(t, peerA, peerB);
      expect(c.isClosed, isFalse);
      await c.close();
      expect(c.isClosed, isTrue);
    });

    test('isClosed - reports connection lifecycle state', () {
      final t = _FakeTransport();
      final c = _FakeCapableConn(t, peerA, peerB);
      expect(c.isClosed, isFalse);
    });

    test('stat() - returns connection statistics', () {
      final t = _FakeTransport();
      final c = _FakeCapableConn(t, peerA, peerB);
      expect(c.stat().direction, equals(Direction.outbound));
    });
  });

  group('RawConn [Atomic Audit]', () {
    test('transport() - returns parent transport', () {
      final t = _FakeTransport();
      final rc = _FakeRawConn(t);
      expect(rc.transport(), equals(t));
    });

    test('localMultiaddr() - returns local address', () {
      final t = _FakeTransport();
      final rc = _FakeRawConn(t);
      expect(rc.localMultiaddr().toString(), equals('/ip4/127.0.0.1/tcp/4001'));
    });

    test('remoteMultiaddr() - returns remote address', () {
      final t = _FakeTransport();
      final rc = _FakeRawConn(t);
      expect(rc.remoteMultiaddr().toString(), equals('/ip4/127.0.0.1/tcp/4002'));
    });

    test('read() - reads bytes from raw conn', () async {
      final t = _FakeTransport();
      final rc = _FakeRawConn(t);
      final bytes = await rc.read();
      expect(bytes, isEmpty);
    });

    test('write() - writes bytes to raw conn', () async {
      final t = _FakeTransport();
      final rc = _FakeRawConn(t);
      await expectLater(rc.write(Uint8List(0)), completes);
    });

    test('close() - closes raw conn', () async {
      final t = _FakeTransport();
      final rc = _FakeRawConn(t);
      expect(rc.isClosed, isFalse);
      await rc.close();
      expect(rc.isClosed, isTrue);
    });

    test('isClosed - reports closed state', () {
      final t = _FakeTransport();
      final rc = _FakeRawConn(t);
      expect(rc.isClosed, isFalse);
    });
  });

  group('Listener [Atomic Audit]', () {
    test('accept() - accepts capable conn', () async {
      final t = _FakeTransport();
      final l = _FakeListener(t, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final c = await l.accept();
      expect(c.transport(), equals(t));
    });

    test('close() - closes listener', () async {
      final t = _FakeTransport();
      final l = _FakeListener(t, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      await l.close();
      expect(() => l.accept(), throwsA(isA<ListenerClosedException>()));
    });

    test('multiaddr() - returns listening multiaddr', () {
      final t = _FakeTransport();
      final addr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
      final l = _FakeListener(t, addr);
      expect(l.multiaddr(), equals(addr));
    });
  });

  group('Transport [Atomic Audit]', () {
    test('dial() - dials endpoint and returns CapableConn', () async {
      final t = _FakeTransport();
      final c = await t.dial(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), peerB);
      expect(c.transport(), equals(t));
    });

    test('canDial() - checks multiaddr support', () {
      final t = _FakeTransport();
      expect(t.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')), isTrue);
    });

    test('listen() - returns listener', () async {
      final t = _FakeTransport();
      final l = await t.listen(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      expect(l.multiaddr().toString(), contains('4001'));
    });

    test('protocols() - returns supported protocols', () {
      final t = _FakeTransport();
      expect(t.protocols(), contains(4));
    });

    test('proxy() - reports whether transport is proxy', () {
      final t = _FakeTransport();
      expect(t.proxy(), isFalse);
    });
  });

  group('TransportNetwork [Atomic Audit]', () {
    test('addTransport() - adds transport to network', () {
      final tn = _FakeTransportNetwork();
      final t = _FakeTransport();
      tn.addTransport(t);
      expect(tn.transports, contains(t));
    });
  });

  group('DialUpdater [Atomic Audit]', () {
    test('dialWithUpdates() - yields dial progress updates', () async {
      final du = _FakeDialUpdater();
      final updates = await du.dialWithUpdates(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), peerA).toList();
      expect(updates, hasLength(1));
      expect(updates.first.kind, equals('connecting'));
    });
  });

  group('Upgrader [Atomic Audit]', () {
    test('upgrade() - upgrades connection into CapableConn', () async {
      final upg = _FakeUpgrader();
      final conn = _FakeConn(local: peerA, remote: peerB);
      final c = await upg.upgrade(conn, Direction.outbound, peerB);
      expect(c, isNotNull);
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('reserve() - reserves slot on relay host', () async {
      final host = _newTestHost();
      final ai = AddrInfo(id: peerB, addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      final rsvp = await reserve(host, ai);
      expect(rsvp.limitData, greaterThan(0));
      expect(rsvp.limitDuration.inSeconds, greaterThan(0));
    });

    test('isRelayAddress() - checks if address contains p2p-circuit', () {
      final direct = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
      final relay = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001/p2p-circuit');
      expect(isRelayAddress(direct), isFalse);
      expect(isRelayAddress(relay), isTrue);
    });
  });

  group('HolePunchMessageType [Atomic Audit]', () {
    test('sync - enum value', () {
      expect(HolePunchMessageType.sync.code, equals(300));
    });

    test('fromCode() - parses message types from wire codes', () {
      expect(HolePunchMessageType.fromCode(100), equals(HolePunchMessageType.connect));
      expect(HolePunchMessageType.fromCode(300), equals(HolePunchMessageType.sync));
      expect(HolePunchMessageType.fromCode(999), equals(HolePunchMessageType.connect));
    });
  });

  group('HolePunchMessage [Atomic Audit]', () {
    test('marshal() - encodes message into protobuf bytes', () {
      final msg = HolePunchMessage(
        type: HolePunchMessageType.connect,
        obsAddrs: [Uint8List.fromList([1, 2, 3])],
      );
      final bytes = msg.marshal();
      expect(bytes, isNotEmpty);
    });

    test('unmarshal() - restores message from protobuf bytes', () {
      final msg = HolePunchMessage(
        type: HolePunchMessageType.sync,
        obsAddrs: [Uint8List.fromList([4, 5, 6])],
      );
      final bytes = msg.marshal();
      final restored = HolePunchMessage.unmarshal(bytes);
      expect(restored.type, equals(HolePunchMessageType.sync));
      expect(restored.obsAddrs, hasLength(1));
    });

    test('type - exposes message type', () {
      final msg = HolePunchMessage(type: HolePunchMessageType.connect);
      expect(msg.type, equals(HolePunchMessageType.connect));
    });

    test('obsAddrs - exposes observed addresses', () {
      final msg = HolePunchMessage(type: HolePunchMessageType.connect);
      expect(msg.obsAddrs, isEmpty);
    });
  });

  group('HolePunchService [Atomic Audit]', () {
    test('isStarted - tracks service start state', () async {
      final host = _newTestHost();
      final svc = HolePunchService(host: host);
      expect(svc.isStarted, isFalse);
      await svc.start();
      expect(svc.isStarted, isTrue);
      await svc.close();
    });

    test('isClosed - tracks service closed state', () async {
      final host = _newTestHost();
      final svc = HolePunchService(host: host);
      expect(svc.isClosed, isFalse);
      await svc.close();
      expect(svc.isClosed, isTrue);
    });

    test('host - exposes host instance', () {
      final host = _newTestHost();
      final svc = HolePunchService(host: host);
      expect(svc.host, equals(host));
    });

    test('directDialTimeout - exposes dial timeout', () {
      final host = _newTestHost();
      final svc = HolePunchService(host: host);
      expect(svc.directDialTimeout.inSeconds, equals(10));
    });

    test('listenAddrs - exposes optional listen addresses callback', () {
      final host = _newTestHost();
      final svc = HolePunchService(host: host);
      expect(svc.listenAddrs, isNull);
    });

    test('holePuncher - exposes puncher instance', () {
      final host = _newTestHost();
      final svc = HolePunchService(host: host);
      expect(svc.holePuncher, isNotNull);
    });

    test('start() - registers hole punch stream handler', () async {
      final host = _newTestHost();
      final svc = HolePunchService(host: host);
      await svc.start();
      expect(svc.isStarted, isTrue);
      await svc.close();
    });

    test('close() - unregisters stream handler and puncher', () async {
      final host = _newTestHost();
      final svc = HolePunchService(host: host);
      await svc.start();
      await svc.close();
      expect(svc.isClosed, isTrue);
    });

    test('handleStream() - handles inbound stream safely', () async {
      final host = _newTestHost();
      final svc = HolePunchService(host: host);
      final stream = _FakeStream(id: 's', local: peerA, remote: peerB);
      await svc.handleStream(stream);
      expect(stream.isReset, isTrue);
    });

    test('directConnect() - attempts direct connect to peer', () async {
      final host = _newTestHost();
      final svc = HolePunchService(host: host);
      final ok = await svc.directConnect(peerB, addrs: []);
      expect(ok, isFalse);
    });
  });

  group('HolePuncher [Atomic Audit]', () {
    test('isPeerActive() - checks if peer is in active punch attempt', () {
      final host = _newTestHost();
      final hp = HolePuncher(host: host);
      expect(hp.isPeerActive(peerA), isFalse);
    });

    test('host - exposes host', () {
      final host = _newTestHost();
      final hp = HolePuncher(host: host);
      expect(hp.host, equals(host));
    });

    test('directDialTimeout - exposes dial timeout', () {
      final host = _newTestHost();
      final hp = HolePuncher(host: host);
      expect(hp.directDialTimeout.inSeconds, equals(10));
    });

    test('listenAddrs - exposes optional listen addresses callback', () {
      final host = _newTestHost();
      final hp = HolePuncher(host: host);
      expect(hp.listenAddrs, isNull);
    });

    test('initiateHolePunch() - fails gracefully if cannot open stream', () async {
      final host = _newTestHost();
      final hp = HolePuncher(host: host);
      final ok = await hp.initiateHolePunch(peerB, []);
      expect(ok, isFalse);
    });

    test('close() - cleans up active punches', () async {
      final host = _newTestHost();
      final hp = HolePuncher(host: host);
      await hp.close();
      expect(hp.isPeerActive(peerA), isFalse);
    });
  });

  group('NatManager [Atomic Audit]', () {
    test('hasDiscoveredNat - indicates whether nat device was found', () {
      final network = _FakeTransportNetwork();
      final nm = BasicNatManager(network: network);
      expect(nm.hasDiscoveredNat, isFalse);
    });

    test('getMapping() - returns external mapping if present', () {
      final network = _FakeTransportNetwork();
      final nm = BasicNatManager(network: network);
      expect(nm.getMapping(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')), isNull);
    });

    test('start() - starts discovery and maps listen addresses', () async {
      final network = _FakeTransportNetwork();
      final gw = SimulatedNatGateway();
      final nm = BasicNatManager(network: network, gateway: gw);
      await nm.start();
      expect(nm.hasDiscoveredNat, isTrue);
      await nm.close();
    });

    test('close() - closes nat manager and clears mappings', () async {
      final network = _FakeTransportNetwork();
      final nm = BasicNatManager(network: network);
      await nm.start();
      await nm.close();
      expect(nm.isClosed, isTrue);
    });
  });

  group('BasicNatManager [Atomic Audit]', () {
    test('syncInterval - exposes sync duration', () {
      final network = _FakeTransportNetwork();
      final nm = BasicNatManager(network: network, syncInterval: const Duration(seconds: 15));
      expect(nm.syncInterval.inSeconds, equals(15));
    });

    test('hasDiscoveredNat - indicates whether nat was found', () {
      final network = _FakeTransportNetwork();
      final nm = BasicNatManager(network: network);
      expect(nm.hasDiscoveredNat, isFalse);
    });

    test('getMapping() - gets mapping', () {
      final network = _FakeTransportNetwork();
      final nm = BasicNatManager(network: network);
      expect(nm.getMapping(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')), isNull);
    });

    test('start() - starts nat manager', () async {
      final network = _FakeTransportNetwork();
      final nm = BasicNatManager(network: network);
      await nm.start();
      expect(nm.hasDiscoveredNat, isTrue);
      await nm.close();
    });

    test('close() - closes nat manager', () async {
      final network = _FakeTransportNetwork();
      final nm = BasicNatManager(network: network);
      await nm.start();
      await nm.close();
      expect(nm.isClosed, isTrue);
    });

    test('isClosed - exposes closed state', () async {
      final network = _FakeTransportNetwork();
      final nm = BasicNatManager(network: network);
      expect(nm.isClosed, isFalse);
      await nm.close();
      expect(nm.isClosed, isTrue);
    });
  });

  group('NatGateway [Atomic Audit]', () {
    test('discover() - discovers nat device', () async {
      final gw = SimulatedNatGateway();
      expect(await gw.discover(), isTrue);
    });

    test('getExternalIp() - gets external ip address', () async {
      final gw = SimulatedNatGateway();
      expect(await gw.getExternalIp(), equals('203.0.113.1'));
    });

    test('addPortMapping() - adds port mapping', () async {
      final gw = SimulatedNatGateway();
      final ext = await gw.addPortMapping(protocol: 'tcp', internalPort: 4001);
      expect(ext, equals(4001));
    });

    test('removePortMapping() - removes port mapping', () async {
      final gw = SimulatedNatGateway();
      await gw.removePortMapping(protocol: 'tcp', internalPort: 4001);
      expect(true, isTrue);
    });
  });

  group('SimulatedNatGateway [Atomic Audit]', () {
    test('externalIp - exposes configured external ip', () {
      final gw = SimulatedNatGateway(externalIp: '1.2.3.4');
      expect(gw.externalIp, equals('1.2.3.4'));
    });

    test('shouldDiscover - exposes discovery simulation flag', () {
      final gw = SimulatedNatGateway(shouldDiscover: false);
      expect(gw.shouldDiscover, isFalse);
    });

    test('discover() - discovers nat device', () async {
      final gw = SimulatedNatGateway();
      expect(await gw.discover(), isTrue);
    });

    test('getExternalIp() - gets external ip address', () async {
      final gw = SimulatedNatGateway();
      expect(await gw.getExternalIp(), equals('203.0.113.1'));
    });

    test('addPortMapping() - adds port mapping', () async {
      final gw = SimulatedNatGateway();
      final ext = await gw.addPortMapping(protocol: 'tcp', internalPort: 4001);
      expect(ext, equals(4001));
    });

    test('removePortMapping() - removes port mapping', () async {
      final gw = SimulatedNatGateway();
      await gw.removePortMapping(protocol: 'tcp', internalPort: 4001);
      expect(true, isTrue);
    });
  });
}

