// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
//
// Atomic tests for Marco F.3 (Objetivo 5): the `ObservedAddrManager` port
// (packages/transpiled_libp2p/lib/src/p2p/host/observedaddrs/manager.dart),
// its wiring into `Identify` (.../p2p/protocol/identify/id.dart) and into
// `BasicHost.addrs` (.../p2p/host/basic/basic_host.dart).
import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

/// In-memory byte pipe used to give two [NetworkStream] fakes a real,
/// order-preserving, async-blocking duplex channel -- so
/// `selectOutbound`/`selectInbound` (real multistream-select wire
/// negotiation) and the identify varint-delimited protobuf exchange run
/// unmodified, exactly as they would over a real transport.
class _ByteQueue {
  final List<int> _buf = [];
  Completer<void>? _waiter;

  void add(List<int> data) {
    _buf.addAll(data);
    final w = _waiter;
    if (w != null && !w.isCompleted) w.complete();
  }

  Future<Uint8List> read(int maxLength) async {
    while (_buf.isEmpty) {
      _waiter = Completer<void>();
      await _waiter!.future;
    }
    final n = maxLength < _buf.length ? maxLength : _buf.length;
    final chunk = _buf.sublist(0, n);
    _buf.removeRange(0, n);
    return Uint8List.fromList(chunk);
  }
}

class _PipeStream implements NetworkStream {
  _PipeStream({
    required this.id,
    required Conn conn,
    required _ByteQueue writeQ,
    required _ByteQueue readQ,
  }) : _conn = conn,
       _writeQ = writeQ,
       _readQ = readQ;

  @override
  final String id;
  final Conn _conn;
  final _ByteQueue _writeQ;
  final _ByteQueue _readQ;
  ProtocolId _proto = '';
  bool _closed = false;

  @override
  ProtocolId protocol() => _proto;

  @override
  Future<void> setProtocol(ProtocolId id) async => _proto = id;

  @override
  Stats stat() => Stats(direction: Direction.outbound, opened: DateTime.now());

  @override
  Conn conn() => _conn;

  @override
  StreamScope scope() => const NullScope();

  @override
  Future<void> resetWithError(StreamErrorCode errorCode) async {
    _closed = true;
  }

  @override
  bool get isClosed => _closed;

  @override
  Future<Uint8List> read([int? maxLength]) => _readQ.read(maxLength ?? 4096);

  @override
  Future<void> write(Uint8List data) async => _writeQ.add(data);

  @override
  Future<void> close() async {
    _closed = true;
  }

