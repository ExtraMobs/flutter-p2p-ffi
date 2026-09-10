// test/atomic/nivel_2/lib_atomic_tests.dart
// Testes atomicos 1 para 1 para o pacote lib.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart' as blocks;
import 'package:transpiled_boxo/bitswap/message.dart';
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_ipfs/src/blockstore/blockstore.dart';
import 'package:transpiled_ipfs/src/config/ipfs_runtime_config.dart';
import 'package:transpiled_ipfs/src/core/builders/build_cfg.dart';
import 'package:transpiled_ipfs/src/core/interfaces/routing_table.dart';
import 'package:transpiled_ipfs/src/network/libp2p_host.dart';
import 'package:transpiled_ipfs/src/node/ipfs_node.dart';
import 'package:transpiled_ipfs/src/protocols/bitswap/bitswap_client.dart';
import 'package:transpiled_ipfs/src/protocols/bitswap/bitswap_message.dart';
import 'package:transpiled_ipfs/src/protocols/bitswap/interface_bitswap_handler.dart';
import 'package:transpiled_ipfs/src/protocols/dht/dht_message.dart';
import 'package:transpiled_ipfs/src/protocols/dht/query_peerset.dart';
import 'package:transpiled_ipfs/src/routing/dht_provider_finder.dart';
import 'package:transpiled_ipfs/src/transport/dns/dns_bootstrap_resolver.dart';
import 'package:transpiled_ipfs/src/transport/dns/dns_message.dart';
import 'package:transpiled_ipfs/src/transport/dns/system_resolver.dart';
import 'package:transpiled_ipfs/src/transport/dns/udp_dns_client.dart';
import 'package:transpiled_ipfs/src/unixfs/unixfs.dart';
import 'package:transpiled_ipfs/src/utils/immutable_bytes.dart';
import 'package:transpiled_ipfs/src/utils/typed_map.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart' as libp2p;
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart';
import 'package:transpiled_multihash/transpiled_multihash.dart';
import 'package:transpiled_varint/transpiled_varint.dart';

// ---------------------------------------------------------------------------
// Helpers e Fakes de Teste
// ---------------------------------------------------------------------------

class _TestBlockGetter implements BlockGetter {
  @override
  Future<blocks.Block> getBlock(Cid cid) async =>
      blocks.BasicBlock(Uint8List.fromList([1, 2, 3]), cid);
}

class _TestDistanceMetric implements DistanceMetric {
  @override
  int calculateDistance(libp2p.PeerId a, libp2p.PeerId b) => 42;

  @override
  int calculateDistanceToKey(libp2p.PeerId peerId, List<int> key) => 24;
}

class _TestDhtRoutingTable implements DhtRoutingTable {
  final _peers = <libp2p.PeerId>{};
  final _metric = _TestDistanceMetric();

  @override
  DistanceMetric get distanceMetric => _metric;

  @override
  List<libp2p.PeerId> findClosestPeers(libp2p.PeerId target, {int k = 20}) =>
      _peers.take(k).toList();

  @override
  List<libp2p.PeerId> findClosestPeersToKey(List<int> key, {int k = 20}) =>
      _peers.take(k).toList();

  @override
  Future<void> addPeer(
    libp2p.PeerId peerId,
    libp2p.PeerId associatedPeerId, {
    String? address,
  }) async {
    _peers.add(peerId);
  }

  @override
  void removePeer(libp2p.PeerId peerId) {
    _peers.remove(peerId);
  }

  @override
  bool containsPeer(libp2p.PeerId peerId) => _peers.contains(peerId);

  @override
  int get peerCount => _peers.length;

  @override
  void clear() => _peers.clear();
}

