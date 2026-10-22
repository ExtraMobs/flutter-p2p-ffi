// A API gerada (go/gen) na ordem em que o kubo monta um nó: plugins →
// identidade e config → fsrepo.Init/Open → core.NewNode → CoreAPI → Unixfs
// (M1) → pins, blocos e GC (M2). O kubo roda no ipfs_host, noutro processo
// (exige `dart run tool/build.dart`: native/ipfs_host e a ipfs_shm).
import 'dart:async';
import 'dart:convert';
import 'dart:math' show Random;
import 'dart:typed_data';
import 'dart:io' show Directory, File, InternetAddress;

import 'package:ipfs_ffi/go/boxo/blockservice.dart' as blockservice;
import 'package:ipfs_ffi/go/boxo/blockstore.dart' as blockstore;
import 'package:ipfs_ffi/go/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/boxo/gateway.dart' as gateway;
import 'package:ipfs_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:ipfs_ffi/go/boxo/ipld/unixfs/file.dart' as unixfile;
import 'package:ipfs_ffi/go/boxo/mfs.dart' as mfs;
import 'package:ipfs_ffi/go/boxo/path.dart' as path;
import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/datastore.dart' as datastore;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/io.dart' as io;
import 'package:ipfs_ffi/go/io_stream.dart' as io_stream;
import 'package:ipfs_ffi/go/os.dart' as os;
import 'package:ipfs_ffi/go/kubo/config.dart' as config;
import 'package:ipfs_ffi/go/kubo/core.dart' as core;
import 'package:ipfs_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:ipfs_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/go/kubo/core/coreiface.dart' as iface;
import 'package:ipfs_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/go/kubo/core/corerepo.dart' as corerepo;
import 'package:ipfs_ffi/go/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/go/kubo/core/node/libp2p.dart' as libp2p;
import 'package:ipfs_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/go/libp2p/core/network.dart' as network;
import 'package:ipfs_ffi/go/libp2p/core/peer.dart' as peer;
import 'package:ipfs_ffi/go/cid.dart' as cid;
import 'package:ipfs_ffi/ipfs_ffi.dart'
    show
        IpfsBackground,
        IpfsPlatform,
        IpfsStop,
        IpfsStopReason,
        IpfsEof,
        IpfsException,
        IpfsService,
        IpfsServiceException,
        hasIpv6,
        isGlobalIpv6;
