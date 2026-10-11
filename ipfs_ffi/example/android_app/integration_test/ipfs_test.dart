// O ipfs_ffi dentro de um app Android (marco final, A3/A5/A6): os fluxos da
// suíte de desktop (test/kubo_test.dart) que cabem num processo, os ciclos de
// fechar e reabrir o nó e o custo da ponte. Roda com:
//   flutter test integration_test -d <emulador-ou-aparelho>
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/boxo/path.dart' as path;
import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/go_libp2p/core/peer.dart' as peer;
import 'package:ipfs_ffi/io.dart' as io;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsException;
import 'package:ipfs_ffi/kubo/config.dart' as config;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/commands/dag.dart' as dag;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface.dart' as iface;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/corerepo.dart' as corerepo;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/core/node/libp2p.dart' as libp2p;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi_android/main.dart' show prepare;

final ctx = context.background();

/// Repo novo com o perfil `test` (127.0.0.1, portas aleatórias, sem bootstrap).
String newRepo(Directory tmp, String name) {
  final repoPath = '${tmp.path}/$name';
  final cfg = config
      .initWithIdentity(config.createIdentity([options.key.type('ed25519')]));
  config.profiles['test']!.transform(cfg);
  fsrepo.init(repoPath, cfg);
  return repoPath;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late core.IpfsNode n;
  late iface.CoreApi api;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('ipfs_ffi_it_');
    // plugins (1x por processo) e relatório de crash, como o app faz
    prepare('${tmp.path}/app-repo', '${tmp.path}/crash.log');
    n = await core.newNode(
        ctx, node.BuildCfg(repo: fsrepo.open(newRepo(tmp, 'offline'))));
    api = coreapi.newCoreApi(n);
  });

  tearDownAll(() async {
    await n.close();
    tmp.deleteSync(recursive: true);
  });

  test('add/get, opções e pins + GC', () async {
    final p = await api.unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('olá do emulador')),
        [options.unixfs.pin(true, '')]);
    final got = files.toFile(await api.unixfs().get(ctx, p));
    expect(utf8.decode(io.readAll(got)), 'olá do emulador');

    final loose = await api
        .unixfs()
        .add(ctx, files.newBytesFile(utf8.encode('solto ${DateTime.now()}')));
    final removed = await corerepo.garbageCollectAsync(n, ctx).toList();
    expect(removed, isNotEmpty);
    await expectLater(
        api.block().stat(ctx, loose), throwsA(isA<IpfsException>()));
    expect((await api.block().stat(ctx, p)).size, greaterThan(0));
  });

  test('progresso do add (events + progress)', () async {
    final data = Uint8List.fromList(List.generate(2 << 20, (i) => i * 7));
    final events = StreamController<iface.AddEvent>();
    final got = events.stream.toList();
    final p = await api.unixfs().add(ctx, files.newBytesFile(data),
        [options.unixfs.events(events.sink), options.unixfs.progress(true)]);
    final list = await got;
    expect(
        [
          for (final e in list)
            if (e.path == null) e.bytes
        ].last,
        data.length);
    expect(list.last.path?.value, p.value);
  });

  test('IPNS, chaves e dag put/get', () async {
    final p = await api.unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('ipns ${DateTime.now()}')),
        [options.unixfs.pin(true, '')]);
    final name =
        await api.name().publish(ctx, p, [options.name.allowOffline(true)]);
    expect(
        (await api
                .name()
                .resolve(ctx, '/ipns/$name', [options.name.cache(false)]))
            .value,
        p.value);

    final k = await api
        .key()
        .generate(ctx, 'k-android', [options.key.type('ed25519')]);
    final (_, sig) = await api.key().sign(ctx, k.name, utf8.encode('x'));
    expect((await api.key().verify(ctx, k.name, sig, utf8.encode('x'))).$2,
        isTrue);
    await api.key().remove(ctx, k.name);

    final c = await dag.put(api, ctx, utf8.encode('{"a": {"b": [1, 2]}}'));
    expect(
        jsonDecode(
            utf8.decode(await dag.get(api, ctx, path.Path('/ipfs/$c/a/b')))),
        [1, 2]);
  });

  test('CAR: export, GC, import de volta', () async {
    final p = await api.unixfs().add(
        ctx,
        files.newBytesFile(Uint8List.fromList(List.generate(600000, (i) => i))),
        [options.unixfs.pin(true, '')]);
    final car = await dag.exportCar(n, ctx, p);
    await api.pin().rm(ctx, p);
    await corerepo.garbageCollect(n, ctx);
    await expectLater(api.block().stat(ctx, p), throwsA(isA<IpfsException>()));
    final r = await dag.importCar(n, ctx, car);
    expect(r.roots.single.pinErrorMsg, isEmpty);
    expect((await api.pin().isPinned(ctx, p)).$2, isTrue);
  });

  test('dois nós: connect, bitswap, provide/findProviders e pubsub', () async {
    Future<(core.IpfsNode, iface.CoreApi)> online(String name) async {
      final nn = await core.newNode(
          ctx,
          node.BuildCfg(
              repo: fsrepo.open(newRepo(tmp, name)),
              online: true,
              routing: libp2p.dhtServerOption,
              extraOpts: {'pubsub': true}));
      return (nn, coreapi.newCoreApi(nn));
    }

    final (na, a) = await online('a');
    final (nb, b) = await online('b');
    try {
      final idA = (await a.key().self(ctx)).id!;
      await b.swarm().connect(
          ctx, peer.AddrInfo(id: idA, addrs: await a.swarm().localAddrs(ctx)));

      final p = await a.unixfs().add(
          ctx,
          files.newBytesFile(utf8.encode('de A ${DateTime.now()}')),
          [options.unixfs.pin(true, '')]);
      final (c, cancel) = context.withTimeout(ctx, const Duration(seconds: 30));
      try {
        expect(
            utf8.decode(io.readAll(files.toFile(await b.unixfs().get(c, p)))),
            startsWith('de A'));
      } finally {
        cancel();
      }

      await a.routing().provide(ctx, p);
      var provs = <peer.AddrInfo>[];
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (
          !provs.any((i) => i.id == idA) && DateTime.now().isBefore(deadline)) {
        provs = await b
            .routing()
            .findProviders(ctx, p, [options.routing.numProviders(5)]).toList();
        if (provs.isEmpty)
          await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      expect([for (final i in provs) i.id], contains(idA));

      const topic = 'ipfs-ffi-android';
      final sub = await a.pubSub().subscribe(ctx, topic);
      while (!(await b.pubSub().peers(ctx, [options.pubSub.topic(topic)]))
              .contains(idA) &&
          DateTime.now().isBefore(deadline.add(const Duration(seconds: 30)))) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      await b.pubSub().publish(ctx, topic, utf8.encode('oi do B'));
      final (c2, cancel2) =
          context.withTimeout(ctx, const Duration(seconds: 30));
      try {
        expect(utf8.decode((await sub.next(c2)).data!), 'oi do B');
      } finally {
        cancel2();
        sub.close();
      }
    } finally {
      await na.close();
      await nb.close();
    }
  });

  // Com Routing none (nilRouterOption) o kubo 0.43 não fecha o datastore do
  // provider-keystore no close (o hook pula o provider Noop) e a reabertura no
  // mesmo processo esbarra no lock: os ciclos usam DHT cliente, como o app.
  test('ciclo de vida: 10x newNode → close → fsrepo.open no mesmo repo',
      () async {
    final repoPath = newRepo(tmp, 'ciclos');
    for (var i = 0; i < 10; i++) {
      final nn = await core.newNode(
          ctx,
          node.BuildCfg(
              repo: fsrepo.open(repoPath),
              online: true,
              routing: libp2p.dhtClientOption));
      await nn.close();
    }
    final nn =
        await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repoPath)));
    final a = coreapi.newCoreApi(nn);
    final p = await a.unixfs().add(ctx, files.newBytesFile(utf8.encode('fim')));
    expect(utf8.decode(io.readAll(files.toFile(await a.unixfs().get(ctx, p)))),
        'fim');
    await nn.close();
  });

  test('custo da ponte (JSON × export direto)', () async {
    final repoPath = '${tmp.path}/offline';
    double bench(void Function() f) {
      for (var i = 0; i < 500; i++) {
        f();
      }
      const count = 5000;
      final sw = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        f();
      }
      return sw.elapsedMicroseconds / count;
    }

    final direct = bench(() => api.unixfs());
    final stat = bench(() => fsrepo.isInitialized(repoPath));
    final json = bench(() => ctx.err());
    // ignore: avoid_print
    print('bench android: api.unixfs() ${direct.toStringAsFixed(1)} µs; '
        'fsrepo.isInitialized ${stat.toStringAsFixed(1)} µs; '
        'ctx.err() (JSON) ${json.toStringAsFixed(1)} µs');
    expect(direct, lessThan(json * 2)); // o direto não pode ser pior que o JSON
  });
}
