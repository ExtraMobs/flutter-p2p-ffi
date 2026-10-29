// Lesson 17 · How do I join the public IPFS network?
//
// Question: lessons 13-16 used my own hosts on loopback. How does my node
// join the real IPFS network and fetch content anyone published?
//
// Answer: an online kubo node with a normal config does everything of part C
// for you:
//   - bootstrap: it dials the well-known peers in the config's Bootstrap
//     list (kubo's AutoConf keeps that list and the routers up to date);
//   - routing: Routing.Type decides how it finds content: the public DHT
//     (`/ipfs/kad/1.0.0`), delegated HTTP routers (cid.contact), or both
//     ("auto", the default);
//   - bitswap over its host and that routing (lesson 16) is n.exchange;
//   - reachability: AutoNAT asks other peers to dial it back; behind a NAT
//     it stays a DHT client and can use relays and hole punching to be
//     reached. It provides (announces) what it adds, so others can fetch it.
// On Android, Go cannot find the system's DNS resolver: set DNS.Resolvers in
// the config (DNS over HTTPS), or names like `/dnsaddr/bootstrap.libp2p.io`
// do not resolve.
//
// Needs: lessons 08 (a node) and 13-16 (what it does online), plus a network
// that lets it reach the internet. The `randomports` profile keeps it off
// port 4001, which IPFS Desktop (or another kubo) may hold.
//
//   dart run example/en_us/17_public_network.dart
//
// Next question: "Fetching is pull. Can peers push messages to each other as
// they happen?" → lesson 18.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

/// A small file published by the IPFS public gateway checker: anyone on the
/// network can fetch it.
const known = 'bafybeifx7yeb55armcsxwwitkymga5xf53dxiarykms3ygqic223w5sk3m';

