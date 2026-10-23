// Step 14: a libp2p host of one's own, without kubo. Two hosts in the same
// p2p_host: an identity that survives a restart, a transport stack of one's
// own, a connection, ping, a protocol of one's own served by a Dart handler,
// connection events (a Dart Notifiee and the event bus), and discovery on the
// local network (mDNS).
//
//   dart run example/14_libp2p_host.dart
//
// Each step carries the same code in Go.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/io_stream.dart' as io;
import 'package:p2p_ffi/go/libp2p.dart' as libp2p;
import 'package:p2p_ffi/go/libp2p/core/crypto.dart' as crypto;
import 'package:p2p_ffi/go/libp2p/core/event.dart' as event;
import 'package:p2p_ffi/go/libp2p/core/host.dart' as host;
import 'package:p2p_ffi/go/libp2p/core/network.dart' as network;
import 'package:p2p_ffi/go/libp2p/p2p/discovery/mdns.dart' as mdns;
import 'package:p2p_ffi/go/libp2p/p2p/muxer/yamux.dart' as yamux;
import 'package:p2p_ffi/go/libp2p/p2p/protocol/ping.dart' as ping;
import 'package:p2p_ffi/go/libp2p/p2p/security/noise.dart' as noise;
import 'package:p2p_ffi/go/libp2p/p2p/transport/tcp.dart' as tcp;
import 'package:p2p_ffi/p2p_ffi.dart';

const greet = '/example/greet/1.0.0';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = context.background();

    // 1. The identity. Keep the marshaled key (a file, secure storage) and the
    //    peer ID stays the same on the next start.
    //    sk, _, _ := crypto.GenerateKeyPair(crypto.Ed25519, -1)
    //    saved, _ := crypto.MarshalPrivateKey(sk)
    final (sk, _) = crypto.generateKeyPair(crypto.ed25519, -1);
    final saved = crypto.marshalPrivateKey(sk);

    // 2. Two hosts on loopback, port chosen by the system.
    //    a, _ := libp2p.New(libp2p.Identity(sk), libp2p.ListenAddrStrings(...))
    final a = await libp2p.new$([
      libp2p.identity(crypto.unmarshalPrivateKey(saved)),
      libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0']),
    ]);
    //    b: only TCP, Noise and yamux. The constructors are Go functions,
    //    passed as tokens (Go gets the function itself).
    //    libp2p.New(libp2p.Transport(tcp.NewTCPTransport), libp2p.Security(noise.ID, noise.New), ...)
    final b = await libp2p.new$([
      libp2p.transport(tcp.newTcpTransportFunc),
      libp2p.security(noise.id, noise.newFunc),
      libp2p.muxer(yamux.id, yamux.defaultTransport),
      libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0']),
    ]);
    print('a: ${a.id()} ${a.addrs()}');
    print('b: ${b.id()} ${b.addrs()}');

    // 3. Connection events: a Dart implementation of network.Notifiee.
    //    a.Network().Notify(&network.NotifyBundle{ConnectedF: ...})
    final events = network.Notifiee(
      connected: (_, c) => print('a connected to ${c.remotePeer()}'),
      disconnected: (_, c) => print('a disconnected from ${c.remotePeer()}'),
    );
    a.network().notify(events);
    //    The same from b's event bus: the event type goes by example.
    //    sub, _ := b.EventBus().Subscribe(new(event.EvtPeerConnectednessChanged))
    final bus = b.eventBus().subscribe(event.EvtPeerConnectednessChanged.$type);
    final busDone = bus.out().forEach((e) {
      if (e is event.EvtPeerConnectednessChanged) {
        print('b event bus: ${e.peer} connectedness ${e.connectedness}');
      }
    });

    // 4. Connect and ping.
    //    a.Connect(ctx, *host.InfoFromHost(b)); <-ping.Ping(ctx, a, b.ID())
    await a.connect(ctx, host.infoFromHost(b));
    final (pingCtx, stopPing) = context.withCancel(ctx);
    await for (final r in ping.ping(pingCtx, a, b.id()).take(3)) {
      print('ping: ${r.rtt.inMicroseconds} µs ${r.error ?? ''}');
    }
    stopPing();

    // 5. A protocol of one's own: b answers each greeting. The handler is a
    //    Dart function Go keeps (a retained callback) and calls per stream.
    //    b.SetStreamHandler(greet, func(s network.Stream) {...})
    b.setStreamHandler(greet, (s) async {
      final name = await io.readerStream(s).expand((c) => c).toList();
      await s.write(utf8.encode('hello, ${utf8.decode(name)}'));
      await s.close();
    });
    //    s, _ := a.NewStream(ctx, b.ID(), greet)
    final s = await a.newStream(ctx, b.id(), [greet]);
    await s.write(Uint8List.fromList(utf8.encode('a')));
    await s.closeWrite();
    final answer = await io.readerStream(s).expand((c) => c).toList();
    print('b answered: ${utf8.decode(answer)}');

    // 6. Discovery on the local network: each host announces itself by mDNS
    //    and a Dart mdns.Notifee hears the others.
    //    mdns.NewMdnsService(h, "example", notifee).Start()
    final found = Completer<void>();
    final service = mdns.newMdnsService(b, 'p2p-ffi-example',
        mdns.Notifee(handlePeerFound: (pi) {
      if (pi.id == a.id() && !found.isCompleted) {
        print('b found a on the local network: ${pi.addrs}');
        found.complete();
      }
    }));
    final announce = mdns.newMdnsService(a, 'p2p-ffi-example', mdns.Notifee());
    service.start();
    announce.start();
    await found.future.timeout(const Duration(seconds: 10),
        onTimeout: () => print('mDNS: nothing in 10 s (multicast blocked?)'));
    service.close();
    announce.close();

    a.network().stopNotify(events);
    bus.close();
    await busDone;
    await a.close();
    await b.close();
  } finally {
    await P2pService.stop();
  }
}
