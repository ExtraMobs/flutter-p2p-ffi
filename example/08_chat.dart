// Step 8: real-time chat over pubsub (`ipfs pubsub sub/pub`). Each typed line
// goes to the topic; the others' messages show up on screen. Two instances on the
// same local network find each other through mDNS; over the internet, through the
// DHT (the repo's routing). Each instance needs its own repo.
//
//   dart run example/01_init_repo.dart .chat-a randomports
//   dart run example/08_chat.dart .chat-a room-1 ana
//   (in another terminal, with .chat-b) dart run example/08_chat.dart .chat-b room-1 bob
//
// `/peers` lists who is on the topic; `/quit` or Ctrl-D ends.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface.dart' as iface;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/core/node/libp2p.dart' as libp2p;
import 'package:p2p_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/p2p_ffi.dart' show GolangException, P2pService;

/// The messages of a subscription as a Stream (Go delivers one per `next`).
Stream<iface.PubSubMessage> messages(
    iface.PubSubSubscription sub, context.Context ctx) async* {
  while (true) {
    try {
      yield await sub.next(ctx);
    } on GolangException {
      return; // subscription closed or context canceled
    }
  }
}

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
        'usage: dart run example/08_chat.dart <repo> <topic> [nickname]');
    exit(64);
  }
  final (repoPath, topic) = (args[0], args[1]);
  final nick = args.length > 2 ? args[2] : 'anon';

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
          routing:
              libp2p.constructDefaultRouting(repo.config(), libp2p.dhtOption),
          extraOpts: {'pubsub': true})); // the daemon's Pubsub.Enabled
  final api = coreapi.newCoreApi(n);
  final me = (await api.key().self(ctx)).id!;
  final (subCtx, stop) = context.withCancel(ctx);
  final sub = await api.pubSub().subscribe(subCtx, topic);
  print('[$nick] on topic "$topic" as $me; /peers, /quit');

  final reading = messages(sub, subCtx).listen((m) {
    if (m.from == me) return; // our own echo
    final text = utf8.decode(m.data ?? const []);
    print(text);
  });

  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line == '/quit') break;
    if (line == '/peers') {
      final peers =
          await api.pubSub().peers(ctx, [options.pubSub.topic(topic)]);
      print('[${peers.length} on the topic] ${peers.join(', ')}');
      continue;
    }
    if (line.trim().isEmpty) continue;
    await api.pubSub().publish(ctx, topic, utf8.encode('<$nick> $line'));
  }

  stop();
  sub.close();
  await reading.cancel();
  await n.close();
  await P2pService.stop();
}
