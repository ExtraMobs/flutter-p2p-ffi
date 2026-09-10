import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipfs/src/network/libp2p_host.dart';
import 'package:transpiled_ipfs/src/protocols/dht/dht_message.dart';
import 'package:transpiled_ipfs/src/routing/dht_provider_finder.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_varint/transpiled_varint.dart';

void main() {
  group('DhtClient', () {
    final selfPeerId = PeerId.decode(
      '12D3KooWCryG7Mon9orvQxcS1rYZjotPgpwoJNHHKcLLfE4Hf5mV',
    );
    final bootstrapPeer = AddrInfo(
      id: PeerId.decode('12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c'),
      addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')],
    );
    final targetCid = Cid.decode(
      'bafkreibs723667mosvbz3kzygkbpaxkkg6zld7qmxrbh3ky2mreeoyjlue',
    );

    test('persists closerPeers in peerstore with TempAddrTTL', () async {
      final fakeHost = FakeHost(selfId: selfPeerId);
      final router = Libp2pRouter(fakeHost);

      final closerPeer = AddrInfo(
        id: PeerId.decode('12D3KooWDeH2M6r2L9c5Z8n1P3q4R7s8T9u1V2w3X4y5Z6a7B8c9'),
        addrs: [Multiaddr.parse('/ip4/1.2.3.4/tcp/4001')],
      );

      final responseBytes = encodeDhtResponse(closerPeers: [closerPeer]);
      fakeHost.streamHandler = (peerId) => FakeP2PStream(responseBytes);

      final client = DhtClient(
        router: router,
        bootstrapPeers: [bootstrapPeer],
      );

      final providers = await client.findProvidersAsync(targetCid, 1).toList();
      expect(providers, isEmpty);

      // Verify closer peer was persisted into peerstore with tempAddrTtl (2 min)
      final storedAddrs = await router.getAddrs(closerPeer.id);
      expect(storedAddrs, hasLength(1));
      expect(storedAddrs.single.toString(), closerPeer.addrs.single.toString());
      expect(fakeHost.lastAddedTtl, tempAddrTtl);
    });

    test('preserves complete AddrInfo for providers and merges peerstore addrs', () async {
      final fakeHost = FakeHost(selfId: selfPeerId);
      final router = Libp2pRouter(fakeHost);

      final providerPeer = AddrInfo(
        id: PeerId.decode('12D3KooWDeH2M6r2L9c5Z8n1P3q4R7s8T9u1V2w3X4y5Z6a7B8c9'),
        addrs: [Multiaddr.parse('/ip4/5.6.7.8/tcp/4001')],
      );

      // Pre-populate peerstore with an extra address for this provider
      final existingAddr = Multiaddr.parse('/ip4/9.10.11.12/tcp/4001');
      await router.addAddrs(
        AddrInfo(id: providerPeer.id, addrs: [existingAddr]),
      );

      final responseBytes = encodeDhtResponse(providerPeers: [providerPeer]);
      fakeHost.streamHandler = (peerId) => FakeP2PStream(responseBytes);

      final client = DhtClient(
        router: router,
        bootstrapPeers: [bootstrapPeer],
      );

      final providers = await client.findProvidersAsync(targetCid, 1).toList();
      expect(providers, hasLength(1));
      final result = providers.single;
      expect(result.id, providerPeer.id);

      // Provider preserves both the DHT response address and pre-known peerstore address
      final addrStrings = result.addrs.map((a) => a.toString()).toSet();
      expect(addrStrings, contains('/ip4/5.6.7.8/tcp/4001'));
      expect(addrStrings, contains('/ip4/9.10.11.12/tcp/4001'));
    });

    test('discards self peer ID from queries, closerPeers and providers', () async {
      final fakeHost = FakeHost(selfId: selfPeerId);
      final router = Libp2pRouter(fakeHost);

      // Response returns self as closer and provider
      final selfAsCloser = AddrInfo(
        id: selfPeerId,
        addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')],
      );
      final responseBytes = encodeDhtResponse(
        closerPeers: [selfAsCloser],
        providerPeers: [selfAsCloser],
      );
      fakeHost.streamHandler = (peerId) => FakeP2PStream(responseBytes);

      final client = DhtClient(
        router: router,
        bootstrapPeers: [bootstrapPeer, selfAsCloser],
      );

      final providers = await client.findProvidersAsync(targetCid, 1).toList();
      // Self must not be emitted
      expect(providers, isEmpty);

      // Self must not be added to peerstore by closerPeers handling
      expect(fakeHost.addedAddrsForSelf, isFalse);
    });

    test('clean cancellation resets active streams and stops query', () async {
      final fakeHost = FakeHost(selfId: selfPeerId);
      final router = Libp2pRouter(fakeHost);

      final streamCreated = Completer<FakeP2PStream>();
      fakeHost.streamHandler = (peerId) {
        final stream = FakeP2PStream(null, delay: const Duration(seconds: 5));
        streamCreated.complete(stream);
        return stream;
      };

      final client = DhtClient(
        router: router,
        bootstrapPeers: [bootstrapPeer],
        timeout: const Duration(seconds: 10),
      );

      final sub = client.findProvidersAsync(targetCid, 1).listen((_) {});
      final stream = await streamCreated.future;
      expect(stream.isReset, isFalse);

      await sub.cancel();
      // Cancellation must reset active stream
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(stream.isReset, isTrue);
    });

    test('client.close() aborts in-flight streams and rejects new queries', () async {
      final fakeHost = FakeHost(selfId: selfPeerId);
      final router = Libp2pRouter(fakeHost);

      final streamCreated = Completer<FakeP2PStream>();
      fakeHost.streamHandler = (peerId) {
        final stream = FakeP2PStream(null, delay: const Duration(seconds: 5));
        streamCreated.complete(stream);
        return stream;
      };

      final client = DhtClient(
        router: router,
        bootstrapPeers: [bootstrapPeer],
      );

      final sub = client.findProvidersAsync(targetCid, 1).listen((_) {});
      final stream = await streamCreated.future;

      await client.close();
      expect(stream.isReset, isTrue);
      await sub.cancel();

      // Subsequent queries throw StateError
      expect(
        () => client.findProvidersAsync(targetCid, 1),
        throwsStateError,
      );
    });

    test('RPC query timeout resets stream and emits TimeoutException when all fail', () async {
      final fakeHost = FakeHost(selfId: selfPeerId);
      final router = Libp2pRouter(fakeHost);

      fakeHost.streamHandler = (peerId) {
        // Stream never returns, causing RPC timeout
        return FakeP2PStream(null, delay: const Duration(seconds: 10));
      };

      final client = DhtClient(
        router: router,
        bootstrapPeers: [bootstrapPeer],
        timeout: const Duration(milliseconds: 50),
        lookupTimeout: const Duration(milliseconds: 200),
      );

      expect(
        client.findProvidersAsync(targetCid, 1).toList(),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('limits closerPeers to 2 * bucketSize (40)', () async {
      final fakeHost = FakeHost(selfId: selfPeerId);
      final router = Libp2pRouter(fakeHost);

      // Return 50 closer peers
      final closerPeers = [
        for (var i = 0; i < 50; i++)
          AddrInfo(
            id: PeerId(value: Uint8List.fromList([i + 1, ...List.filled(31, 0)])),
            addrs: [Multiaddr.parse('/ip4/10.0.0.1/tcp/${2000 + i}')],
          ),
      ];

      final responseBytes = encodeDhtResponse(closerPeers: closerPeers);
      fakeHost.streamHandler = (peerId) => FakeP2PStream(responseBytes);

      final client = DhtClient(
        router: router,
        bootstrapPeers: [bootstrapPeer],
        bucketSize: 20,
      );

      await client.findProvidersAsync(targetCid, 0).toList();

      // Only the first 40 (2 * 20) should have been processed/added
      expect(fakeHost.addedAddrsCount, lessThanOrEqualTo(40));
    });

    test('executes follow-up query on top K heard peers', () async {
      final fakeHost = FakeHost(selfId: selfPeerId);
      final router = Libp2pRouter(fakeHost);

      final peerA = AddrInfo(
        id: PeerId.decode('12D3KooWDeH2M6r2L9c5Z8n1P3q4R7s8T9u1V2w3X4y5Z6a7B8c9'),
        addrs: [Multiaddr.parse('/ip4/10.0.0.1/tcp/4001')],
      );
      final peerB = AddrInfo(
        id: PeerId.decode('12D3KooWNvV1Z6A3M5P7Q9R2T4U6W8X1Y3Z5A7B9C1D3E5F7G9H1'),
        addrs: [Multiaddr.parse('/ip4/10.0.0.2/tcp/4001')],
      );

      final queriedPeers = <PeerId>[];
      fakeHost.streamHandler = (peerId) {
        queriedPeers.add(peerId);
        // First query (to bootstrap) returns peerA and peerB as closer peers
        if (peerId.toString() == bootstrapPeer.id.toString()) {
          return FakeP2PStream(encodeDhtResponse(closerPeers: [peerA, peerB]));
        }
        // Query to peerA or peerB returns empty response
        return FakeP2PStream(encodeDhtResponse());
      };

      final client = DhtClient(
        router: router,
        bootstrapPeers: [bootstrapPeer],
        alpha: 1,
        beta: 1, // Beta = 1 terminates lookup loop once bootstrap is queried
        bucketSize: 20,
      );

      await client.findProvidersAsync(targetCid, 0).toList();

      // Follow-up must have queried the closer peers
      final queriedBase58 = queriedPeers.map((p) => p.toString()).toSet();
      expect(queriedBase58, contains(bootstrapPeer.id.toString()));
      expect(queriedBase58.contains(peerA.id.toString()) || queriedBase58.contains(peerB.id.toString()), isTrue);
    });
  });
}

class _FakeNetwork implements Network {
  @override
  List<Conn> conns() => const [];
  @override
  List<Multiaddr> listenAddresses() => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePeerStore extends MemoryPeerstore {
  _FakePeerStore(this.host);
  final FakeHost host;

  @override
  void addAddrs(PeerId p, List<Multiaddr> addrs, Duration ttl) {
    if (p == host.selfId) {
      host.addedAddrsForSelf = true;
    }
    host.addedAddrsCount++;
    host.lastAddedTtl = ttl;
    super.addAddrs(p, addrs, ttl);
  }
}

class FakeHost implements Host {
  FakeHost({required this.selfId}) {
    peerstore = _FakePeerStore(this);
  }

  final PeerId selfId;
  late final _FakePeerStore peerstore;
  Duration? lastAddedTtl;
  bool addedAddrsForSelf = false;
  int addedAddrsCount = 0;

  FakeP2PStream Function(PeerId peerId)? streamHandler;

  @override
  PeerId get id => selfId;

  @override
  List<Multiaddr> get addrs => const [];

  @override
  Network get network => _FakeNetwork();

  @override
  ProtocolSwitch get mux => throw UnimplementedError();

  @override
  ConnManager get connManager => const NullConnMgr();

  @override
  Bus get eventBus => BasicBus();

  @override
  Future<void> connect(AddrInfo pi, {NetworkContext context = NetworkContext.empty}) async {}

  @override
  Future<NetworkStream> newStream(
    PeerId p,
    List<ProtocolId> protocols, {
    NetworkContext context = NetworkContext.empty,
  }) async {
    final handler = streamHandler;
    if (handler != null) {
      return handler(p);
    }
    return FakeP2PStream(Uint8List(0));
  }

  @override
  void setStreamHandler(ProtocolId pid, StreamHandler handler) {}

  @override
  void setStreamHandlerMatch(ProtocolId pid, bool Function(ProtocolId) match, StreamHandler handler) {}

  @override
  void removeStreamHandler(ProtocolId pid) {}

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeP2PStream implements NetworkStream {
  FakeP2PStream(Uint8List? responseBytes, {this.delay}) {
    if (responseBytes != null) {
      final framed = [
        ...encodeVarint(responseBytes.length),
        ...responseBytes,
      ];
      _buffer.addAll(framed);
    }
  }

  final List<int> _buffer = [];
  int _offset = 0;
  final Duration? delay;
  @override
  bool isClosed = false;
  bool isReset = false;

  @override
  String get id => 'fake-stream';
  @override
  ProtocolId protocol() => '';
  @override
  Future<void> setProtocol(ProtocolId id) async {}
  @override
  Stats stat() => Stats(direction: Direction.outbound, opened: DateTime.now());
  @override
  Conn conn() => throw UnimplementedError();
  @override
  StreamScope scope() => const NullScope();
  @override
  Future<void> resetWithError(StreamErrorCode errorCode) => reset();
  @override
  Future<void> closeWrite() => close();
  @override
  Future<void> closeRead() => close();
  @override
  Future<void> setReadDeadline(DateTime? time) => setDeadline(time);
  @override
  Future<void> setWriteDeadline(DateTime? time) => setDeadline(time);

  @override
  Future<void> setDeadline(DateTime? d) async {}

  @override
  Future<void> write(Uint8List data) async {}

  @override
  Future<Uint8List> read([int? maxLength]) async {
    if (isReset) throw StateError('stream reset');
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    if (isReset) throw StateError('stream reset');
    if (_offset >= _buffer.length) {
      if (delay != null) throw TimeoutException('read timeout');
      return Uint8List(0);
    }
    final toRead = maxLength == null
        ? _buffer.length - _offset
        : (_buffer.length - _offset < maxLength
            ? _buffer.length - _offset
            : maxLength);
    final chunk = Uint8List.fromList(
      _buffer.sublist(_offset, _offset + toRead),
    );
    _offset += toRead;
    return chunk;
  }

  @override
  Future<void> close() async {
    isClosed = true;
  }

  @override
  Future<void> reset() async {
    isReset = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