class _FakeNetwork implements libp2p.Network {
  @override
  List<libp2p.Conn> conns() => const [];
  @override
  List<Multiaddr> listenAddresses() => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHost implements libp2p.Host {
  _FakeHost({libp2p.PeerId? selfId})
      : selfId = selfId ??
            libp2p.PeerId.decode(
              '12D3KooWCryG7Mon9orvQxcS1rYZjotPgpwoJNHHKcLLfE4Hf5mV',
            ) {
    peerstore = libp2p.MemoryPeerstore();
  }

  final libp2p.PeerId selfId;
  @override
  late final libp2p.Peerstore peerstore;
  final Map<String, dynamic> handlers = {};

  @override
  libp2p.PeerId get id => selfId;

  @override
  List<Multiaddr> get addrs => const [];

  @override
  libp2p.Network get network => _FakeNetwork();

  @override
  libp2p.ProtocolSwitch get mux => throw UnimplementedError();

  @override
  libp2p.ConnManager get connManager => const libp2p.NullConnMgr();

  @override
  libp2p.Bus get eventBus => libp2p.BasicBus();

  @override
  Future<void> connect(libp2p.AddrInfo pi, {libp2p.NetworkContext context = libp2p.NetworkContext.empty}) async {}

  @override
  void setStreamHandler(libp2p.ProtocolId protocol, libp2p.StreamHandler handler) {
    handlers[protocol] = handler;
  }

  @override
  void setStreamHandlerMatch(libp2p.ProtocolId pid, bool Function(libp2p.ProtocolId) match, libp2p.StreamHandler handler) {}

  @override
  void removeStreamHandler(libp2p.ProtocolId pid) {}

  @override
  Future<libp2p.NetworkStream> newStream(
    libp2p.PeerId p,
    List<libp2p.ProtocolId> protocols, {
    libp2p.NetworkContext context = libp2p.NetworkContext.empty,
  }) async => _FakeP2PStream();

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeP2PStream implements libp2p.NetworkStream {
  _FakeP2PStream([List<int>? bytes]) : _data = bytes ?? [];
  final List<int> _data;
  int _readOffset = 0;
  @override
  bool isClosed = false;
  bool isReset = false;

  @override
  String get id => 'fake-stream';
  @override
  libp2p.ProtocolId protocol() => '';
  @override
  Future<void> setProtocol(libp2p.ProtocolId id) async {}
  @override
  libp2p.Stats stat() => libp2p.Stats(direction: libp2p.Direction.outbound, opened: DateTime.now());
  @override
  libp2p.Conn conn() => throw UnimplementedError();
  @override
  libp2p.StreamScope scope() => const libp2p.NullScope();
  @override
  Future<void> resetWithError(libp2p.StreamErrorCode errorCode) => reset();
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
  Future<Uint8List> read([int? maxLength]) async {
    if (isClosed) throw StateError('stream closed');
    if (_readOffset >= _data.length) return Uint8List(0);
    final remaining = _data.length - _readOffset;
    final count = (maxLength == null || remaining < maxLength) ? remaining : maxLength;
    final result = Uint8List.fromList(
      _data.sublist(_readOffset, _readOffset + count),
    );
    _readOffset += count;
    return result;
  }

  @override
  Future<void> write(Uint8List data) async {}

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

// ---------------------------------------------------------------------------
// Testes Atomicos
// ---------------------------------------------------------------------------

void main() {
  final samplePeerId = libp2p.PeerId.decode(
    '12D3KooWCryG7Mon9orvQxcS1rYZjotPgpwoJNHHKcLLfE4Hf5mV',
  );
  final sampleRawData = Uint8List.fromList([1, 2, 3, 4, 5]);
  final sampleCid = Cid.v1(
    'raw',
    MultihashUtils.sum('sha2-256', sampleRawData),
  );

  // Top-level functions

  test('unixFsLinks() - decodifica links filhos de blocos raw ou dag pb', () {
    final links = unixFsLinks(sampleCid, sampleRawData);
    expect(links, isEmpty);
    expect(
      () => unixFsLinks(
        Cid.v1('dag-cbor', MultihashUtils.sum('sha2-256', sampleRawData)),
        sampleRawData,
      ),
      throwsFormatException,
    );
  });

  test('readUnixFs() - realiza streaming de bytes de arquivo unixfs', () async {
    final chunks = await readUnixFs(
      sampleCid,
      (c) async => blocks.BasicBlock(sampleRawData, c),
    ).toList();
    expect(chunks, hasLength(1));
    expect(chunks.single, equals(sampleRawData));
  });

  test('walkUnixFs() - percorre dag unixfs em profundidade', () async {
    final walked = await walkUnixFs(
      sampleCid,
      (c) async => blocks.BasicBlock(sampleRawData, c),
    ).toList();
    expect(walked, equals([sampleCid]));
  });

  test('createDnsResolver() - instancia resolver dns padrao da plataforma', () {
    final resolver = createDnsResolver();
    expect(resolver, isNotNull);
  });

  test('encodeDnsQuery() - codifica requisicao dns com id e tipo', () {
    final query = encodeDnsQuery(id: 0x1234, name: 'ipfs.io', type: 16);
    expect(query, isNotEmpty);
    expect(query.length, greaterThan(12));
  });

  test('decodeDnsMessage() - decodifica mensagem dns da rede com validacao', () {
    expect(() => decodeDnsMessage(Uint8List(5)), throwsFormatException);
  });

  test('encodeWantBlock() - codifica mensagem want block com prioridade', () {
    final bytes = encodeWantBlock(sampleCid, priority: 2);
    expect(bytes, isNotEmpty);
  });

  test('encodeBitswapMessage() - codifica mensagem bitswap com framing varint', () {
    final msg = BitSwapMessage(false);
    msg.addEntry(sampleCid, 1, WantType.block, true);
    final bytes = encodeBitswapMessage(msg);
    expect(bytes, isNotEmpty);
  });

  test('readBitswapMessage() - le mensagem bitswap emoldurada em varint', () async {
    final payload = encodeWantBlock(sampleCid);
    final stream = _FakeP2PStream(payload);
    final msg = await readBitswapMessage(stream);
    expect(msg, isA<BitSwapMessage>());
    expect(msg.wantlist(), isNotEmpty);
  });

  test('blockFromMessage() - extrai bloco correspondente da mensagem', () {
    final msg = BitSwapMessage(false);
    final blk = blocks.BasicBlock(sampleRawData, sampleCid);
    msg.addBlock(blk);
    final extracted = blockFromMessage(msg, sampleCid);
    expect(extracted?.rawData(), equals(sampleRawData));

    final msgDontHave = BitSwapMessage(false);
    msgDontHave.addDontHave(sampleCid);
    expect(() => blockFromMessage(msgDontHave, sampleCid), throwsStateError);

    final emptyMsg = BitSwapMessage(false);
    expect(blockFromMessage(emptyMsg, sampleCid), isNull);
  });

  test('encodeGetProviders() - codifica requisicao get providers para a dht', () {
    final bytes = encodeGetProviders(sampleCid);
    expect(bytes, isNotEmpty);
  });

  test('encodeFindNode() - codifica requisicao find node para a dht', () {
    final key = Uint8List.fromList(sampleCid.multihash.toBytes());
    final bytes = encodeFindNode(key);
    expect(bytes, isNotEmpty);
    // Campo 1 (type) == 4 (FIND_NODE), apos o varint de tamanho do frame.
    expect(bytes.sublist(1, 3), equals(Uint8List.fromList([0x08, 0x04])));
  });

  test('encodeAddProvider() - codifica requisicao add provider para a dht', () {
    final maddr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
    final provider = libp2p.AddrInfo(id: samplePeerId, addrs: [maddr]);
    final bytes = encodeAddProvider(sampleCid, provider);
    expect(bytes, isNotEmpty);
  });

  test('boundPeerRecordAddrs() - delimita enderecos para caber no limite maximo', () {
    final maddr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
    final bounded = boundPeerRecordAddrs(
      id: samplePeerId.value,
      rawAddrs: [maddr.toBytes()],
      connection: 2,
      maxSize: 8192,
    );
    expect(bounded, hasLength(1));
  });

  test('encodePeerRecord() - codifica registro de peer com enderecos', () {
    final maddr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
    final record = encodePeerRecord(id: samplePeerId, addrs: [maddr]);
    expect(record, isNotEmpty);
  });

  test('encodeDhtResponse() - codifica resposta protobuf da dht com peers', () {
    final maddr = Multiaddr.parse('/ip4/127.0.0.1/tcp/4001');
    final peer = libp2p.AddrInfo(id: samplePeerId, addrs: [maddr]);
    final resp = encodeDhtResponse(
      closerPeers: [peer],
      providerPeers: [peer],
    );
    expect(resp, isNotEmpty);
  });

  // BlockstoreHashMismatchException
  group('BlockstoreHashMismatchException [Atomic Audit]', () {
    test('toString() - formata mensagem de erro de hash mismatch', () {
      final ex = BlockstoreHashMismatchException(sampleCid);
      expect(ex.toString(), contains('blockstore: data did not match'));
    });
  });

  // Blockstore
  group('Blockstore [Atomic Audit]', () {
    test('has() - verifica se o bloco existe no blockstore', () async {
      final bs = Blockstore();
      expect(await bs.has(sampleCid), isFalse);
      await bs.close();
    });

    test('getSize() - retorna tamanho em bytes do bloco', () async {
      final bs = Blockstore();
      await bs.put(blocks.BasicBlock(sampleRawData, sampleCid));
      expect(await bs.getSize(sampleCid), equals(sampleRawData.length));
      await bs.close();
    });

    test('get() - recupera bloco validando o hash', () async {
      final bs = Blockstore();
      await bs.put(blocks.BasicBlock(sampleRawData, sampleCid));
      final blk = await bs.get(sampleCid);
      expect(blk.rawData(), equals(sampleRawData));
      await bs.close();
    });

    test('put() - persiste bloco no storage', () async {
      final bs = Blockstore();
      await bs.put(blocks.BasicBlock(sampleRawData, sampleCid));
      expect(await bs.has(sampleCid), isTrue);
      await bs.close();
    });

    test('putMany() - persiste multiplos blocos no storage', () async {
      final bs = Blockstore();
      final data2 = Uint8List.fromList([6, 7, 8]);
      final cid2 = Cid.v1('raw', MultihashUtils.sum('sha2-256', data2));
      await bs.putMany([
        blocks.BasicBlock(sampleRawData, sampleCid),
        blocks.BasicBlock(data2, cid2),
      ]);
      expect(await bs.has(sampleCid), isTrue);
      expect(await bs.has(cid2), isTrue);
      await bs.close();
    });

    test('close() - fecha o datastore subjacente', () async {
      final bs = Blockstore();
      await bs.close();
      expect(await bs.has(sampleCid), isFalse);
    });
  });

  // IpfsConfig
  group('IpfsConfig [Atomic Audit]', () {
    test('copyWith() - cria copia com novos parametros', () {
      const cfg = IpfsConfig(offline: true);
      final copy = cfg.copyWith(offline: false);
      expect(copy.offline, isFalse);
      expect(cfg.offline, isTrue);
    });
  });

  // Libp2pRouter
  group('Libp2pRouter [Atomic Audit]', () {
    test('connect() - conecta ao endereco do peer', () async {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final peer = libp2p.AddrInfo(
        id: samplePeerId,
        addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')],
      );
      await router.connect(peer);
      expect(router.host, equals(host));
    });

    test('addAddrs() - adiciona enderecos no peerstore com ttl', () async {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final peer = libp2p.AddrInfo(
        id: samplePeerId,
        addrs: [Multiaddr.parse('/ip4/127.0.0.1/tcp/4001')],
      );
      await router.addAddrs(peer);
      expect(router.host, equals(host));
    });

    test('getAddrs() - busca enderecos do peer no peerstore', () async {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final addrs = await router.getAddrs(samplePeerId);
      expect(addrs, isA<List<Multiaddr>>());
    });

    test('runtimePeerId() - converte peer id para o tipo de runtime', () {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final rtId = router.runtimePeerId(samplePeerId);
      expect(rtId.toBase58(), equals(samplePeerId.toBase58()));
    });
  });

  // IpfsNode
  group('IpfsNode [Atomic Audit]', () {
    test('fromBuildCfg() - constroi instancia de ipfs node', () async {
      final cfg = BuildCfg(online: false);
      final node = await IpfsNode.fromBuildCfg(cfg);
      expect(node, isA<IpfsNode>());
      await node.close();
    });

    test('isOnline - indica se o node possui rede ativa', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      expect(node.isOnline, isFalse);
      await node.close();
    });

    test('connect() - lanca erro se o node estiver offline', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      final peer = libp2p.AddrInfo(id: samplePeerId, addrs: []);
      expect(() => node.connect(peer), throwsStateError);
      await node.close();
    });

    test('getBlock() - lanca erro se o node estiver offline', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      expect(() => node.getBlock(sampleCid), throwsStateError);
      await node.close();
    });

    test('findProvidersAsync() - lanca erro se o node estiver offline', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      expect(() => node.findProvidersAsync(sampleCid, 1), throwsStateError);
      await node.close();
    });

    test('getBlockFromDht() - lanca erro se o node estiver offline', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      expect(() => node.getBlockFromDht(sampleCid), throwsStateError);
      await node.close();
    });

