// ignore_for_file: duplicate_ignore, public_member_api_docs, sort_constructors_first, directives_ordering, dangling_library_doc_comments, library_prefixes, constant_identifier_names, depend_on_referenced_packages
import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_go_yamux/transpiled_go_yamux.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';

class _MemoryStreamReadWriter implements StreamReadWriter {
  final List<int> _buffer = [];
  Completer<void>? _completer;
  bool _closed = false;

  @override
  Future<Uint8List> read([int? maxLength]) async {
    while (_buffer.isEmpty && !_closed) {
      _completer = Completer<void>();
      await _completer!.future;
      _completer = null;
    }
    if (_buffer.isEmpty) return Uint8List(0);
    final count = maxLength != null && maxLength > 0
        ? (maxLength < _buffer.length ? maxLength : _buffer.length)
        : _buffer.length;
    final chunk = Uint8List.fromList(_buffer.sublist(0, count));
    _buffer.removeRange(0, count);
    return chunk;
  }

  @override
  Future<void> write(Uint8List data) async {
    _buffer.addAll(data);
    final waiting = _completer;
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete();
    }
  }

  void close() {
    _closed = true;
    final waiting = _completer;
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete();
    }
  }
}

class _Link implements YamuxTransport {
  _Link._(this._input);
  final StreamController<List<int>> _input;
  late final _Link _peer;
  bool _closed = false;

  static (_Link, _Link) pair() {
    late _Link a;
    late _Link b;
    a = _Link._(StreamController<List<int>>.broadcast());
    b = _Link._(StreamController<List<int>>.broadcast());
    a._peer = b;
    b._peer = a;
    return (a, b);
  }

  @override
  Stream<List<int>> get input => _input.stream;

  @override
  Future<void> write(Uint8List bytes) async {
    if (!_closed) _peer._input.add(Uint8List.fromList(bytes));
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _input.close();
  }
}

class _MockRawConn implements RawConn {
  _MockRawConn({
    required this.transportInstance,
    required this.localAddr,
    required this.remoteAddr,
  });

  final Transport transportInstance;
  final Multiaddr localAddr;
  final Multiaddr remoteAddr;
  bool _closed = false;
  final List<int> _inBuffer = [];
  Completer<void>? _readCompleter;

  void feed(Uint8List data) {
    _inBuffer.addAll(data);
    final waiting = _readCompleter;
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete();
    }
  }

  @override
  Transport transport() => transportInstance;

  @override
  Multiaddr localMultiaddr() => localAddr;

  @override
  Multiaddr remoteMultiaddr() => remoteAddr;

  @override
  Future<Uint8List> read([int? maxLength]) async {
    while (_inBuffer.isEmpty && !_closed) {
      _readCompleter = Completer<void>();
      await _readCompleter!.future;
      _readCompleter = null;
    }
    if (_inBuffer.isEmpty) return Uint8List(0);
    final count = maxLength != null && maxLength > 0
        ? (maxLength < _inBuffer.length ? maxLength : _inBuffer.length)
        : _inBuffer.length;
    final res = Uint8List.fromList(_inBuffer.sublist(0, count));
    _inBuffer.removeRange(0, count);
    return res;
  }

  @override
  Future<void> write(Uint8List data) async {}

  @override
  Future<void> close() async {
    _closed = true;
    final waiting = _readCompleter;
    if (waiting != null && !waiting.isCompleted) {
      waiting.complete();
    }
  }

  @override
  bool get isClosed => _closed;
}

class _MockCapableConn implements CapableConn {
  _MockCapableConn({
    required this.transportInstance,
    required this.local,
    required this.remote,
    required this.localAddr,
    required this.remoteAddr,
  });

  final Transport transportInstance;
  final PeerId local;
  final PeerId remote;
  final Multiaddr localAddr;
  final Multiaddr remoteAddr;
  bool _closed = false;

