// Passo 4: o nó na rede IPFS pública, como o `ipfs daemon` sem HTTP (sem
// API RPC nem gateway). O roteamento sai do Routing.Type da config, como no
// cmd/ipfs/kubo/daemon.go.
//
//   dart run example/01_init_repo.dart .ipfs-online randomports
//   dart run example/04_online.dart .ipfs-online [segundos] [cid-para-buscar]
//
// `randomports` evita a 4001 (ocupada se o IPFS Desktop estiver aberto).
// Sem [segundos], roda até o Ctrl-C.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/boxo/path.dart' as path;
import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/io.dart' as io;
import 'package:ipfs_ffi/kubo/config.dart' as config;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/core/node/libp2p.dart' as libp2p;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;

/// O switch do daemon.go sobre Routing.Type.
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
    _ => throw ArgumentError('Routing.Type "$type" não suportado no exemplo'),
  };
}

Future<void> main(List<String> args) async {
  final repoPath = args.isNotEmpty ? args.first : '.ipfs-online';
  final seconds = args.length > 1 ? int.parse(args[1]) : null;

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
      print('  ouvindo $a');
    }

    // conteúdo próprio: pinado e anunciado na DHT
    final p = await api.unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('olá da rede, via Dart FFI\n')),
        [options.unixfs.pin(true, 'exemplo-04')]);
    print('add: $p (anunciando...)');
    unawaited(api.routing().provide(ctx, p).then((_) => print('provide: ok'),
        onError: (Object e) => print('provide: $e')));

    // conteúdo de outro peer, pela rede
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
      print('peers conectados: ${(await api.swarm().peers(ctx)).length}');
    });
    if (seconds != null) {
      await Future<void>.delayed(Duration(seconds: seconds));
    } else {
      print('rodando; Ctrl-C para parar');
      await ProcessSignal.sigint.watch().first;
    }
    ticker.cancel();
  } finally {
    await n.close();
  }
}
