// Lesson 18 · How do I send messages in real time?
//
// Question: bitswap fetches content someone asks for. How do peers push
// messages to everyone interested, as they happen (a chat, live updates)?
//
// Answer: pubsub, with libp2p's gossipsub. Peers subscribe to a topic (a
// name); a message published to it is forwarded peer to peer through a mesh
// of the subscribers, each peer passing it to a few others, until all have
// it. Messages are signed by their author and deduplicated. A validator, a
// function each peer runs on every message, decides whether to accept,
// ignore or reject it (and penalizes peers that send rejected ones).
// Nothing is stored: who was not subscribed when it was sent never sees it;
// for history, publish a CID (content) or an IPNS name (lesson 11).
// Two ways in this lesson:
//   - kubo's pubsub (`ipfs pubsub`): the node's own gossipsub, enabled by
//     Pubsub.Enabled in the config or the `pubsub` extra option;
//   - gossipsub straight on libp2p hosts, with a Dart validator.
//
// Needs: lessons 14-15 (connected peers; subscribers find each other through
// the peers they are connected to, or through the DHT/mDNS discovery of an
// online kubo node). Technically: a host, a gossipsub router on it, and at
// least one path of connected subscribers between author and reader.
//
//   dart run example/en_us/18_pubsub.dart
//
// Next question: "Some of these calls can wait forever. How do I give them
// a deadline, and what errors can come back?" → lesson 19.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/kubo/config.dart' as config;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/core/node/libp2p.dart' as kubo_libp2p;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/go/libp2p.dart' as libp2p;
import 'package:p2p_ffi/go/libp2p/core/host.dart' as host;
import 'package:p2p_ffi/go/libp2p/core/peer.dart' as peer;
import 'package:p2p_ffi/go/libp2p_pubsub.dart' as pubsub;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson18_');
  final ctx = context.background();
  try {
    // 1. kubo's pubsub: two online nodes on loopback, pubsub enabled.
    //    Go:  core.NewNode(ctx, &node.BuildCfg{..., ExtraOpts: map[string]bool{"pubsub": true}})
    loadPlugins();
    Future<core.IpfsNode> pubsubNode(String name) async {
      final cfg = config.initWithIdentity(
          config.createIdentity(null, [options.key.type('ed25519')]));
      config.profiles['test']!.transform(cfg);
      fsrepo.init('${tmp.path}/$name', cfg);
      return core.newNode(
          ctx,
          node.BuildCfg(
              repo: fsrepo.open('${tmp.path}/$name'),
              online: true,
              routing: kubo_libp2p.dhtServerOption,
              extraOpts: {'pubsub': true}));
    }

    final na = await pubsubNode('a'), nb = await pubsubNode('b');
    final a = coreapi.newCoreApi(na), b = coreapi.newCoreApi(nb);
    final idA = (await a.key().self(ctx)).id!;
    await b.swarm().connect(
        ctx, peer.AddrInfo(id: idA, addrs: await a.swarm().localAddrs(ctx)));

    //    a subscribes; b waits until it sees a on the topic, then publishes.
    //    Go:  sub, _ := api.PubSub().Subscribe(ctx, "news")
    final (subCtx, stopSub) = context.withCancel(ctx);
    final sub = await a.pubSub().subscribe(subCtx, 'news');
    while (!(await b.pubSub().peers(ctx, [options.pubSub.topic('news')]))
        .contains(idA)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    //    Go:  api.PubSub().Publish(ctx, "news", data)
    await b.pubSub().publish(ctx, 'news', utf8.encode('hello from b'));
    final m = await sub.next(subCtx);
    say('kubo pubsub: a got "${utf8.decode(m.data!)}" on '
        '${m.topics.join(', ')} from ${m.from!.shortString()}');
    stopSub();
    sub.close();
    await na.close();
    await nb.close();

    // 2. gossipsub on libp2p hosts: three hosts in a line (x - y - z), so a
    //    message from x reaches z only through y.
    //    Go:  ps, _ := pubsub.NewGossipSub(ctx, h); t, _ := ps.Join("chat")
    final hosts = [
      for (var i = 0; i < 3; i++)
        await libp2p.new$([
          libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]),
    ];
    final [x, y, z] = hosts;
    await x.connect(ctx, host.infoFromHost(y));
    await z.connect(ctx, host.infoFromHost(y));
    final routers = [for (final h in hosts) await pubsub.newGossipSub(ctx, h)];
    //    z only accepts short messages: a Dart function Go calls for each
    //    message (accept, ignore or reject; an exception also rejects).
    //    Go:  ps.RegisterTopicValidator("chat", func(ctx, from, m) ValidationResult {...})
    await routers[2].registerTopicValidator(
        'chat',
        (_, from, msg) => msg.message!.getData().length <= 64
            ? pubsub.validationAccept
            : pubsub.validationReject);
    final topics = [for (final r in routers) await r.join('chat')];
    final zSub = await topics[2].subscribe();
    final ySub = await topics[1].subscribe(); // y relays only if subscribed
    while ((await topics[0].listPeers()).isEmpty ||
        (await topics[2].listPeers()).isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await topics[0].publish(ctx, Uint8List.fromList(utf8.encode('hi from x')));
    await topics[0].publish(
        ctx, Uint8List.fromList(utf8.encode('${'x' * 100} (z rejects it)')));
    await topics[0].publish(ctx, Uint8List.fromList(utf8.encode('bye from x')));
    for (var i = 0; i < 2; i++) {
      final (nctx, cancel) =
          context.withTimeout(ctx, const Duration(seconds: 10));
      final got = await zSub.next(nctx);
      cancel();
      say('gossipsub: z got "${utf8.decode(got.message!.getData())}" '
          '(author ${peer.idFromBytes(got.message!.getFrom()).shortString()}, '
          'relayed by ${got.receivedFrom!.shortString()})');
    }

    say('\n== Common mistakes\n');
    final late = await topics[2].subscribe();
    await mistake('expecting a message published before you subscribed',
        why: 'pubsub keeps nothing: "hi from x" went out before this '
            'subscription existed',
        instead: 'publish a CID or an IPNS name for history; pubsub only '
            'for what happens now', action: () async {
      final (nctx, cancel) =
          context.withTimeout(ctx, const Duration(seconds: 2));
      try {
        await late.next(nctx);
      } finally {
        cancel();
      }
    });
    late.cancel();
    await mistake('joining the same topic twice on one router',
        why: 'a router keeps one Topic per name; join returns it once',
        instead: 'keep the Topic from the first join and reuse it',
        action: () => routers[0].join('chat'));

    zSub.cancel();
    ySub.cancel();
    for (final h in hosts) {
      await h.close();
    }
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
