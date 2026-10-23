// libp2p without kubo (0.22.0): two hosts in the same p2p_host, on loopback.
// Needs `dart run tool/build.dart`.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/io_stream.dart' as io;
import 'package:p2p_ffi/go/libp2p.dart' as libp2p;
import 'package:p2p_ffi/go/libp2p/core/crypto.dart' as crypto;
import 'package:p2p_ffi/go/libp2p/core/host.dart' as host;
import 'package:p2p_ffi/go/libp2p/core/network.dart' as network;
import 'package:p2p_ffi/go/libp2p/core/peer.dart' as peer;
import 'package:p2p_ffi/go/libp2p/p2p/discovery/routing.dart' as routing;
import 'package:p2p_ffi/go/libp2p/p2p/protocol/ping.dart' as ping;
import 'package:p2p_ffi/go/libp2p_kad_dht.dart' as dht;
import 'package:p2p_ffi/go/libp2p_pubsub.dart' as pubsub;
import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:test/test.dart';

const echo = '/p2p-ffi-test/echo/1.0.0';

Future<host.Host> newHost([crypto.PrivKey? key]) => libp2p.new$([
      libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0']),
      if (key != null) libp2p.identity(key),
    ]);

void main() {
  setUpAll(P2pService.start);
  tearDownAll(P2pService.stop);

  late host.Host a, b;
  late final context.Context ctx;
  setUpAll(() => ctx = context.background());

  setUp(() async {
    a = await newHost();
    b = await newHost();
    await a.connect(ctx, host.infoFromHost(b));
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('identity: the peer ID comes from the key, which survives a round trip',
      () async {
    final (sk, _) = crypto.generateKeyPair(crypto.ed25519, -1);
    final again = crypto.unmarshalPrivateKey(crypto.marshalPrivateKey(sk));
    final h = await newHost(again);
    addTearDown(h.close);
    expect(h.id(), peer.idFromPrivateKey(sk));
    final sig = sk.sign(utf8.encode('hi'));
    expect(sk.getPublic().verify(utf8.encode('hi'), sig), isTrue);
  });

  test('connected, and ping measures the round trip', () async {
    expect(a.network().connectedness(b.id()), network.connected);
    expect(a.network().peers(), contains(b.id()));
    final (pingCtx, cancel) = context.withCancel(ctx);
    final first = await ping.ping(pingCtx, a, b.id()).first;
    cancel();
    expect(first.error, isNull);
    // Go itself measures 0 s on Windows loopback (checked with a go test)
    expect(first.rtt, greaterThanOrEqualTo(Duration.zero));
  });

  test('a stream handler of our own: echo, both ways', () async {
    final served = Completer<String>();
    b.setStreamHandler(echo, (s) async {
      served.complete(s.protocol());
      final got = BytesBuilder();
      await for (final chunk in io.readerStream(s)) {
        got.add(chunk);
      }
      await s.write(got.takeBytes());
      await s.close();
    });
    final s = await a.newStream(ctx, b.id(), [echo]);
    await s.write(utf8.encode('hello'));
    await s.closeWrite();
    final back = await io.readerStream(s).expand((c) => c).toList();
    expect(utf8.decode(back), 'hello');
    expect(await served.future, echo);
    b.removeStreamHandler(echo);
    // the protocol is negotiated lazily: the first read finds it gone
    final s2 = await a.newStream(ctx, b.id(), [echo]);
    await expectLater(s2.read(16), throwsA(isA<GolangException>()));
  });

  test('a match function: Go waits for its verdict', () async {
    final asked = <String>[];
    b.setStreamHandlerMatch('/p2p-ffi-test/any', (pid) {
      asked.add(pid);
      return pid.startsWith('/p2p-ffi-test/any/');
    }, (s) => s.close());
    final s = await a.newStream(ctx, b.id(), ['/p2p-ffi-test/any/7']);
    expect(await s.read(16), isEmpty); // the handler closed it: EOF
    expect(asked, contains('/p2p-ffi-test/any/7'));
    b.removeStreamHandler('/p2p-ffi-test/any');
  });

  test('a Dart Notifiee sees the connection close', () async {
    final gone = Completer<peer.Id>();
    final n = network.Notifiee(
        disconnected: (_, conn) => gone.complete(conn.remotePeer()));
    a.network().notify(n);
    a.network().closePeer(b.id());
    expect(await gone.future.timeout(const Duration(seconds: 10)), b.id());
    a.network().stopNotify(n);
  });

  test('gossipsub between the two hosts', () async {
    final psA = await pubsub.newGossipSub(ctx, a);
    final psB = await pubsub.newGossipSub(ctx, b);
    final topicA = psA.join('p2p-ffi-test');
    final topicB = psB.join('p2p-ffi-test');
    final sub = topicB.subscribe();
    // the mesh forms after the subscription is announced
    while (!topicA.listPeers().contains(b.id())) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await topicA.publish(ctx, Uint8List.fromList(utf8.encode('news')));
    final (nextCtx, cancel) =
        context.withTimeout(ctx, const Duration(seconds: 10));
    final msg = await sub.next(nextCtx);
    cancel();
    expect(utf8.decode(msg.message!.getData()), 'news');
    expect(msg.receivedFrom, a.id());
    sub.cancel();
  });

  test('a private DHT: provide on one host, find it from the other', () async {
    final opts = [
      dht.mode(dht.modeServer),
      dht.protocolPrefix('/p2p-ffi-test')
    ];
    final da = dht.new$(a, opts), db = dht.new$(b, opts);
    addTearDown(() async {
      await da.close();
      await db.close();
    });
    // the routing tables fill once identify sees the DHT protocol
    while (da.routingTable().size() == 0 || db.routingTable().size() == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final key =
        cid.Cid('bafkreifzjut3te2nhyekklss27nh3k72ysco7y32koao5eei66wof36n5e');
    await da.provide(ctx, key, true);
    final found = await db.findProviders(ctx, key);
    expect(found.map((p) => p.id), contains(a.id()));

    // rendezvous by name over the same DHT
    await routing.RoutingDiscovery(da).advertise(ctx, 'p2p-ffi-room');
    final peers = await routing.RoutingDiscovery(db)
        .findPeers(ctx, 'p2p-ffi-room')
        .toList();
    expect(peers.map((p) => p.id), contains(a.id()));
  });
}
