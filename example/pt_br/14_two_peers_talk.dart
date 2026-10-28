// Lição 14 · Como dois peers conversam?
//
// Pergunta: tenho dois hosts com IDs e endereços (lição 13). Como um alcança
// o outro, e como trocam os meus próprios dados?
//
// Resposta: um host se conecta ao outro (um AddrInfo: o peer ID mais pelo
// menos um endereço para discar). Sobre essa única conexão eles abrem
// streams: cada stream é um cano de bytes nos dois sentidos, marcado com o
// nome de um protocolo (`/ipfs/bitswap/1.2.0`, `/ipfs/kad/1.0.0`, ou o seu:
// `/meu-app/greet/1.0.0`). Um host atende um protocolo registrando um handler
// de stream para o nome dele; abrir um stream para um protocolo que ninguém
// atende falha. O próprio IPFS é só um conjunto desses protocolos (bitswap,
// kad-dht, identify, ping...) no mesmo tipo de host. Os hosts descobrem os
// endereços uns dos outros quando alguém conta, pelo DHT (lição 15), ou na
// rede local pelo mDNS.
//
// Precisa de: lição 13 (hosts). Tecnicamente, para conectar: o peer ID do
// outro e um endereço discável (no AddrInfo ou já no peerstore); para abrir
// um stream: uma conexão (ou como fazer uma) e um handler do outro lado para
// aquele protocolo.
//
//   dart run example/pt_br/14_two_peers_talk.dart
//
// Próxima pergunta: "Aqui eu dei o endereço do b para o a na mão. Numa rede
// de verdade, como acho um peer, ou quem tem um conteúdo?" → lição 15.
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

/// network.Connectedness em palavras.
String state(int c) => switch (c) {
      network.notConnected => 'desconectado',
      network.connected => 'conectado',
      network.canConnect => 'pode conectar',
      network.cannotConnect => 'não consegue conectar',
      network.limited => 'conectado (limitado, por um relay)',
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

    // 1. Observar as conexões de a: uma implementação em Dart de uma
    //    interface Go (network.Notifiee), chamada pelo Go a cada evento.
    //    Go:  a.Network().Notify(&network.NotifyBundle{ConnectedF: ...})
    final watcher = network.Notifiee(
      connected: (_, c) =>
          say('  [a] conectado a ${c.remotePeer().shortString()} '
              'por ${c.remoteMultiaddr()}'),
      disconnected: (_, c) =>
          say('  [a] desconectado de ${c.remotePeer().shortString()}'),
    );
    a.network().notify(watcher);
    //    A mesma notícia pelo barramento de eventos de b.
    //    Go:  sub, _ := b.EventBus().Subscribe(new(event.EvtPeerConnectednessChanged))
    final bus = b.eventBus().subscribe(event.EvtPeerConnectednessChanged.$type);
    final busDone = bus.out().forEach((e) {
      if (e is event.EvtPeerConnectednessChanged) {
        say('  [b] ${e.peer!.shortString()} agora está '
            '${state(e.connectedness)}');
      }
    });

    // 2. Conectar: o ID e os endereços de b, como um AddrInfo.
    //    Go:  a.Connect(ctx, *host.InfoFromHost(b))
    await a.connect(ctx, host.infoFromHost(b));
    say('a e b: ${state(a.network().connectedness(b.id()))}');

    // 3. Ping: um protocolo que todo host fala (/ipfs/ping/1.0.0).
    //    Go:  for r := range ping.Ping(ctx, a, b.ID()) { r.RTT }
    final (pingCtx, stopPing) = context.withCancel(ctx);
    await for (final r in ping.ping(pingCtx, a, b.id()).take(3)) {
      // No Windows o relógio do Go é grosso: um ping local pode dar 0.
      say('ping a → b: ${r.rtt.inMicroseconds} µs');
    }
    stopPing();

    // 4. Um protocolo nosso: b responde cada saudação. O handler é uma
    //    função Dart que o Go guarda e chama uma vez por stream que chega.
    //    Go:  b.SetStreamHandler(greet, func(s network.Stream) {...})
    b.setStreamHandler(greet, (s) async {
      final name = await io_stream.readerStream(s).expand((c) => c).toList();
      await s.write(utf8.encode('hello, ${utf8.decode(name)}, from b'));
      await s.close();
    });
    //    Go:  s, _ := a.NewStream(ctx, b.ID(), greet)
    final s = await a.newStream(ctx, b.id(), [greet]);
    await s.write(Uint8List.fromList(utf8.encode('a')));
    await s.closeWrite(); // "terminei de mandar"; o laço de leitura de b acaba
    final answer = await io_stream.readerStream(s).expand((c) => c).toList();
    say('a mandou "a" em $greet; b respondeu "${utf8.decode(answer)}"');
    //    O que a aprendeu que b fala (o identify, que roda a cada conexão
    //    nova):
    final speaks = await a.peerstore().getProtocols(b.id());
    say('  a sabe que b fala ${speaks.length} protocolos, por exemplo '
        '${speaks.where((p) => p.contains('ping') || p.contains('identify')).join(', ')}');

    // 5. mDNS: hosts na mesma rede local se anunciam; um mdns.Notifee em
    //    Dart os ouve (a rede precisa permitir multicast).
    //    Go:  mdns.NewMdnsService(h, "lesson", notifee).Start()
    final c = await newHost();
    final found = Completer<void>();
    final listen = mdns.newMdnsService(c, 'p2p-ffi-lesson',
        mdns.Notifee(handlePeerFound: (pi) {
      if (pi.id == a.id() && !found.isCompleted) {
        say('mDNS: c achou a na rede local em ${pi.addrs.first}');
        found.complete();
      }
    }));
    final announce = mdns.newMdnsService(a, 'p2p-ffi-lesson', mdns.Notifee());
    listen.start();
    announce.start();
    await found.future.timeout(const Duration(seconds: 10),
        onTimeout: () => say('mDNS: nada em 10 s (multicast bloqueado?)'));
    listen.close();
    announce.close();

    say('\n== Erros comuns\n');
    await mistake('abrir um stream para um protocolo que o outro lado não tem',
        why: 'b não tem handler para ele: a negociação do protocolo falha',
        instead: 'registre o handler do outro lado antes; confira com '
            'peerstore().getProtocols(id)',
        action: () => a.newStream(ctx, b.id(), ['/nobody/here/1.0.0']));
    await mistake('conectar sabendo só o peer ID',
        why: 'c nunca viu b: não há endereço no peerstore dele para discar',
        instead: 'passe os endereços (um AddrInfo), ou ache-os pelo DHT '
            '(lição 15) ou pelo mDNS',
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
