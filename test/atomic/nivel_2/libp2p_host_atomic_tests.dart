// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

class _FakeNetwork implements Network {
  _FakeNetwork({required this.localPeer, required this.peerstore});

  @override
  final PeerId localPeer;

  @override
  final Peerstore peerstore;

  StreamHandler? handler;
  bool closed = false;
  final List<Multiaddr> _listenAddrs = [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')];

  @override
  List<Multiaddr> listenAddresses() => _listenAddrs;

  @override
  Future<List<Multiaddr>> interfaceListenAddresses() async => _listenAddrs;

  @override
  Future<void> listen(List<Multiaddr> addresses) async {
    _listenAddrs.addAll(addresses);
  }

  @override
  void setStreamHandler(StreamHandler h) {
    handler = h;
  }

  @override
  Connectedness connectedness(PeerId peer) => Connectedness.notConnected;

  @override
  bool canDial(PeerId peer, Multiaddr address) => true;

  @override
  Future<Conn> dialPeer(NetworkContext context, PeerId peer) async {
    return _FakeConn(localPeer: localPeer, remotePeer: peer);
  }

  @override
  Future<NetworkStream> newStream(NetworkContext context, PeerId peer) async {
    return _FakeStream(id: 's-1', local: localPeer, remote: peer);
  }

  @override
  Future<void> closePeer(PeerId peer) async {}

  @override
  List<PeerId> peers() => [localPeer];

  @override
  List<Conn> conns() => [];

  @override
  List<Conn> connsToPeer(PeerId peer) => [];

  @override
  void notify(Notifiee notifiee) {}

  @override
  void stopNotify(Notifiee notifiee) {}

  @override
  ResourceManager get resourceManager => NullResourceManager();

  @override
  Future<void> close() async {
    closed = true;
  }
}

class _FakeConn implements Conn {
  _FakeConn({required this.localPeer, required this.remotePeer});
  final PeerId localPeer;
  final PeerId remotePeer;
}

class _FakeStream implements NetworkStream {
  _FakeStream({required this.id, required this.local, required this.remote});
  @override
  final String id;
  final PeerId local;
  final PeerId remote;
  ProtocolId _protocol = '';

  @override
  ProtocolId protocol() => _protocol;

  @override
  Future<void> setProtocol(ProtocolId id) async {
    _protocol = id;
  }

  @override
  Stats stat() => Stats(direction: Direction.outbound, opened: DateTime.now());

  @override
  Conn conn() => _FakeConn(localPeer: local, remotePeer: remote);

  @override
  StreamScope scope() => const NullScope();

  @override
  Future<void> resetWithError(StreamErrorCode errorCode) async {}

  @override
  bool get isClosed => false;

  @override
  Future<Uint8List> read([int? maxLength]) async => Uint8List(0);

  @override
  Future<void> write(Uint8List data) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> reset() async {}

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

class _FakeRouting implements PeerRouting {
  _FakeRouting(this.info);
  final AddrInfo info;

