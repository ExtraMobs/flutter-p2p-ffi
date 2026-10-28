// Lección 14 · ¿Cómo hablan dos peers?
//
// Pregunta: tengo dos hosts con IDs y direcciones (lección 13). ¿Cómo llega
// uno al otro, y cómo intercambian mis propios datos?
//
// Respuesta: un host se conecta al otro (un AddrInfo: el peer ID más al menos
// una dirección que marcar). Sobre esa única conexión abren streams: cada
// stream es una tubería de bytes en los dos sentidos, marcada con el nombre
// de un protocolo (`/ipfs/bitswap/1.2.0`, `/ipfs/kad/1.0.0`, o el tuyo:
// `/mi-app/greet/1.0.0`). Un host atiende un protocolo registrando un handler
// de stream para su nombre; abrir un stream a un protocolo que nadie atiende
// falla. El propio IPFS es solo un conjunto de esos protocolos (bitswap,
// kad-dht, identify, ping...) sobre el mismo tipo de host. Los hosts conocen
// las direcciones de los otros porque alguien se las da, por el DHT (lección
// 15), o en la red local por mDNS.
//
// Necesita: la lección 13 (hosts). Técnicamente, para conectar: el peer ID
// del otro y una dirección marcable (en el AddrInfo o ya en el peerstore);
// para abrir un stream: una conexión (o cómo hacer una) y un handler al otro
// lado para ese protocolo.
//
//   dart run example/es/14_two_peers_talk.dart
//
// Siguiente pregunta: "Aquí le di a a la dirección de b a mano. En una red
// de verdad, ¿cómo encuentro un peer, o quién tiene un contenido?" →
// lección 15.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/io_stream.dart' as io_stream;
import 'package:p2p_ffi/go/libp2p.dart' as libp2p;
import 'package:p2p_ffi/go/libp2p/core/event.dart' as event;
import 'package:p2p_ffi/go/libp2p/core/host.dart' as host;
import 'package:p2p_ffi/go/libp2p/core/network.dart' as network;
import 'package:p2p_ffi/go/libp2p/core/peer.dart' as peer;
import 'package:p2p_ffi/go/libp2p/p2p/discovery/mdns.dart' as mdns;
import 'package:p2p_ffi/go/libp2p/p2p/protocol/ping.dart' as ping;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

const greet = '/lesson/greet/1.0.0';

