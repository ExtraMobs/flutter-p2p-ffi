import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:transpiled_block_format/transpiled_block_format.dart'
    as block_format;
import 'package:transpiled_boxo/transpiled_boxo.dart' hide Blockstore;
import 'package:transpiled_cid/transpiled_cid.dart';
import 'package:transpiled_datastore/transpiled_datastore.dart'
    show MapDatastore;
import 'package:transpiled_go_car/transpiled_go_car.dart';
import 'package:transpiled_libp2p/transpiled_libp2p.dart'
    as libp2p
    show Manager;
import 'package:transpiled_libp2p/transpiled_libp2p.dart';
import 'package:transpiled_libp2p_kad_dht/transpiled_libp2p_kad_dht.dart';
import 'package:transpiled_multiaddr/transpiled_multiaddr.dart' as multiaddr;

import '../blockstore/blockstore.dart';
import '../config/ipfs_runtime_config.dart';
import '../core/builders/build_cfg.dart';
import '../network/libp2p_host.dart';
import '../protocols/bitswap/bitswap_client.dart';
import '../repo/repo.dart';
import '../unixfs/unixfs.dart';

/// Embedded IPFS node containing the currently ported reusable runtime.
final class IpfsNode {
  IpfsNode._({
    required this.config,
    required this.blockstore,
    required Host? host,
    required BitswapClient? bitswap,
    required DhtClient? dht,
    required IdService? idService,
    required Duration shutdownTimeout,
  }) : _host = host,
       _bitswap = bitswap,
       _dht = dht,
       _idService = idService,
       _shutdownTimeout = shutdownTimeout;

