// libp2p without kubo on the device (0.22–0.24): the desktop's test/libp2p_test.dart
// checks, plus what a retained callback costs here (a pubsub validator and a
// subscription filter run once per message, and Go waits for Dart each time).
// Run with:
//   flutter test integration_test/libp2p_test.dart -d <device>
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:p2p_ffi/p2p_ffi.dart';

const echo = '/p2p-ffi-test/echo/1.0.0';

Future<Libp2pCoreHost> newHost() => go.libp2p.libp2p.new$([
      go.libp2p.libp2p
          .transport(go.libp2p.libp2p.p2p.transport.tcp.newTcpTransportFunc),
      go.libp2p.libp2p.security(go.libp2p.libp2p.p2p.security.noise.id,
          go.libp2p.libp2p.p2p.security.noise.newFunc),
      go.libp2p.libp2p.muxer(go.libp2p.libp2p.p2p.muxer.yamux.id,
          go.libp2p.libp2p.p2p.muxer.yamux.defaultTransport),
      go.libp2p.libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0']),
    ]);

Uint8List bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('libp2p without kubo', () async {
    await P2pService.start();
    final ctx = go.context.background();
    final a = await newHost(), b = await newHost();
    try {
      // the event bus sees the connection
      final sub = b
          .eventBus()
          .subscribe(Libp2pCoreEventEvtPeerConnectednessChanged.$type);
      final connected = sub.out().firstWhere((e) =>
          e is Libp2pCoreEventEvtPeerConnectednessChanged &&
          e.connectedness == go.libp2p.libp2p.core.network.connected);
      await a.connect(ctx, go.libp2p.libp2p.core.host.infoFromHost(b));
      await connected.timeout(const Duration(seconds: 10));
      sub.close();

      // a stream handler: echo
      b.setStreamHandler(echo, (s) async {
        final got = await readerStream(s).expand((c) => c).toList();
        await s.write(Uint8List.fromList(got));
        await s.close();
      });
      final s = await a.newStream(ctx, b.id(), [echo]);
      await s.write(bytes('hello'));
      await s.closeWrite();
      expect(utf8.decode(await readerStream(s).expand((c) => c).toList()),
          'hello');

      // retained callbacks per message: a validator on b, a filter on its
      // subscription
      final psA = await go.libp2p.libp2pPubsub.newGossipSub(ctx, a);
      final psB = await go.libp2p.libp2pPubsub.newGossipSub(ctx, b);
      var validated = 0;
      await psB.registerTopicValidator('bench', (_, __, m) {
        validated++;
        return go.libp2p.libp2pPubsub.validationAccept;
      });
      final topicA = await psA.join('bench');
      final subB = await (await psB.join('bench')).subscribe([
        go.libp2p.libp2pPubsub
            .withBufferSize(256), // the default 32 drops a burst (measured)
        go.libp2p.libp2pPubsub.withMessageFilter((m) => true),
      ]);
      while (!(await topicA.listPeers()).contains(b.id())) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      // one at a time: the latency of a message through both callbacks
      const n = 100;
      final clock = Stopwatch()..start();
      for (var i = 0; i < n; i++) {
        await topicA.publish(ctx, bytes('m$i'));
        final (nextCtx, cancel) =
            go.context.withTimeout(ctx, const Duration(seconds: 10));
        await subB.next(nextCtx);
        cancel();
      }
      clock.stop();
      // ignore: avoid_print
      print('libp2p: $n messages one at a time through a Dart validator and '
          'filter: ${(clock.elapsedMicroseconds / n).round()} µs each');
      // a burst: gossipsub's queues (32) drop what the validator does not keep
      // up with; count what arrives
      const burst = 200;
      validated = 0;
      for (var i = 0; i < burst; i++) {
        await topicA.publish(ctx, bytes('b$i'));
      }
      var got = 0;
      try {
        for (;;) {
          final (nextCtx, cancel) =
              go.context.withTimeout(ctx, const Duration(seconds: 3));
          try {
            await subB.next(nextCtx);
            got++;
          } finally {
            cancel();
          }
        }
      } on GolangDeadlineExceededException {
        // no more
      }
      // ignore: avoid_print
      print('libp2p: a burst of $burst: $got delivered, validator called '
          '$validated times');
      expect(got, greaterThan(0));
      await subB.cancel();
    } finally {
      await a.close();
      await b.close();
      await P2pService.stop();
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