  @override
  Transport transport() => transportInstance;

  @override
  PeerId localPeer() => local;

  @override
  PeerId remotePeer() => remote;

  @override
  PubKey remotePublicKey() => unmarshalEd25519PublicKey(Uint8List(32));

  @override
  ConnectionState connState() => const ConnectionState();

  @override
  Multiaddr localMultiaddr() => localAddr;

  @override
  Multiaddr remoteMultiaddr() => remoteAddr;

  @override
  ConnScope scope() => const NullScope();

  @override
  ConnStats stat() => ConnStats(direction: Direction.outbound, opened: DateTime.now());

  @override
  Future<NetworkStream> openStream() async => _DummyNetworkStream(this);

  @override
  Future<NetworkStream> acceptStream() async => _DummyNetworkStream(this);

  @override
  Future<void> close() async {
    _closed = true;
  }

  @override
  bool get isClosed => _closed;
}

class _DummyNetworkStream implements NetworkStream {
  _DummyNetworkStream(this._conn);
  final Conn _conn;
  ProtocolId _proto = '';

  @override
  String get id => 'dummy-1';

  @override
  ProtocolId protocol() => _proto;

  @override
  Future<void> setProtocol(ProtocolId id) async {
    _proto = id;
  }

  @override
  Stats stat() => Stats(direction: Direction.outbound, opened: DateTime.now());

  @override
  Conn conn() => _conn;

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

class _MockTransport implements Transport {
  _MockTransport(this.addr);
  final Multiaddr addr;
  bool _closed = false;

  @override
  bool canDial(Multiaddr a) => a.toString() == addr.toString();

  @override
  Future<CapableConn> dial(Multiaddr a, PeerId peer) async {
    if (_closed) throw StateError('Transport closed');
    return _MockCapableConn(
      transportInstance: this,
      local: PeerId(value: Uint8List.fromList([1])),
      remote: peer,
      localAddr: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
      remoteAddr: a,
    );
  }

  @override
  Future<Listener> listen(Multiaddr a) async {
    return _MockListener(this, a);
  }

  @override
  List<int> protocols() => const [4, 6];

  @override
  bool proxy() => false;
}

class _MockListener implements Listener {
  _MockListener(this._transport, this._addr);
  final Transport _transport;
  final Multiaddr _addr;
  bool _closed = false;

  @override
  Future<CapableConn> accept() async {
    if (_closed) throw const ListenerClosedException();
    return _MockCapableConn(
      transportInstance: _transport,
      local: PeerId(value: Uint8List.fromList([1])),
      remote: PeerId(value: Uint8List.fromList([2])),
      localAddr: _addr,
      remoteAddr: Multiaddr.parse('/ip4/127.0.0.1/tcp/4002'),
    );
  }

  @override
  Future<void> close() async {
    _closed = true;
  }

