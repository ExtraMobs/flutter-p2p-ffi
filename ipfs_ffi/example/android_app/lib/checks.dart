// Verificações do ipfs_ffi no aparelho: as locais (os fluxos da suíte de
// desktop que cabem num processo, os ciclos de fechar e reabrir e o custo da
// ponte) rodam no integration test e ao abrir o app; as de rede pública só
// no app, sobre o nó dele. Cada uma escreve no log e falha com exceção.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

typedef Log = void Function(String line);

final ctx = context.background();

void check(bool ok, String what) {
  if (!ok) throw StateError('falhou: $what');
}

Future<void> expectThrows(Future<Object?> f, String what) async {
  try {
    await f;
  } on IpfsException {
    return;
  }
  throw StateError('falhou: $what (não deu erro)');
}

/// Roda [checks] em ordem, cada um isolado; devolve quantos falharam.
Future<int> runAll(Map<String, Future<void> Function()> checks, Log log) async {
  var failed = 0;
  for (final MapEntry(key: name, value: run) in checks.entries) {
    log('▶ $name');
    final sw = Stopwatch()..start();
    try {
      await run();
      log('✔ $name (${sw.elapsedMilliseconds} ms)');
    } catch (e, st) {
      failed++;
      log('✘ $name (${sw.elapsedMilliseconds} ms): $e\n$st');
    }
  }
  return failed;
}

/// Repo novo com o perfil `test` (127.0.0.1, portas aleatórias, sem bootstrap).
String newRepo(Directory tmp, String name) {
  final repoPath = '${tmp.path}/$name';
  final cfg = config
      .initWithIdentity(config.createIdentity([options.key.type('ed25519')]));
  config.profiles['test']!.transform(cfg);
  fsrepo.init(repoPath, cfg);
  return repoPath;
}

/// As verificações locais, num diretório temporário próprio (os plugins já
/// têm de estar injetados). Devolve quantas falharam.
Future<int> localChecks(Log log) async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_chk_');
  final n = await core.newNode(
      ctx, node.BuildCfg(repo: fsrepo.open(newRepo(tmp, 'offline'))));
  final api = coreapi.newCoreApi(n);
  try {
    return await runAll({
      'add/get, opções e pins + GC': () async {
        final p = await api.unixfs().add(
            ctx,
            files.newBytesFile(utf8.encode('olá do Android')),
            [options.unixfs.pin(true, '')]);
        final got = files.toFile(await api.unixfs().get(ctx, p));
        check(utf8.decode(io.readAll(got)) == 'olá do Android', 'get == add');
        final loose = await api.unixfs().add(
            ctx, files.newBytesFile(utf8.encode('solto ${DateTime.now()}')));
        final removed = await corerepo.garbageCollectAsync(n, ctx).toList();
        check(removed.isNotEmpty, 'GC removeu algo');
        await expectThrows(api.block().stat(ctx, loose), 'bloco solto sumiu');
        check((await api.block().stat(ctx, p)).size > 0, 'pinado ficou');
      },
      'progresso do add (events + progress)': () async {
        final data = Uint8List.fromList(List.generate(2 << 20, (i) => i * 7));
        final events = StreamController<iface.AddEvent>();
        final got = events.stream.toList();
        final p = await api.unixfs().add(ctx, files.newBytesFile(data), [
          options.unixfs.events(events.sink),
          options.unixfs.progress(true)
        ]);
        final list = await got;
        check(
            [
                  for (final e in list)
                    if (e.path == null) e.bytes
                ].last ==
                data.length,
            'último progresso == tamanho');
        check(list.last.path?.value == p.value, 'último evento traz o CID');
      },
      'IPNS, chaves e dag put/get': () async {
        final p = await api.unixfs().add(
            ctx,
            files.newBytesFile(utf8.encode('ipns ${DateTime.now()}')),
            [options.unixfs.pin(true, '')]);
        final name =
            await api.name().publish(ctx, p, [options.name.allowOffline(true)]);
        final back = await api
            .name()
            .resolve(ctx, '/ipns/$name', [options.name.cache(false)]);
        check(back.value == p.value, 'resolve == publish');

        final k = await api
            .key()
            .generate(ctx, 'k-android', [options.key.type('ed25519')]);
        final (_, sig) = await api.key().sign(ctx, k.name, utf8.encode('x'));
        check((await api.key().verify(ctx, k.name, sig, utf8.encode('x'))).$2,
            'assinatura confere');
        await api.key().remove(ctx, k.name);

        final c = await dag.put(api, ctx, utf8.encode('{"a": {"b": [1, 2]}}'));
        final got = jsonDecode(
            utf8.decode(await dag.get(api, ctx, path.Path('/ipfs/$c/a/b'))));
        check('$got' == '[1, 2]', 'dag get /a/b');
      },
      'CAR: export, GC, import de volta': () async {
        final p = await api.unixfs().add(
            ctx,
            files.newBytesFile(
                Uint8List.fromList(List.generate(600000, (i) => i))),
            [options.unixfs.pin(true, '')]);
        final car = await dag.exportCar(n, ctx, p);
        await api.pin().rm(ctx, p);
        await corerepo.garbageCollect(n, ctx);
        await expectThrows(api.block().stat(ctx, p), 'GC levou o arquivo');
        final r = await dag.importCar(n, ctx, car);
        check(r.roots.single.pinErrorMsg.isEmpty, 'import pinou');
        check((await api.pin().isPinned(ctx, p)).$2, 'pinado após import');
      },
      'dois nós: connect, bitswap, provide/findProviders e pubsub': () =>
          _twoNodes(tmp),
      // Com Routing none (nilRouterOption) o kubo 0.43 não fecha o datastore
      // do provider-keystore no close (o hook pula o provider Noop) e a
      // reabertura no mesmo processo esbarra no lock: os ciclos usam DHT
      // cliente, como o app.
      'ciclo de vida: 10x newNode → close → fsrepo.open no mesmo repo':
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
        try {
          final a = coreapi.newCoreApi(nn);
          final p =
              await a.unixfs().add(ctx, files.newBytesFile(utf8.encode('fim')));
          check(
              utf8.decode(
                      io.readAll(files.toFile(await a.unixfs().get(ctx, p)))) ==
                  'fim',
              'add/get após os ciclos');
        } finally {
          await nn.close();
        }
      },
      'custo da ponte (JSON × export direto)': () async {
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
        log('  api.unixfs() ${direct.toStringAsFixed(1)} µs; '
            'fsrepo.isInitialized ${stat.toStringAsFixed(1)} µs; '
            'ctx.err() (JSON) ${json.toStringAsFixed(1)} µs');
        check(direct < json * 2, 'o direto não é pior que o JSON');
      },
    }, log);
  } finally {
    await n.close();
    tmp.deleteSync(recursive: true);
  }
}

