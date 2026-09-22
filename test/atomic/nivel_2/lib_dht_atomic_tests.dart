// test/atomic/nivel_2/lib_dht_atomic_tests.dart
// Testes atomicos 1 para 1 para o servidor DHT (Marco F.2) e para os
// simbolos novos/alterados do Marco F.1 (tabela de roteamento em runtime).

import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipfs/src/network/libp2p_host.dart';
import 'package:transpiled_ipfs/src/protocols/dht/dht_message.dart';
import 'package:transpiled_ipfs/src/protocols/dht/dht_provider_manager.dart';
import 'package:transpiled_ipfs/src/protocols/dht/dht_server.dart';
import 'package:transpiled_ipfs/src/routing/dht_provider_finder.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_kbucket/transpiled_libp2p_kbucket.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';

// ---------------------------------------------------------------------------
// Helpers e Fakes de Teste
// ---------------------------------------------------------------------------

/// A structurally-valid (but not cryptographically meaningful) sha2-256
/// multihash-shaped PeerId, distinguished by [seed]. `PeerId`'s unnamed
/// constructor doesn't validate its bytes, matching go-libp2p's raw
/// `peer.ID` byte-string semantics.
PeerId _peerId(int seed) =>
    PeerId(value: Uint8List.fromList([0x12, 0x20, ...List.filled(32, seed)]));

class _ZeroLatencyMetrics implements PeerMetrics {
  @override
  Duration latencyEwma(PeerId id) => Duration.zero;
}

RoutingTable _buildRoutingTable(PeerId local) => RoutingTable(
  bucketSize: 20,
  local: local,
  maxLatency: const Duration(minutes: 1),
  metrics: _ZeroLatencyMetrics(),
  usefulnessGracePeriod: const Duration(hours: 1),
);

