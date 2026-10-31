// Lección 15 · ¿Cómo encuentro quién tiene un contenido?
//
// Pregunta: en la lección 14 le di a un host la dirección del otro a mano. En
// una red de miles de peers, ¿cómo encuentro la dirección de un peer a partir
// de su ID, o qué peers tienen un CID?
//
// Respuesta: un DHT (Kademlia, el protocolo `kad-dht`): una tabla repartida
// entre todos los peers. Cada peer guarda una tabla de enrutamiento con
// algunos otros, ordenados por la distancia XOR entre los IDs; una búsqueda
// pregunta a los más cercanos que conoce, que responden con otros más
// cercanos, hasta llegar a los peers más cercanos a la clave. Lo que se
// guarda ahí:
//   - registros de proveedor: "el peer P tiene el CID X" (Provide, luego
//     FindProviders); caducan, así que los proveedores los vuelven a anunciar
//     (kubo cada 22 h);
//   - direcciones de peers: FindPeer(ID) devuelve dónde marcar;
//   - valores pequeños y firmados, como los registros IPNS (lección 11).
// El DHT público de IPFS usa el prefijo `/ipfs`; esta lección arma uno
// privado (con prefijo propio) en loopback, así que nunca se mezcla con la
// red pública. Un punto de encuentro (rendezvous) es el mismo truco para un
// nombre: el hash del nombre de una sala se vuelve un CID que se anuncia y se
// busca.
//
// Necesita: la lección 14 (hosts que se conectan). Técnicamente, un DHT
// necesita un host y al menos un peer por donde empezar (un peer de
// bootstrap); en modo servidor también atiende a los demás (kubo pasa a
// modo cliente detrás de un NAT, lección 17).
//
//   dart run example/es/15_find_on_the_dht.dart
//
// Siguiente pregunta: "Encontré quién tiene el CID. ¿Qué es lo que de verdad
// me trae sus bloques?" → lección 16.
import 'dart:convert';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

const prefix = '/p2p-ffi-lesson'; // un DHT privado: no el /ipfs

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = go.context.background();

    // 1. Cinco hosts, cada uno con un DHT en modo servidor. Solo el primero
    //    es conocido por los demás: es su peer de bootstrap.
    //    Go:  d, _ := dht.New(ctx, h, dht.Mode(dht.ModeServer), dht.ProtocolPrefix(prefix))
    final hosts = [
      for (var i = 0; i < 5; i++)
        await go.libp2p.libp2p.new$([
          go.libp2p.libp2p.options.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]),
    ];
    final opts = [
      go.libp2p.libp2pKadDht.options
          .mode(go.libp2p.libp2pKadDht.enums.modeServer),
      go.libp2p.libp2pKadDht.options.protocolPrefix(prefix)
    ];
    final dhts = [for (final h in hosts) go.libp2p.libp2pKadDht.new$(h, opts)];
    for (final h in hosts.skip(1)) {
      await h.connect(ctx, go.libp2p.libp2p.core.host.infoFromHost(hosts[0]));
    }
    //    Bootstrap: cada uno pide a la red los peers más cercanos a sí mismo,
    //    llenando su tabla de enrutamiento más allá del peer de bootstrap.
    for (final d in dhts) {
      await d.bootstrap(ctx);
    }
    for (var i = 0;
        i < 100 && dhts.any((d) => d.routingTable().size() < 4);
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    say('tablas de enrutamiento: '
        '${dhts.map((d) => d.routingTable().size()).join(', ')} peers');

    // 2. FindPeer: el host 4 pide la dirección del host 3 solo por su ID.
    //    Go:  pi, _ := d.FindPeer(ctx, id)
    final target = hosts[3].id();
    final found = await () async {
      for (var i = 1;; i++) {
        try {
          return await dhts[4].findPeer(ctx, target);
        } on GolangException catch (e) {
          // En un DHT tan pequeño una búsqueda puede fallar mientras se llenan
          // las tablas (kb.ErrLookupFailure, routing.ErrNotFound): reintenta
          // solo en esos casos.
          if (i == 5 ||
              (e is! Libp2pKbucketErrLookupFailure &&
                  e is! Libp2pCoreRoutingErrNotFound)) {
            rethrow;
          }
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }();
    say('\nel host 4 buscó ${target.shortString()}: ${found.addrs}');

    // 3. Provide y FindProviders: el host 1 dice que tiene un CID; el host 4
    //    averigua quién lo tiene.
    //    Go:  d.Provide(ctx, c, true); provs, _ := d.FindProviders(ctx, c)
    final content = go.ipfs.cid
        .newPrefixV1(go.multiformats.multicodec.enums.raw,
            go.multiformats.multihash.consts.sha2256)
        .sum(utf8.encode('something host 1 has'));
    await dhts[1].provide(ctx, content, true);
    final providers = await dhts[4].findProviders(ctx, content);
    say('\nel host 1 anunció $content');
    say('el host 4 encontró los proveedores: '
        '${providers.map((p) => p.id!.shortString()).join(', ')} '
        '(el host 1 es ${hosts[1].id().shortString()})');

    // 4. Punto de encuentro por nombre: el host 2 anuncia una sala, el host
    //    4 averigua quién está en ella.
    //    Go:  rd := routing.NewRoutingDiscovery(d); rd.Advertise(ctx, "room")
    //         for pi := range rd.FindPeers(ctx, "room") {...}
    final ttl = await Libp2pP2pDiscoveryRoutingDiscovery(dhts[2])
        .advertise(ctx, 'room');
    say('\nel host 2 anunció "room" (válido ${ttl.inHours} h)');
    await for (final pi
        in Libp2pP2pDiscoveryRoutingDiscovery(dhts[4]).findPeers(ctx, 'room')) {
      say('el host 4 encontró en "room": ${pi.id!.shortString()}');
    }

    say('\n== Errores comunes\n');
    final lonely = await go.libp2p.libp2p.new$([
      go.libp2p.libp2p.options.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
    ]);
    final lonelyDht = go.libp2p.libp2pKadDht.new$(lonely, opts);
    await mistake('anunciar en un DHT que no conoce ningún peer',
        why: 'su tabla de enrutamiento está vacía: no hay en quién guardar el '
            'registro',
        instead: 'conéctate antes a un peer de bootstrap (en kubo: la lista '
            'Bootstrap de la config)',
        action: () => lonelyDht.provide(ctx, content, true));
    final other = await go.libp2p.libp2p.new$([
      go.libp2p.libp2p.options.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
    ]);
    final otherDht = go.libp2p.libp2pKadDht.new$(other, [
      go.libp2p.libp2pKadDht.options
          .mode(go.libp2p.libp2pKadDht.enums.modeServer),
      go.libp2p.libp2pKadDht.options.protocolPrefix('/x')
    ]);
    await other.connect(ctx, go.libp2p.libp2p.core.host.infoFromHost(hosts[0]));
    await silentlyWrong('entrar con otro prefijo de protocolo',
        why: 'otro prefijo es otro DHT: los peers están conectados pero nunca '
            'entran en las tablas de los otros',
        instead: 'el mismo prefijo en todos los peers (/ipfs para la red IPFS '
            'pública)',
        wrong: () async {
          await otherDht.bootstrap(ctx);
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return '${otherDht.routingTable().size()} peers en la tabla';
        },
        right: () => '${dhts[0].routingTable().size()} peers en la tabla');

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