Future<void> _twoNodes(Directory tmp) async {
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
      check(
          utf8
              .decode(io.readAll(files.toFile(await b.unixfs().get(c, p))))
              .startsWith('de A'),
          'B leu por bitswap');
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
      if (provs.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }
    check(provs.any((i) => i.id == idA), 'B achou A como provedor');

    const topic = 'ipfs-ffi-android';
    final sub = await a.pubSub().subscribe(ctx, topic);
    while (!(await b.pubSub().peers(ctx, [options.pubSub.topic(topic)]))
            .contains(idA) &&
        DateTime.now().isBefore(deadline.add(const Duration(seconds: 30)))) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    await b.pubSub().publish(ctx, topic, utf8.encode('oi do B'));
    final (c2, cancel2) = context.withTimeout(ctx, const Duration(seconds: 30));
    try {
      check(utf8.decode((await sub.next(c2)).data!) == 'oi do B',
          'A recebeu a mensagem do B');
    } finally {
      cancel2();
      sub.close();
    }
  } finally {
    await na.close();
    await nb.close();
  }
}

/// As verificações de rede pública sobre o nó online do app [api]: interfaces
/// (wlan* = Wi-Fi, rmnet*/ccmni* = dados móveis), peers (entrada × saída indica
/// se o NAT deixa entrar), endereços, DNS (DNSLink) e um bloco da rede.
Future<int> networkChecks(iface.CoreApi api, Log log) => runAll({
      'interfaces de rede': () async {
        for (final i in await NetworkInterface.list()) {
          log('  ${i.name}: ${[
            for (final a in i.addresses) a.address
          ].join(', ')}');
        }
      },
      'peers da rede pública (até 60 s)': () async {
        final sw = Stopwatch()..start();
        var peers = await api.swarm().peers(ctx);
        while (peers.isEmpty && sw.elapsed < const Duration(seconds: 60)) {
          await Future<void>.delayed(const Duration(seconds: 1));
          peers = await api.swarm().peers(ctx);
        }
        final inbound = peers.where((p) => p.direction == 1).length;
        log('  ${peers.length} peers (entrada $inbound, '
            'saída ${peers.length - inbound}) em ${sw.elapsed.inSeconds} s');
        check(peers.isNotEmpty, 'algum peer');
      },
      'endereços do nó': () async {
        log('  locais: ${(await api.swarm().localAddrs(ctx)).join(' ')}');
        log('  escuta: ${(await api.swarm().listenAddrs(ctx)).join(' ')}');
      },
      'DNSLink + bloco da rede (/ipns/ipfs.tech, até 60 s)': () async {
        final (c, cancel) =
            context.withTimeout(ctx, const Duration(seconds: 60));
        try {
          final sw = Stopwatch()..start();
          final p = await api.name().resolve(c, '/ipns/ipfs.tech');
          log('  resolveu em ${sw.elapsedMilliseconds} ms: $p');
          final st = await api.block().stat(c, p);
          log('  bloco raiz (${st.size} bytes) em ${sw.elapsedMilliseconds} ms');
        } finally {
          cancel();
        }
      },
    }, log);