  @override
  Future<void> reset() async {
    _closed = true;
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

/// A [CapableConn] fake whose `openStream()` optionally wires up a real
/// duplex [_PipeStream] pair and delivers the remote end to [peerNetwork]'s
/// registered incoming-stream handler -- modeling what a real Swarm does
/// when the other side opens a stream on a connection.
class _FakeCapableConn implements CapableConn {
  _FakeCapableConn({
    required this.local,
    required this.remote,
    required Multiaddr localAddr,
    required Multiaddr remoteAddr,
    _FakeNetwork? peerNetwork,
    Conn? peerConn,
  }) : _localAddr = localAddr,
       _remoteAddr = remoteAddr,
       _peerNetwork = peerNetwork,
       _peerConn = peerConn;

  final PeerId local;
  final PeerId remote;
  final Multiaddr _localAddr;
  final Multiaddr _remoteAddr;
  final _FakeNetwork? _peerNetwork;
  final Conn? _peerConn;
  bool closed = false;

  @override
  Transport transport() => throw UnimplementedError();

  @override
  PeerId localPeer() => local;

  @override
  PeerId remotePeer() => remote;

  @override
  PubKey remotePublicKey() => unmarshalEd25519PublicKey(Uint8List(32));

  @override
  ConnectionState connState() => const ConnectionState();

  @override
  Multiaddr localMultiaddr() => _localAddr;

  @override
  Multiaddr remoteMultiaddr() => _remoteAddr;

  @override
  ConnScope scope() => const NullScope();

  @override
  ConnStats stat() =>
      ConnStats(direction: Direction.outbound, opened: DateTime.now());

  @override
  bool get isClosed => closed;

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<NetworkStream> openStream() async {
    final aToB = _ByteQueue();
    final bToA = _ByteQueue();
    final localStream = _PipeStream(
      id: 's-local',
      conn: this,
      writeQ: aToB,
      readQ: bToA,
    );
    final peerConn = _peerConn;
    final peerNetwork = _peerNetwork;
    if (peerConn != null && peerNetwork != null) {
      final remoteStream = _PipeStream(
        id: 's-remote',
        conn: peerConn,
        writeQ: bToA,
        readQ: aToB,
      );
      final handler = peerNetwork.incomingHandler;
      if (handler != null) {
        unawaited(Future(() => handler(remoteStream)));
      }
    }
    return localStream;
  }

  @override
  Future<NetworkStream> acceptStream() => throw UnimplementedError();
}

/// Minimal [Network] fake: exposes fixed listen addrs, records the
/// incoming-stream handler `BasicHost` registers, and tracks
/// `notify`/`stopNotify` so disconnect delivery and [Manager.close]'s
/// unregistration are directly observable.
class _FakeNetwork implements Network {
  _FakeNetwork({
    required this.localPeer,
    List<Multiaddr> listenAddrs = const [],
  }) : _listenAddrs = listenAddrs;

  @override
  final PeerId localPeer;
  final List<Multiaddr> _listenAddrs;
  StreamHandler? incomingHandler;
  final List<Notifiee> notifiees = [];

  @override
  List<Multiaddr> listenAddresses() => _listenAddrs;

  @override
  Future<List<Multiaddr>> interfaceListenAddresses() async => const [];

  @override
  void setStreamHandler(StreamHandler handler) => incomingHandler = handler;

  @override
  Future<NetworkStream> newStream(NetworkContext context, PeerId peer) =>
      throw UnimplementedError();

  @override
  Future<void> listen(List<Multiaddr> addresses) async {}

  @override
  ResourceManager get resourceManager => const NullResourceManager();

  @override
  Object get peerstore => MemoryPeerstore();

  @override
  Future<Conn> dialPeer(NetworkContext context, PeerId peer) =>
      throw UnimplementedError();

  @override
  Future<void> closePeer(PeerId peer) async {}

  @override
  Connectedness connectedness(PeerId peer) => Connectedness.notConnected;

  @override
  List<PeerId> peers() => const [];

  @override
  List<Conn> conns() => const [];

  @override
  List<Conn> connsToPeer(PeerId peer) => const [];

  @override
  void notify(Notifiee notifiee) => notifiees.add(notifiee);

  @override
  void stopNotify(Notifiee notifiee) => notifiees.remove(notifiee);

  @override
  bool canDial(PeerId peer, Multiaddr address) => true;

  @override
  Future<void> close() async {}
}

/// Simple in-test [ObservedAddrsManager] used only to test that
/// `BasicHost.addrs` folds in and caps observed addresses -- independent of
/// the real [Manager]'s own activation logic, which is covered separately.
class _CannedObservedAddrs implements ObservedAddrsManager {
  _CannedObservedAddrs(this.byListenAddr);
  final Map<Multiaddr, List<Multiaddr>> byListenAddr;

  @override
  List<Multiaddr> addrsFor(Multiaddr local) => byListenAddr[local] ?? const [];

  @override
  List<Multiaddr> addrs(int minObservers) => [
    for (final v in byListenAddr.values) ...v,
  ];
}

void main() {
  final peerA = PeerId(value: Uint8List.fromList([1, 2, 3]));
  final peerB = PeerId(value: Uint8List.fromList([4, 5, 6]));

  group('activationThresh [Atomic Audit]', () {
    test(
      "activationThresh - defaults to 4, matching go-libp2p's ActivationThresh",
      () {
        expect(activationThresh, equals(4));
      },
    );
  });

  group('Manager [Atomic Audit]', () {
    test(
      'Manager() - constructs from Network.listenAddresses with no observations recorded yet',
      () {
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [Multiaddr.parse('/ip4/10.0.0.1/tcp/4001')],
        );
        final manager = Manager(BasicBus(), network);
        expect(
          manager.addrsFor(Multiaddr.parse('/ip4/10.0.0.1/tcp/4001')),
          isEmpty,
        );
      },
    );

    test(
      'addrsFor() - returns [] for a multiaddr that is not a thin waist',
      () {
        final network = _FakeNetwork(localPeer: peerA);
        final manager = Manager(BasicBus(), network);
        expect(manager.addrsFor(Multiaddr.empty), isEmpty);
        expect(manager.addrsFor(Multiaddr.parse('/p2p-circuit')), isEmpty);
      },
    );

    test(
      'addrsFor() and start() - records an observation reported via EvtPeerIdentificationCompleted '
      'once activationThresh observers agree, and returns the joined external address',
      () async {
        activationThresh = 1;
        addTearDown(() => activationThresh = 4);

        final listenAddr = Multiaddr.parse('/ip4/10.0.0.1/tcp/4001');
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [listenAddr],
        );
        final bus = BasicBus();
        final manager = Manager(bus, network);
        manager.start(network);
        addTearDown(manager.close);

        final observedOfA = Multiaddr.parse('/ip4/198.51.100.7/tcp/4001');
        final conn = _FakeCapableConn(
          local: peerA,
          remote: peerB,
          localAddr: listenAddr,
          remoteAddr: Multiaddr.parse('/ip4/203.0.113.9/tcp/9999'),
        );

        final emitter = await bus.emitter(EvtPeerIdentificationCompleted);
        await emitter.emit(
          EvtPeerIdentificationCompleted(
            peer: peerB,
            conn: conn,
            observedAddr: observedOfA,
          ),
        );
        // Let the subscription's stream listener run.
        await Future<void>.delayed(Duration.zero);

        final result = manager.addrsFor(listenAddr);
        expect(result, contains(observedOfA));
      },
    );

    test(
      'addrsFor() - rejects a loopback observed address (same conditional as manager.go shouldRecordObservation)',
      () async {
        activationThresh = 1;
        addTearDown(() => activationThresh = 4);

        final listenAddr = Multiaddr.parse('/ip4/10.0.0.1/tcp/4001');
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [listenAddr],
        );
        final bus = BasicBus();
        final manager = Manager(bus, network);
        manager.start(network);
        addTearDown(manager.close);

        final conn = _FakeCapableConn(
          local: peerA,
          remote: peerB,
          localAddr: listenAddr,
          remoteAddr: Multiaddr.parse('/ip4/203.0.113.9/tcp/9999'),
        );

        final emitter = await bus.emitter(EvtPeerIdentificationCompleted);
        await emitter.emit(
          EvtPeerIdentificationCompleted(
            peer: peerB,
            conn: conn,
            observedAddr: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(manager.addrsFor(listenAddr), isEmpty);
      },
    );

    test(
      'addrsFor() - rejects a relayed (/p2p-circuit) observed address',
      () async {
        activationThresh = 1;
        addTearDown(() => activationThresh = 4);

        final listenAddr = Multiaddr.parse('/ip4/10.0.0.1/tcp/4001');
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [listenAddr],
        );
        final bus = BasicBus();
        final manager = Manager(bus, network);
        manager.start(network);
        addTearDown(manager.close);

        final conn = _FakeCapableConn(
          local: peerA,
          remote: peerB,
          localAddr: listenAddr,
          remoteAddr: Multiaddr.parse('/ip4/203.0.113.9/tcp/9999'),
        );

        final relayed = Multiaddr.parse(
          '/ip4/198.51.100.7/tcp/4001/p2p-circuit',
        );
        final emitter = await bus.emitter(EvtPeerIdentificationCompleted);
        await emitter.emit(
          EvtPeerIdentificationCompleted(
            peer: peerB,
            conn: conn,
            observedAddr: relayed,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(manager.addrsFor(listenAddr), isEmpty);
      },
    );

    test(
      'addrsFor() - rejects an observation whose connection local addr is not one of our listen addrs',
      () async {
        activationThresh = 1;
        addTearDown(() => activationThresh = 4);

        final listenAddr = Multiaddr.parse('/ip4/10.0.0.1/tcp/4001');
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [listenAddr],
        );
        final bus = BasicBus();
        final manager = Manager(bus, network);
        manager.start(network);
        addTearDown(manager.close);

        // Connection's local addr (/ip4/10.0.0.9/tcp/4001) is NOT a listen addr.
        final conn = _FakeCapableConn(
          local: peerA,
          remote: peerB,
          localAddr: Multiaddr.parse('/ip4/10.0.0.9/tcp/4001'),
          remoteAddr: Multiaddr.parse('/ip4/203.0.113.9/tcp/9999'),
        );

        final emitter = await bus.emitter(EvtPeerIdentificationCompleted);
        await emitter.emit(
          EvtPeerIdentificationCompleted(
            peer: peerB,
            conn: conn,
            observedAddr: Multiaddr.parse('/ip4/198.51.100.7/tcp/4001'),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(manager.addrsFor(listenAddr), isEmpty);
      },
    );

    test("addrsFor() - rejects a closed connection's observation", () async {
      activationThresh = 1;
      addTearDown(() => activationThresh = 4);

      final listenAddr = Multiaddr.parse('/ip4/10.0.0.1/tcp/4001');
      final network = _FakeNetwork(localPeer: peerA, listenAddrs: [listenAddr]);
      final bus = BasicBus();
      final manager = Manager(bus, network);
      manager.start(network);
      addTearDown(manager.close);

      final conn = _FakeCapableConn(
        local: peerA,
        remote: peerB,
        localAddr: listenAddr,
        remoteAddr: Multiaddr.parse('/ip4/203.0.113.9/tcp/9999'),
      )..closed = true;

      final emitter = await bus.emitter(EvtPeerIdentificationCompleted);
      await emitter.emit(
        EvtPeerIdentificationCompleted(
          peer: peerB,
          conn: conn,
          observedAddr: Multiaddr.parse('/ip4/198.51.100.7/tcp/4001'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(manager.addrsFor(listenAddr), isEmpty);
    });

    test(
      'addrs() - aggregates observed addresses across listen addrs honoring minObservers',
      () async {
        final listenAddr = Multiaddr.parse('/ip4/10.0.0.1/tcp/4001');
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [listenAddr],
        );
        final bus = BasicBus();
        final manager = Manager(bus, network);
        manager.start(network);
        addTearDown(manager.close);

        final observedOfA = Multiaddr.parse('/ip4/198.51.100.7/tcp/4001');
        final emitter = await bus.emitter(EvtPeerIdentificationCompleted);
        // Three distinct observers (distinct /24s) reporting the same address.
        for (final observerIp in [
          '203.0.113.9',
          '203.0.114.9',
          '203.0.115.9',
        ]) {
          final conn = _FakeCapableConn(
            local: peerA,
            remote: peerB,
            localAddr: listenAddr,
            remoteAddr: Multiaddr.parse('/ip4/$observerIp/tcp/9999'),
          );
          await emitter.emit(
            EvtPeerIdentificationCompleted(
              peer: peerB,
              conn: conn,
              observedAddr: observedOfA,
            ),
          );
          await Future<void>.delayed(Duration.zero);
        }

        // 3 observers is below the default activationThresh (4): addrs(0) (=
        // default threshold) must not surface it yet...
        expect(manager.addrs(0), isEmpty);
        // ...but requesting a lower explicit threshold does.
        expect(manager.addrs(3), contains(observedOfA));
      },
    );

    test(
      'start() - stops recording observations for a connection once it disconnects',
      () async {
        activationThresh = 1;
        addTearDown(() => activationThresh = 4);

        final listenAddr = Multiaddr.parse('/ip4/10.0.0.1/tcp/4001');
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [listenAddr],
        );
        final bus = BasicBus();
        final manager = Manager(bus, network);
        manager.start(network);
        addTearDown(manager.close);

        final conn = _FakeCapableConn(
          local: peerA,
          remote: peerB,
          localAddr: listenAddr,
          remoteAddr: Multiaddr.parse('/ip4/203.0.113.9/tcp/9999'),
        );
        final observedOfA = Multiaddr.parse('/ip4/198.51.100.7/tcp/4001');

        final emitter = await bus.emitter(EvtPeerIdentificationCompleted);
        await emitter.emit(
          EvtPeerIdentificationCompleted(
            peer: peerB,
            conn: conn,
            observedAddr: observedOfA,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(manager.addrsFor(listenAddr), contains(observedOfA));

        expect(network.notifiees, isNotEmpty);
        for (final n in List.of(network.notifiees)) {
          n.disconnected(network, conn);
        }

        expect(manager.addrsFor(listenAddr), isEmpty);
      },
    );

    test(
      'close() - unregisters the disconnect notifee and stops delivering new observations',
      () async {
        final listenAddr = Multiaddr.parse('/ip4/10.0.0.1/tcp/4001');
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [listenAddr],
        );
        final bus = BasicBus();
        final manager = Manager(bus, network);
        manager.start(network);
        expect(network.notifiees, isNotEmpty);

        await manager.close();
        expect(network.notifiees, isEmpty);

        final conn = _FakeCapableConn(
          local: peerA,
          remote: peerB,
          localAddr: listenAddr,
          remoteAddr: Multiaddr.parse('/ip4/203.0.113.9/tcp/9999'),
        );
        final emitter = await bus.emitter(EvtPeerIdentificationCompleted);
        await emitter.emit(
          EvtPeerIdentificationCompleted(
            peer: peerB,
            conn: conn,
            observedAddr: Multiaddr.parse('/ip4/198.51.100.7/tcp/4001'),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(manager.addrsFor(listenAddr), isEmpty);
      },
    );
  });

  group('ObservedAddrsManager [Atomic Audit]', () {
    test(
      'addrsFor() - Manager fulfills the ObservedAddrsManager contract with no observations',
      () {
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [Multiaddr.parse('/ip4/10.0.0.1/tcp/4001')],
        );
        final ObservedAddrsManager manager = Manager(BasicBus(), network);
        expect(
          manager.addrsFor(Multiaddr.parse('/ip4/10.0.0.1/tcp/4001')),
          isEmpty,
        );
      },
    );

    test(
      'addrs() - Manager fulfills the ObservedAddrsManager contract with no observations',
      () {
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [Multiaddr.parse('/ip4/10.0.0.1/tcp/4001')],
        );
        final ObservedAddrsManager manager = Manager(BasicBus(), network);
        expect(manager.addrs(1), isEmpty);
      },
    );
  });

  group('BasicHost.addrs with ObservedAddrsManager [Atomic Audit]', () {
    test(
      'addrs - folds observed addresses per listen addr into BasicHost.addrs',
      () {
        final listenAddr = Multiaddr.parse('/ip4/10.0.0.1/tcp/4001');
        final observed = Multiaddr.parse('/ip4/198.51.100.7/tcp/4001');
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [listenAddr],
        );
        final host = BasicHost(
          network: network,
          observedAddrsManager: _CannedObservedAddrs({
            listenAddr: [observed],
          }),
        );

        expect(host.addrs, containsAll(<Multiaddr>[listenAddr, observed]));
      },
    );

    test('addrs - caps observed addresses at 3 per listen addr', () {
      final listenAddr = Multiaddr.parse('/ip4/10.0.0.1/tcp/4001');
      final many = [
        for (var i = 0; i < 5; i++)
          Multiaddr.parse('/ip4/198.51.100.$i/tcp/4001'),
      ];
      final network = _FakeNetwork(localPeer: peerA, listenAddrs: [listenAddr]);
      final host = BasicHost(
        network: network,
        observedAddrsManager: _CannedObservedAddrs({listenAddr: many}),
      );

      final observedInResult = host.addrs.where(many.contains).toList();
      expect(observedInResult.length, equals(3));
    });

    test(
      'addrs - without an ObservedAddrsManager behaves exactly as before (no observed addrs)',
      () {
        final listenAddr = Multiaddr.parse('/ip4/10.0.0.1/tcp/4001');
        final network = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [listenAddr],
        );
        final host = BasicHost(network: network);
        expect(host.addrs, equals([listenAddr]));
      },
    );
  });

  group('IdService observedAddr wiring [Atomic Audit]', () {
    test(
      'start() and identifyWait() - the responder reports our remoteMultiaddr as observedAddr, '
      'and the requester collects it end to end over a real multistream-select exchange',
      () async {
        final networkA = _FakeNetwork(
          localPeer: peerA,
          listenAddrs: [Multiaddr.parse('/ip4/10.0.0.1/tcp/4001')],
        );
        final hostA = BasicHost(network: networkA);
        final idA = IdService(host: hostA);

        final networkB = _FakeNetwork(
          localPeer: peerB,
          listenAddrs: [Multiaddr.parse('/ip4/10.0.0.2/tcp/4002')],
        );
        final hostB = BasicHost(network: networkB);
        final idB = IdService(host: hostB);
        idB.start();
        addTearDown(idB.close);

        final observedOfA = Multiaddr.parse('/ip4/198.51.100.7/tcp/55555');
        final connB = _FakeCapableConn(
          local: peerB,
          remote: peerA,
          localAddr: Multiaddr.parse('/ip4/10.0.0.2/tcp/4002'),
          remoteAddr: observedOfA,
        );
        final connA = _FakeCapableConn(
          local: peerA,
          remote: peerB,
          localAddr: Multiaddr.parse('/ip4/10.0.0.1/tcp/4001'),
          remoteAddr: Multiaddr.parse('/ip4/10.0.0.2/tcp/4002'),
          peerNetwork: networkB,
          peerConn: connB,
        );

        final sub = hostA.eventBus.subscribe(EvtPeerIdentificationCompleted);
        final eventFuture = sub.out().first;

        await idA.identifyWait(connA);

        final evt = await eventFuture as EvtPeerIdentificationCompleted;
        expect(evt.observedAddr, equals(observedOfA));
        await sub.close();
      },
    );

    test(
      'identifyWait() - falls back to an empty observedAddr when the connection cannot open a stream',
      () async {
        final network = _FakeNetwork(localPeer: peerA);
        final host = BasicHost(network: network);
        final idService = IdService(host: host);

        // A ConnSecurity+ConnMultiaddrs conn that is not a CapableConn cannot
        // be identified over the wire; identifyWait must still complete
        // (matching id.go's IdentifyWait, which always closes its channel)
        // with an empty observedAddr rather than throwing.
        final conn = _NonCapableConn(local: peerA, remote: peerB);
        final sub = host.eventBus.subscribe(EvtPeerIdentificationCompleted);
        final eventFuture = sub.out().first;

        await idService.identifyWait(conn);

        final evt = await eventFuture as EvtPeerIdentificationCompleted;
        expect(evt.observedAddr, equals(Multiaddr.empty));
        await sub.close();
      },
    );
  });
}

class _NonCapableConn implements Conn, ConnSecurity, ConnMultiaddrs {
  _NonCapableConn({required this.local, required this.remote});
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
}