class _FakeConn implements Conn, ConnSecurity {
  _FakeConn(this._remote);
  final PeerId _remote;
  @override
  PeerId remotePeer() => _remote;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDhtStream implements NetworkStream {
  _FakeDhtStream(this._remotePeer, [Uint8List? wireBytes])
    : _buffer = wireBytes ?? Uint8List(0);

  final PeerId _remotePeer;
  final Uint8List _buffer;
  int _offset = 0;
  final List<Uint8List> written = [];
  @override
  bool isClosed = false;
  bool isReset = false;

  /// Completes when the handler terminates the stream (via `close` or
  /// `reset`). `StreamHandler` is `void Function(NetworkStream)` -- faithful
  /// to go-libp2p's `network.StreamHandler` -- so a `void` closure discards
  /// its body's value and the caller gets `null`, never the handler's
  /// `Future`. Awaiting this instead is how a test observes completion
  /// without changing the production signature.
  final Completer<void> _finished = Completer<void>();
  Future<void> get finished => _finished.future;
  void _markFinished() {
    if (!_finished.isCompleted) _finished.complete();
  }

  @override
  String get id => 'fake-dht-stream';
  @override
  ProtocolId protocol() => '';
  @override
  Future<void> setProtocol(ProtocolId id) async {}
  @override
  Stats stat() => Stats(direction: Direction.inbound, opened: DateTime.now());
  @override
  Conn conn() => _FakeConn(_remotePeer);
  @override
  StreamScope scope() => const NullScope();
  @override
  Future<void> resetWithError(StreamErrorCode errorCode) => reset();
  @override
  Future<void> closeWrite() => close();
  @override
  Future<void> closeRead() => close();
  @override
  Future<void> setReadDeadline(DateTime? time) async {}
  @override
  Future<void> setWriteDeadline(DateTime? time) async {}
  @override
  Future<void> setDeadline(DateTime? d) async {}

  @override
  Future<Uint8List> read([int? maxLength]) async {
    if (_offset >= _buffer.length) return Uint8List(0);
    final remaining = _buffer.length - _offset;
    final count = (maxLength == null || remaining < maxLength)
        ? remaining
        : maxLength;
    final result = Uint8List.fromList(
      _buffer.sublist(_offset, _offset + count),
    );
    _offset += count;
    return result;
  }

  @override
  Future<void> write(Uint8List data) async {
    written.add(data);
  }

  @override
  Future<void> close() async {
    isClosed = true;
    _markFinished();
  }

  @override
  Future<void> reset() async {
    isReset = true;
    isClosed = true;
    _markFinished();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNetwork implements Network {
  @override
  List<Conn> conns() => const [];
  @override
  List<Multiaddr> listenAddresses() => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHost implements Host {
  _FakeHost({PeerId? selfId}) : selfId = selfId ?? _peerId(0) {
    peerstore = MemoryPeerstore();
  }

  final PeerId selfId;
  @override
  late final Peerstore peerstore;

  /// Registered inbound handlers, keyed by protocol id. Dispatch goes
  /// through [_dispatchToHandler], which waits on the stream rather than on
  /// the handler's return value -- see `_FakeDhtStream.finished`.
  final Map<String, dynamic> handlers = {};

  /// Every peer [newStream] was asked to dial, in order. Lets a test assert
  /// that a lookup did (or did not) reach the network.
  final List<PeerId> openedStreams = [];

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
  final Bus _eventBus = BasicBus();
  @override
  Bus get eventBus => _eventBus;
  @override
  Future<void> connect(
    AddrInfo pi, {
    NetworkContext context = NetworkContext.empty,
  }) async {}
  @override
  void setStreamHandler(ProtocolId protocol, StreamHandler handler) {
    handlers[protocol] = handler;
  }

  @override
  void setStreamHandlerMatch(
    ProtocolId pid,
    bool Function(ProtocolId) match,
    StreamHandler handler,
  ) {}
  @override
  void removeStreamHandler(ProtocolId pid) {}
  @override
  Future<NetworkStream> newStream(
    PeerId p,
    List<ProtocolId> protocols, {
    NetworkContext context = NetworkContext.empty,
  }) async {
    openedStreams.add(p);
    return _FakeDhtStream(selfId);
  }

  @override
  Future<void> close() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Invokes the handler registered for [protocol] and waits until it has
/// terminated [stream], which `DhtServer._handleStream` always does before
/// returning (`close` on a clean exit, `reset` on failure).
Future<void> _dispatchToHandler(
  _FakeHost host,
  String protocol,
  _FakeDhtStream stream,
) async {
  (host.handlers[protocol] as StreamHandler)(stream);
  await stream.finished.timeout(const Duration(seconds: 5));
}

/// Strips the varint length frame off one already-written wire message and
/// returns the protobuf body, by feeding it back through [readDhtFrame].
Future<Uint8List> _unframe(Uint8List wireBytes) =>
    readDhtFrame(_FakeDhtStream(_peerId(0), wireBytes));

// ---------------------------------------------------------------------------
// Testes Atomicos
// ---------------------------------------------------------------------------

void main() {
  final sampleCidBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
  final sampleCid = Cid.v1(
    'raw',
    MultihashUtils.sum('sha2-256', sampleCidBytes),
  );

  // Top-level functions

  test('frameDhtMessage() - emoldura corpo com prefixo varint de tamanho', () {
    final body = Uint8List.fromList([10, 20, 30]);
    final framed = frameDhtMessage(body);
    expect(framed.length, equals(body.length + 1));
    expect(framed.last, equals(30));
  });

  test(
    'readDhtFrame() - le um frame prefixado por varint de um stream',
    () async {
      final body = Uint8List.fromList([1, 2, 3]);
      final stream = _FakeDhtStream(_peerId(0), frameDhtMessage(body));
      final read = await readDhtFrame(stream);
      expect(read, equals(body));
    },
  );

  test('readDhtFrame() - lanca FormatException em eof inesperado', () async {
    // A varint continuation byte (high bit set) with nothing following.
    final stream = _FakeDhtStream(_peerId(0), Uint8List.fromList([0x80]));
    expect(() => readDhtFrame(stream), throwsFormatException);
  });

  test(
    'encodeDhtResponse() - inclui type, key e clusterLevelRaw quando informados',
    () {
      final key = Uint8List.fromList([9, 8, 7]);
      final bytes = encodeDhtResponse(type: 4, key: key, clusterLevelRaw: 2);
      final decoded = DhtRequest.fromBytes(bytes);
      expect(decoded.type, equals(4));
      expect(decoded.key, equals(key));
      expect(decoded.clusterLevelRaw, equals(2));
    },
  );

  test(
    'DhtRequest.fromBytes() - decodifica requisicao find_node com key',
    () async {
      final target = _peerId(1);
      final body = await _unframe(
        encodeFindNode(Uint8List.fromList(target.value)),
      );
      final req = DhtRequest.fromBytes(body);
      expect(req.type, equals(4));
      expect(req.key, equals(target.value));
    },
  );

  test(
    'DhtRequest.fromBytes() - decodifica providerPeers de uma requisicao add_provider',
    () async {
      final provider = AddrInfo(
        id: _peerId(2),
        addrs: [Multiaddr.parse('/ip4/1.2.3.4/tcp/4001')],
      );
      final body = await _unframe(encodeAddProvider(sampleCid, provider));
      final req = DhtRequest.fromBytes(body);
      expect(req.type, equals(2));
      expect(req.providerPeers, hasLength(1));
      expect(req.providerPeers.single.id, equals(provider.id));
    },
  );

  // DhtClient
  group('DhtClient [Atomic Audit]', () {
    test('routingTable - expoe a tabela kademlia viva do cliente', () async {
      final host = _FakeHost(selfId: _peerId(0));
      final router = Libp2pRouter(host);
      final client = DhtClient(router: router, bootstrapPeers: []);
      expect(client.routingTable, isA<RoutingTable>());
      expect(client.routingTable.size(), equals(0));
      await client.close();
    });

    test(
      'bootstrap() - nao dispara consulta alguma antes de ser chamado',
      () async {
        final host = _FakeHost(selfId: _peerId(0));
        final client = DhtClient(
          router: Libp2pRouter(host),
          bootstrapPeers: [
            AddrInfo(
              id: _peerId(1),
              addrs: [Multiaddr.parse('/ip4/1.2.3.4/tcp/4001')],
            ),
          ],
        );
        // Construir o cliente nao pode abrir stream nenhum: em Go quem
        // inicia as goroutines de refresh e o `New` com um context, e o
        // equivalente Dart e o bootstrap() explicito.
        await Future<void>.delayed(Duration.zero);
        expect(host.openedStreams, isEmpty);
        await client.close();
      },
    );

    test(
      'bootstrap() - dispara o refresh e close() para de reagendar',
      () async {
        final host = _FakeHost(selfId: _peerId(0));
        final client = DhtClient(
          router: Libp2pRouter(host),
          bootstrapPeers: [
            AddrInfo(
              id: _peerId(1),
              addrs: [Multiaddr.parse('/ip4/1.2.3.4/tcp/4001')],
            ),
          ],
          refreshInterval: const Duration(milliseconds: 30),
        );

        client.bootstrap();
        // Chamar duas vezes nao pode duplicar o agendamento nem lancar.
        client.bootstrap();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(host.openedStreams, isNotEmpty);

        await client.close();
        final afterClose = host.openedStreams.length;
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(
          host.openedStreams.length,
          equals(afterClose),
          reason: 'close() deve cancelar o timer periodico de refresh',
        );
      },
    );
  });

  // ProviderManager
  group('ProviderManager [Atomic Audit]', () {
    test('addProvider() - adiciona provider recuperavel via getProviders', () {
      final store = ProviderManager();
      final key = Uint8List.fromList([1, 2, 3]);
      final provider = AddrInfo(
        id: _peerId(3),
        addrs: [Multiaddr.parse('/ip4/5.6.7.8/tcp/4001')],
      );
      store.addProvider(key, provider);
      final result = store.getProviders(key);
      expect(result, hasLength(1));
      expect(result.single.id, equals(provider.id));
    });

    test('getProviders() - retorna lista vazia para chave desconhecida', () {
      final store = ProviderManager();
      expect(store.getProviders(Uint8List.fromList([9, 9, 9])), isEmpty);
    });

    test('getProviders() - expira registros apos o periodo de validade', () {
      final store = ProviderManager(validity: const Duration(milliseconds: -1));
      final key = Uint8List.fromList([4, 5, 6]);
      store.addProvider(key, AddrInfo(id: _peerId(4), addrs: const []));
      expect(store.getProviders(key), isEmpty);
    });
  });

  // DhtServer
  group('DhtServer [Atomic Audit]', () {
    test('isServing() - modo client nunca registra handlers', () {
      final self = _peerId(0);
      final host = _FakeHost(selfId: self);
      final server = DhtServer(
        router: Libp2pRouter(host),
        routingTable: _buildRoutingTable(self),
        mode: ModeOpt.client,
      )..start();
      expect(server.isServing, isFalse);
      expect(host.handlers.containsKey(dhtProtocol), isFalse);
    });

    test('isServing() - modo auto so serve quando a alcancabilidade vira '
        'publica', () async {
      final self = _peerId(0);
      final host = _FakeHost(selfId: self);
      final server = DhtServer(
        router: Libp2pRouter(host),
        routingTable: _buildRoutingTable(self),
        mode: ModeOpt.auto,
      )..start();
      // Go: a alcancabilidade comeca desconhecida, e sob ModeAuto isso
      // significa cliente (subscriber_notifee.go:108-113).
      expect(server.isServing, isFalse);

      final emitter = await host.eventBus.emitter(EvtLocalReachabilityChanged);
      await emitter.emit(
        const EvtLocalReachabilityChanged(reachability: Reachability.public_),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(server.isServing, isTrue);

      await emitter.emit(
        const EvtLocalReachabilityChanged(reachability: Reachability.private_),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(server.isServing, isFalse);
      await server.close();
    });

    test('close() - para de servir e libera a assinatura', () async {
      final self = _peerId(0);
      final host = _FakeHost(selfId: self);
      final server = DhtServer(
        router: Libp2pRouter(host),
        routingTable: _buildRoutingTable(self),
      )..start();
      expect(server.isServing, isTrue);
      await server.close();
      expect(server.isServing, isFalse);
    });

    test('start() - registra handlers para os protocolos dht wan e lan', () {
      final self = _peerId(0);
      final host = _FakeHost(selfId: self);
      final router = Libp2pRouter(host);
      DhtServer(router: router, routingTable: _buildRoutingTable(self)).start();
      expect(host.handlers.containsKey(dhtProtocol), isTrue);
      expect(host.handlers.containsKey(lanDhtProtocol), isTrue);
    });

    test('start() - responde PING ecoando type e key', () async {
      final self = _peerId(0);
      final host = _FakeHost(selfId: self);
      final router = Libp2pRouter(host);
      DhtServer(router: router, routingTable: _buildRoutingTable(self)).start();

      final key = Uint8List.fromList([1, 2, 3]);
      final pingFramed = frameDhtMessage(encodeDhtResponse(type: 5, key: key));
      final stream = _FakeDhtStream(_peerId(3), pingFramed);
      await _dispatchToHandler(host, dhtProtocol, stream);

      expect(stream.written, hasLength(1));
      final resp = DhtRequest.fromBytes(await _unframe(stream.written.single));
      expect(resp.type, equals(5));
      expect(resp.key, equals(key));
    });

    test(
      'start() - responde FIND_NODE com peers proximos e o alvo prependado quando conhecido',
      () async {
        final self = _peerId(0);
        final host = _FakeHost(selfId: self);
        final router = Libp2pRouter(host);
        final routingTable = _buildRoutingTable(self);

        final known = _peerId(1);
        host.peerstore.addAddrs(known, [
          Multiaddr.parse('/ip4/9.9.9.9/tcp/4001'),
        ], addressTtl);
        routingTable.tryAddPeer(known, queryPeer: true, isReplaceable: false);

        final target = _peerId(2);
        host.peerstore.addAddrs(target, [
          Multiaddr.parse('/ip4/8.8.8.8/tcp/4001'),
        ], addressTtl);

        DhtServer(router: router, routingTable: routingTable).start();

        final stream = _FakeDhtStream(
          _peerId(3),
          encodeFindNode(Uint8List.fromList(target.value)),
        );
        await _dispatchToHandler(host, dhtProtocol, stream);

        final resp = DhtResponse.fromBytes(
          await _unframe(stream.written.single),
        );
        final ids = resp.closerPeers.map((p) => p.id).toList();
        expect(ids.first, equals(target));
        expect(ids, contains(known));
      },
    );

    test(
      'start() - responde GET_PROVIDERS com closerPeers e providerPeers armazenados',
      () async {
        final self = _peerId(0);
        final host = _FakeHost(selfId: self);
        final router = Libp2pRouter(host);
        final routingTable = _buildRoutingTable(self);
        final known = _peerId(1);
        host.peerstore.addAddrs(known, [
          Multiaddr.parse('/ip4/9.9.9.9/tcp/4001'),
        ], addressTtl);
        routingTable.tryAddPeer(known, queryPeer: true, isReplaceable: false);

        final providerStore = ProviderManager();
        final key = Uint8List.fromList(sampleCid.multihash.toBytes());
        final provider = AddrInfo(
          id: _peerId(4),
          addrs: [Multiaddr.parse('/ip4/7.7.7.7/tcp/4001')],
        );
        providerStore.addProvider(key, provider);

        DhtServer(
          router: router,
          routingTable: routingTable,
          providerStore: providerStore,
        ).start();

        final stream = _FakeDhtStream(
          _peerId(3),
          encodeGetProviders(sampleCid),
        );
        await _dispatchToHandler(host, dhtProtocol, stream);

        final resp = DhtResponse.fromBytes(
          await _unframe(stream.written.single),
        );
        expect(resp.closerPeers.map((p) => p.id), contains(known));
        expect(resp.providerPeers.single.id, equals(provider.id));
      },
    );

    test(
      'start() - armazena ADD_PROVIDER quando o remetente e o proprio provider anunciado',
      () async {
        final self = _peerId(0);
        final host = _FakeHost(selfId: self);
        final router = Libp2pRouter(host);
        final providerStore = ProviderManager();
        DhtServer(
          router: router,
          routingTable: _buildRoutingTable(self),
          providerStore: providerStore,
        ).start();

        final announcer = _peerId(5);
        final provider = AddrInfo(
          id: announcer,
          addrs: [Multiaddr.parse('/ip4/6.6.6.6/tcp/4001')],
        );
        final key = Uint8List.fromList(sampleCid.multihash.toBytes());
        final stream = _FakeDhtStream(
          announcer,
          encodeAddProvider(sampleCid, provider),
        );
        await _dispatchToHandler(host, dhtProtocol, stream);

        expect(stream.written, isEmpty);
        expect(providerStore.getProviders(key).single.id, equals(announcer));
      },
    );

    test(
      'start() - ignora ADD_PROVIDER cujo remetente difere do provider anunciado',
      () async {
        final self = _peerId(0);
        final host = _FakeHost(selfId: self);
        final router = Libp2pRouter(host);
        final providerStore = ProviderManager();
        DhtServer(
          router: router,
          routingTable: _buildRoutingTable(self),
          providerStore: providerStore,
        ).start();

        final announced = _peerId(6);
        final impersonator = _peerId(7);
        final provider = AddrInfo(
          id: announced,
          addrs: [Multiaddr.parse('/ip4/1.1.1.1/tcp/4001')],
        );
        final key = Uint8List.fromList(sampleCid.multihash.toBytes());
        final stream = _FakeDhtStream(
          impersonator,
          encodeAddProvider(sampleCid, provider),
        );
        await _dispatchToHandler(host, dhtProtocol, stream);

        expect(stream.isReset, isTrue);
        expect(providerStore.getProviders(key), isEmpty);
      },
    );
  });
}
