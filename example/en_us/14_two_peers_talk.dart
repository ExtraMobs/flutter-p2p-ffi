// Lesson 14 · How do two peers talk?
//
// Question: I have two hosts with IDs and addresses (lesson 13). How does
// one reach the other, and how do they exchange my own data?
//
// Answer: one host connects to the other (an AddrInfo: the peer ID plus at
// least one address to dial). Over that one connection they open streams:
// each stream is a two-way byte pipe tagged with a protocol name
// (`/ipfs/bitswap/1.2.0`, `/ipfs/kad/1.0.0`, or yours: `/my-app/greet/1.0.0`).
// A host answers a protocol by setting a stream handler for its name;
// opening a stream to a protocol nobody handles fails. IPFS itself is just
// a set of such protocols (bitswap, kad-dht, identify, ping...) on the same
// kind of host. Hosts find each other's addresses by being told them, by the
// DHT (lesson 15), or on the local network by mDNS.
//
// Needs: lesson 13 (hosts). Technically, to connect: the other's peer ID and
// a dialable address (in the AddrInfo or already in the peerstore); to open a
// stream: a connection (or a way to make one) and a handler on the other
// side for that protocol.
//
//   dart run example/en_us/14_two_peers_talk.dart
//
// Next question: "Here I gave b's address to a by hand. On a real network,
// how do I find a peer, or who has some content?" → lesson 15.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

const greet = '/lesson/greet/1.0.0';

/// network.Connectedness as words.
String state(int c) =>
    {
      goLibp2p.core.network.notConnected: 'not connected',
      goLibp2p.core.network.connected: 'connected',
      goLibp2p.core.network.canConnect: 'can connect',
      goLibp2p.core.network.cannotConnect: 'cannot connect',
      goLibp2p.core.network.limited: 'connected (limited, through a relay)',
    }[c] ??
    '$c';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = goContext.background();
    Future<Libp2pCoreHost> newHost() => goLibp2p.new$([
          goLibp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]);
    final a = await newHost(), b = await newHost();
    say('a: ${a.id().shortString()}  b: ${b.id().shortString()}');

    // 1. Watch a's connections: a Dart implementation of a Go interface
    //    (network.Notifiee), called by Go on each event.
    //    Go:  a.Network().Notify(&network.NotifyBundle{ConnectedF: ...})
    final watcher = Libp2pCoreNetworkNotifiee(
      connected: (_, c) =>
          say('  [a] connected to ${c.remotePeer().shortString()} '
              'over ${c.remoteMultiaddr()}'),
      disconnected: (_, c) =>
          say('  [a] disconnected from ${c.remotePeer().shortString()}'),
    );
    a.network().notify(watcher);
    //    The same news from b's event bus.
    //    Go:  sub, _ := b.EventBus().Subscribe(new(event.EvtPeerConnectednessChanged))
    final bus = b
        .eventBus()
        .subscribe(Libp2pCoreEventEvtPeerConnectednessChanged.$type);
    final busDone = bus.out().forEach((e) {
      if (e is Libp2pCoreEventEvtPeerConnectednessChanged) {
        say('  [b] ${e.peer!.shortString()} is now ${state(e.connectedness)}');
      }
    });

    // 2. Connect: b's ID and addresses, as an AddrInfo.
    //    Go:  a.Connect(ctx, *host.InfoFromHost(b))
    await a.connect(ctx, goLibp2p.core.host.infoFromHost(b));
    say('a and b: ${state(a.network().connectedness(b.id()))}');

    // 3. Ping: a protocol every host speaks (/ipfs/ping/1.0.0).
    //    Go:  for r := range ping.Ping(ctx, a, b.ID()) { r.RTT }
    final (pingCtx, stopPing) = goContext.withCancel(ctx);
    await for (final r
        in goLibp2p.p2p.protocol.ping.ping(pingCtx, a, b.id()).take(3)) {
      // On Windows Go's clock ticks coarsely: a loopback ping may read 0.
      say('ping a → b: ${r.rtt.inMicroseconds} µs');
    }
    stopPing();

    // 4. A protocol of our own: b answers each greeting. The handler is a
    //    Dart function Go keeps and calls once per incoming stream.
    //    Go:  b.SetStreamHandler(greet, func(s network.Stream) {...})
    b.setStreamHandler(greet, (s) async {
      final name = await readerStream(s).expand((c) => c).toList();
      await s.write(utf8.encode('hello, ${utf8.decode(name)}, from b'));
      await s.close();
    });
    //    Go:  s, _ := a.NewStream(ctx, b.ID(), greet)
    final s = await a.newStream(ctx, b.id(), [greet]);
    await s.write(Uint8List.fromList(utf8.encode('a')));
    await s.closeWrite(); // "I am done sending"; b's read loop ends
    final answer = await readerStream(s).expand((c) => c).toList();
    say('a sent "a" on $greet; b answered "${utf8.decode(answer)}"');
    //    What a learned b speaks (identify, run on every new connection):
    final speaks = await a.peerstore().getProtocols(b.id());
    say('  a knows b speaks ${speaks.length} protocols, e.g. '
        '${speaks.where((p) => p.contains('ping') || p.contains('identify')).join(', ')}');

    // 5. mDNS: hosts on the same local network announce themselves; a Dart
    //    mdns.Notifee hears them (multicast must be allowed on the network).
    //    Go:  mdns.NewMdnsService(h, "lesson", notifee).Start()
    final c = await newHost();
    final found = Completer<void>();
    final listen = goLibp2p.p2p.discovery.mdns
        .newMdnsService(c, 'p2p-ffi-lesson',
            Libp2pP2pDiscoveryMdnsNotifee(handlePeerFound: (pi) {
      if (pi.id == a.id() && !found.isCompleted) {
        say('mDNS: c found a on the local network at ${pi.addrs.first}');
        found.complete();
      }
    }));
    final announce = goLibp2p.p2p.discovery.mdns
        .newMdnsService(a, 'p2p-ffi-lesson', Libp2pP2pDiscoveryMdnsNotifee());
    listen.start();
    announce.start();
    await found.future.timeout(const Duration(seconds: 10),
        onTimeout: () => say('mDNS: nothing in 10 s (multicast blocked?)'));
    listen.close();
    announce.close();

    say('\n== Common mistakes\n');
    await mistake('opening a stream to a protocol the other side lacks',
        why: 'b has no handler for it: the protocol negotiation fails',
        instead: 'set the handler on the other side first; check with '
            'peerstore().getProtocols(id)',
        action: () => a.newStream(ctx, b.id(), ['/nobody/here/1.0.0']));
    await mistake('connecting knowing only the peer ID',
        why: 'c has never seen b: no address in its peerstore to dial',
        instead: 'pass the addresses (an AddrInfo), or find them by the DHT '
            '(lesson 15) or mDNS',
        action: () => c.connect(ctx, Libp2pCorePeerAddrInfo(id: b.id())));

    a.network().stopNotify(watcher);
    bus.close();
    await busDone;
    for (final h in [a, b, c]) {
      await h.close();
    }
  } finally {
    await P2pService.stop();
  }
}
