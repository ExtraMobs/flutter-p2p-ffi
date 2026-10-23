// Step 15: gossipsub and a DHT on libp2p hosts of one's own, without kubo.
// Three hosts on loopback: a private Kademlia DHT (its own protocol prefix,
// so it never mixes with the IPFS one), rendezvous by name over it, and a chat
// topic with a validator. Pubsub is pulled (Subscription.next); the validator
// is a Dart function Go asks for each message.
//
//   dart run example/15_libp2p_pubsub_dht.dart
//
// Each step carries the same code in Go.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/libp2p.dart' as libp2p;
import 'package:p2p_ffi/go/libp2p/core/host.dart' as host;
import 'package:p2p_ffi/go/libp2p/p2p/discovery/routing.dart' as routing;
import 'package:p2p_ffi/go/libp2p_kad_dht.dart' as dht;
import 'package:p2p_ffi/go/libp2p_pubsub.dart' as pubsub;
import 'package:p2p_ffi/p2p_ffi.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = context.background();
    final hosts = [
      for (var i = 0; i < 3; i++)
        await libp2p.new$([
          libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]),
    ];
    final [a, b, c] = hosts;

    // 1. A private DHT on each host. Only a knows the others at first: b and
    //    c bootstrap from it.
    //    dht.New(h, dht.Mode(dht.ModeServer), dht.ProtocolPrefix("/example"))
    final opts = [
      dht.mode(dht.modeServer),
      dht.protocolPrefix('/p2p-ffi-example')
    ];
    final dhts = [for (final h in hosts) dht.new$(h, opts)];
    for (final h in [b, c]) {
      await h.connect(ctx, host.infoFromHost(a));
    }
    for (final d in dhts) {
      await d.bootstrap(ctx);
    }
    while (dhts.any((d) => d.routingTable().size() == 0)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    // 2. Rendezvous by name: c advertises a room and b finds it through the
    //    DHT (to b.connect(ctx, pi) if they are not connected yet).
    //    routing.NewRoutingDiscovery(d).Advertise(ctx, "room")
    final ttl = await routing.RoutingDiscovery(dhts[2]).advertise(ctx, 'room');
    print('c advertised "room" for ${ttl.inMinutes} min');
    await for (final pi
        in routing.RoutingDiscovery(dhts[1]).findPeers(ctx, 'room')) {
      if (pi.id != b.id()) print('b found in "room": ${pi.id} ${pi.addrs}');
    }

    // 3. A chat topic: everyone joins, c listens, a and b talk.
    //    ps, _ := pubsub.NewGossipSub(ctx, h); t, _ := ps.Join("chat")
    final pss = [for (final h in hosts) await pubsub.newGossipSub(ctx, h)];
    final psC = pss[2];
    final topics = [for (final ps in pss) await ps.join('chat')];
    //    c accepts only short messages; an exception would reject too.
    //    ps.RegisterTopicValidator("chat", func(ctx, from, m) ValidationResult {...})
    await psC.registerTopicValidator(
        'chat',
        (_, from, m) => m.message!.getData().length <= 64
            ? pubsub.validationAccept
            : pubsub.validationReject);
    final sub = await topics[2].subscribe();
    while ((await topics[0].listPeers()).isEmpty ||
        (await topics[1].listPeers()).isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await topics[0].publish(ctx, Uint8List.fromList(utf8.encode('hi from a')));
    await topics[1].publish(
        ctx, Uint8List.fromList(utf8.encode('${'x' * 100} (c rejects it)')));
    await topics[1].publish(ctx, Uint8List.fromList(utf8.encode('hi from b')));
    for (var i = 0; i < 2; i++) {
      final (nextCtx, cancel) =
          context.withTimeout(ctx, const Duration(seconds: 10));
      final m = await sub.next(nextCtx);
      cancel();
      print(
          'c got "${utf8.decode(m.message!.getData())}" from ${m.receivedFrom}');
    }
    await sub.cancel();

    for (final d in dhts) {
      await d.close();
    }
    for (final h in hosts) {
      await h.close();
    }
  } finally {
    await P2pService.stop();
  }
}