  /// Kubo `core.NewNode` equivalent for the supported Dart subset.
  static Future<IpfsNode> fromBuildCfg(BuildCfg buildCfg) async {
    final rollback = <Future<void> Function()>[];
    try {
      return await _build(buildCfg, rollback);
    } catch (error, stack) {
      for (final close in rollback.reversed) {
        try {
          await close();
        } catch (cleanupError, cleanupStack) {
          _log.warning(
            'Could not release resource after node construction failed',
            cleanupError,
            cleanupStack,
          );
        }
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  static Future<IpfsNode> _build(
    BuildCfg buildCfg,
    List<Future<void> Function()> rollback,
  ) async {
    final repo = buildCfg.repo;
    if (repo != null) rollback.add(repo.close);
    final config = (repo == null ? buildCfg.config : await repo.config())
        .copyWith(offline: !buildCfg.online);
    final store = repo?.datastore();
    final blockstore = Blockstore(datastore: store);
    if (repo == null) rollback.add(blockstore.close);
    if (!buildCfg.online) {
      final node = IpfsNode._(
        config: config,
        blockstore: blockstore,
        host: null,
        bitswap: null,
        dht: null,
        idService: null,
        shutdownTimeout: buildCfg.shutdownTimeout,
      );
      node._repo = repo;
      return node;
    }

    final identity = config.identity;
    if (repo != null && identity == null) {
      throw StateError('repository configuration has no identity');
    }
    final identityKey = identity == null
        ? await generateEd25519KeyPair()
        : await identity.decodePrivateKey('');
    final localPeer = PeerId.fromPubKey(identityKey.getPublic());
    if (identity != null && PeerId.decode(identity.peerId) != localPeer) {
      throw StateError(
        'private key in config does not match id: ${identity.peerId} != $localPeer',
      );
    }
    final Peerstore peerstore = store == null
        ? MemoryPeerstore()
        : await Pstoreds.open(store);
    rollback.add(peerstore.close);
    peerstore.addPrivKey(localPeer, identityKey);
    peerstore.addPubKey(localPeer, identityKey.getPublic());

    final upgrader = BasicUpgrader(
      localIdentityKey: identityKey,
      // go-libp2p's DefaultSecurity offers TLS first and Noise second
      // (`config/config.go`), and the order is preserved here now that the
      // TLS 1.3 handshake completes against a real go-libp2p peer in both
      // directions -- see test/interop/test/local_kubo_tls_handshake_test.dart.
      security: [
        TlsTransport(privKey: identityKey),
        NoiseTransport(privKey: identityKey),
      ],
    );
    final tcpTransport = TcpTransport(upgrader: upgrader);
    final eventBus = BasicBus();
    final swarm = Swarm(
      localPeer: localPeer,
      peerstore: peerstore,
      eventBus: eventBus,
      transports: [
        QuicTransport(privKey: identityKey),
        WebtransportTransport(privKey: identityKey),
        WebRtcTransport(privKey: identityKey),
        WebsocketTransport(upgrader: upgrader),
        tcpTransport,
      ],
    );
    rollback.add(swarm.close);

    final listenAddrs = config.network.listenAddresses
        .map(multiaddr.Multiaddr.parse)
        .toList();
    await swarm.listen(listenAddrs);

    String? announcedIp;
    for (final a in config.network.announceAddresses) {
      try {
        final parsed = multiaddr.Multiaddr.parse(a);
        for (final c in parsed.components) {
          if (c.protocol.name == 'ip4') {
            announcedIp = c.value;
            break;
          }
        }
      } catch (_) {}
    }

    final autoRelay = AutoRelay();
    rollback.add(autoRelay.close);
    final natGateway = announcedIp != null
        ? SimulatedNatGateway(externalIp: announcedIp)
        : null;
    final natManager = BasicNatManager(network: swarm, gateway: natGateway);
    rollback.add(natManager.close);
    await natManager.start();

    HolePunchService? holePunch;
    final observedAddresses = libp2p.Manager(eventBus, swarm);
    rollback.add(observedAddresses.close);
    observedAddresses.start(swarm);
    // Kubo's connection manager defaults (`kubo/config/init.go:79-93`): note
    // its grace period is 20s, shorter than go-libp2p's own one minute.
    final connManager = BasicConnMgr(32, 96, [
      withGracePeriod(const Duration(seconds: 20)),
      withSilencePeriod(const Duration(seconds: 10)),
    ]);
    final host = BasicHost(
      network: swarm,
      peerstore: peerstore,
      eventBus: eventBus,
      connManager: connManager,
      observedAddrsManager: observedAddresses,
      autoRelay: autoRelay,
      natManager: natManager,
      holePunchService: holePunch,
    );
    // The host takes ownership of the peerstore, swarm, NAT and relay.
    // Keep the repository first so rollback closes it last.
    rollback.removeRange(1, rollback.length);
    rollback.addAll([host.close, observedAddresses.close]);

    holePunch = HolePunchService(host: host);
    rollback.add(holePunch.close);
    await holePunch.start();

    final router = Libp2pRouter(host);
    final bootstrapPeers = config.network.bootstrapPeers
        .map(addrInfoFromString)
        .toList();
    final dht = DhtClient(host: host, bootstrapPeers: bootstrapPeers);
    rollback.add(dht.close);
    dht.bootstrap();
    final dhtServer = DhtServer(host: host, routingTable: dht.routingTable)
      ..start();
    rollback.add(dhtServer.close);
    final bitswap = BitswapClient(
      router: router,
      blockstore: blockstore,
      timeout: config.bitswap.p2pTimeout,
    );
    rollback.add(bitswap.close);
    bitswap.start();
    final idService = IdService(host: host);
    rollback.add(idService.close);
    idService.start();
    final node = IpfsNode._(
      config: config,
      blockstore: blockstore,
      host: host,
      bitswap: bitswap,
      dht: dht,
      idService: idService,
      shutdownTimeout: buildCfg.shutdownTimeout,
    );
    node._observedAddresses = observedAddresses;
    node._repo = repo;
    node._holePunch = holePunch;
    rollback
      ..clear()
      ..add(node.close);
    if (config.network.mdnsEnabled) {
      final handler = _NodeDiscoveryHandler(host);
      final discovery = MdnsService(host, notifee: handler);
      try {
        await discovery.start();
        node._mdns = discovery;
        node._discoveryHandler = handler;
      } catch (error, stack) {
        // Kubo SetupDiscovery reports failure without aborting the node.
        handler.close();
        await discovery.close();
        _log.warning('Could not start mDNS discovery', error, stack);
      }
    }

    // Marco F.5 (scheduling half of PROGRESS.md's Objetivo 5): reprovide
    // every stored block on boxo's default schedule
    // (reprovider.go:24, 22h -- see DefaultReproviderInterval in
    // packages/transpiled_boxo/lib/src/provider/reprovider.dart). Wired
    // right after the DHT comes up so the library itself keeps content
    // discoverable without a caller-managed timer; started here and closed
    // in IpfsNode.close(), so it never outlives the node.
    node._reprovider = reproviderSystem(
      store ?? MapDatastore(),
      options: [
        online(_NodeReproviderAdapter(node)),
        keyProvider(node._reprovideKeys),
      ],
    );
    return node;
  }

  /// Effective node configuration.
  final IpfsConfig config;

  /// Validating blockstore used by Bitswap.
  final Blockstore blockstore;

  final Host? _host;
  final BitswapClient? _bitswap;
  final DhtClient? _dht;
  final IdService? _idService;
  final Duration _shutdownTimeout;
  Future<void>? _closeFuture;
  static final _log = Logger('ipfs.node');
  libp2p.Manager? _observedAddresses;
  MdnsService? _mdns;
  _NodeDiscoveryHandler? _discoveryHandler;
  HolePunchService? _holePunch;
  Repo? _repo;

  System? _reprovider;

  /// Whether networking is active.
  bool get isOnline => _host != null;

  /// Network host, or null when offline (Kubo IpfsNode.PeerHost).
  Host? get peerHost => _host;

  /// Local cryptographic peer ID of this node.
  PeerId get peerId {
    final host = _host;
    if (host == null) throw StateError('IPFS node is offline');
    return host.id;
  }

  /// Active listening multiaddresses for this node.
  List<String> get listenAddresses {
    if (config.network.announceAddresses.isNotEmpty) {
      return config.network.announceAddresses;
    }
    final host = _host;
    if (host == null) return const [];
    final addrs = host.addrs;
    if (addrs.isNotEmpty) {
      return addrs.map((a) => a.toString()).toList();
    }
    return host.network.listenAddresses().map((a) => a.toString()).toList();
  }

  /// Formatted multiaddresses including peer ID (e.g. `/ip4/127.0.0.1/tcp/xxxxx/p2p/<peerId>`).
  List<String> get swarmAddresses {
    final pid = peerId.toString();
    return listenAddresses.map((a) => '$a/p2p/$pid').toList();
  }

  /// Stores a block in the local blockstore.
  Future<void> putBlock(block_format.Block block) => blockstore.put(block);

  /// Creates and stores a raw block from [bytes] and returns its Cid.
  Future<Cid> putRawBlock(Uint8List bytes) async {
    final block = block_format.BasicBlock.fromData(bytes);
    await blockstore.put(block);
    return block.cid();
  }

  /// Connects this node to a complete provider address.
  Future<void> connect(AddrInfo provider) {
    final bitswap = _bitswap;
    if (bitswap == null) throw StateError('IPFS node is offline');
    return bitswap.connect(provider);
  }

  /// Retrieves and persists one block through Bitswap.
  Future<block_format.Block> getBlock(Cid cid) {
    final bitswap = _bitswap;
    if (bitswap == null) throw StateError('IPFS node is offline');
    return bitswap.getBlock(cid);
  }

  /// Discovers providers through the IPFS Kademlia DHT.
  Stream<AddrInfo> findProvidersAsync(Cid cid, int count) {
    final dht = _dht;
    if (dht == null) throw StateError('IPFS node is offline');
    return dht.findProvidersAsync(cid, count);
  }

  /// Announces this node as a provider of [cid] to the DHT.
  Future<void> provide(Cid cid) async {
    final dht = _dht;
    if (dht == null) throw StateError('IPFS node is offline');
    final self = AddrInfo(
      id: peerId,
      addrs: listenAddresses.map(multiaddr.Multiaddr.parse).toList(),
    );
    await dht.provide(cid, self);
  }

  /// Streams the CIDs backed by the blockstore, including after restart.
  /// to boxo's `KeyChanFunc`, feeding the library's [ReproviderSystem].
  Stream<Cid> _reprovideKeys() async* {
    yield* await blockstore.allKeysChanWithErr();
  }

  /// Discovers providers and downloads the first valid Bitswap block.
  Future<block_format.Block> getBlockFromDht(Cid cid) async {
    Object? lastError;
    await for (final provider in findProvidersAsync(cid, 0)) {
      if (provider.addrs.isEmpty) continue;
      try {
        await connect(provider);
        return await getBlock(cid);
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('DHT/Bitswap could not retrieve $cid: $lastError');
  }

  /// Streams a regular UnixFS file, fetching every missing block by Bitswap.
  Stream<Uint8List> getUnixFs(Cid cid) => readUnixFs(cid, _getContentBlock);

  /// Returns logical and stored sizes for a UnixFS root.
  Future<UnixFsStat> statUnixFs(Cid cid) async {
    final root = await _getContentBlock(cid);
    final bytes = root.rawData();
    if (cid.codec == 'raw') {
      return UnixFsStat(
        cid: cid,
        size: bytes.length,
        blockSize: bytes.length,
        cumulativeSize: bytes.length,
        numLinks: 0,
        numBlocks: 1,
      );
    }
    final dag = DagPbNode.fromBytes(bytes);
    final fs = UnixFsData.fromBytes(dag.data);
    var blocksCount = 0;
    await for (final _ in walkUnixFs(cid, _getContentBlock)) {
      blocksCount++;
    }
    return UnixFsStat(
      cid: cid,
      size: fs.filesize,
      blockSize: bytes.length,
      cumulativeSize:
          bytes.length + dag.links.fold(0, (total, link) => total + link.tsize),
      numLinks: dag.links.length,
      numBlocks: blocksCount,
    );
  }

  /// Lists the root and all nested CIDs in depth-first order.
  Stream<Cid> listUnixFsCids(Cid cid) => walkUnixFs(cid, _getContentBlock);

  /// Streams a CAR v1 containing the complete UnixFS DAG.
  Stream<Uint8List> exportCar(Cid cid) => CarWriter(
    roots: [cid],
    get: (child) async => (await _getContentBlock(child)).rawData(),
    linksWithData: unixFsLinks,
  ).stream();

  /// Validates and imports a CAR v1 into this node's blockstore.
  Future<CarHeader> importCar(Object input) =>
      loadCar(input, (CarBlock block) => blockstore.put(block));

  Future<block_format.Block> _getContentBlock(Cid cid) async {
    if (await blockstore.has(cid)) return blockstore.get(cid);
    try {
      return await getBlock(cid);
    } catch (bitswapError) {
      try {
        return await getBlockFromDht(cid);
      } catch (dhtError) {
        throw StateError(
          'could not retrieve $cid; connected Bitswap: $bitswapError; '
          'DHT fallback: $dhtError',
        );
      }
    }
  }

  /// Closes the node once; concurrent callers share the same future.
  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    final close = () async {
      _discoveryHandler?.close();
      Object? firstError;
      StackTrace? firstStack;
      for (final stop in <Future<void> Function()>[
        if (_mdns != null) _mdns!.close,
        if (_reprovider != null) _reprovider!.close,
        if (_dht != null) _dht.close,
        if (_bitswap != null) _bitswap.close,
        if (_idService != null) _idService.close,
        if (_observedAddresses != null) _observedAddresses!.close,
        if (_holePunch != null) _holePunch!.close,
        if (_host != null) _host.close,
        if (_repo != null) _repo!.close else blockstore.close,
      ]) {
        try {
          await stop();
        } catch (error, stack) {
          if (firstError == null) {
            firstError = error;
            firstStack = stack;
          }
        }
      }
      if (firstError != null) {
        Error.throwWithStackTrace(firstError, firstStack!);
      }
    }();
    if (_shutdownTimeout > Duration.zero) {
      await close.timeout(_shutdownTimeout);
    } else {
      await close;
    }
  }
}

/// Kubo core/node/libp2p.discoveryHandler: connect to discovered LAN peers.
final class _NodeDiscoveryHandler implements Notifee {
  _NodeDiscoveryHandler(this._host);
  final Host _host;
  final Set<PeerId> _connecting = {};
  bool _closed = false;

  @override
  void handlePeerFound(AddrInfo info) {
    if (_closed || info.id == _host.id || !_connecting.add(info.id)) return;
    unawaited(_connect(info));
  }

  Future<void> _connect(AddrInfo info) async {
    try {
      await _host.connect(
        info,
        context: const NetworkContext(dialPeerTimeout: Duration(seconds: 30)),
      );
    } catch (error, stack) {
      if (!_closed) {
        IpfsNode._log.warning(
          'Could not connect to discovered peer ${info.id}',
          error,
          stack,
        );
      }
    } finally {
      _connecting.remove(info.id);
    }
  }

  void close() => _closed = true;
}

/// Routes the library's reprovider through [IpfsNode.provide]. Not present
/// upstream -- boxo's reprovider is handed an already-online
/// `provider.Provide` implementation (typically the DHT client itself);
/// this runtime delegates through `IpfsNode.provide`, so the adapter remains
/// private per this
/// project's rule that Go-internal-only helpers stay unexported.
final class _NodeReproviderAdapter implements Provider {
  const _NodeReproviderAdapter(this._node);

  final IpfsNode _node;

  @override
  Future<void> provide(Cid cid, bool announce) => _node.provide(cid);
}
