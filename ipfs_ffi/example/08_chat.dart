// Passo 8: chat em tempo real sobre pubsub (`ipfs pubsub sub/pub`). Cada
// linha digitada vai para o tópico; as mensagens dos outros aparecem na tela.
// Duas instâncias na mesma rede local se acham pelo mDNS; pela internet, pela
// DHT (o roteamento do repo). Cada instância precisa de um repo próprio.
//
//   dart run example/01_init_repo.dart .chat-a randomports
//   dart run example/08_chat.dart .chat-a sala-1 ana
//   (em outro terminal, com .chat-b) dart run example/08_chat.dart .chat-b sala-1 beto
//
// `/peers` lista quem está no tópico; `/sair` ou Ctrl-D encerra.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsException, IpfsService;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface.dart' as iface;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/core/node/libp2p.dart' as libp2p;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;

/// As mensagens de uma assinatura como Stream (o Go entrega uma por `next`).
Stream<iface.PubSubMessage> messages(
    iface.PubSubSubscription sub, context.Context ctx) async* {
  while (true) {
    try {
      yield await sub.next(ctx);
    } on IpfsException {
      return; // assinatura fechada ou contexto cancelado
    }
  }
}

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
        'uso: dart run example/08_chat.dart <repo> <topico> [apelido]');
    exit(64);
  }
  final (repoPath, topic) = (args[0], args[1]);
  final nick = args.length > 2 ? args[2] : 'anon';

  // O kubo roda no ipfs_host, noutro processo (dart run tool/build.dart).
  await IpfsService.start();
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
          routing:
              libp2p.constructDefaultRouting(repo.config(), libp2p.dhtOption),
          extraOpts: {'pubsub': true})); // Pubsub.Enabled do daemon
  final api = coreapi.newCoreApi(n);
  final me = (await api.key().self(ctx)).id!;
  final (subCtx, stop) = context.withCancel(ctx);
  final sub = await api.pubSub().subscribe(subCtx, topic);
  print('[$nick] no tópico "$topic" como $me; /peers, /sair');

  final reading = messages(sub, subCtx).listen((m) {
    if (m.from == me) return; // o próprio eco
    final text = utf8.decode(m.data ?? const []);
    print(text);
  });

  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line == '/sair') break;
    if (line == '/peers') {
      final peers =
          await api.pubSub().peers(ctx, [options.pubSub.topic(topic)]);
      print('[${peers.length} no tópico] ${peers.join(', ')}');
      continue;
    }
    if (line.trim().isEmpty) continue;
    await api.pubSub().publish(ctx, topic, utf8.encode('<$nick> $line'));
  }

  stop();
  sub.close();
  await reading.cancel();
  await n.close();
  await IpfsService.stop();
}