import 'package:ipfs_ffi/src/runtime.dart'
    show $W, $call, $callSync, $stream, GoSink;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late core.IpfsNode n;
  late iface.CoreApi api;
  late context.Context ctx;
  var hostCrashed = false; // o último teste derruba o host de propósito
  final stops = StreamController<IpfsStop>.broadcast(); // o onStop do serviço

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('ipfs_ffi_kubo_');
    await IpfsService.start(
        crashLog: '${tmp.path}/crash.log', onStop: stops.add);
    ctx = context.background();
    final repoPath = '${tmp.path}/repo';

    // Plugins: uma vez por processo (como o setupPlugins do kubo-as-a-library).
    final plugins = loader.PluginLoader('');
    plugins.initialize();
    plugins.inject();

    // ipfs init
    final identity = config.createIdentity(null, [options.key.type('ed25519')]);
    final cfg = config.initWithIdentity(identity);
    config.profiles['test']!.transform(cfg); // portas aleatórias, sem bootstrap
    expect(fsrepo.isInitialized(repoPath), isFalse);
    fsrepo.init(repoPath, cfg);
    expect(fsrepo.isInitialized(repoPath), isTrue);

    // nó offline sobre o repo em disco
    final repo = fsrepo.open(repoPath);
    n = await core.newNode(ctx, node.BuildCfg(repo: repo));
    api = coreapi.newCoreApi(n);
  });

  tearDownAll(() async {
    if (!hostCrashed) await n.close();
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  });

  test('add e get de bytes', () async {
    final p = await api
        .unixfs()
        .add(ctx, files.newBytesFile(utf8.encode('olá ipfs')));
    expect(p.value, startsWith('/ipfs/Qm')); // padrão do kubo: CIDv0
    final got = await api.unixfs().get(ctx, p);
    expect(utf8.decode(io.readAll(files.toFile(got))), 'olá ipfs');
  });

  // 0.20: any io.Reader handle as a Stream, in 256 KiB pieces
  test('readerStream reads a Go reader to the end in pieces', () async {
    final rnd = Random(3);
    final data =
        Uint8List.fromList(List.generate(1 << 20, (_) => rnd.nextInt(256)));
    final pieces =
        await io_stream.readerStream(files.newBytesFile(data)).toList();
    expect(pieces.length, 4);
    expect(Uint8List.fromList([for (final p in pieces) ...p]), data);
  });

  test('opções do add (CIDv1, raw leaves)', () async {
    final p = await api.unixfs().add(ctx, files.newBytesFile(utf8.encode('x')),
        [options.unixfs.cidVersion(1), options.unixfs.rawLeaves(true)]);
    expect(p.value, startsWith('/ipfs/bafkrei'));
  });

  test('diretório do disco: add, ls, resolvePath e writeTo', () async {
    final dir = Directory('${tmp.path}/in')..createSync();
    File('${dir.path}/a.txt').writeAsStringSync('A');
    File('${dir.path}/b.txt').writeAsStringSync('BB');

    final root = await api
        .unixfs()
        .add(ctx, files.newSerialFile(dir.path, false, os.stat(dir.path)));
    final entries = await api.unixfs().ls(ctx, root).toList();
    expect([for (final e in entries) e.name], ['a.txt', 'b.txt']);
    expect([for (final e in entries) e.size], [1, 2]);

    final (resolved, rest) =
        await api.resolvePath(ctx, path.Path('${root.value}/b.txt'));
    expect(resolved.value, startsWith('/ipfs/'));
    expect(rest, isEmpty);

    final out = '${tmp.path}/out';
    files.writeTo(await api.unixfs().get(ctx, root), out);
    expect(File('$out/b.txt').readAsStringSync(), 'BB');
  });

  test('context: cancelado e com prazo vencido', () async {
    final (c, cancel) = context.withCancel(context.background());
    expect(c.err(), isNull);
    cancel();
    expect(c.err(), 'context canceled');
    await expectLater(api.unixfs().add(c, files.newBytesFile(utf8.encode('y'))),
        throwsA(isA<IpfsException>()));

    final (t, cancelT) =
        context.withTimeout(context.background(), Duration.zero);
    expect(t.err(), 'context deadline exceeded');
    cancelT();
  });

  test('erros do Go viram IpfsException (o panic: grupo abaixo)', () async {
    await expectLater(api.resolvePath(ctx, path.Path('não é path')),
        throwsA(isA<IpfsException>()));
    // handle inválido: a tabela do host responde erro
    await expectLater(
        core.IpfsNode.$h(1 << 40).close(),
        throwsA(isA<IpfsException>()
            .having((e) => e.message, 'message', contains('does not exist'))));
  });

  // M2: pins, blocos e GC
  Future<path.ImmutablePath> addUnpinned(String s) => api.unixfs().add(
      ctx, files.newBytesFile(utf8.encode(s)), [options.unixfs.pin(false, '')]);

  test('pin add, isPinned, ls, update e rm', () async {
    final a = await addUnpinned('pin a');
    final b = await addUnpinned('pin b');
    expect((await api.pin().isPinned(ctx, a)).$2, isFalse);

    await api.pin().add(ctx, a, [options.pin.name('meu-pin')]);
    final (how, pinned) = await api.pin().isPinned(ctx, a);
    expect((how, pinned), ('recursive', true));
    // o filtro por nome só vale com detailed (como `ipfs pin ls --names`)
    final pins = await api.pin().ls(ctx, [
      options.pin.ls.recursive(),
      options.pin.ls.detailed(true),
      options.pin.ls.name('meu-pin'),
    ]).toList();
    expect([for (final p in pins) p.path?.value], [a.value]);
    expect(pins.single.name, 'meu-pin');

    await api.pin().update(ctx, a, b); // move o pin de a para b
    expect((await api.pin().isPinned(ctx, a)).$2, isFalse);
    expect((await api.pin().isPinned(ctx, b)).$2, isTrue);

    await api.pin().rm(ctx, b);
    expect((await api.pin().isPinned(ctx, b)).$2, isFalse);
    expect(await api.pin().verify(ctx).every((s) => s.ok && s.err == null),
        isTrue);
  });

  test('block put, stat, get e rm', () async {
    final data = utf8.encode('bloco cru');
    final st = await api.block().put(ctx, data, [options.block.pin(false)]);
    expect(st.size, data.length);
    expect(st.path!.value, startsWith('/ipfs/bafkrei')); // raw + sha2-256

    expect((await api.block().stat(ctx, st.path!)).size, data.length);
    final r = await api.block().get(ctx, st.path!);
    expect(io.readAll(r), data);

    await api.block().rm(ctx, st.path!);
    await expectLater(
        api.block().stat(ctx, st.path!), throwsA(isA<IpfsException>()));
  });

  test('GC apaga o que não está pinado e mantém o pinado', () async {
    final loose = await addUnpinned('solto ${DateTime.now()}');
    // a CoreAPI não pina por padrão (o `ipfs add` do CLI é que passa pin=true)
    final kept = await api.unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('pinado ${DateTime.now()}')),
        [options.unixfs.pin(true, '')]);

    final removed = await corerepo.garbageCollectAsync(n, ctx).toList();
    // O blockstore guarda pelo multihash: o GC informa CIDv1 raw (bafkrei...),
    // não o CIDv0 (Qm...) do add.
    expect(removed, isNotEmpty);
    expect([for (final r in removed) r.error], everyElement(isNull));

    await expectLater(
        api.block().stat(ctx, loose), throwsA(isA<IpfsException>()));
    expect((await api.block().stat(ctx, kept)).size, greaterThan(0));
    await corerepo.garbageCollect(n, ctx); // a versão que só espera
  });

  // 0.20: the node's blockstore block by block, and the GC locks
  test('blockstore deleteBlock/getSize/allKeysChan; PinLock holds the GC',
      () async {
    final data = utf8.encode('evict me ${DateTime.now()}');
    final st = await api.block().put(ctx, data, [options.block.pin(false)]);
    final c = cid.Cid(st.path!.value.substring('/ipfs/'.length)); // raw
    final bs = n.blockstore;
    expect(await bs.getSize(ctx, c), data.length);
    expect(await bs.allKeysChan(ctx).map((k) => k.value).toList(),
        contains(c.value));
    await bs.deleteBlock(ctx, c);
    expect(await bs.has(ctx, c), isFalse);

    final pin = await n.gcLocker.pinLock(ctx);
    var collected = false;
    final gc = corerepo.garbageCollect(n, ctx).then((_) => collected = true);
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (!await n.gcLocker.gcRequested(ctx)) {
      if (DateTime.now().isAfter(deadline)) fail('the GC never asked');
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(collected, isFalse); // waiting for the PinLock
    await pin.unlock(ctx);
    await gc;
    expect(collected, isTrue);
  });

  // 0.20: without the filestore, BaseBlocks is the same store as Blockstore
  test('baseBlocks sees what the blockstore sees', () async {
    final data = utf8.encode('base ${DateTime.now()}');
    final st = await api.block().put(ctx, data, [options.block.pin(false)]);
    final c = cid.Cid(st.path!.value.substring('/ipfs/'.length));
    final base = n.baseBlocks;
    expect(await base.has(ctx, c), isTrue);
    expect(await base.getSize(ctx, c), data.length);
    expect((await base.get(ctx, c)).rawData, data);
    await base.deleteBlock(ctx, c);
    expect(await n.blockstore.has(ctx, c), isFalse);
  });

  // 0.20: only the daemon starts PeriodicGC; a library node has to call it
  test('conditionalGc and periodicGc follow the watermark', () async {
    // offset far beyond StorageMax*watermark: collects now
    var loose = await addUnpinned('conditional ${DateTime.now()}');
    await corerepo.conditionalGc(ctx, n, 1 << 50);
    await expectLater(
        api.block().stat(ctx, loose), throwsA(isA<IpfsException>()));
    // below the watermark: nothing happens
    loose = await addUnpinned('kept ${DateTime.now()}');
    await corerepo.conditionalGc(ctx, n, 0);
    expect((await api.block().stat(ctx, loose)).size, greaterThan(0));

    // a tiny StorageMax and a short period: the loop collects on its own
    final repo = n.repo;
    repo.setConfigKey('Datastore.StorageMax', '1KB');
    repo.setConfigKey('Datastore.GCPeriod', '100ms');
    final (gcCtx, cancel) = context.withCancel(ctx);
    final loop = corerepo.periodicGc(gcCtx, n);
    try {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (true) {
        try {
          await api.block().stat(ctx, loose);
        } on IpfsException {
          break; // collected
        }
        if (DateTime.now().isAfter(deadline)) fail('periodicGc did not run');
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      cancel();
      await loop; // returns nil once the context is done
      repo.setConfigKey('Datastore.StorageMax', '10GB');
      repo.setConfigKey('Datastore.GCPeriod', '1h');
    }
  });

  // 0.15: os bugs do kubo/boxo que o build corrige por patch (tool/build.dart,
  // upstreamPatches; go/upstream_test.go afirma cada um sem o patch).
  test('upstream corrigido: Routing none fecha e reabre o mesmo repo',
      () async {
    final cfg = config.initWithIdentity(
        config.createIdentity(null, [options.key.type('ed25519')]));
    config.profiles['test']!.transform(cfg);
    final repoPath = '${tmp.path}/none';
    fsrepo.init(repoPath, cfg);
    for (var i = 0; i < 2; i++) {
      final nn = await core.newNode(
          ctx,
          node.BuildCfg(
              repo: fsrepo.open(repoPath),
              online: true,
              routing: libp2p.nilRouterOption));
      await nn.close();
    }
  });

  // M3: dois nós online no mesmo processo (como o kubo-as-a-library):
  // perfil `test` (127.0.0.1, portas aleatórias, sem bootstrap) e DHT em
  // modo servidor, para um achar o outro como provedor.
  group('rede', () {
    late core.IpfsNode na, nb;
    late iface.CoreApi a, b;

    Future<(core.IpfsNode, iface.CoreApi)> online(String name) async {
      final cfg = config.initWithIdentity(
          config.createIdentity(null, [options.key.type('ed25519')]));
      config.profiles['test']!.transform(cfg);
      final repoPath = '${tmp.path}/$name';
      fsrepo.init(repoPath, cfg);
      final n = await core.newNode(
          ctx,
          node.BuildCfg(
              repo: fsrepo.open(repoPath),
              online: true,
              routing: libp2p.dhtServerOption,
              extraOpts: {'pubsub': true})); // como Pubsub.Enabled no daemon
      return (n, coreapi.newCoreApi(n));
    }

    setUpAll(() async {
      (na, a) = await online('a');
      (nb, b) = await online('b');
    });

    tearDownAll(() async {
      await na.close();
      await nb.close();
    });

    test('identidade, endereços, connect e peers', () async {
      final idA = (await a.key().self(ctx)).id!;
      final addrs = await a.swarm().localAddrs(ctx);
      expect(addrs, isNotEmpty);
      expect((await a.swarm().listenAddrs(ctx)), isNotEmpty);

      await b.swarm().connect(ctx, peer.AddrInfo(id: idA, addrs: addrs));
      final peers = await b.swarm().peers(ctx);
      expect([for (final p in peers) p.id], contains(idA));
      // F2: ipfs swarm addrs (mapa com chave peer.ID)
      final known = await b.swarm().knownAddrs(ctx);
      expect(known[idA], isNotEmpty);

      // o mesmo AddrInfo pelo formato texto /ip4/.../p2p/<id>
      final p2p = peer.addrInfoToP2pAddrs(peer.AddrInfo(id: idA, addrs: addrs));
      expect(peer.addrInfoFromString(p2p.first.value).id, idA);

      final found = await b.routing().findPeer(ctx, idA);
      expect(found.addrs, isNotEmpty);
    });

    // 0.17: o gateway do boxo sobre o nó B busca pela rede (bitswap) os
    // blocos que só A tem e devolve o CAR verificável do caminho
    test('B baixa de A pelo gateway (getCar, bitswap)', () async {
      final rnd = Random(7);
      final data = Uint8List.fromList(
          List.generate(600000, (_) => rnd.nextInt(256))); // 3 fatias distintas
      final dir = Directory('${tmp.path}/gw')..createSync();
      File('${dir.path}/dados.bin').writeAsBytesSync(data);
      File('${dir.path}/outro.txt').writeAsStringSync('não pedido');
      final p = await a
          .unixfs()
          .add(ctx, files.newSerialFile(dir.path, false, os.stat(dir.path)), [
        options.unixfs.cidVersion(1),
        options.unixfs.chunker('size-262144'),
        options.unixfs.pin(true, '')
      ]);
      // B não tem nada disso: só pela rede
      final offline = b.withOptions([options.api.offline(true)]);
      await expectLater(
          offline.block().stat(ctx, p), throwsA(isA<IpfsException>()));

      final backend = gateway.BlocksBackend(nb.blocks);
      final (c, cancel) = context.withTimeout(
          context.background(), const Duration(seconds: 30));
      try {
        /// O CAR de [path]: os CIDs e os dados das fatias raw, em ordem.
        Future<(List<String>, Uint8List)> getCar(
            String where, gateway.CarParams params) async {
          final (_, rc) =
              await backend.getCar(c, path.ImmutablePath(where), params);
          final br = car.BlockReader(io.readAll(rc));
          rc.close();
          final cids = <String>[];
          final leaves = BytesBuilder();
          while (true) {
            try {
              final blk = br.next();
              cids.add(blk.cid!.value);
              if (blk.cid!.value.startsWith('bafk')) leaves.add(blk.rawData!);
            } on IpfsEof {
              return (cids, leaves.toBytes());
            }
          }
        }

        final file = '${p.value}/dados.bin';
        // entity: a pasta (prova do caminho), a raiz do arquivo e 3 fatias
        final (all, bytes) = await getCar(
            file, gateway.CarParams(scope: gateway.dagScopeEntity));
        expect(all, hasLength(5));
        expect(all.first, p.value.substring('/ipfs/'.length));
        expect(bytes, data);
        // faixa: só a fatia que cobre os bytes pedidos
        final (some, part) = await getCar(
            file,
            gateway.CarParams(
                scope: gateway.dagScopeEntity,
                range: gateway.DagByteRange(from: 300000, to: 300099)));
        expect(some, hasLength(3));
        expect(part, data.sublist(262144, 2 * 262144));
      } finally {
        cancel();
      }
    });

    // 0.20: blockservice.getBlock caches what it fetches; over the null
    // datastore the puts are dropped, so B reads A's file and keeps nothing
    test('B reads from A without storing (null datastore)', () async {
      final rnd = Random(11);
      final data =
          Uint8List.fromList(List.generate(600000, (_) => rnd.nextInt(256)));
      final p = await a.unixfs().add(ctx, files.newBytesFile(data), [
        options.unixfs.cidVersion(1),
        options.unixfs.pin(true, ''),
      ]);
      final root = cid.Cid(p.value.substring('/ipfs/'.length));
      final (c, cancel) = context.withTimeout(
          context.background(), const Duration(seconds: 30));
      try {
        final bs = blockservice.new$(
            blockstore.Blockstore(datastore.NullDatastore()), nb.exchange);
        final dag = merkledag.newDagService(bs);
        final nd = await unixfile.newUnixfsFile(c, dag, await dag.get(c, root));
        final got = BytesBuilder();
        await for (final chunk in io_stream.readerStream(files.toFile(nd))) {
          got.add(chunk);
        }
        expect(got.toBytes(), data);
        expect(await nb.blockstore.has(c, root), isFalse);
      } finally {
        cancel();
      }
    });

    // README, "Points of attention" › "Config": as duas camadas do bitswap pela config
    test('bitswap só por libp2p e sem servir; sem nenhuma camada, não sobe',
        () async {
      final cfg = config.initWithIdentity(
          config.createIdentity(null, [options.key.type('ed25519')]));
      config.profiles['test']!.transform(cfg);
      final repoPath = '${tmp.path}/bitswap-cfg';
      fsrepo.init(repoPath, cfg);
      final repo = fsrepo.open(repoPath);
      repo.setConfigKey('HTTPRetrieval.Enabled', false);
      repo.setConfigKey('Bitswap.ServerEnabled', false);
      final c =
          await core.newNode(ctx, node.BuildCfg(repo: repo, online: true));
      final api = coreapi.newCoreApi(c);
      final p =
          await api.unixfs().add(ctx, files.newBytesFile(utf8.encode('x')));
      expect((await api.block().stat(ctx, p)).size, greaterThan(0));
      await c.close();

      final repo2 = fsrepo.open(repoPath);
      repo2.setConfigKey('Bitswap.Libp2pEnabled', false);
      await expectLater(
          core.newNode(ctx, node.BuildCfg(repo: repo2, online: true)),
          throwsA(isA<IpfsException>().having((e) => e.message, 'message',
              contains('Libp2pEnabled and HTTPRetrieval.Enabled'))));
    });

    test('B busca por bitswap o que A adicionou', () async {
      final data = utf8.encode('de A para B ${DateTime.now()}');
      final p = await a
          .unixfs()
          .add(ctx, files.newBytesFile(data), [options.unixfs.pin(true, '')]);
      final (c, cancel) = context.withTimeout(
          context.background(), const Duration(seconds: 30));
      try {
        final got = await b.unixfs().get(c, p);
        expect(io.readAll(files.toFile(got)), data);
      } finally {
        cancel();
      }
    });

    test('provide em A e findProviders em B', () async {
      final idA = (await a.key().self(ctx)).id!;
      final p = await a.unixfs().add(
          ctx,
          files.newBytesFile(utf8.encode('provide ${DateTime.now()}')),
          [options.unixfs.pin(true, '')]);
      // No kubo 0.43 o Provide só enfileira o anúncio (StartProviding): a
      // busca é repetida até o registro chegar à DHT.
      await a.routing().provide(ctx, p);
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      var provs = <peer.AddrInfo>[];
      while (
          !provs.any((i) => i.id == idA) && DateTime.now().isBefore(deadline)) {
        provs = await b
            .routing()
            .findProviders(ctx, p, [options.routing.numProviders(5)]).toList();
        if (provs.isEmpty)
          await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      expect([for (final i in provs) i.id], contains(idA));
    });

    test('pubsub: A assina, B publica, A recebe', () async {
      final idA = (await a.key().self(ctx)).id!;
      final idB = (await b.key().self(ctx)).id!;
      const topic = 'ipfs-ffi-chat';
      final sub = await a.pubSub().subscribe(ctx, topic);
      expect(await a.pubSub().ls(ctx), contains(topic));

      // B só entrega a quem ele já sabe que assina o tópico (gossipsub)
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!(await b.pubSub().peers(ctx, [options.pubSub.topic(topic)]))
              .contains(idA) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }

      final (c, cancel) = context.withTimeout(
          context.background(), const Duration(seconds: 30));
      try {
        await b.pubSub().publish(ctx, topic, utf8.encode('olá do B'));
        final msg = await sub.next(c);
        expect(utf8.decode(msg.data!), 'olá do B');
        expect(msg.from, idB);
        expect(msg.topics, [topic]);
        expect(msg.seq, isNotEmpty);
      } finally {
        cancel();
        sub.close();
      }
      // depois do close, o next falha em vez de esperar para sempre
      await expectLater(sub.next(ctx), throwsA(isA<IpfsException>()));
    });

    // 0.13: o serviço de peering do nó (IpfsNode.Peering, campo como raiz)
    test('peering: addPeer, listPeers e removePeer', () async {
      final idA = (await a.key().self(ctx)).id!;
      final addrs = await a.swarm().localAddrs(ctx);
      final ps = nb.peering;
      ps.addPeer(peer.AddrInfo(id: idA, addrs: addrs));
      expect([for (final p in ps.listPeers()) p.id], contains(idA));
      ps.removePeer(idA);
      expect([for (final p in ps.listPeers()) p.id], isNot(contains(idA)));
    });

    // 0.20: the connection manager of the running node
    test('connManager: protect, tag and trim keep the protected peer',
        () async {
      final idA = (await a.key().self(ctx)).id!;
      final cm = nb.peerHost.connManager();
      cm.protect(idA, 'download');
      expect(cm.isProtected(idA, 'download'), isTrue);
      cm.tagPeer(idA, 'download-weight', 50);
      await cm.trimOpenConns(ctx);
      expect([for (final p in await b.swarm().peers(ctx)) p.id], contains(idA));
      cm.untagPeer(idA, 'download-weight');
      // unprotect returns whether other tags still protect the peer (the
      // peering test above protects the same one), so only this tag is checked
      cm.unprotect(idA, 'download');
      expect(cm.isProtected(idA, 'download'), isFalse);
    });

    // 0.20: the resource manager's scopes, read inside the callback
    test('resourceManager: system and transient scope stats', () async {
      final rm = nb.resourceManager;
      network.ScopeStat? system, transient;
      await rm.viewSystem((scope) => system = scope.stat());
      await rm.viewTransient((scope) => transient = scope.stat());
      expect(system!.numConnsInbound + system!.numConnsOutbound,
          greaterThanOrEqualTo(1)); // A is connected
      expect(system!.memory, greaterThanOrEqualTo(0));
      expect(transient, isNotNull);
    });

    test('disconnect', () async {
      final idA = (await a.key().self(ctx)).id!;
      // como `ipfs swarm disconnect`: o multiaddr tem de terminar em /p2p/<id>
      final p2p = peer.addrInfoToP2pAddrs(peer.AddrInfo(id: idA, addrs: [
        for (final c in await b.swarm().peers(ctx))
          if (c.id == idA) c.address!
      ]));
      await b.swarm().disconnect(ctx, p2p.first);
      final peers = await b.swarm().peers(ctx);
      expect([for (final p in peers) p.id], isNot(contains(idA)));
    });
  });

  // F2: IPNS, chaves, Dag (merkledag) e DAG-CBOR/JSON, no nó offline
  group('IPNS e chaves', () {
    test('publish e resolve (offline, chave do nó)', () async {
      final p = await api.unixfs().add(
          ctx,
          files.newBytesFile(utf8.encode('ipns ${DateTime.now()}')),
          [options.unixfs.pin(true, '')]);
      final name =
          await api.name().publish(ctx, p, [options.name.allowOffline(true)]);
      expect(name.value, startsWith('k51'));
      final resolved = await api
          .name()
          .resolve(ctx, '/ipns/$name', [options.name.cache(false)]);
      expect(resolved.value, p.value);
      final found = await api.name().search(ctx, '/ipns/$name').toList();
      expect([for (final r in found) r.path?.value], contains(p.value));
    });

    test('generate, list, rename, sign, verify e remove', () async {
      final k =
          await api.key().generate(ctx, 'k1', [options.key.type('ed25519')]);
      expect(k.name, 'k1');
      expect([for (final k in await api.key().list(ctx)) k.name],
          containsAll(['self', 'k1']));
      final (renamed, overwritten) = await api.key().rename(ctx, 'k1', 'k2');
      expect((renamed.name, overwritten), ('k2', false));

      final data = utf8.encode('assinado');
      final (signer, sig) = await api.key().sign(ctx, 'k2', data);
      expect(signer.id, k.id);
      expect((await api.key().verify(ctx, 'k2', sig, data)).$2, isTrue);
      expect((await api.key().verify(ctx, 'k2', sig, utf8.encode('outro'))).$2,
          isFalse);
      expect((await api.key().remove(ctx, 'k2')).id, k.id);
    });
  });

  group('Dag', () {
    test('nós raw e dag-pb: add, get, links, stat, getMany e remove', () async {
      final raw = merkledag.RawNode(utf8.encode('folha'));
      await api.dag().add(ctx, raw);
      final got = await api.dag().get(ctx, raw.cid());
      expect(utf8.decode(got.rawData()), 'folha');

      final pn = merkledag.nodeWithData(utf8.encode('raiz'));
      pn.addNodeLink('filho', raw);
      await api.dag().pinning().add(ctx, pn);
      expect(utf8.decode(pn.data()), 'raiz');
      final links = pn.links();
      expect([for (final l in links) (l.name, l.cid)], [('filho', raw.cid())]);
      expect(pn.stat().numLinks, 1);
      expect((await api.pin().isPinned(ctx, path.Path('/ipfs/${pn.cid()}'))).$2,
          isTrue);

      final many = await api.dag().getMany(ctx, [raw.cid(), pn.cid()]).toList();
      expect([for (final o in many) o.err], everyElement(isNull));
      expect({for (final o in many) o.node!.cid()}, {raw.cid(), pn.cid()});

      final node =
          await api.resolveNode(ctx, path.Path('/ipfs/${pn.cid()}/filho'));
      expect(node.cid(), raw.cid());

      await api.dag().remove(ctx, raw.cid());
      await expectLater(api.block().stat(ctx, path.Path('/ipfs/${raw.cid()}')),
          throwsA(isA<IpfsException>()));
    });

    test('dag put/get: DAG-JSON → DAG-CBOR, caminho dentro do nó e link',
        () async {
      final c = await dag.dagPut(
          api, ctx, utf8.encode('{"a": {"b": [1, 2]}, "t": "oi"}'));
      expect(c.value, startsWith('bafyrei')); // dag-cbor + sha2-256
      expect(
          jsonDecode(
              utf8.decode(await dag.dagGet(api, ctx, path.Path('/ipfs/$c')))),
          {
            'a': {
              'b': [1, 2]
            },
            't': 'oi'
          });
      expect(
          jsonDecode(utf8
              .decode(await dag.dagGet(api, ctx, path.Path('/ipfs/$c/a/b')))),
          [1, 2]);

      // link IPLD: {"/": cid} em dag-json
      final c2 = await dag.dagPut(api, ctx, utf8.encode('{"x": {"/": "$c"}}'),
          pin: true);
      expect(
          jsonDecode(utf8
              .decode(await dag.dagGet(api, ctx, path.Path('/ipfs/$c2/x/t')))),
          'oi');

      // outro codec de saída: o mesmo nó em dag-cbor tem o próprio CID como hash
      final cbor = await dag.dagGet(api, ctx, path.Path('/ipfs/$c'),
          outputCodec: 'dag-cbor');
      expect(cbor, isNotEmpty);

      // bloco acima de 2 MiB: recusado, como no CLI, salvo allowBigBlock
      final big = utf8.encode('{"d": "${'x' * (2 * 1024 * 1024 + 1)}"}');
      await expectLater(
          dag.dagPut(api, ctx, big), throwsA(isA<IpfsException>()));
      expect((await dag.dagPut(api, ctx, big, allowBigBlock: true)).value,
          startsWith('bafyrei'));
    });
  });

  // F3: progresso do add (options.unixfs.events + progress)
  group('progresso do add', () {
    test('4 MiB com progress: bytes crescentes, último com o path', () async {
      final data = Uint8List.fromList(List.generate(4 << 20, (i) => i * 13));
      final events = StreamController<iface.AddEvent>();
      final got = <iface.AddEvent>[];
      var closed = false;
      events.stream.listen(got.add, onDone: () => closed = true);

      final p = await api.unixfs().add(ctx, files.newBytesFile(data), [
        options.unixfs.events(events.sink),
        options.unixfs.progress(true),
      ]);
      expect(closed, isTrue, reason: 'o sink fecha antes do Future completar');

      final progress = [
        for (final e in got)
          if (e.path == null) e.bytes
      ];
      expect(progress, isNotEmpty);
      expect(progress, orderedEquals([...progress]..sort()));
      expect(progress.last, data.length);
      expect(got.last.path?.value, p.value);
    });

    test('diretório sem progress: um evento por arquivo', () async {
      final dir = Directory('${tmp.path}/ev')..createSync();
      File('${dir.path}/x.txt').writeAsStringSync('x');
      File('${dir.path}/y.txt').writeAsStringSync('yy');
      final events = StreamController<iface.AddEvent>();
      final names = events.stream.map((e) => e.name).toList();
      final root = await api.unixfs().add(
          ctx,
          files.newSerialFile(dir.path, false, os.stat(dir.path)),
          [options.unixfs.events(events.sink)]);
      // nomes relativos à raiz ('' = o próprio diretório); o `ipfs add` do CLI
      // mostra 'ev/x.txt' porque embrulha a pasta num diretório com o nome dela
      expect(await names, containsAll(['x.txt', 'y.txt', '']));
      expect(root.value, startsWith('/ipfs/'));
    });

    test('context cancelado: o Future falha e o sink fecha', () async {
      final (c, cancel) = context.withCancel(context.background());
      cancel();
      final events = StreamController<iface.AddEvent>();
      final done = events.stream.toList();
      await expectLater(
          api.unixfs().add(c, files.newBytesFile(Uint8List(1 << 20)), [
            options.unixfs.events(events.sink),
            options.unixfs.progress(true)
          ]),
          throwsA(isA<IpfsException>()));
      await done.timeout(const Duration(seconds: 5));
    });
  });

  // As goroutines do próprio ipfs_ffi (go/runtime.go try/goTry): o panic vira
  // IpfsException e o processo segue.
  group('panic em goroutine do ipfs_ffi vira erro', () {
    test('função do kubo com chan<- (goTry)', () async {
      final events = <Object?>[];
      await expectLater(
          $stream(25).map((r) => r.i64()).forEach(events.add),
          throwsA(isA<IpfsException>().having((e) => e.message, 'message',
              contains('test panic in a function with a channel'))));
      expect(events, [1]); // o que saiu antes do panic chega
    });

    test('encoder do sink de uma opção (chanSink)', () async {
      final c = StreamController<Object?>();
      final got = <Object?>[];
      // o erro chega ao sink antes de a chamada voltar
      final check = expectLater(
          c.stream.forEach(got.add),
          throwsA(isA<IpfsException>().having((e) => e.message, 'message',
              contains('test panic in the sink'))));
      await $call(26, $W()..sink(GoSink(c.sink, (r) => r.i64())));
      await check;
      expect(got, [1]);
    });
  });

  test('isGlobalIpv6 / hasIpv6', () async {
    bool g(String a) => isGlobalIpv6(InternetAddress(a));
    expect(g('2001:4860:4860::8888'), isTrue); // DNS do Google
    expect(g('2001:db8::1'), isTrue); // documentação, mas 2000::/3
    expect(g('fe80::1'), isFalse); // link-local
    expect(g('fd00::1'), isFalse); // privado (ULA)
    expect(g('::1'), isFalse);
    expect(g('ff02::1'), isFalse); // multicast
    expect(g('192.168.0.10'), isFalse);
    expect(await hasIpv6(), isA<bool>()); // depende da rede da máquina
  });

  // Arquivos CAR (ipfs dag export / import)
  // 0.13: o resto da CoreAPI, o MFS e a config de baixo nível (o que o Go
  // expõe, sem nada refeito no Dart)
  group('0.13', () {
    test('withOptions (offline) e routing get/put sem rede', () async {
      final off = api.withOptions([options.api.offline(true)]);
      final p =
          await off.unixfs().add(ctx, files.newBytesFile(utf8.encode('off')));
      expect(
          utf8.decode(io.readAll(files.toFile(await off.unixfs().get(ctx, p)))),
          'off');
      await expectLater(off.routing().get(ctx, '/ipns/nao-existe'),
          throwsA(isA<IpfsException>()));
      await expectLater(
          off.routing().put(ctx, '/ipns/nao-existe', Uint8List(1),
              [options.routing.allowOffline(true)]),
          throwsA(isA<IpfsException>()));
    });

    test('object addLink, rmLink e diff (com as constantes)', () async {
      final empty = Directory('${tmp.path}/vazio')..createSync();
      final p0 = await api.unixfs().add(
          ctx, files.newSerialFile(empty.path, false, os.stat(empty.path)));
      final child =
          await api.unixfs().add(ctx, files.newBytesFile(utf8.encode('filho')));
      final obj = api.object();
      final p1 = await obj.addLink(ctx, p0, 'a', child);
      final added = await obj.diff(ctx, p0, p1);
      expect([for (final c in added) (c.type, c.path)], [(iface.diffAdd, 'a')]);
      final p2 = await obj.rmLink(ctx, p1, 'a');
      final removed = await obj.diff(ctx, p1, p2);
      expect([for (final c in removed) (c.type, c.path)],
          [(iface.diffRemove, 'a')]);
      expect(p2.value, p0.value);
    });

    test('MFS: mkdir, casts, escrita, leitura, list, mv e flush', () async {
      final root = n.filesRoot;
      mfs.mkdir(root, '/t013/sub', mfs.MkdirOpts(mkparents: true, flush: true));
      final dirNode = mfs.lookup(root, '/t013');
      expect(mfs.isDir(dirNode), isTrue);
      expect(dirNode.type(), mfs.tDir);
      expect(dirNode.asFile(), isNull);
      final dir = dirNode.asDirectory()!;
      expect(dir.path(), '/t013');

      // um arquivo pelo nó unixfs de um add
      final p = await api
          .unixfs()
          .add(ctx, files.newBytesFile(utf8.encode('olá mfs')));
      mfs.putNode(root, '/t013/a.txt', await api.resolveNode(ctx, p));
      final file = mfs.lookup(root, '/t013/a.txt').asFile()!;
      expect(file.size(), utf8.encode('olá mfs').length);
      expect(file.rawLeaves, isFalse);
      file.rawLeaves = true; // campo do Go, leitura e escrita
      expect(file.rawLeaves, isTrue);
      file.rawLeaves = false;

      final r0 = await file.open(ctx, mfs.Flags(read: true));
      expect(utf8.decode(await r0.ctxReadFull(ctx, 100)), 'olá mfs');
      r0.close();
      // reescreve (truncate + write) e anexa no fim (seek io.SeekEnd)
      final fw = await file.open(ctx, mfs.Flags(write: true));
      fw.truncate(0);
      expect(fw.write(utf8.encode('novo')), 4);
      expect(fw.seek(0, 2), 4);
      expect(fw.write(utf8.encode('!')), 1);
      fw.close();
      expect(file.size(), 5);
      final fr = await file.open(ctx, mfs.Flags(read: true));
      fr.seek(0, 0);
      expect(utf8.decode(fr.read(2)), 'no');
      fr.seek(0, 0);
      // buffer de saída: pede 100, volta o que havia (EOF não é erro)
      expect(utf8.decode(await fr.ctxReadFull(ctx, 100)), 'novo!');
      expect(await fr.ctxReadFull(ctx, 10), isEmpty);
      fr.close();

      expect(await dir.listNames(ctx), unorderedEquals(['a.txt', 'sub']));
      final list = {for (final e in await dir.list(ctx)) e.name: e};
      expect(list['a.txt']!.type, mfs.tFile);
      expect(list['sub']!.type, mfs.tDir);

      mfs.mv(root, '/t013/a.txt', '/t013/sub/b.txt');
      expect(mfs.isFile(mfs.lookup(root, '/t013/sub/b.txt')), isTrue);
      expect(
          () => mfs.lookup(root, '/t013/a.txt'), throwsA(isA<IpfsException>()));
      final flushed = await mfs.flushPath(ctx, root, '/t013');
      expect(flushed.cid().value, isNotEmpty);
    });

    test('upstream corrigido: append num arquivo pequeno do MFS', () async {
      final root = n.filesRoot;
      final p =
          await api.unixfs().add(ctx, files.newBytesFile(utf8.encode('abc')));
      mfs.putNode(root, '/t015.txt', await api.resolveNode(ctx, p));
      final file = mfs.lookup(root, '/t015.txt').asFile()!;
      final fw = await file.open(ctx, mfs.Flags(write: true));
      fw.seek(0, 2);
      fw.write(utf8.encode('def'));
      fw.close();
      final fr = await file.open(ctx, mfs.Flags(read: true));
      expect(utf8.decode(await fr.ctxReadFull(ctx, 100)), 'abcdef');
      fr.close();
    });

    test('config: setConfigKey/getConfigKey, bootstrap e backup', () async {
      final r = n.repo;
      r.setConfigKey('Discovery.MDNS.Enabled', false);
      expect(r.getConfigKey('Discovery.MDNS.Enabled'), false);
      r.setConfigKey('Discovery.MDNS.Enabled', true);
      expect(r.getConfigKey('Discovery.MDNS.Enabled'), true);
      final addresses = r.getConfigKey('Addresses') as Map<String, Object?>;
      expect(addresses['Swarm'], isA<List<Object?>>());

      final id = (await api.key().self(ctx)).id!;
      final s = '/ip4/127.0.0.1/tcp/4001/p2p/${id.value}';
      final infos = config.parseBootstrapPeers([s]);
      expect(infos.single.id, id);
      expect(config.bootstrapPeerStrings(infos), [s]);
      expect(File(r.backupConfig('teste-')).existsSync(), isTrue);
    });
  });

  group('CAR', () {
    test('export, apaga do repo, import de volta (bytes)', () async {
      final dir = Directory('${tmp.path}/car')..createSync();
      File('${dir.path}/a.txt').writeAsStringSync('A' * 1000);
      File('${dir.path}/b.txt')
          .writeAsStringSync('B' * 300000); // vários blocos
      final root = await api.unixfs().add(
          ctx,
          files.newSerialFile(dir.path, false, os.stat(dir.path)),
          [options.unixfs.pin(true, '')]);

      final bytes = await dag.dagExport(n, ctx, root);
      expect(bytes.length, greaterThan(300000));
      final partial = await dag.dagExport(n, ctx, root, localOnly: true);
      expect(partial, bytes, reason: 'tudo local: o CAR parcial é o completo');

      // some do repo
      await api.pin().rm(ctx, root);
      await corerepo.garbageCollect(n, ctx);
      await expectLater(
          api.block().stat(ctx, root), throwsA(isA<IpfsException>()));

      final r = await dag.dagImport(n, ctx, bytes);
      expect([for (final m in r.roots) (m.cid.value, m.pinErrorMsg)],
          [(root.value.substring('/ipfs/'.length), '')]);
      expect(r.blockCount, greaterThan(2));
      expect(r.blockBytesCount, greaterThan(300000));
      expect((await api.pin().isPinned(ctx, root)).$2, isTrue);
      final out = '${tmp.path}/car-out';
      files.writeTo(await api.unixfs().get(ctx, root), out);
      expect(File('$out/b.txt').lengthSync(), 300000);
    });

    test('dagExportFile e dagImportFiles (sem pin)', () async {
      final c =
          await dag.dagPut(api, ctx, utf8.encode('{"car": true}'), pin: true);
      final file = '${tmp.path}/obj.car';
      await dag.dagExportFile(n, ctx, path.Path('/ipfs/$c'), file);
      expect(File(file).lengthSync(), greaterThan(0));

      final r = await dag.dagImportFiles(n, ctx, [file], pinRoots: false);
      expect(r.roots, isEmpty); // sem --pin-roots, nada é pinado nem listado
      expect(r.blockCount, 1);
      await expectLater(
          dag.dagImportFiles(n, ctx, ['${tmp.path}/nao-existe.car']),
          throwsA(isA<IpfsException>()));
    });
  });

  // 0.9.0: um panic numa goroutine do Go (fora de uma chamada) derruba só o
  // ipfs_host; este processo segue e o onStop recebe o relatório do Go. Nada
  // volta sozinho: quem usa o pacote chama restart(). Por último: o nó dos
  // outros testes cai junto.
  test('panic numa goroutine do Go: só o host cai; onStop decide', () async {
    final oldPid = IpfsService.hostPid;
    final pending = expectLater(
        $call(1, $W()..u32(60000)), // Sleep: ainda pendente na queda
        throwsA(isA<IpfsServiceException>()
            .having((e) => e.reason, 'reason', IpfsStopReason.crash)));
    $callSync(24); // responde e cai logo depois
    hostCrashed = true;
    final crash = await stops.stream.first.timeout(const Duration(seconds: 30));
    await pending;
    expect(crash.reason, IpfsStopReason.crash);
    expect(crash.report, contains('test panic in a goroutine'));
    expect(crash.exitCode, isNot(0));
    expect(crash.pid, oldPid);
    expect(crash.crashLog, '${tmp.path}/crash.log');
    expect(File(crash.crashLog!).readAsStringSync(),
        contains('test panic in a goroutine'));
    // sem restart() o serviço fica fora: as chamadas falham
    expect(IpfsService.isRunning, isFalse);
    expect(
        () => context.background(),
        throwsA(isA<IpfsServiceException>()
            .having((e) => e.reason, 'reason', IpfsStopReason.crash)));

    File(crash.crashLog!).writeAsStringSync(''); // o app decide limpar
    await IpfsService.restart();
    expect(IpfsService.isRunning, isTrue);
    expect(IpfsService.hostPid, isNot(oldPid));

    // o serviço novo funciona; os handles do anterior não valem nele
    expect(context.background().err(), isNull);
    expect(() => ctx.err(), throwsA(isA<IpfsServiceException>()));
    expect(() => api.unixfs(), throwsA(isA<IpfsServiceException>()));
    // processo novo: os plugins do kubo são injetados de novo
    loader.PluginLoader('')
      ..initialize()
      ..inject();
    final repo = '${tmp.path}/depois-do-crash';
    final cfg = config.initWithIdentity(
        config.createIdentity(null, [options.key.type('ed25519')]));
    config.profiles['test']!.transform(cfg);
    fsrepo.init(repo, cfg);
    final n2 = await core.newNode(
        context.background(), node.BuildCfg(repo: fsrepo.open(repo)));
    final api2 = coreapi.newCoreApi(n2);
    final p = await api2
        .unixfs()
        .add(context.background(), files.newBytesFile(utf8.encode('de volta')));
    expect(
        utf8.decode(io.readAll(
            files.toFile(await api2.unixfs().get(context.background(), p)))),
        'de volta');
    await n2.close();
  }, timeout: const Timeout(Duration(minutes: 2)));

  // 0.10.0: no modo padrão (IpfsBackground.stop), o app ir para o segundo
  // plano para o serviço e avisa no onStop; no foregroundService, nada muda.
  test('segundo plano: stop para e avisa; foregroundService segue', () async {
    expect(IpfsService.background, IpfsBackground.stop);
    final oldPid = IpfsService.hostPid;
    final pending = expectLater(
        $call(1, $W()..u32(60000)),
        throwsA(isA<IpfsServiceException>()
            .having((e) => e.reason, 'reason', IpfsStopReason.background)));
    final next = stops.stream.first; // o onStop roda antes de retornar
    await IpfsService.appInBackground();
    final s = await next.timeout(const Duration(seconds: 30));
    await pending;
    expect(s.reason, IpfsStopReason.background);
    expect(s.pid, oldPid);
    expect(s.exitCode, 0); // o host sai sozinho com o canal fechado
    expect(s.report, isEmpty);
    expect(IpfsService.isRunning, isFalse);
    expect(
        () => context.background(),
        throwsA(isA<IpfsServiceException>()
            .having((e) => e.reason, 'reason', IpfsStopReason.background)));
    await IpfsService.appInBackground(); // já parado: nada

    // o app decide subir de novo; o modo é lido na subida
    IpfsService.background = IpfsBackground.foregroundService;
    try {
      await IpfsService.restart();
      final pid = IpfsService.hostPid;
      await IpfsService.appInBackground();
      expect(IpfsService.isRunning, isTrue);
      expect(IpfsService.hostPid, pid);
      expect(context.background().err(), isNull);
    } finally {
      IpfsService.background = IpfsBackground.stop;
    }
  });

  // 0.15, achado no aparelho: o Android só inicia um serviço em primeiro plano
  // com o app na frente; depois de uma queda em foregroundService, o restart
  // do onStop (no segundo plano) tem de achar a plataforma ainda de pé.
  test('foregroundService: a queda não para a plataforma; o stop para',
      () async {
    final calls = <String>[];
    final old = IpfsService.platform;
    Future<void> crash() async {
      final next = stops.stream.first;
      $callSync(24); // panic numa goroutine: o host cai
      expect((await next.timeout(const Duration(seconds: 30))).reason,
          IpfsStopReason.crash);
    }

    // o último teste: termina com o serviço parado (o tearDownAll só para)
    await crash(); // modo stop, plataforma do teste ainda não instalada
    IpfsService.platform = _Platform(calls);
    IpfsService.background = IpfsBackground.foregroundService;
    try {
      await IpfsService.restart();
      expect(calls, ['started foregroundService']);
      await crash();
      expect(calls, ['started foregroundService'], reason: 'sem stopped');
      await IpfsService.restart();
      expect(calls.last, 'started foregroundService');
      await IpfsService.stop();
      expect(calls.last, 'stopped');
    } finally {
      IpfsService.background = IpfsBackground.stop;
      IpfsService.platform = old;
    }
  });
}

final class _Platform implements IpfsPlatform {
  _Platform(this.calls);
  final List<String> calls;

  @override
  Future<void> serviceStarted(IpfsBackground mode) async =>
      calls.add('started ${mode.name}');

  @override
  Future<void> serviceStopped() async => calls.add('stopped');
}
