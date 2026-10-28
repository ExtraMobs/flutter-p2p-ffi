// Lesson 15 · How do I find who has some content?
//
// Question: in lesson 14 I gave one host the other's address by hand. On a
// network of thousands of peers, how do I find the address of a peer from
// its ID, or which peers have a CID?
//
// Answer: a DHT (Kademlia, the `kad-dht` protocol): a table spread over all
// the peers. Each peer keeps a routing table of some others, ordered by the
// XOR distance between IDs; a lookup asks the closest peers it knows, which
// answer with closer ones, until it reaches the peers closest to the key.
// What is stored there:
//   - provider records: "peer P has CID X" (Provide, then FindProviders);
//     records expire, so providers re-announce them (kubo every 22 h);
//   - peer addresses: FindPeer(ID) returns where to dial it;
//   - small signed values, like IPNS records (lesson 11).
// IPFS's public DHT uses the prefix `/ipfs`; this lesson builds a private one
// (its own prefix) on loopback, so it never mixes with the public network.
// A rendezvous is the same trick for a name: hash a room name into a CID and
// provide/find it.
//
// Needs: lesson 14 (hosts that connect). Technically, a DHT needs a host and
// at least one peer to start from (a bootstrap peer); in server mode it also
// answers others (kubo switches to client mode behind a NAT, lesson 17).
//
//   dart run example/en_us/15_find_on_the_dht.dart
//
// Next question: "I found who has the CID. What actually brings its blocks
// to me?" → lesson 16.
import 'dart:convert';

import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/libp2p.dart' as libp2p;
import 'package:p2p_ffi/go/libp2p/core/host.dart' as host;
import 'package:p2p_ffi/go/libp2p/p2p/discovery/routing.dart' as discovery;
import 'package:p2p_ffi/go/libp2p_kad_dht.dart' as dht;
import 'package:p2p_ffi/go/multicodec.dart' as multicodec;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

const prefix = '/p2p-ffi-lesson'; // a private DHT: not the /ipfs one

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = context.background();

    // 1. Five hosts, each with a DHT in server mode. Only the first is known
    //    to the others: it is their bootstrap peer.
    //    Go:  d, _ := dht.New(ctx, h, dht.Mode(dht.ModeServer), dht.ProtocolPrefix(prefix))
    final hosts = [
      for (var i = 0; i < 5; i++)
        await libp2p.new$([
          libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]),
    ];
    final opts = [dht.mode(dht.modeServer), dht.protocolPrefix(prefix)];
    final dhts = [for (final h in hosts) dht.new$(h, opts)];
    for (final h in hosts.skip(1)) {
      await h.connect(ctx, host.infoFromHost(hosts[0]));
    }
    //    Bootstrap: each asks the network for the peers closest to itself,
    //    filling its routing table beyond the bootstrap peer.
    for (final d in dhts) {
      await d.bootstrap(ctx);
    }
    for (var i = 0;
        i < 100 && dhts.any((d) => d.routingTable().size() < 4);
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    say('routing tables: '
        '${dhts.map((d) => d.routingTable().size()).join(', ')} peers');

    // 2. FindPeer: host 4 asks for host 3's address by ID alone.
    //    Go:  pi, _ := d.FindPeer(ctx, id)
    final target = hosts[3].id();
    final found = await () async {
      for (var i = 1;; i++) {
        try {
          return await dhts[4].findPeer(ctx, target);
        } on GolangException {
          // On a DHT this small a lookup can miss while the tables fill: retry.
          if (i == 5) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }();
    say('\nhost 4 looked up ${target.shortString()}: ${found.addrs}');

    // 3. Provide and FindProviders: host 1 says it has a CID; host 4 finds
    //    who has it.
    //    Go:  d.Provide(ctx, c, true); provs, _ := d.FindProviders(ctx, c)
    final content = cid
        .newPrefixV1(multicodec.raw, multicodec.sha2256)
        .sum(utf8.encode('something host 1 has'));
    await dhts[1].provide(ctx, content, true);
    final providers = await dhts[4].findProviders(ctx, content);
    say('\nhost 1 provided $content');
    say('host 4 found providers: '
        '${providers.map((p) => p.id!.shortString()).join(', ')} '
        '(host 1 is ${hosts[1].id().shortString()})');

    // 4. Rendezvous by name: host 2 advertises a room, host 4 finds who is
    //    in it.
    //    Go:  rd := routing.NewRoutingDiscovery(d); rd.Advertise(ctx, "room")
    //         for pi := range rd.FindPeers(ctx, "room") {...}
    final ttl =
        await discovery.RoutingDiscovery(dhts[2]).advertise(ctx, 'room');
    say('\nhost 2 advertised "room" (valid ${ttl.inHours} h)');
    await for (final pi
        in discovery.RoutingDiscovery(dhts[4]).findPeers(ctx, 'room')) {
      say('host 4 found in "room": ${pi.id!.shortString()}');
    }

    say('\n== Common mistakes\n');
    final lonely = await libp2p.new$([
      libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
    ]);
    final lonelyDht = dht.new$(lonely, opts);
    await mistake('providing on a DHT that knows no peer',
        why: 'its routing table is empty: there is nobody to store the '
            'record on',
        instead: 'connect to a bootstrap peer first (kubo: the Bootstrap '
            'list of the config)',
        action: () => lonelyDht.provide(ctx, content, true));
    final other = await libp2p.new$([
      libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
    ]);
    final otherDht =
        dht.new$(other, [dht.mode(dht.modeServer), dht.protocolPrefix('/x')]);
    await other.connect(ctx, host.infoFromHost(hosts[0]));
    await silentlyWrong('joining with another protocol prefix',
        why: 'a different prefix is a different DHT: the peers are '
            'connected but never enter each other\'s tables',
        instead: 'the same prefix on every peer (/ipfs for the public IPFS '
            'network)',
        wrong: () async {
          await otherDht.bootstrap(ctx);
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return '${otherDht.routingTable().size()} peers in the table';
        },
        right: () => '${dhts[0].routingTable().size()} peers in the table');

    for (final d in [...dhts, lonelyDht, otherDht]) {
      await d.close();
    }
    for (final h in [...hosts, lonely, other]) {
      await h.close();
    }
  } finally {
    await P2pService.stop();
  }
}
