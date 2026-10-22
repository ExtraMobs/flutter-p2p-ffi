// Step 4: the node on the public IPFS network, like `ipfs daemon` without HTTP
// (no RPC API nor gateway). Routing comes from the config's Routing.Type, as in
// cmd/ipfs/kubo/daemon.go.
//
//   dart run example/01_init_repo.dart .ipfs-online randomports
//   dart run example/04_online.dart .ipfs-online [seconds] [cid-to-fetch]
//
// `randomports` avoids 4001 (taken while IPFS Desktop is open).
// Without [seconds], it runs until Ctrl-C.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ipfs_ffi/go/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/boxo/path.dart' as path;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/io.dart' as io;
import 'package:ipfs_ffi/go/kubo/config.dart' as config;
import 'package:ipfs_ffi/go/kubo/core.dart' as core;
import 'package:ipfs_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/go/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/go/kubo/core/node/libp2p.dart' as libp2p;
import 'package:ipfs_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/ipfs_ffi.dart' show P2pService;

/// daemon.go's switch over Routing.Type.
libp2p.RoutingOption routingFor(config.Config cfg) {
  final type = (cfg.json['Routing'] as Map?)?['Type'] as String? ?? '';
  return switch (type) {
    '' ||
    'auto' ||
    'default' =>
      libp2p.constructDefaultRouting(cfg, libp2p.dhtOption),
    'autoclient' => libp2p.constructDefaultRouting(cfg, libp2p.dhtClientOption),
    'dht' => libp2p.dhtOption,
    'dhtclient' => libp2p.dhtClientOption,
    'dhtserver' => libp2p.dhtServerOption,
    'none' => libp2p.nilRouterOption,
    _ =>
      throw ArgumentError('Routing.Type "$type" not supported in the example'),
  };
}

Future<void> main(List<String> args) async {
  final repoPath = args.isNotEmpty ? args.first : '.ipfs-online';
  final seconds = args.length > 1 ? int.parse(args[1]) : null;

  // Kubo runs in the ipfs_host, in another process (dart run tool/build.dart).
  await P2pService.start();
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final ctx = context.background();
  final repo = fsrepo.open(repoPath);
  final n = await core.newNode(
      ctx,
      node.BuildCfg(
          repo: repo,
          online: true,
          permanent: true,
          routing: routingFor(repo.config())));
  try {
    final api = coreapi.newCoreApi(n);
    print('peer: ${(await api.key().self(ctx)).id}');
    for (final a in await api.swarm().listenAddrs(ctx)) {
      print('  listening on $a');
    }

    // our own content: pinned and announced on the DHT
    final p = await api.unixfs().add(
        ctx,
        files.newBytesFile(
            utf8.encode('hello from the network, over Dart FFI\n')),
        [options.unixfs.pin(true, 'exemplo-04')]);
    print('add: $p (announcing...)');
    unawaited(api.routing().provide(ctx, p).then((_) => print('provide: ok'),
        onError: (Object e) => print('provide: $e')));

    // another peer's content, over the network
    if (args.length > 2) {
      final (c, cancel) = context.withTimeout(ctx, const Duration(seconds: 60));
      try {
        final got = await api.unixfs().get(c, path.Path(args[2]));
        print('get ${args[2]}: ${io.readAll(files.toFile(got)).length} B');
      } on Exception catch (e) {
        print('get ${args[2]}: $e');
      } finally {
        cancel();
      }
    }

    final ticker = Timer.periodic(const Duration(seconds: 5), (_) async {
      print('connected peers: ${(await api.swarm().peers(ctx)).length}');
    });
    if (seconds != null) {
      await Future<void>.delayed(Duration(seconds: seconds));
    } else {
      print('running; Ctrl-C to stop');
      await ProcessSignal.sigint.watch().first;
    }
    ticker.cancel();
  } finally {
    await n.close();
  }
  await P2pService.stop();
}