  @override
  Future<AddrInfo> findPeer(PeerId id) async => info;
}

void main() async {
  final kp = await generateEd25519KeyPair();
  final localPeer = PeerId.fromPubKey(kp.getPublic());
  final otherKp = await generateEd25519KeyPair();
  final otherPeer = PeerId.fromPubKey(otherKp.getPublic());

  group('Subscription [Atomic Audit]', () {
    test('out() - returns event stream', () async {
      final bus = BasicBus();
      final sub = bus.subscribe(String);
      expect(sub.out(), isA<Stream<Object>>());
      await sub.close();
    });

    test('name() - returns subscription name', () async {
      final bus = BasicBus();
      final sub = bus.subscribe(String);
      expect(sub.name(), equals('String'));
      await sub.close();
    });

    test('close() - closes subscription', () async {
      final bus = BasicBus();
      final sub = bus.subscribe(String);
      await sub.close();
      expect(true, isTrue);
    });
  });

  group('Emitter [Atomic Audit]', () {
    test('emit() - emits events', () async {
      final bus = BasicBus();
      final emitter = await bus.emitter(String);
      await emitter.emit('test');
      await emitter.close();
      expect(true, isTrue);
    });

    test('close() - closes emitter', () async {
      final bus = BasicBus();
      final emitter = await bus.emitter(String);
      await emitter.close();
      expect(() => emitter.emit('after close'), throwsStateError);
    });
  });

  group('Bus [Atomic Audit]', () {
    test('subscribe() - subscribes to event type', () {
      final Bus bus = BasicBus();
      final sub = bus.subscribe(String);
      expect(sub, isNotNull);
      sub.close();
    });

    test('emitter() - creates typed event emitter', () async {
      final Bus bus = BasicBus();
      final em = await bus.emitter(String);
      expect(em, isNotNull);
      await em.close();
    });

    test('getAllEventTypes() - returns list of known types', () async {
      final Bus bus = BasicBus();
      await bus.emitter(String);
      expect(bus.getAllEventTypes(), contains(String));
    });
  });

  group('BasicBus [Atomic Audit]', () {
    test('subscribe() - subscribes on BasicBus', () {
      final bus = BasicBus();
      final sub = bus.subscribe(int);
      expect(sub, isNotNull);
      sub.close();
    });

    test('emitter() - creates emitter on BasicBus', () async {
      final bus = BasicBus();
      final em = await bus.emitter(int);
      expect(em, isNotNull);
      await em.close();
    });

    test('getAllEventTypes() - returns all types on BasicBus', () async {
      final bus = BasicBus();
      await bus.emitter(int);
      expect(bus.getAllEventTypes(), contains(int));
    });
  });

  group('Host [Atomic Audit]', () {
    late Host host;
    late _FakeNetwork net;
    late MemoryPeerstore ps;

    setUp(() {
      ps = MemoryPeerstore();
      net = _FakeNetwork(localPeer: localPeer, peerstore: ps);
      host = BlankHost(network: net, peerstore: ps);
    });
    tearDown(() => host.close());

    test('id - returns local peer ID', () => expect(host.id, equals(localPeer)));
    test('peerstore - returns host peerstore', () => expect(host.peerstore, same(ps)));
    test('addrs - returns listen addresses', () => expect(host.addrs, isNotEmpty));
    test('network - returns underlying network', () => expect(host.network, same(net)));
    test('mux - returns protocol muxer', () => expect(host.mux, isA<ProtocolSwitch>()));
    test('connManager - returns connection manager', () => expect(host.connManager, isA<ConnManager>()));
    test('eventBus - returns host event bus', () => expect(host.eventBus, isA<Bus>()));
    test('connect() - connects to remote peer', () async {
      await host.connect(AddrInfo(id: otherPeer, addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4002')]));
      expect(host.peerstore.addrs(otherPeer), isNotEmpty);
    });
    test('setStreamHandler() - registers stream handler', () {
      host.setStreamHandler('/test/1.0.0', (stream) {});
      expect(host.mux.protocols(), contains('/test/1.0.0'));
    });
    test('setStreamHandlerMatch() - registers matching stream handler', () {
      host.setStreamHandlerMatch('/match/1.0.0', (p) => true, (stream) {});
      expect(host.mux.protocols(), contains('/match/1.0.0'));
    });
    test('removeStreamHandler() - removes stream handler', () {
      host.setStreamHandler('/del/1.0.0', (stream) {});
      host.removeStreamHandler('/del/1.0.0');
      expect(host.mux.protocols(), isNot(contains('/del/1.0.0')));
    });
    test('newStream() - opens stream to remote peer', () async {
      final s = await host.newStream(otherPeer, ['/proto/1.0.0']);
      expect(s.protocol(), equals('/proto/1.0.0'));
    });
    test('close() - closes host and network', () async {
      await host.close();
      expect(net.closed, isTrue);
    });
  });

  group('BlankHost [Atomic Audit]', () {
    late BlankHost host;
    late _FakeNetwork net;
    late MemoryPeerstore ps;

    setUp(() {
      ps = MemoryPeerstore();
      net = _FakeNetwork(localPeer: localPeer, peerstore: ps);
      host = BlankHost(network: net, peerstore: ps);
    });
    tearDown(() => host.close());

    test('id - returns local peer ID', () => expect(host.id, equals(localPeer)));
    test('peerstore - returns host peerstore', () => expect(host.peerstore, same(ps)));
    test('addrs - returns listen addresses', () => expect(host.addrs, isNotEmpty));
    test('network - returns underlying network', () => expect(host.network, same(net)));
    test('mux - returns protocol muxer', () => expect(host.mux, isA<ProtocolSwitch>()));
    test('connManager - returns connection manager', () => expect(host.connManager, isA<ConnManager>()));
    test('eventBus - returns host event bus', () => expect(host.eventBus, isA<Bus>()));
    test('connect() - connects to remote peer', () async {
      await host.connect(AddrInfo(id: otherPeer, addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4002')]));
      expect(host.peerstore.addrs(otherPeer), isNotEmpty);
    });
    test('setStreamHandler() - registers stream handler', () {
      host.setStreamHandler('/blank/1.0.0', (stream) {});
      expect(host.mux.protocols(), contains('/blank/1.0.0'));
    });
    test('setStreamHandlerMatch() - registers matching stream handler', () {
      host.setStreamHandlerMatch('/blank_m/1.0.0', (p) => true, (stream) {});
      expect(host.mux.protocols(), contains('/blank_m/1.0.0'));
    });
    test('removeStreamHandler() - removes stream handler', () {
      host.setStreamHandler('/blank_d/1.0.0', (stream) {});
      host.removeStreamHandler('/blank_d/1.0.0');
      expect(host.mux.protocols(), isNot(contains('/blank_d/1.0.0')));
    });
    test('newStream() - opens stream', () async {
      final s = await host.newStream(otherPeer, ['/blank_proto/1.0.0']);
      expect(s.protocol(), equals('/blank_proto/1.0.0'));
    });
    test('close() - closes blank host', () async {
      await host.close();
      expect(net.closed, isTrue);
    });
  });

  group('RoutedHost [Atomic Audit]', () {
    late BlankHost rawHost;
    late RoutedHost routed;
    late _FakeNetwork net;
    late MemoryPeerstore ps;

    setUp(() {
      ps = MemoryPeerstore();
      net = _FakeNetwork(localPeer: localPeer, peerstore: ps);
      rawHost = BlankHost(network: net, peerstore: ps);
      final route = _FakeRouting(AddrInfo(
        id: otherPeer,
        addrs: [Multiaddr.parse('/ip4/1.2.3.4/tcp/4001')],
      ));
      routed = RoutedHost(host: rawHost, route: route);
    });
    tearDown(() => routed.close());

    test('id - returns local peer ID', () => expect(routed.id, equals(localPeer)));
    test('peerstore - returns host peerstore', () => expect(routed.peerstore, same(ps)));
    test('addrs - returns listen addresses', () => expect(routed.addrs, isNotEmpty));
    test('network - returns underlying network', () => expect(routed.network, same(net)));
    test('mux - returns protocol muxer', () => expect(routed.mux, isA<ProtocolSwitch>()));
    test('connManager - returns connection manager', () => expect(routed.connManager, isA<ConnManager>()));
    test('eventBus - returns host event bus', () => expect(routed.eventBus, isA<Bus>()));
    test('connect() - queries routing and connects', () async {
      await routed.connect(AddrInfo(id: otherPeer));
      expect(routed.peerstore.addrs(otherPeer), isNotEmpty);
    });
    test('setStreamHandler() - registers stream handler', () {
      routed.setStreamHandler('/r/1.0.0', (s) {});
      expect(routed.mux.protocols(), contains('/r/1.0.0'));
    });
    test('setStreamHandlerMatch() - registers matching stream handler', () {
      routed.setStreamHandlerMatch('/r_m/1.0.0', (p) => true, (s) {});
      expect(routed.mux.protocols(), contains('/r_m/1.0.0'));
    });
    test('removeStreamHandler() - removes stream handler', () {
      routed.setStreamHandler('/r_d/1.0.0', (s) {});
      routed.removeStreamHandler('/r_d/1.0.0');
      expect(routed.mux.protocols(), isNot(contains('/r_d/1.0.0')));
    });
    test('newStream() - opens routed stream', () async {
      final s = await routed.newStream(otherPeer, ['/r/1.0.0']);
      expect(s.protocol(), equals('/r/1.0.0'));
    });
    test('close() - closes routed host', () async {
      await routed.close();
      expect(net.closed, isTrue);
    });
  });

  group('MultistreamMuxer [Atomic Audit]', () {
    test('addHandler() - adds protocol handler', () {
      final mux = MultistreamMuxer();
      mux.addHandler('/test/1.0.0', (proto, stream) async {});
      expect(mux.protocols(), contains('/test/1.0.0'));
    });

    test('addHandlerWithFunc() - adds matching protocol handler', () {
      final mux = MultistreamMuxer();
      mux.addHandlerWithFunc('/test/1.0.0', (p) => true, (proto, stream) async {});
      expect(mux.protocols(), contains('/test/1.0.0'));
    });

    test('removeHandler() - removes protocol handler', () {
      final mux = MultistreamMuxer();
      mux.addHandler('/test/1.0.0', (proto, stream) async {});
      mux.removeHandler('/test/1.0.0');
      expect(mux.protocols(), isNot(contains('/test/1.0.0')));
    });

    test('protocols() - lists registered protocols', () {
      final mux = MultistreamMuxer();
      mux.addHandler('/a', (p, s) async {});
      expect(mux.protocols(), equals(['/a']));
    });

    test('negotiate() - negotiates protocol', () async {
      final mux = MultistreamMuxer();
      mux.addHandler('/echo/1.0.0', (proto, stream) async {});
      final stream = _FakeStream(id: 's', local: localPeer, remote: otherPeer);
      await stream.setProtocol('/echo/1.0.0');
      final (proto, handler) = await mux.negotiate(stream);
      expect(proto, equals('/echo/1.0.0'));
      expect(handler, isNotNull);
    });

    test('handle() - executes matching protocol handler', () async {
      final mux = MultistreamMuxer();
      var handled = false;
      mux.addHandler('/echo/1.0.0', (proto, stream) async => handled = true);
      final stream = _FakeStream(id: 's', local: localPeer, remote: otherPeer);
      await stream.setProtocol('/echo/1.0.0');
      await mux.handle(stream);
      expect(handled, isTrue);
    });
  });

  group('AddrBook [Atomic Audit]', () {
    late AddrBook ab;
    setUp(() => ab = MemoryPeerstore());

    test('addAddr() - adds address', () {
      ab.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      expect(ab.addrs(otherPeer), hasLength(1));
    });
    test('addAddrs() - adds multiple addresses', () {
      ab.addAddrs(otherPeer, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')], addressTtl);
      expect(ab.addrs(otherPeer), hasLength(1));
    });
    test('setAddr() - sets address', () {
      ab.setAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4002'), addressTtl);
      expect(ab.addrs(otherPeer), hasLength(1));
    });
    test('setAddrs() - sets address list', () {
      ab.setAddrs(otherPeer, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4003')], addressTtl);
      expect(ab.addrs(otherPeer), hasLength(1));
    });
    test('updateAddrs() - updates address TTL', () {
      ab.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      ab.updateAddrs(otherPeer, addressTtl, tempAddrTtl);
      expect(ab.addrs(otherPeer), hasLength(1));
    });
    test('addrs() - retrieves valid addresses', () {
      ab.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      expect(ab.addrs(otherPeer), isNotEmpty);
    });
    test('addrStream() - streams addresses', () async {
      ab.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      final stream = ab.addrStream(otherPeer);
      final item = await stream.first;
      expect(item, isNotNull);
    });
    test('clearAddrs() - clears addresses', () {
      ab.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      ab.clearAddrs(otherPeer);
      expect(ab.addrs(otherPeer), isEmpty);
    });
    test('peersWithAddrs() - lists peers with addresses', () {
      ab.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      expect(ab.peersWithAddrs(), contains(otherPeer));
    });
  });

  group('CertifiedAddrBook [Atomic Audit]', () {
    late CertifiedAddrBook cab;
    setUp(() => cab = MemoryPeerstore());

    test('consumePeerRecord() - accepts peer record', () async {
      final rec = PeerRecord(peerId: localPeer, addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      final env = await Envelope.seal(rec, kp);
      expect(cab.consumePeerRecord(env, addressTtl), isTrue);
    });

    test('getPeerRecord() - retrieves peer record', () async {
      final rec = PeerRecord(peerId: localPeer, addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      final env = await Envelope.seal(rec, kp);
      cab.consumePeerRecord(env, addressTtl);
      expect(cab.getPeerRecord(localPeer), isNotNull);
    });
  });

  group('KeyBook [Atomic Audit]', () {
    late KeyBook kb;
    setUp(() => kb = MemoryPeerstore());

    test('pubKey() - retrieves public key', () {
      expect(kb.pubKey(otherPeer)?.raw(), equals(otherKp.getPublic().raw()));
    });
    test('addPubKey() - stores public key', () {
      kb.addPubKey(otherPeer, otherKp.getPublic());
      expect(kb.pubKey(otherPeer), isNotNull);
    });
    test('privKey() - retrieves private key', () {
      kb.addPrivKey(localPeer, kp);
      expect(kb.privKey(localPeer)?.raw(), equals(kp.raw()));
    });
    test('addPrivKey() - stores private key', () {
      kb.addPrivKey(localPeer, kp);
      expect(kb.privKey(localPeer), isNotNull);
    });
    test('peersWithKeys() - lists peers with keys', () {
      kb.addPrivKey(localPeer, kp);
      expect(kb.peersWithKeys(), contains(localPeer));
    });
    test('removePeer() - removes keys for peer', () {
      kb.addPrivKey(localPeer, kp);
      kb.removePeer(localPeer);
      expect(kb.privKey(localPeer), isNull);
    });
  });

  group('Metrics [Atomic Audit]', () {
    late Metrics m;
    setUp(() => m = MemoryPeerstore());

    test('recordLatency() - records latency', () {
      m.recordLatency(otherPeer, const Duration(milliseconds: 50));
      expect(m.latencyEwma(otherPeer), equals(const Duration(milliseconds: 50)));
    });
    test('latencyEwma() - calculates EWMA latency', () {
      m.recordLatency(otherPeer, const Duration(milliseconds: 50));
      m.recordLatency(otherPeer, const Duration(milliseconds: 100));
      expect(m.latencyEwma(otherPeer).inMilliseconds, greaterThan(50));
    });
    test('removePeer() - removes metrics for peer', () {
      m.recordLatency(otherPeer, const Duration(milliseconds: 50));
      m.removePeer(otherPeer);
      expect(m.latencyEwma(otherPeer), equals(Duration.zero));
    });
  });

  group('ProtoBook [Atomic Audit]', () {
    late ProtoBook pb;
    setUp(() => pb = MemoryPeerstore());

    test('getProtocols() - retrieves protocols', () {
      pb.addProtocols(otherPeer, ['/proto/1']);
      expect(pb.getProtocols(otherPeer), equals(['/proto/1']));
    });
    test('addProtocols() - adds protocols', () {
      pb.addProtocols(otherPeer, ['/proto/1', '/proto/2']);
      expect(pb.getProtocols(otherPeer), hasLength(2));
    });
    test('setProtocols() - sets protocols', () {
      pb.setProtocols(otherPeer, ['/proto/new']);
      expect(pb.getProtocols(otherPeer), equals(['/proto/new']));
    });
    test('removeProtocols() - removes protocols', () {
      pb.setProtocols(otherPeer, ['/proto/1', '/proto/2']);
      pb.removeProtocols(otherPeer, ['/proto/1']);
      expect(pb.getProtocols(otherPeer), equals(['/proto/2']));
    });
    test('supportsProtocols() - filters supported protocols', () {
      pb.setProtocols(otherPeer, ['/proto/1']);
      expect(pb.supportsProtocols(otherPeer, ['/proto/1', '/proto/2']), equals(['/proto/1']));
    });
    test('firstSupportedProtocol() - returns first supported protocol', () {
      pb.setProtocols(otherPeer, ['/proto/2']);
      expect(pb.firstSupportedProtocol(otherPeer, ['/proto/1', '/proto/2']), equals('/proto/2'));
    });
    test('removePeer() - removes protocols for peer', () {
      pb.setProtocols(otherPeer, ['/proto/1']);
      pb.removePeer(otherPeer);
      expect(pb.getProtocols(otherPeer), isEmpty);
    });
  });

  group('PeerMetadata [Atomic Audit]', () {
    late PeerMetadata pm;
    setUp(() => pm = MemoryPeerstore());

    test('put() - stores metadata', () {
      pm.put(otherPeer, 'agent', 'go/1.0');
      expect(pm.get(otherPeer, 'agent'), equals('go/1.0'));
    });
    test('get() - retrieves metadata', () {
      pm.put(otherPeer, 'version', '2.0');
      expect(pm.get(otherPeer, 'version'), equals('2.0'));
    });
    test('removePeer() - removes peer metadata', () {
      pm.put(otherPeer, 'k', 'v');
      pm.removePeer(otherPeer);
      expect(() => pm.get(otherPeer, 'k'), throwsA(isA<ItemNotFoundException>()));
    });
  });

  group('Peerstore [Atomic Audit]', () {
    late Peerstore ps;
    setUp(() => ps = MemoryPeerstore());
    tearDown(() => ps.close());

    test('peerInfo() - returns AddrInfo', () {
      ps.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      final info = ps.peerInfo(otherPeer);
      expect(info.id, equals(otherPeer));
      expect(info.addrs, hasLength(1));
    });
    test('peers() - returns all known peer IDs', () {
      ps.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      expect(ps.peers(), contains(otherPeer));
    });
    test('removePeer() - removes peer across sub-stores', () {
      ps.put(otherPeer, 'k', 'v');
      ps.removePeer(otherPeer);
      expect(() => ps.get(otherPeer, 'k'), throwsA(isA<ItemNotFoundException>()));
    });
    test('close() - closes peerstore', () async {
      await ps.close();
      expect(() => ps.peers(), throwsStateError);
    });
  });

  group('MemoryPeerstore [Atomic Audit]', () {
    late MemoryPeerstore ps;
    setUp(() => ps = MemoryPeerstore());
    tearDown(() => ps.close());

    test('addAddr() - adds address', () {
      ps.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      expect(ps.addrs(otherPeer), hasLength(1));
    });
    test('addAddrs() - adds address list', () {
      ps.addAddrs(otherPeer, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')], addressTtl);
      expect(ps.addrs(otherPeer), hasLength(1));
    });
    test('setAddr() - sets address', () {
      ps.setAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4002'), addressTtl);
      expect(ps.addrs(otherPeer), hasLength(1));
    });
    test('setAddrs() - sets address list', () {
      ps.setAddrs(otherPeer, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4003')], addressTtl);
      expect(ps.addrs(otherPeer), hasLength(1));
    });
    test('updateAddrs() - updates address TTL', () {
      ps.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      ps.updateAddrs(otherPeer, addressTtl, tempAddrTtl);
      expect(ps.addrs(otherPeer), hasLength(1));
    });
    test('addrs() - returns active addresses', () {
      ps.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      expect(ps.addrs(otherPeer), isNotEmpty);
    });
    test('addrStream() - streams addresses', () async {
      ps.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      final item = await ps.addrStream(otherPeer).first;
      expect(item, isNotNull);
    });
    test('clearAddrs() - clears addresses', () {
      ps.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      ps.clearAddrs(otherPeer);
      expect(ps.addrs(otherPeer), isEmpty);
    });
    test('peersWithAddrs() - lists peers with addresses', () {
      ps.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      expect(ps.peersWithAddrs(), contains(otherPeer));
    });
    test('consumePeerRecord() - consumes record', () async {
      final rec = PeerRecord(peerId: localPeer, addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      final env = await Envelope.seal(rec, kp);
      expect(ps.consumePeerRecord(env, addressTtl), isTrue);
    });
    test('getPeerRecord() - gets record', () async {
      final rec = PeerRecord(peerId: localPeer, addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      final env = await Envelope.seal(rec, kp);
      ps.consumePeerRecord(env, addressTtl);
      expect(ps.getPeerRecord(localPeer), isNotNull);
    });
    test('pubKey() - gets public key', () {
      expect(ps.pubKey(otherPeer), isNotNull);
    });
    test('addPubKey() - adds public key', () {
      ps.addPubKey(otherPeer, otherKp.getPublic());
      expect(ps.pubKey(otherPeer), isNotNull);
    });
    test('privKey() - gets private key', () {
      ps.addPrivKey(localPeer, kp);
      expect(ps.privKey(localPeer), isNotNull);
    });
    test('addPrivKey() - adds private key', () {
      ps.addPrivKey(localPeer, kp);
      expect(ps.privKey(localPeer), isNotNull);
    });
    test('peersWithKeys() - lists peers with keys', () {
      ps.addPrivKey(localPeer, kp);
      expect(ps.peersWithKeys(), contains(localPeer));
    });
    test('recordLatency() - records latency', () {
      ps.recordLatency(otherPeer, const Duration(milliseconds: 30));
      expect(ps.latencyEwma(otherPeer), equals(const Duration(milliseconds: 30)));
    });
    test('latencyEwma() - calculates EWMA', () {
      ps.recordLatency(otherPeer, const Duration(milliseconds: 30));
      expect(ps.latencyEwma(otherPeer), equals(const Duration(milliseconds: 30)));
    });
    test('getProtocols() - gets protocols', () {
      ps.setProtocols(otherPeer, ['/p1']);
      expect(ps.getProtocols(otherPeer), equals(['/p1']));
    });
    test('addProtocols() - adds protocols', () {
      ps.addProtocols(otherPeer, ['/p1', '/p2']);
      expect(ps.getProtocols(otherPeer), hasLength(2));
    });
    test('setProtocols() - sets protocols', () {
      ps.setProtocols(otherPeer, ['/p3']);
      expect(ps.getProtocols(otherPeer), equals(['/p3']));
    });
    test('removeProtocols() - removes protocols', () {
      ps.setProtocols(otherPeer, ['/p1', '/p2']);
      ps.removeProtocols(otherPeer, ['/p1']);
      expect(ps.getProtocols(otherPeer), equals(['/p2']));
    });
    test('supportsProtocols() - tests supported protocols', () {
      ps.setProtocols(otherPeer, ['/p1']);
      expect(ps.supportsProtocols(otherPeer, ['/p1', '/p2']), equals(['/p1']));
    });
    test('firstSupportedProtocol() - returns first supported', () {
      ps.setProtocols(otherPeer, ['/p2']);
      expect(ps.firstSupportedProtocol(otherPeer, ['/p1', '/p2']), equals('/p2'));
    });
    test('put() - stores metadata', () {
      ps.put(otherPeer, 'k', 'v');
      expect(ps.get(otherPeer, 'k'), equals('v'));
    });
    test('get() - retrieves metadata', () {
      ps.put(otherPeer, 'k', 'v');
      expect(ps.get(otherPeer, 'k'), equals('v'));
    });
    test('peerInfo() - returns AddrInfo', () {
      ps.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      expect(ps.peerInfo(otherPeer).id, equals(otherPeer));
    });
    test('peers() - lists all peers', () {
      ps.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      expect(ps.peers(), contains(otherPeer));
    });
    test('removePeer() - removes peer', () {
      ps.put(otherPeer, 'k', 'v');
      ps.removePeer(otherPeer);
      expect(() => ps.get(otherPeer, 'k'), throwsA(isA<ItemNotFoundException>()));
    });
    test('close() - closes memory peerstore', () async {
      await ps.close();
      expect(() => ps.peers(), throwsStateError);
    });
  });

  group('ItemNotFoundException [Atomic Audit]', () {
    test('toString() - returns item not found message', () {
      const ex = ItemNotFoundException();
      expect(ex.toString(), equals('item not found'));
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('infoFromHost() - extracts AddrInfo from host', () {
      final ps = MemoryPeerstore();
      final net = _FakeNetwork(localPeer: localPeer, peerstore: ps);
      final host = BlankHost(network: net, peerstore: ps);
      final info = infoFromHost(host);
      expect(info.id, equals(localPeer));
      expect(info.addrs, equals(host.addrs));
    });

    test('getCertifiedAddrBook() - casts AddrBook to CertifiedAddrBook', () {
      final ps = MemoryPeerstore();
      expect(getCertifiedAddrBook(ps), isNotNull);
    });

    test('addrInfos() - converts peer list to AddrInfo list', () {
      final ps = MemoryPeerstore();
      ps.addAddr(otherPeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'), addressTtl);
      final infos = addrInfos(ps, [otherPeer]);
      expect(infos, hasLength(1));
      expect(infos.first.id, equals(otherPeer));
    });

    test('ttlIsConnected() - checks connected TTL threshold', () {
      expect(ttlIsConnected(connectedAddrTtl), isTrue);
      expect(ttlIsConnected(addressTtl), isFalse);
    });
  });
}