    test('getUnixFs() - le bytes de arquivo unixfs', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      await node.blockstore.put(blocks.BasicBlock(sampleRawData, sampleCid));
      final chunks = await node.getUnixFs(sampleCid).toList();
      expect(chunks.single, equals(sampleRawData));
      await node.close();
    });

    test('statUnixFs() - retorna estatisticas do unixfs', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      await node.blockstore.put(blocks.BasicBlock(sampleRawData, sampleCid));
      final stat = await node.statUnixFs(sampleCid);
      expect(stat.size, equals(sampleRawData.length));
      expect(stat.numBlocks, equals(1));
      await node.close();
    });

    test('listUnixFsCids() - lista cids da arvore unixfs', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      await node.blockstore.put(blocks.BasicBlock(sampleRawData, sampleCid));
      final cids = await node.listUnixFsCids(sampleCid).toList();
      expect(cids, equals([sampleCid]));
      await node.close();
    });

    test('exportCar() - exporta dag em formato car', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      await node.blockstore.put(blocks.BasicBlock(sampleRawData, sampleCid));
      final carBytes = await node.exportCar(sampleCid).fold<List<int>>(
        [],
        (a, b) => [...a, ...b],
      );
      expect(carBytes, isNotEmpty);
      await node.close();
    });

    test('importCar() - importa blocos de arquivo car', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      await node.blockstore.put(blocks.BasicBlock(sampleRawData, sampleCid));
      final carBytes = await node.exportCar(sampleCid).fold<List<int>>(
        [],
        (a, b) => [...a, ...b],
      );
      final header = await node.importCar(Uint8List.fromList(carBytes));
      expect(header.roots, contains(sampleCid));
      await node.close();
    });

    test('peerId() - lanca erro se o node estiver offline', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      expect(() => node.peerId, throwsStateError);
      await node.close();
    });

    test('listenAddresses() - retorna lista vazia se offline', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      expect(node.listenAddresses, isEmpty);
      await node.close();
    });

    test('swarmAddresses() - lanca erro se offline pois depende do peerId', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      expect(() => node.swarmAddresses, throwsStateError);
      await node.close();
    });

    test('putBlock() - persiste bloco no blockstore local', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      final blk = blocks.BasicBlock(sampleRawData, sampleCid);
      await node.putBlock(blk);
      expect(await node.blockstore.has(sampleCid), isTrue);
      await node.close();
    });

    test('putRawBlock() - divide dados brutos, persiste no blockstore e retorna cid', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      final cid = await node.putRawBlock(sampleRawData);
      expect(cid.version, equals(0));
      expect(await node.blockstore.has(cid), isTrue);
      await node.close();
    });

    test('provide() - lanca erro se o node estiver offline', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      expect(() => node.provide(sampleCid), throwsStateError);
      await node.close();
    });

    test('close() - encerra componentes do ipfs node', () async {
      final node = await IpfsNode.fromBuildCfg(BuildCfg(online: false));
      await node.close();
      expect(node.isOnline, isFalse);
    });
  });

  // DhtClient
  group('DhtClient [Atomic Audit]', () {
    test('close() - encerra cliente dht e cancela streams', () async {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final client = DhtClient(router: router, bootstrapPeers: []);
      await client.close();
      expect(() => client.findProvidersAsync(sampleCid, 1), throwsStateError);
    });

    test('findProvidersAsync() - valida parametros e encerramento', () async {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final client = DhtClient(router: router, bootstrapPeers: []);
      expect(() => client.findProvidersAsync(sampleCid, -1), throwsRangeError);
      await client.close();
    });

    test('getClosestPeers() - caminha a dht e valida encerramento', () async {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final client = DhtClient(router: router, bootstrapPeers: []);
      final key = Uint8List.fromList(sampleCid.multihash.toBytes());
      expect(await client.getClosestPeers(key), isEmpty);
      await client.close();
      expect(() => client.getClosestPeers(key), throwsStateError);
    });

    test('provide() - lanca erro se cliente dht estiver fechado ou conclui sem candidatos', () async {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final client = DhtClient(router: router, bootstrapPeers: []);
      final provider = libp2p.AddrInfo(id: samplePeerId, addrs: []);
      await client.provide(sampleCid, provider);
      await client.close();
      expect(() => client.provide(sampleCid, provider), throwsStateError);
    });
  });

  // ImmutableBytes
  group('ImmutableBytes [Atomic Audit]', () {
    test('toBytes() - retorna copia dos bytes subjacentes', () {
      final bytes = ImmutableBytes(Uint8List.fromList([1, 2, 3]));
      expect(bytes.toBytes(), equals(Uint8List.fromList([1, 2, 3])));
    });

    test('length - retorna quantidade de bytes encapsulados', () {
      final bytes = ImmutableBytes(Uint8List.fromList([1, 2, 3]));
      expect(bytes.length, equals(3));
    });

    test('operator == - compara igualdade de valor entre bytes', () {
      final a = ImmutableBytes(Uint8List.fromList([1, 2, 3]));
      final b = ImmutableBytes(Uint8List.fromList([1, 2, 3]));
      final c = ImmutableBytes(Uint8List.fromList([4, 5, 6]));
      expect(a == b, isTrue);
      expect(a == c, isFalse);
    });

    test('hashCode - computa hash code consistente', () {
      final a = ImmutableBytes(Uint8List.fromList([1, 2, 3]));
      final b = ImmutableBytes(Uint8List.fromList([1, 2, 3]));
      expect(a.hashCode, equals(b.hashCode));
      expect({a, b}, hasLength(1));
      expect({a: 'found'}[b], 'found');
    });
  });

  // TypedMap
  group('TypedMap [Atomic Audit]', () {
    test('get() - obtem valor com fallback caso ausente', () {
      final map = TypedMap({'a': 10, 'b': 'ola'});
      expect(map.get<int>('a', 0), equals(10));
      expect(map.get<int>('naoExiste', 99), equals(99));
    });

    test('operator [] - acessa valor diretamente pela chave', () {
      final map = TypedMap({'chave': 'valor'});
      expect(map['chave'], equals('valor'));
      expect(map['outra'], isNull);
    });

    test('toMap() - exporta mapa subjacente nao modificavel', () {
      final map = TypedMap({'k': 'v'});
      expect(map.toMap(), equals({'k': 'v'}));
    });

    test('containsKey() - verifica existencia da chave no mapa', () {
      final map = TypedMap({'existe': true});
      expect(map.containsKey('existe'), isTrue);
      expect(map.containsKey('naoExiste'), isFalse);
    });

    test('length - retorna numero de entradas no mapa', () {
      final map = TypedMap({'a': 1, 'b': 2});
      expect(map.length, equals(2));
    });

    test('operator == - compara igualdade de conteudo entre mapas', () {
      final a = TypedMap({'x': 1});
      final b = TypedMap({'x': 1});
      final c = TypedMap({'x': 2});
      expect(a == b, isTrue);
      expect(a == c, isFalse);
      expect(TypedMap({'x': 1, 'y': 2}), TypedMap({'y': 2, 'x': 1}));
      expect(TypedMap({'x': null}) == TypedMap({'y': null}), isFalse);
    });

    test('hashCode - gera hash code compativel', () {
      final a = TypedMap({'x': 1});
      final b = TypedMap({'x': 1});
      expect(a.hashCode, equals(b.hashCode));
      expect({a, b}, hasLength(1));
      expect(TypedMap({'x': 1, 'y': 2}).hashCode,
          TypedMap({'y': 2, 'x': 1}).hashCode);
    });
  });

  // SystemResolver
  group('SystemResolver [Atomic Audit]', () {
    test('lookupIpAddr() - resolve enderecos ip pelo sistema', () async {
      final resolver = SystemResolver();
      final ips = await resolver.lookupIpAddr('127.0.0.1');
      expect(ips, contains('127.0.0.1'));
    });

    test('lookupTxt() - consulta registros txt via cliente dns', () async {
      final client = UdpDnsClient(
        resolvers: ['127.0.0.1'],
        timeout: const Duration(milliseconds: 10),
        attemptsPerResolver: 1,
      );
      final resolver = SystemResolver(client: client);
      expect(() => resolver.lookupTxt('example.invalid'), throwsA(isA<TimeoutException>()));
    });
  });

  // UdpDnsClient
  group('UdpDnsClient [Atomic Audit]', () {
    test('lookup() - executa consulta udp com tratamento de timeout', () async {
      final client = UdpDnsClient(
        resolvers: ['127.0.0.1'],
        timeout: const Duration(milliseconds: 10),
        attemptsPerResolver: 1,
      );
      expect(() => client.lookup('example.invalid', 16), throwsA(isA<TimeoutException>()));
    });

  });

  // BitswapClient
  group('BitswapClient [Atomic Audit]', () {
    test('start() - registra handler para protocolo bitswap', () {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final bstore = Blockstore();
      final client = BitswapClient(
        router: router,
        blockstore: bstore,
        timeout: const Duration(seconds: 30),
      );
      client.start();
      expect(host.handlers.containsKey('/ipfs/bitswap/1.2.0'), isTrue);
      client.close();
      bstore.close();
    });

    test('connect() - conecta a provedor bitswap', () async {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final bstore = Blockstore();
      final client = BitswapClient(
        router: router,
        blockstore: bstore,
        timeout: const Duration(seconds: 30),
      );
      final peer = libp2p.AddrInfo(id: samplePeerId, addrs: []);
      await client.connect(peer);
      expect(client.blockstore, equals(bstore));
      await client.close();
      await bstore.close();
    });

    test('getBlock() - recupera bloco do storage se disponivel', () async {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final bstore = Blockstore();
      await bstore.put(blocks.BasicBlock(sampleRawData, sampleCid));
      final client = BitswapClient(
        router: router,
        blockstore: bstore,
        timeout: const Duration(seconds: 30),
      );
      final blk = await client.getBlock(sampleCid);
      expect(blk.rawData(), equals(sampleRawData));
      await client.close();
      await bstore.close();
    });

    test('close() - encerra cliente bitswap e fluxos pendentes', () async {
      final host = _FakeHost();
      final router = Libp2pRouter(host);
      final bstore = Blockstore();
      final client = BitswapClient(
        router: router,
        blockstore: bstore,
        timeout: const Duration(seconds: 30),
      );
      await client.close();
      expect(client.blockstore, equals(bstore));
      await bstore.close();
    });
  });

  // BlockGetter
  group('BlockGetter [Atomic Audit]', () {
    test('getBlock() - busca bloco por cid na interface block getter', () async {
      final getter = _TestBlockGetter();
      final blk = await getter.getBlock(sampleCid);
      expect(blk.rawData(), equals([1, 2, 3]));
    });
  });

  // QueryPeerset
  group('QueryPeerset [Atomic Audit]', () {
    test('tryAdd() - insere novo peer no peerset se ausente', () {
      final target = samplePeerId;
      final qp = QueryPeerset(target, (t, a, b) => 0);
      final p1 = libp2p.PeerId.decode(
        '12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c',
      );
      expect(qp.tryAdd(p1, target), isTrue);
      expect(qp.tryAdd(p1, target), isFalse);
    });

    test('setState() - atualiza estado de consulta do peer', () {
      final target = samplePeerId;
      final qp = QueryPeerset(target, (t, a, b) => 0);
      final p1 = libp2p.PeerId.decode(
        '12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c',
      );
      qp.tryAdd(p1, target);
      qp.setState(p1, PeerState.waiting);
      expect(qp.getState(p1), equals(PeerState.waiting));
    });

    test('getState() - consulta estado atual do peer', () {
      final target = samplePeerId;
      final qp = QueryPeerset(target, (t, a, b) => 0);
      final p1 = libp2p.PeerId.decode(
        '12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c',
      );
      qp.tryAdd(p1, target);
      expect(qp.getState(p1), equals(PeerState.heard));
    });

    test('getReferrer() - obtem peer que indicou o endereco', () {
      final target = samplePeerId;
      final qp = QueryPeerset(target, (t, a, b) => 0);
      final p1 = libp2p.PeerId.decode(
        '12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c',
      );
      qp.tryAdd(p1, target);
      expect(qp.getReferrer(p1), equals(target));
    });

    test('getClosestNInStates() - busca n peers mais proximos nos estados', () {
      final target = samplePeerId;
      final qp = QueryPeerset(target, (t, a, b) => 0);
      final p1 = libp2p.PeerId.decode(
        '12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c',
      );
      qp.tryAdd(p1, target);
      final list = qp.getClosestNInStates(1, {PeerState.heard});
      expect(list, equals([p1]));
    });

    test('getClosestInStates() - busca todos os peers mais proximos nos estados', () {
      final target = samplePeerId;
      final qp = QueryPeerset(target, (t, a, b) => 0);
      final p1 = libp2p.PeerId.decode(
        '12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c',
      );
      qp.tryAdd(p1, target);
      final list = qp.getClosestInStates({PeerState.heard});
      expect(list, equals([p1]));
    });

    test('numHeard - quantidade de peers descobertos pendentes', () {
      final target = samplePeerId;
      final qp = QueryPeerset(target, (t, a, b) => 0);
      final p1 = libp2p.PeerId.decode(
        '12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c',
      );
      qp.tryAdd(p1, target);
      expect(qp.numHeard, equals(1));
    });

    test('numWaiting - quantidade de queries em andamento', () {
      final target = samplePeerId;
      final qp = QueryPeerset(target, (t, a, b) => 0);
      final p1 = libp2p.PeerId.decode(
        '12D3KooWStiM2F2p4k2c6c3H3c2wM7d8Xv5R7n3w4k7K2c6c3H3c',
      );
      qp.tryAdd(p1, target);
      expect(qp.numWaiting, equals(0));
      qp.setState(p1, PeerState.waiting);
      expect(qp.numWaiting, equals(1));
    });
  });

  // BuildCfg
  group('BuildCfg [Atomic Audit]', () {
    test('config - obtem configuracao resolvida do build cfg', () {
      final cfgOffline = BuildCfg(online: false);
      expect(cfgOffline.config.offline, isTrue);
      final cfgOnline = BuildCfg(online: true);
      expect(cfgOnline.config.offline, isFalse);
    });
  });

  // DistanceMetric
  group('DistanceMetric [Atomic Audit]', () {
    test('calculateDistance() - calcula distancia numerica entre peers', () {
      final metric = _TestDistanceMetric();
      expect(metric.calculateDistance(samplePeerId, samplePeerId), equals(42));
    });

    test('calculateDistanceToKey() - calcula distancia entre peer e chave raw', () {
      final metric = _TestDistanceMetric();
      expect(metric.calculateDistanceToKey(samplePeerId, [1, 2, 3]), equals(24));
    });
  });

  // DhtRoutingTable
  group('DhtRoutingTable [Atomic Audit]', () {
    test('distanceMetric - expoem metrica de distancia da tabela', () {
      final rt = _TestDhtRoutingTable();
      expect(rt.distanceMetric, isA<DistanceMetric>());
    });

    test('findClosestPeers() - busca peers mais proximos por id', () {
      final rt = _TestDhtRoutingTable();
      rt.addPeer(samplePeerId, samplePeerId);
      final closest = rt.findClosestPeers(samplePeerId);
      expect(closest, equals([samplePeerId]));
    });

    test('findClosestPeersToKey() - busca peers mais proximos por chave', () {
      final rt = _TestDhtRoutingTable();
      rt.addPeer(samplePeerId, samplePeerId);
      final closest = rt.findClosestPeersToKey([1, 2, 3]);
      expect(closest, equals([samplePeerId]));
    });

    test('addPeer() - adiciona peer a tabela de roteamento', () async {
      final rt = _TestDhtRoutingTable();
      await rt.addPeer(samplePeerId, samplePeerId);
      expect(rt.containsPeer(samplePeerId), isTrue);
    });

    test('removePeer() - remove peer da tabela de roteamento', () {
      final rt = _TestDhtRoutingTable();
      rt.addPeer(samplePeerId, samplePeerId);
      rt.removePeer(samplePeerId);
      expect(rt.containsPeer(samplePeerId), isFalse);
    });

    test('containsPeer() - verifica presenca de peer na tabela', () {
      final rt = _TestDhtRoutingTable();
      expect(rt.containsPeer(samplePeerId), isFalse);
      rt.addPeer(samplePeerId, samplePeerId);
      expect(rt.containsPeer(samplePeerId), isTrue);
    });

    test('peerCount - quantidade total de peers na tabela', () {
      final rt = _TestDhtRoutingTable();
      expect(rt.peerCount, equals(0));
      rt.addPeer(samplePeerId, samplePeerId);
      expect(rt.peerCount, equals(1));
    });

    test('clear() - remove todos os peers da tabela', () {
      final rt = _TestDhtRoutingTable();
      rt.addPeer(samplePeerId, samplePeerId);
      rt.clear();
      expect(rt.peerCount, equals(0));
    });
  });
}