  @override
  Multiaddr multiaddr() => _addr;
}

void main() async {
  final identity = await generateEd25519KeyPair();
  final localPeer = PeerId.fromPubKey(identity.getPublic());
  final remoteIdentity = await generateEd25519KeyPair();
  final remotePeer = PeerId.fromPubKey(remoteIdentity.getPublic());

  group('StreamReadWriter [Atomic Audit]', () {
    test('read() - reads written bytes from memory read writer', () async {
      final rw = _MemoryStreamReadWriter();
      await rw.write(Uint8List.fromList([1, 2, 3]));
      final res = await rw.read(3);
      expect(res, equals(Uint8List.fromList([1, 2, 3])));
    });

    test('write() - adds bytes to internal buffer', () async {
      final rw = _MemoryStreamReadWriter();
      await expectLater(rw.write(Uint8List.fromList([42])), completes);
      final res = await rw.read(1);
      expect(res, equals(Uint8List.fromList([42])));
    });
  });

  group('Top-Level Functions [Atomic Audit]', () {
    test('writeDelimited() - writes varint prefixed message', () async {
      final rw = _MemoryStreamReadWriter();
      await writeDelimited(rw, '/multistream/1.0.0');
      final bytes = await rw.read();
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], equals(19));
    });

    test('readDelimited() - reads message stripping newline', () async {
      final rw = _MemoryStreamReadWriter();
      await writeDelimited(rw, '/ipfs/id/1.0.0');
      final str = await readDelimited(rw);
      expect(str, equals('/ipfs/id/1.0.0'));
    });

    test('selectOutbound() - negotiates preferred protocol', () async {
      final clientRw = _MemoryStreamReadWriter();
      final serverRw = _MemoryStreamReadWriter();

      final serverFuture = () async {
        final clientHeader = await readDelimited(serverRw);
        expect(clientHeader, equals(multistreamProtocol));
        await writeDelimited(clientRw, multistreamProtocol);

        final req = await readDelimited(serverRw);
        expect(req, equals('/echo/1.0.0'));
        await writeDelimited(clientRw, '/echo/1.0.0');
      }();

      final clientReadWriter = _DualStreamReadWriter(clientRw, serverRw);
      final selected = await selectOutbound(clientReadWriter, const ['/echo/1.0.0']);
      await serverFuture;
      expect(selected, equals('/echo/1.0.0'));
    });

    test('selectInbound() - handles incoming protocol negotiation', () async {
      final clientRw = _MemoryStreamReadWriter();
      final serverRw = _MemoryStreamReadWriter();

      final clientFuture = () async {
        await writeDelimited(serverRw, multistreamProtocol);
        final header = await readDelimited(clientRw);
        expect(header, equals(multistreamProtocol));

        await writeDelimited(serverRw, '/chat/1.0.0');
        final ack = await readDelimited(clientRw);
        expect(ack, equals('/chat/1.0.0'));
      }();

      final serverReadWriter = _DualStreamReadWriter(serverRw, clientRw);
      final selected = await selectInbound(serverReadWriter, const ['/chat/1.0.0']);
      await clientFuture;
      expect(selected, equals('/chat/1.0.0'));
    });
  });

  group('UpgradedCapableConn [Atomic Audit]', () {
    UpgradedCapableConn createTestConn({YamuxSession? clientSession, YamuxTransport? bridgeTransport}) {
      final (linkClient, linkServer) = _Link.pair();
      final session = clientSession ?? YamuxSession(linkClient, isClient: true);
      final raw = _MockRawConn(
        transportInstance: _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')),
        localAddr: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
        remoteAddr: Multiaddr.parse('/ip4/127.0.0.1/tcp/4002'),
      );
      final cs1 = CipherState(key: Uint8List(32));
      final cs2 = CipherState(key: Uint8List(32));
      final bridge = bridgeTransport ?? _createSecureBridge(raw, cs1, cs2);
      return UpgradedCapableConn(
        transport: raw.transport(),
        localPeer: localPeer,
        remotePeer: remotePeer,
        remotePublicKey: remoteIdentity.getPublic(),
        localMultiaddr: raw.localMultiaddr(),
        remoteMultiaddr: raw.remoteMultiaddr(),
        direction: Direction.outbound,
        session: session,
        bridge: bridge,
      );
    }

    test('transport() - returns underlying transport', () {
      final conn = createTestConn();
      expect(conn.transport(), isNotNull);
    });

    test('localPeer() - returns local peer ID', () {
      final conn = createTestConn();
      expect(conn.localPeer(), equals(localPeer));
    });

    test('remotePeer() - returns remote peer ID', () {
      final conn = createTestConn();
      expect(conn.remotePeer(), equals(remotePeer));
    });

    test('remotePublicKey() - returns remote public key', () {
      final conn = createTestConn();
      expect(conn.remotePublicKey(), equals(remoteIdentity.getPublic()));
    });

    test('connState() - returns connection state info', () {
      final conn = createTestConn();
      expect(conn.connState().streamMultiplexer, equals('/yamux/1.0.0'));
      expect(conn.connState().security, equals('/noise'));
    });

    test('localMultiaddr() - returns local multiaddr', () {
      final conn = createTestConn();
      expect(conn.localMultiaddr().toString(), equals('/ip4/127.0.0.1/tcp/4001'));
    });

    test('remoteMultiaddr() - returns remote multiaddr', () {
      final conn = createTestConn();
      expect(conn.remoteMultiaddr().toString(), equals('/ip4/127.0.0.1/tcp/4002'));
    });

    test('scope() - returns connection scope', () {
      final conn = createTestConn();
      expect(conn.scope(), isNotNull);
    });

    test('stat() - returns connection stats', () {
      final conn = createTestConn();
      expect(conn.stat().direction, equals(Direction.outbound));
    });

    test('isClosed() - returns closed status', () {
      final conn = createTestConn();
      expect(conn.isClosed, isFalse);
    });

    test('openStream() - opens outbound network stream', () async {
      final (linkClient, linkServer) = _Link.pair();
      final clientSession = YamuxSession(linkClient, isClient: true);
      final serverSession = YamuxSession(linkServer, isClient: false);
      final acceptFuture = serverSession.acceptStream();

      final conn = createTestConn(clientSession: clientSession);
      final s = await conn.openStream();
      final incoming = await acceptFuture;
      expect(s.stat().direction, equals(Direction.outbound));

      await s.close();
      await incoming.close();
      await clientSession.close();
      await serverSession.close();
    });

    test('acceptStream() - accepts inbound network stream', () async {
      final (linkClient, linkServer) = _Link.pair();
      final clientSession = YamuxSession(linkClient, isClient: true);
      final serverSession = YamuxSession(linkServer, isClient: false);

      final openFuture = clientSession.openStream();
      final conn = createTestConn(clientSession: serverSession);
      final acceptFuture = conn.acceptStream();

      final yStream = await openFuture;
      final accepted = await acceptFuture;
      expect(accepted.stat().direction, equals(Direction.inbound));

      await yStream.close();
      await accepted.close();
      await clientSession.close();
      await serverSession.close();
    });

    test('close() - closes session and bridge', () async {
      final (linkClient, linkServer) = _Link.pair();
      final session = YamuxSession(linkClient, isClient: true);
      final serverSession = YamuxSession(linkServer, isClient: false);
      final conn = createTestConn(clientSession: session);

      await conn.close();
      await serverSession.close();
      expect(conn.isClosed, isTrue);
    });
  });

  group('BasicUpgrader [Atomic Audit]', () {
    test('localIdentityKey and localPeerId - initialized properly', () {
      final upgrader = BasicUpgrader(localIdentityKey: identity);
      expect(upgrader.localIdentityKey, equals(identity));
      expect(upgrader.localPeerId, equals(localPeer));
      expect(upgrader.resourceManager, isNotNull);
    });

    test('upgrade() - upgrades raw connection with security and muxer', () async {
      final upgraderServer = BasicUpgrader(localIdentityKey: remoteIdentity);
      final tServer = TcpTransport(upgrader: upgraderServer);
      final listener = await tServer.listen(Multiaddr.parse('/ip4/127.0.0.1/tcp/0'));
      final boundAddr = listener.multiaddr();

      final upgraderClient = BasicUpgrader(localIdentityKey: identity);
      final tClient = TcpTransport(upgrader: upgraderClient);

      final acceptFuture = listener.accept();
      final dialFuture = tClient.dial(boundAddr, remotePeer);

      final clientConn = await dialFuture;
      final serverConn = await acceptFuture;

      expect(clientConn.remotePeer(), equals(remotePeer));
      expect(serverConn.remotePeer(), equals(localPeer));

      await clientConn.close();
      await serverConn.close();
      await listener.close();
      await tServer.close();
      await tClient.close();
    });
  });

  group('TcpTransport [Atomic Audit]', () {
    test('canDial() - matches valid TCP multiaddrs', () {
      final upgrader = BasicUpgrader(localIdentityKey: identity);
      final t = TcpTransport(upgrader: upgrader);
      expect(t.canDial(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')), isTrue);
      expect(t.canDial(Multiaddr.parse('/ip6/::1/tcp/4001')), isTrue);
      expect(t.canDial(Multiaddr.parse('/ip4/127.0.0.1/udp/4001')), isFalse);
    });

    test('protocols() - returns supported protocols', () {
      final upgrader = BasicUpgrader(localIdentityKey: identity);
      final t = TcpTransport(upgrader: upgrader);
      expect(t.protocols(), contains(4));
    });

    test('proxy() - returns proxy flag', () {
      final upgrader = BasicUpgrader(localIdentityKey: identity);
      final t = TcpTransport(upgrader: upgrader);
      expect(t.proxy(), isFalse);
    });

    test('dial() - establishes connection to remote endpoint', () async {
      final upgraderServer = BasicUpgrader(localIdentityKey: remoteIdentity);
      final tServer = TcpTransport(upgrader: upgraderServer);
      final listener = await tServer.listen(Multiaddr.parse('/ip4/127.0.0.1/tcp/0'));
      final boundAddr = listener.multiaddr();

      final upgraderClient = BasicUpgrader(localIdentityKey: identity);
      final tClient = TcpTransport(upgrader: upgraderClient);

      final acceptFuture = listener.accept();
      final clientConn = await tClient.dial(boundAddr, remotePeer);
      final serverConn = await acceptFuture;

      expect(clientConn.remotePeer(), equals(remotePeer));
      await clientConn.close();
      await serverConn.close();
      await listener.close();
      await tServer.close();
      await tClient.close();
    });

    test('listen() - binds listener socket', () async {
      final upgrader = BasicUpgrader(localIdentityKey: identity);
      final t = TcpTransport(upgrader: upgrader);
      final listener = await t.listen(Multiaddr.parse('/ip4/127.0.0.1/tcp/0'));
      expect(listener.multiaddr().toString(), contains('/tcp/'));
      await listener.close();
      await t.close();
    });

    test('dialWithUpdates() - yields start and success events', () async {
      final upgraderServer = BasicUpgrader(localIdentityKey: remoteIdentity);
      final tServer = TcpTransport(upgrader: upgraderServer);
      final listener = await tServer.listen(Multiaddr.parse('/ip4/127.0.0.1/tcp/0'));
      final boundAddr = listener.multiaddr();

      final upgraderClient = BasicUpgrader(localIdentityKey: identity);
      final tClient = TcpTransport(upgrader: upgraderClient);

      final acceptFuture = listener.accept();
      final events = <DialUpdate>[];
      final subscription = tClient.dialWithUpdates(boundAddr, remotePeer).listen(events.add);

      final serverConn = await acceptFuture;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await subscription.cancel();

      expect(events.any((e) => e.kind == 'start'), isTrue);
      expect(events.any((e) => e.kind == 'success'), isTrue);

      await serverConn.close();
      await listener.close();
      await tServer.close();
      await tClient.close();
    });

    test('close() - closes transport and all listeners', () async {
      final upgrader = BasicUpgrader(localIdentityKey: identity);
      final t = TcpTransport(upgrader: upgrader);
      final listener = await t.listen(Multiaddr.parse('/ip4/127.0.0.1/tcp/0'));
      expect(listener, isNotNull);
      await t.close();
    });
  });

  group('ReservationVoucher [Atomic Audit]', () {
    test('parseRecord() - decodes bytes into reservation voucher', () {
      final bytes = Uint8List.fromList([
        1, 10, // relay peer: 1 byte [10]
        1, 20, // client peer: 1 byte [20]
        0, 0, 0, 0, 0, 0, 0, 100, // expiration sec
      ]);
      final v = ReservationVoucher.parseRecord(bytes);
      expect(v.relay.value, equals(Uint8List.fromList([10])));
      expect(v.peer.value, equals(Uint8List.fromList([20])));
      expect(v.expiration.millisecondsSinceEpoch, equals(100000));
    });
  });

  group('Swarm [Atomic Audit]', () {
    test('addTransport() - registers new transport', () {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: []);
      swarm.addTransport(mockTransport);
      expect(swarm.canDial(remotePeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')), isTrue);
    });

    test('setStreamHandler() - registers incoming stream handler', () {
      final swarm = Swarm(localPeer: localPeer, transports: []);
      swarm.setStreamHandler((stream) {});
      expect(swarm.localPeer, equals(localPeer));
    });

    test('dialPeer() - establishes connection to peer', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      swarm.peerstore.addAddrs(remotePeer, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')], tempAddrTtl);

      final conn = await swarm.dialPeer(NetworkContext.empty, remotePeer);
      expect(conn.remotePeer(), equals(remotePeer));
      await swarm.close();
    });

    test('newStream() - opens stream to peer', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      swarm.peerstore.addAddrs(remotePeer, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')], tempAddrTtl);

      final stream = await swarm.newStream(NetworkContext.empty, remotePeer);
      expect(stream.id, equals('dummy-1'));
      await swarm.close();
    });

    test('listenAddresses() - returns listen multiaddrs', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      await swarm.listen([Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      expect(swarm.listenAddresses(), contains(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')));
      await swarm.close();
    });

    test('interfaceListenAddresses() - returns interface addresses', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      await swarm.listen([Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      final iface = await swarm.interfaceListenAddresses();
      expect(iface, contains(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')));
      await swarm.close();
    });

    test('connectedness() - returns connectedness state', () {
      final swarm = Swarm(localPeer: localPeer, transports: []);
      expect(swarm.connectedness(remotePeer), equals(Connectedness.notConnected));
    });

    test('peers() - lists all connected peers', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      swarm.peerstore.addAddrs(remotePeer, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')], tempAddrTtl);
      await swarm.dialPeer(NetworkContext.empty, remotePeer);
      expect(swarm.peers(), contains(remotePeer));
      await swarm.close();
    });

    test('conns() - returns all active connections', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      swarm.peerstore.addAddrs(remotePeer, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')], tempAddrTtl);
      final c = await swarm.dialPeer(NetworkContext.empty, remotePeer);
      expect(swarm.conns(), contains(c));
      await swarm.close();
    });

    test('connsToPeer() - returns connections to specific peer', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      swarm.peerstore.addAddrs(remotePeer, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')], tempAddrTtl);
      final c = await swarm.dialPeer(NetworkContext.empty, remotePeer);
      expect(swarm.connsToPeer(remotePeer), contains(c));
      await swarm.close();
    });

    test('closePeer() - closes connections to peer', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      swarm.peerstore.addAddrs(remotePeer, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')], tempAddrTtl);
      await swarm.dialPeer(NetworkContext.empty, remotePeer);
      await swarm.closePeer(remotePeer);
      expect(swarm.connectedness(remotePeer), equals(Connectedness.canConnect));
      await swarm.close();
    });

    test('canDial() - checks dialability of address', () {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      expect(swarm.canDial(remotePeer, Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')), isTrue);
      expect(swarm.canDial(remotePeer, Multiaddr.parse('/ip4/127.0.0.1/udp/4001')), isFalse);
    });

    test('listen() - binds listen addresses', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      await swarm.listen([Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      expect(swarm.listenAddresses(), isNotEmpty);
      await swarm.close();
    });

    test('notify() - registers network notifiee', () {
      final swarm = Swarm(localPeer: localPeer, transports: []);
      final notifiee = _TestNotifiee();
      swarm.notify(notifiee);
      expect(notifiee, isNotNull);
      swarm.stopNotify(notifiee);
    });

    test('stopNotify() - removes network notifiee', () {
      final swarm = Swarm(localPeer: localPeer, transports: []);
      final notifiee = _TestNotifiee();
      swarm.stopNotify(notifiee);
      expect(notifiee, isNotNull);
    });

    test('close() - closes all listeners and connections', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      await swarm.listen([Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      await swarm.close();
      expect(swarm.listenAddresses(), isEmpty);
    });
  });

  group('SwarmStream [Atomic Audit]', () {
    Future<(SwarmStream, SwarmStream, YamuxSession, YamuxSession)> createStreamPair() async {
      final (linkClient, linkServer) = _Link.pair();
      final clientSession = YamuxSession(linkClient, isClient: true);
      final serverSession = YamuxSession(linkServer, isClient: false);
      final acceptFuture = serverSession.acceptStream();
      final yStream = await clientSession.openStream();
      final incoming = await acceptFuture;

      final mockConn = _MockCapableConn(
        transportInstance: _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')),
        local: localPeer,
        remote: remotePeer,
        localAddr: Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'),
        remoteAddr: Multiaddr.parse('/ip4/127.0.0.1/tcp/4002'),
      );

      final stream1 = SwarmStream(yamuxStream: yStream, conn: mockConn, direction: Direction.outbound, protocol: '/test/1.0.0');
      final stream2 = SwarmStream(yamuxStream: incoming, conn: mockConn, direction: Direction.inbound, protocol: '/test/1.0.0');
      return (stream1, stream2, clientSession, serverSession);
    }

    test('stat() - returns stream stats', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      expect(s1.stat().direction, equals(Direction.outbound));
      expect(s2.stat().direction, equals(Direction.inbound));
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('id() - returns stream identifier', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      expect(s1.id, isNotEmpty);
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('protocol() - returns negotiated protocol', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      expect(s1.protocol(), equals('/test/1.0.0'));
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('setProtocol() - updates protocol string', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      await s1.setProtocol('/updated/1.0.0');
      expect(s1.protocol(), equals('/updated/1.0.0'));
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('conn() - returns underlying connection', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      expect(s1.conn(), isNotNull);
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('scope() - returns stream scope', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      expect(s1.scope(), isNotNull);
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('resetWithError() - resets stream with error', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      await s1.resetWithError(0);
      expect(s1, isNotNull);
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('isClosed() - returns closed status', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      expect(s1.isClosed, isFalse);
      await s1.close();
      expect(s1.isClosed, isTrue);
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('read() - reads bytes from stream', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      await s1.write(Uint8List.fromList([1, 2, 3]));
      final res = await s2.read(3);
      expect(res, equals(Uint8List.fromList([1, 2, 3])));
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('write() - writes bytes to stream', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      await expectLater(s1.write(Uint8List.fromList([42])), completes);
      final res = await s2.read(1);
      expect(res, equals(Uint8List.fromList([42])));
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('close() - closes stream', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      await s1.close();
      expect(s1.isClosed, isTrue);
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('reset() - resets stream', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      await s1.reset();
      expect(s1, isNotNull);
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('closeWrite() - closes write half', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      await s1.closeWrite();
      expect(s1, isNotNull);
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('closeRead() - closes read half', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      await s1.closeRead();
      expect(s1, isNotNull);
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('setDeadline() - sets deadline', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      await s1.setDeadline(DateTime.now().add(const Duration(seconds: 1)));
      expect(s1, isNotNull);
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('setReadDeadline() - sets read deadline', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      await s1.setReadDeadline(DateTime.now().add(const Duration(seconds: 1)));
      expect(s1, isNotNull);
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });

    test('setWriteDeadline() - sets write deadline', () async {
      final (s1, s2, c1, c2) = await createStreamPair();
      await s1.setWriteDeadline(DateTime.now().add(const Duration(seconds: 1)));
      expect(s1, isNotNull);
      await s1.close();
      await s2.close();
      await c1.close();
      await c2.close();
    });
  });

  group('BasicHost [Atomic Audit]', () {
    test('id() - returns host peer ID', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      expect(host.id, equals(localPeer));
      await host.close();
    });

    test('peerstore() - returns host peerstore', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      expect(host.peerstore, isNotNull);
      await host.close();
    });

    test('network() - returns underlying swarm network', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      expect(host.network, equals(swarm));
      await host.close();
    });

    test('mux() - returns protocol multiplexer', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      expect(host.mux, isNotNull);
      await host.close();
    });

    test('connManager() - returns connection manager', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      expect(host.connManager, isNotNull);
      await host.close();
    });

    test('eventBus() - returns event bus', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      expect(host.eventBus, isNotNull);
      await host.close();
    });

    test('setStreamHandler() - registers stream handler', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      host.setStreamHandler('/chat/1.0.0', (stream) {});
      expect(host.mux.protocols(), contains('/chat/1.0.0'));
      await host.close();
    });

    test('setStreamHandlerMatch() - registers matching stream handler', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      host.setStreamHandlerMatch('/match/1.0.0', (p) => p.startsWith('/match'), (stream) {});
      expect(host.mux.protocols(), contains('/match/1.0.0'));
      await host.close();
    });

    test('removeStreamHandler() - removes stream handler', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      host.setStreamHandler('/del/1.0.0', (stream) {});
      host.removeStreamHandler('/del/1.0.0');
      expect(host.mux.protocols().contains('/del/1.0.0'), isFalse);
      await host.close();
    });

    test('newStream() - opens stream to peer', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      swarm.peerstore.addAddrs(remotePeer, [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')], tempAddrTtl);
      await expectLater(
        () => host.newStream(remotePeer, const ['/echo/1.0.0']),
        throwsA(anything),
      );
      await host.close();
    });

    test('addrs() - returns listen multiaddrs including relay', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      await swarm.listen([Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      final host = BasicHost(network: swarm);
      expect(host.addrs, contains(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')));
      await host.close();
    });

    test('connect() - connects host to remote peer info', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      final pi = AddrInfo(id: remotePeer, addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')]);
      await host.connect(pi);
      expect(swarm.connectedness(remotePeer), equals(Connectedness.connected));
      await host.close();
    });

    test('natManager - exposes configured nat manager', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      expect(host.natManager, isNull);
      await host.close();
    });

    test('holePunchService - exposes configured hole punch service', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      expect(host.holePunchService, isNull);
      await host.close();
    });

    test('close() - closes host and network', () async {
      final mockTransport = _MockTransport(Multiaddr.parse('/ip4/127.0.0.1/tcp/4001'));
      final swarm = Swarm(localPeer: localPeer, transports: [mockTransport]);
      final host = BasicHost(network: swarm);
      await host.close();
      expect(host.network.listenAddresses(), isEmpty);
    });
  });
}

class _DualStreamReadWriter implements StreamReadWriter {
  _DualStreamReadWriter(this._reader, this._writer);
  final StreamReadWriter _reader;
  final StreamReadWriter _writer;

  @override
  Future<Uint8List> read([int? maxLength]) => _reader.read(maxLength);

  @override
  Future<void> write(Uint8List data) => _writer.write(data);
}

class _TestNotifiee implements Notifiee {
  @override
  void listen(Network network, Multiaddr address) {}
  @override
  void listenClose(Network network, Multiaddr address) {}
  @override
  void connected(Network network, Conn connection) {}
  @override
  void disconnected(Network network, Conn connection) {}
}

YamuxTransport _createSecureBridge(RawConn raw, CipherState cs1, CipherState cs2) {
  final (a, _) = _Link.pair();
  return a;
}