/// What `ipfs daemon` does with the config's Routing.Type
/// (cmd/ipfs/kubo/daemon.go).
KuboCoreNodeLibp2pRoutingOption routingFor(KuboConfig cfg) {
  final type = (cfg.json['Routing'] as Map?)?['Type'] as String? ?? '';
  return switch (type) {
    '' || 'auto' || 'default' => goKubo.core.node.libp2p
        .constructDefaultRouting(cfg, goKubo.core.node.libp2p.dhtOption),
    'autoclient' => goKubo.core.node.libp2p
        .constructDefaultRouting(cfg, goKubo.core.node.libp2p.dhtClientOption),
    'dht' => goKubo.core.node.libp2p.dhtOption,
    'dhtclient' => goKubo.core.node.libp2p.dhtClientOption,
    'dhtserver' => goKubo.core.node.libp2p.dhtServerOption,
    'none' => goKubo.core.node.libp2p.nilRouterOption,
    _ => throw ArgumentError('Routing.Type "$type" not handled here'),
  };
}

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson17_');
  final ctx = goContext.background();
  try {
    // 1. A repo with the normal config (bootstrap peers, routing "auto"),
    //    only with random ports.
    loadPlugins();
    final cfg = goKubo.config.initWithIdentity(goKubo.config.createIdentity(
        null, [goKubo.core.coreiface.options.key.type('ed25519')]));
    goKubo.config.profiles['randomports']!.transform(cfg);
    goKubo.repo.fsrepo.init('${tmp.path}/repo', cfg);
    final repo = goKubo.repo.fsrepo.open('${tmp.path}/repo');
    say('Routing.Type: "${(repo.config().json['Routing'] as Map)['Type']}", '
        '${(repo.config().json['Bootstrap'] as List).length} bootstrap '
        'entries');

    // 2. The node online: host, bootstrap, routing, bitswap, all started.
    //    Go:  core.NewNode(ctx, &node.BuildCfg{Repo: r, Online: true,
    //             Permanent: true, Routing: routingFor(cfg)})
    final n = await goKubo.core.newNode(
        ctx,
        KuboCoreNodeBuildCfg(
            repo: repo,
            online: true,
            permanent: true,
            routing: routingFor(repo.config())));
    final api = goKubo.core.coreapi.newCoreApi(n);
    try {
      say('online as ${(await api.key().self(ctx)).id}');
      // (Only the loopback ones are shown: the others are this machine's
      // real IPs, which do not belong in a shared log.)
      final listening = await api.swarm().listenAddrs(ctx);
      say('  listening on ${listening.length} addresses, e.g. '
          '${listening.where((a) => '$a'.startsWith('/ip4/127.')).take(2).join(', ')}');

      // 3. Peers come from the bootstrap list, then from the DHT.
      var peers = 0;
      for (var i = 0; i < 30 && peers < 8; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        peers = (await api.swarm().peers(ctx)).length;
      }
      say('\nconnected to $peers peers');
      if (peers == 0) {
        say('no peers: is there an internet connection? (the rest needs it)');
        return;
      }

      // 4. Fetch something published by someone else: the routing finds
      //    its providers, bitswap brings the blocks, each one checked.
      final (fctx, cancel) =
          goContext.withTimeout(ctx, const Duration(seconds: 90));
      final watch = Stopwatch()..start();
      try {
        final f = await api.unixfs().get(fctx, BoxoPath('/ipfs/$known'));
        say('fetched /ipfs/$known in ${watch.elapsed.inSeconds} s: '
            '"${utf8.decode(goIo.readAll(goBoxo.files.toFile(f))).trim()}"');
      } on GolangException catch (e) {
        say('could not fetch it in 90 s: ${brief(e)}');
      } finally {
        cancel();
      }

      // 5. Publish: add, and the node announces it to the network (here we
      //    ask for the announcement now instead of waiting for the queue).
      final p = await api.unixfs().add(
          ctx,
          goBoxo.files
              .newBytesFile(utf8.encode('hello from a Dart app over p2p_ffi '
                  '${DateTime.now().toUtc()}\n')),
          [goKubo.core.coreiface.options.unixfs.pin(true, 'lesson-17')]);
      say('\nadded $p; announcing it...');
      final (pctx, pcancel) =
          goContext.withTimeout(ctx, const Duration(seconds: 60));
      try {
        await api.routing().provide(pctx, p);
        say('  announced: any node (or https://ipfs.io/ipfs/...) can fetch '
            'it while this node is online');
      } on GolangException catch (e) {
        say('  not announced in time: ${brief(e)} (the node keeps trying)');
      } finally {
        pcancel();
      }

      say('\n== Common mistakes\n');
      // An online node with no routing and no bootstrap peers: online, but
      // alone.
      final lonelyCfg = goKubo.config.initWithIdentity(goKubo.config
          .createIdentity(
              null, [goKubo.core.coreiface.options.key.type('ed25519')]));
      goKubo.config.profiles['test']!.transform(lonelyCfg);
      goKubo.repo.fsrepo.init('${tmp.path}/lonely', lonelyCfg);
      final lonely = await goKubo.core.newNode(
          ctx,
          KuboCoreNodeBuildCfg(
              repo: goKubo.repo.fsrepo.open('${tmp.path}/lonely'),
              online: true,
              routing: goKubo.core.node.libp2p.nilRouterOption));
      final lonelyApi = goKubo.core.coreapi.newCoreApi(lonely);
      await mistake(
          'fetching with an online node that has no peers and no '
          'routing',
          why: '"online" only means bitswap is on: with nobody connected and '
              'no router, there is no one to ask (the test profile removes '
              'the bootstrap list)',
          instead: 'bootstrap peers and a router (the default config), or '
              'connect to a peer that has it', action: () async {
        final (tctx, cancel) =
            goContext.withTimeout(ctx, const Duration(seconds: 5));
        try {
          await lonelyApi.unixfs().get(tctx, BoxoPath('/ipfs/$known'));
        } finally {
          cancel();
        }
      });
      await lonely.close();
    } finally {
      await n.close();
    }
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
