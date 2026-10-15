// Passo 5: dois nós no mesmo processo (como o docs/examples/kubo-as-a-library
// do kubo): B conecta em A, busca por bitswap o que A adicionou e acha A
// como provedor pela DHT. Repos temporários, só em 127.0.0.1.
//
//   dart run example/05_two_nodes.dart
import 'dart:convert';
import 'dart:io';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/libp2p/core/peer.dart' as peer;
import 'package:ipfs_ffi/go/io.dart' as io;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/kubo/config.dart' as config;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface.dart' as iface;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/core/node/libp2p.dart' as libp2p;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;

final ctx = context.background();

/// Repo temporário com o perfil `test` (127.0.0.1, portas aleatórias, sem
/// bootstrap) e nó online com a DHT em modo servidor.
Future<(core.IpfsNode, iface.CoreApi)> spawn(String dir) async {
  final cfg = config
      .initWithIdentity(config.createIdentity([options.key.type('ed25519')]));
  config.profiles['test']!.transform(cfg);
  fsrepo.init(dir, cfg);
  final n = await core.newNode(
      ctx,
      node.BuildCfg(
          repo: fsrepo.open(dir),
          online: true,
          routing: libp2p.dhtServerOption));
  return (n, coreapi.newCoreApi(n));
}

Future<void> main() async {
  // O kubo roda no ipfs_host, noutro processo (dart run tool/build.dart).
  await IpfsService.start();
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_dois_');
  final (na, a) = await spawn('${tmp.path}/a');
  final (nb, b) = await spawn('${tmp.path}/b');
  try {
    final idA = (await a.key().self(ctx)).id!;
    print('A: $idA');
    print('B: ${(await b.key().self(ctx)).id}');

    await b.swarm().connect(
        ctx, peer.AddrInfo(id: idA, addrs: await a.swarm().localAddrs(ctx)));
    print('B conectado a ${(await b.swarm().peers(ctx)).length} peer(s)');

    final p = await a.unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('olá de A\n')),
        [options.unixfs.pin(true, '')]);
    await a.routing().provide(ctx, p);
    print('A adicionou e anunciou $p');

    // O Provide do kubo só enfileira o anúncio: B repete a busca até achar.
    for (var i = 0; i < 100; i++) {
      final provs = await b
          .routing()
          .findProviders(ctx, p, [options.routing.numProviders(5)]).toList();
      // quem baixou o bloco também passa a anunciá-lo: procura A entre eles
      if (provs.any((i) => i.id == idA)) {
        print('B achou A ($idA) entre os provedores na DHT');
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    final (c, cancel) = context.withTimeout(ctx, const Duration(seconds: 30));
    try {
      final got = await b.unixfs().get(c, p);
      print(
          'B leu por bitswap: ${utf8.decode(io.readAll(files.toFile(got))).trim()}');
    } finally {
      cancel();
    }
  } finally {
    await na.close();
    await nb.close();
    tmp.deleteSync(recursive: true);
  }
  await IpfsService.stop();
}