/// network.Connectedness en palabras.
String state(int c) => switch (c) {
      network.notConnected => 'desconectado',
      network.connected => 'conectado',
      network.canConnect => 'puede conectar',
      network.cannotConnect => 'no puede conectar',
      network.limited => 'conectado (limitado, por un relay)',
      _ => '$c',
    };

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = context.background();
    Future<host.Host> newHost() => libp2p.new$([
          libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]);
    final a = await newHost(), b = await newHost();
    say('a: ${a.id().shortString()}  b: ${b.id().shortString()}');

    // 1. Observar las conexiones de a: una implementación en Dart de una
    //    interfaz Go (network.Notifiee), que Go llama en cada evento.
    //    Go:  a.Network().Notify(&network.NotifyBundle{ConnectedF: ...})
    final watcher = network.Notifiee(
      connected: (_, c) =>
          say('  [a] conectado a ${c.remotePeer().shortString()} '
              'por ${c.remoteMultiaddr()}'),
      disconnected: (_, c) =>
          say('  [a] desconectado de ${c.remotePeer().shortString()}'),
    );
    a.network().notify(watcher);
    //    La misma noticia por el bus de eventos de b.
    //    Go:  sub, _ := b.EventBus().Subscribe(new(event.EvtPeerConnectednessChanged))
    final bus = b.eventBus().subscribe(event.EvtPeerConnectednessChanged.$type);
    final busDone = bus.out().forEach((e) {
      if (e is event.EvtPeerConnectednessChanged) {
        say('  [b] ${e.peer!.shortString()} ahora está '
            '${state(e.connectedness)}');
      }
    });

    // 2. Conectar: el ID y las direcciones de b, como un AddrInfo.
    //    Go:  a.Connect(ctx, *host.InfoFromHost(b))
    await a.connect(ctx, host.infoFromHost(b));
    say('a y b: ${state(a.network().connectedness(b.id()))}');

    // 3. Ping: un protocolo que habla todo host (/ipfs/ping/1.0.0).
    //    Go:  for r := range ping.Ping(ctx, a, b.ID()) { r.RTT }
    final (pingCtx, stopPing) = context.withCancel(ctx);
    await for (final r in ping.ping(pingCtx, a, b.id()).take(3)) {
      // En Windows el reloj de Go es grueso: un ping local puede dar 0.
      say('ping a → b: ${r.rtt.inMicroseconds} µs');
    }
    stopPing();

    // 4. Un protocolo propio: b responde a cada saludo. El handler es una
    //    función Dart que Go guarda y llama una vez por cada stream entrante.
    //    Go:  b.SetStreamHandler(greet, func(s network.Stream) {...})
    b.setStreamHandler(greet, (s) async {
      final name = await io_stream.readerStream(s).expand((c) => c).toList();
      await s.write(utf8.encode('hello, ${utf8.decode(name)}, from b'));
      await s.close();
    });
    //    Go:  s, _ := a.NewStream(ctx, b.ID(), greet)
    final s = await a.newStream(ctx, b.id(), [greet]);
    await s.write(Uint8List.fromList(utf8.encode('a')));
    await s.closeWrite(); // "terminé de enviar"; el bucle de lectura de b acaba
    final answer = await io_stream.readerStream(s).expand((c) => c).toList();
    say('a envió "a" en $greet; b respondió "${utf8.decode(answer)}"');
    //    Lo que a aprendió que habla b (identify, que corre en cada conexión
    //    nueva):
    final speaks = await a.peerstore().getProtocols(b.id());
    say('  a sabe que b habla ${speaks.length} protocolos, por ejemplo '
        '${speaks.where((p) => p.contains('ping') || p.contains('identify')).join(', ')}');

    // 5. mDNS: los hosts de la misma red local se anuncian; un mdns.Notifee
    //    en Dart los oye (la red tiene que permitir multicast).
    //    Go:  mdns.NewMdnsService(h, "lesson", notifee).Start()
    final c = await newHost();
    final found = Completer<void>();
    final listen = mdns.newMdnsService(c, 'p2p-ffi-lesson',
        mdns.Notifee(handlePeerFound: (pi) {
      if (pi.id == a.id() && !found.isCompleted) {
        say('mDNS: c encontró a a en la red local en ${pi.addrs.first}');
        found.complete();
      }
    }));
    final announce = mdns.newMdnsService(a, 'p2p-ffi-lesson', mdns.Notifee());
    listen.start();
    announce.start();
    await found.future.timeout(const Duration(seconds: 10),
        onTimeout: () => say('mDNS: nada en 10 s (¿multicast bloqueado?)'));
    listen.close();
    announce.close();

    say('\n== Errores comunes\n');
    await mistake('abrir un stream a un protocolo que el otro lado no tiene',
        why: 'b no tiene handler para él: la negociación del protocolo falla',
        instead: 'registra antes el handler en el otro lado; compruébalo con '
            'peerstore().getProtocols(id)',
        action: () => a.newStream(ctx, b.id(), ['/nobody/here/1.0.0']));
    await mistake('conectar sabiendo solo el peer ID',
        why: 'c nunca vio a b: no hay dirección en su peerstore que marcar',
        instead: 'pasa las direcciones (un AddrInfo), o encuéntralas por el '
            'DHT (lección 15) o por mDNS',
        action: () => c.connect(ctx, peer.AddrInfo(id: b.id())));

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
