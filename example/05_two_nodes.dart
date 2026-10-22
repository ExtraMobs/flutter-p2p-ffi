// Step 5: two nodes in the same process (like kubo's
// docs/examples/kubo-as-a-library): B connects to A, fetches over bitswap what A
// added and finds A as a provider through the DHT. Temporary repos, 127.0.0.1 only.
//
//   dart run example/05_two_nodes.dart
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/libp2p/core/peer.dart' as peer;
import 'package:p2p_ffi/go/io.dart' as io;
import 'package:p2p_ffi/go/kubo/config.dart' as config;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface.dart' as iface;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/core/node/libp2p.dart' as libp2p;
import 'package:p2p_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/p2p_ffi.dart' show P2pService;

final ctx = context.background();

/// A temporary repo with the `test` profile (127.0.0.1, random ports, no
/// bootstrap) and an online node with the DHT in server mode.
Future<(core.IpfsNode, iface.CoreApi)> spawn(String dir) async {
  final cfg = config.initWithIdentity(
      config.createIdentity(null, [options.key.type('ed25519')]));
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
  // Kubo runs in the ipfs_host, in another process (dart run tool/build.dart).
  await P2pService.start();
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final tmp = Directory.systemTemp.createTempSync('p2p_ffi_dois_');
  final (na, a) = await spawn('${tmp.path}/a');
  final (nb, b) = await spawn('${tmp.path}/b');
  try {
    final idA = (await a.key().self(ctx)).id!;
    print('A: $idA');
    print('B: ${(await b.key().self(ctx)).id}');

    await b.swarm().connect(
        ctx, peer.AddrInfo(id: idA, addrs: await a.swarm().localAddrs(ctx)));
    print('B connected to ${(await b.swarm().peers(ctx)).length} peer(s)');

    final p = await a.unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('hello from A\n')),
        [options.unixfs.pin(true, '')]);
    await a.routing().provide(ctx, p);
    print('A added and announced $p');

    // Kubo's Provide only queues the announcement: B retries the lookup until it finds it.
    for (var i = 0; i < 100; i++) {
      final provs = await b
          .routing()
          .findProviders(ctx, p, [options.routing.numProviders(5)]).toList();
      // whoever downloaded the block announces it too: look for A among them
      if (provs.any((i) => i.id == idA)) {
        print('B found A ($idA) among the DHT providers');
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    final (c, cancel) = context.withTimeout(ctx, const Duration(seconds: 30));
    try {
      final got = await b.unixfs().get(c, p);
      print(
          'B read over bitswap: ${utf8.decode(io.readAll(files.toFile(got))).trim()}');
    } finally {
      cancel();
    }
  } finally {
    await na.close();
    await nb.close();
    tmp.deleteSync(recursive: true);
  }
  await P2pService.stop();
}
