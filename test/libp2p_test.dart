// libp2p without kubo (0.22.0): two hosts in the same p2p_host, on loopback.
// Needs `dart run tool/build.dart`.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';
import 'package:test/test.dart';

const echo = '/p2p-ffi-test/echo/1.0.0';

Future<Libp2pCoreHost> newHost([Libp2pCoreCryptoPrivKey? key]) =>
    go.libp2p.libp2p.new$([
      go.libp2p.libp2p.options.listenAddrStrings(['/ip4/127.0.0.1/tcp/0']),
      if (key != null) go.libp2p.libp2p.options.identity(key),
    ]);

void main() {
  setUpAll(P2pService.start);
  tearDownAll(P2pService.stop);

  late Libp2pCoreHost a, b;
  late final Context ctx;
  setUpAll(() => ctx = go.context.background());

  setUp(() async {
    a = await newHost();
    b = await newHost();
    await a.connect(ctx, go.libp2p.libp2p.core.host.infoFromHost(b));
  });
  tearDown(() async {
    await a.close();
    await b.close();
  });

  test('identity: the peer ID comes from the key, which survives a round trip',
      () async {
    final (sk, _) = go.libp2p.libp2p.core.crypto
        .generateKeyPair(go.libp2p.libp2p.core.crypto.consts.ed25519, -1);
    final again = go.libp2p.libp2p.core.crypto.unmarshalPrivateKey(
        go.libp2p.libp2p.core.crypto.marshalPrivateKey(sk));
    final h = await newHost(again);
    addTearDown(h.close);
    expect(h.id(), go.libp2p.libp2p.core.peer.idFromPrivateKey(sk));
    final sig = sk.sign(utf8.encode('hi'));
    expect(sk.getPublic().verify(utf8.encode('hi'), sig), isTrue);
  });

  test('connected, and ping measures the round trip', () async {
    expect(a.network().connectedness(b.id()),
        go.libp2p.libp2p.core.network.enums.connected);
    expect(a.network().peers(), contains(b.id()));
    final (pingCtx, cancel) = go.context.withCancel(ctx);
    final first =
        await go.libp2p.libp2p.p2p.protocol.ping.ping(pingCtx, a, b.id()).first;
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
      await for (final chunk in readerStream(s)) {
        got.add(chunk);
      }
      await s.write(got.takeBytes());
      await s.close();
    });
    final s = await a.newStream(ctx, b.id(), [echo]);
    await s.write(utf8.encode('hello'));
    await s.closeWrite();
    final back = await readerStream(s).expand((c) => c).toList();
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
    final gone = Completer<Libp2pCorePeerId>();
    final n = Libp2pCoreNetworkNotifiee(
        disconnected: (_, conn) => gone.complete(conn.remotePeer()));
    a.network().notify(n);
    a.network().closePeer(b.id());
    expect(await gone.future.timeout(const Duration(seconds: 10)), b.id());
    a.network().stopNotify(n);
  });

  test('gossipsub between the two hosts', () async {
    final psA = await go.libp2p.libp2pPubsub.newGossipSub(ctx, a);
    final psB = await go.libp2p.libp2pPubsub.newGossipSub(ctx, b);
    final topicA = await psA.join('p2p-ffi-test');
    final topicB = await psB.join('p2p-ffi-test');
    final sub = await topicB.subscribe();
    // the mesh forms after the subscription is announced
    while (!(await topicA.listPeers()).contains(b.id())) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await topicA.publish(ctx, Uint8List.fromList(utf8.encode('news')));
    final (nextCtx, cancel) =
        go.context.withTimeout(ctx, const Duration(seconds: 10));
    final msg = await sub.next(nextCtx);
    cancel();
    expect(utf8.decode(msg.message!.getData()), 'news');
    expect(msg.receivedFrom, a.id());
    await sub.cancel();
  });

  test('a private DHT: provide on one host, find it from the other', () async {
    final opts = [
      go.libp2p.libp2pKadDht.options
          .mode(go.libp2p.libp2pKadDht.enums.modeServer),
      go.libp2p.libp2pKadDht.options.protocolPrefix('/p2p-ffi-test')
    ];
    final da = go.libp2p.libp2pKadDht.new$(a, opts),
        db = go.libp2p.libp2pKadDht.new$(b, opts);
    addTearDown(() async {
      await da.close();
      await db.close();
    });
    // the routing tables fill once identify sees the DHT protocol
    while (da.routingTable().size() == 0 || db.routingTable().size() == 0) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final key =
        Cid('bafkreifzjut3te2nhyekklss27nh3k72ysco7y32koao5eei66wof36n5e');
    await da.provide(ctx, key, true);
    final found = await db.findProviders(ctx, key);
    expect(found.map((p) => p.id), contains(a.id()));

    // rendezvous by name over the same DHT
    await Libp2pP2pDiscoveryRoutingDiscovery(da).advertise(ctx, 'p2p-ffi-room');
    final peers = await Libp2pP2pDiscoveryRoutingDiscovery(db)
        .findPeers(ctx, 'p2p-ffi-room')
        .toList();
    expect(peers.map((p) => p.id), contains(a.id()));
  });

  test('a topic validator: Go asks Dart, and an exception rejects', () async {
    final psA = await go.libp2p.libp2pPubsub.newGossipSub(ctx, a);
    final psB = await go.libp2p.libp2pPubsub.newGossipSub(ctx, b);
    final thrown = <Object>[];
    await runZonedGuarded(() {
      return psB.registerTopicValidator('checked', (vctx, from, msg) {
        final text = utf8.decode(msg.message!.getData());
        if (text == 'boom') throw StateError('a bug in the validator');
        return text.startsWith('ok')
            ? go.libp2p.libp2pPubsub.enums.validationAccept
            : go.libp2p.libp2pPubsub.enums.validationReject;
      }, [
        go.libp2p.libp2pPubsub.options
            .withValidatorTimeout(const Duration(seconds: 5))
      ]);
    }, (e, _) => thrown.add(e));
    final topicA = await psA.join('checked');
    final sub = await (await psB.join('checked')).subscribe();
    while (!(await topicA.listPeers()).contains(b.id())) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    for (final text in ['ok 1', 'bad', 'boom', 'ok 2']) {
      await topicA.publish(ctx, Uint8List.fromList(utf8.encode(text)));
    }
    final got = <String>[];
    for (var i = 0; i < 2; i++) {
      final (nextCtx, cancel) =
          go.context.withTimeout(ctx, const Duration(seconds: 10));
      got.add(utf8.decode((await sub.next(nextCtx)).message!.getData()));
      cancel();
    }
    // validation runs in parallel in pubsub: the order may change
    expect(got, unorderedEquals(['ok 1', 'ok 2']));
    while (thrown.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(thrown.single, isA<StateError>());
    await sub.cancel();
    await psB.unregisterTopicValidator('checked');
  });

  test('the event bus: events arrive as their classes', () async {
    final c = await newHost();
    addTearDown(c.close);
    final sub = c.eventBus().subscribe([
      Libp2pCoreEventEvtPeerConnectednessChanged.$type,
      Libp2pCoreEventEvtLocalReachabilityChanged.$type,
    ]);
    final connected = sub.out().firstWhere((e) =>
        e is Libp2pCoreEventEvtPeerConnectednessChanged &&
        e.connectedness == go.libp2p.libp2p.core.network.enums.connected);
    await c.connect(ctx, go.libp2p.libp2p.core.host.infoFromHost(a));
    final e = await connected.timeout(const Duration(seconds: 10))
        as Libp2pCoreEventEvtPeerConnectednessChanged;
    expect(e.peer, a.id());
    sub.close();
  });

  test("a stack of one's own: TCP, Noise and yamux, from Go functions",
      () async {
    final opts = [
      go.libp2p.libp2p.options
          .transport(go.libp2p.libp2p.p2p.transport.tcp.newTcpTransportFunc),
      go.libp2p.libp2p.options.security(
          go.libp2p.libp2p.p2p.security.noise.consts.id,
          go.libp2p.libp2p.p2p.security.noise.newFunc),
      go.libp2p.libp2p.options.muxer(go.libp2p.libp2p.p2p.muxer.yamux.consts.id,
          go.libp2p.libp2p.p2p.muxer.yamux.defaultTransport),
      go.libp2p.libp2p.options.listenAddrStrings(['/ip4/127.0.0.1/tcp/0']),
    ];
    final x = await go.libp2p.libp2p.new$(opts),
        y = await go.libp2p.libp2p.new$(opts);
    addTearDown(() async {
      await x.close();
      await y.close();
    });
    await x.connect(ctx, go.libp2p.libp2p.core.host.infoFromHost(y));
    expect(x.network().connsToPeer(y.id()), isNotEmpty);
    // without the QUIC transport the host refuses a QUIC address
    await expectLater(
        go.libp2p.libp2p.new$([
          ...opts.take(3),
          go.libp2p.libp2p.options
              .listenAddrStrings(['/ip4/127.0.0.1/udp/0/quic-v1']),
        ]),
        throwsA(isA<GolangException>()));
  });

  test('an option that takes a struct: the gossipsub parameters cross',
      () async {
    final params = go.libp2p.libp2pPubsub.defaultGossipSubParams();
    expect(params.d, greaterThan(0));
    expect(params.heartbeatInterval, greaterThan(Duration.zero));
    await go.libp2p.libp2pPubsub.newGossipSub(
        ctx, a, [go.libp2p.libp2pPubsub.options.withGossipSubParams(params)]);
    // invalid on purpose (Dlo above D): gossipsub refuses what arrived
    params.dlo = params.d + 1;
    await expectLater(
        go.libp2p.libp2pPubsub.newGossipSub(ctx, b,
            [go.libp2p.libp2pPubsub.options.withGossipSubParams(params)]),
        throwsA(isA<GolangException>()));
    final r = await go.libp2p.libp2p.new$([
      go.libp2p.libp2p.options.listenAddrStrings(['/ip4/127.0.0.1/tcp/0']),
      go.libp2p.libp2p.options.enableRelayService([
        go.libp2p.libp2p.p2p.protocol.circuitv2.relay.options.withResources(
            go.libp2p.libp2p.p2p.protocol.circuitv2.relay.defaultResources()
              ..limit =
                  go.libp2p.libp2p.p2p.protocol.circuitv2.relay.defaultLimit()),
      ]),
    ]);
    await r.close();
  });

  test('an option that keeps a function: a subscription filter', () async {
    final psA = await go.libp2p.libp2pPubsub.newGossipSub(ctx, a);
    final psB = await go.libp2p.libp2pPubsub.newGossipSub(ctx, b);
    final topicA = await psA.join('filtered');
    final sub = await (await psB.join('filtered')).subscribe([
      go.libp2p.libp2pPubsub.options.withMessageFilter(
          (m) => !utf8.decode(m.message!.getData()).startsWith('skip')),
    ]);
    while (!(await topicA.listPeers()).contains(b.id())) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await topicA.publish(ctx, Uint8List.fromList(utf8.encode('skip me')));
    await topicA.publish(ctx, Uint8List.fromList(utf8.encode('keep me')));
    final (nextCtx, cancel) =
        go.context.withTimeout(ctx, const Duration(seconds: 10));
    final m = await sub.next(nextCtx);
    cancel();
    expect(utf8.decode(m.message!.getData()), 'keep me');
    await sub.cancel();
  });
}
