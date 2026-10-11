// A API gerada (go/gen) na ordem em que o kubo monta um nó: plugins →
// identidade e config → fsrepo.Init/Open → core.NewNode → CoreAPI → Unixfs
// (M1) → pins, blocos e GC (M2).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show Directory, File, Platform, Process;

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/boxo/path.dart' as path;
import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/io.dart' as io;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsException;
import 'package:ipfs_ffi/boxo/ipld/merkledag.dart' as merkledag;
import 'package:ipfs_ffi/kubo/config.dart' as config;
import 'package:ipfs_ffi/kubo/core/commands/dag.dart' as dag;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface.dart' as iface;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/corerepo.dart' as corerepo;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/core/node/libp2p.dart' as libp2p;
import 'package:ipfs_ffi/go_libp2p/core/peer.dart' as peer;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/os.dart' as os;
import 'package:test/test.dart';

void main() {
  late Directory tmp;
  late core.IpfsNode n;
  late iface.CoreApi api;
  final ctx = context.background();

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('ipfs_ffi_kubo_');
    final repoPath = '${tmp.path}/repo';

    // Plugins: uma vez por processo (como o setupPlugins do kubo-as-a-library).
    final plugins = loader.PluginLoader('');
    plugins.initialize();
    plugins.inject();

    // ipfs init
    final identity = config.createIdentity([options.key.type('ed25519')]);
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
    await n.close();
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

  test('erros do Go viram IpfsException, inclusive panic', () async {
    await expectLater(api.resolvePath(ctx, path.Path('não é path')),
        throwsA(isA<IpfsException>()));
    // handle inválido: o Go entra em panic e o recover vira exceção
    await expectLater(
        core.IpfsNode.$h(1 << 40).close(),
        throwsA(isA<IpfsException>()
            .having((e) => e.message, 'message', contains('panic'))));
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

  // M3: dois nós online no mesmo processo (como o kubo-as-a-library):
  // perfil `test` (127.0.0.1, portas aleatórias, sem bootstrap) e DHT em
  // modo servidor, para um achar o outro como provedor.
  group('rede', () {
    late core.IpfsNode na, nb;
    late iface.CoreApi a, b;

    Future<(core.IpfsNode, iface.CoreApi)> online(String name) async {
      final cfg = config.initWithIdentity(
          config.createIdentity([options.key.type('ed25519')]));
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
      final c = await dag.put(
          api, ctx, utf8.encode('{"a": {"b": [1, 2]}, "t": "oi"}'));
      expect(c.value, startsWith('bafyrei')); // dag-cbor + sha2-256
      expect(
          jsonDecode(
              utf8.decode(await dag.get(api, ctx, path.Path('/ipfs/$c')))),
          {
            'a': {
              'b': [1, 2]
            },
            't': 'oi'
          });
      expect(
          jsonDecode(
              utf8.decode(await dag.get(api, ctx, path.Path('/ipfs/$c/a/b')))),
          [1, 2]);

      // link IPLD: {"/": cid} em dag-json
      final c2 =
          await dag.put(api, ctx, utf8.encode('{"x": {"/": "$c"}}'), pin: true);
      expect(
          jsonDecode(
              utf8.decode(await dag.get(api, ctx, path.Path('/ipfs/$c2/x/t')))),
          'oi');

      // outro codec de saída: o mesmo nó em dag-cbor tem o próprio CID como hash
      final cbor = await dag.get(api, ctx, path.Path('/ipfs/$c'),
          outputCodec: 'dag-cbor');
      expect(cbor, isNotEmpty);

      // bloco acima de 2 MiB: recusado, como no CLI, salvo allowBigBlock
      final big = utf8.encode('{"d": "${'x' * (2 * 1024 * 1024 + 1)}"}');
      await expectLater(dag.put(api, ctx, big), throwsA(isA<IpfsException>()));
      expect((await dag.put(api, ctx, big, allowBigBlock: true)).value,
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

  // F4a: panic numa goroutine interna derruba o processo (o guard só cobre a
  // chamada); com debug.setCrashOutput o relatório fica num arquivo.
  test('panic em goroutine do Go: o processo cai e o relatório fica no arquivo',
      () async {
    final log = '${tmp.path}/crash.log';
    final r = await Process.run(
        Platform.resolvedExecutable, ['run', 'test/crash_child.dart', log]);
    expect(r.exitCode, isNot(0));
    final text = File(log).readAsStringSync();
    expect(text, contains('panic: ipfs_ffi: panic de teste numa goroutine'));
    expect(text, contains('goroutine '));
  }, timeout: const Timeout(Duration(minutes: 2)));

  // Arquivos CAR (ipfs dag export / import)
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

      final car = await dag.exportCar(n, ctx, root);
      expect(car.length, greaterThan(300000));
      final partial = await dag.exportCar(n, ctx, root, localOnly: true);
      expect(partial, car, reason: 'tudo local: o CAR parcial é o completo');

      // some do repo
      await api.pin().rm(ctx, root);
      await corerepo.garbageCollect(n, ctx);
      await expectLater(
          api.block().stat(ctx, root), throwsA(isA<IpfsException>()));

      final r = await dag.importCar(n, ctx, car);
      expect([for (final m in r.roots) (m.cid.value, m.pinErrorMsg)],
          [(root.value.substring('/ipfs/'.length), '')]);
      expect(r.blockCount, greaterThan(2));
      expect(r.blockBytesCount, greaterThan(300000));
      expect((await api.pin().isPinned(ctx, root)).$2, isTrue);
      final out = '${tmp.path}/car-out';
      files.writeTo(await api.unixfs().get(ctx, root), out);
      expect(File('$out/b.txt').lengthSync(), 300000);
    });

    test('exportCarFile e importCarFiles (sem pin)', () async {
      final c =
          await dag.put(api, ctx, utf8.encode('{"car": true}'), pin: true);
      final file = '${tmp.path}/obj.car';
      await dag.exportCarFile(n, ctx, path.Path('/ipfs/$c'), file);
      expect(File(file).lengthSync(), greaterThan(0));

      final r = await dag.importCarFiles(n, ctx, [file], pinRoots: false);
      expect(r.roots, isEmpty); // sem --pin-roots, nada é pinado nem listado
      expect(r.blockCount, 1);
      await expectLater(
          dag.importCarFiles(n, ctx, ['${tmp.path}/nao-existe.car']),
          throwsA(isA<IpfsException>()));
    });
  });
}
