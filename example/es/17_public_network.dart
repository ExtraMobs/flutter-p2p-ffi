// Lección 17 · ¿Cómo entro en la red IPFS pública?
//
// Pregunta: las lecciones 13-16 usaron mis propios hosts en loopback. ¿Cómo
// entra mi nodo en la red IPFS de verdad y trae contenido que cualquiera
// haya publicado?
//
// Respuesta: un nodo kubo online con una config normal hace por ti todo lo de
// la parte C:
//   - bootstrap: marca a los peers conocidos de la lista Bootstrap de la
//     config (el AutoConf de kubo mantiene esa lista y los enrutadores al
//     día);
//   - enrutamiento: Routing.Type decide cómo encuentra contenido: el DHT
//     público (`/ipfs/kad/1.0.0`), enrutadores HTTP delegados (cid.contact),
//     o los dos ("auto", el valor por defecto);
//   - bitswap sobre su host y ese enrutamiento (lección 16) es n.exchange;
//   - alcanzabilidad: AutoNAT pide a otros peers que lo llamen de vuelta;
//     detrás de un NAT se queda como cliente del DHT y puede usar relays y
//     hole punching para que lo alcancen. Anuncia (provide) lo que añade,
//     para que otros puedan traerlo.
// En Android, Go no encuentra el resolvedor de DNS del sistema: configura
// DNS.Resolvers en la config (DNS sobre HTTPS), o nombres como
// `/dnsaddr/bootstrap.libp2p.io` no se resuelven.
//
// Necesita: las lecciones 08 (un nodo) y 13-16 (lo que hace online), más una
// red que le deje llegar a internet. El perfil `randomports` lo mantiene
// fuera del puerto 4001, que IPFS Desktop (u otro kubo) puede estar usando.
//
//   dart run example/es/17_public_network.dart
//
// Siguiente pregunta: "Traer es tirar. ¿Pueden los peers empujarse mensajes
// en el momento en que ocurren?" → lección 18.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/boxo/path.dart' as path;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/io.dart' as io;
import 'package:p2p_ffi/go/kubo/config.dart' as config;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/core/node/libp2p.dart' as kubo_libp2p;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

/// Un archivo pequeño publicado por el verificador de gateways públicos de
/// IPFS: cualquiera en la red puede traerlo.
const known = 'bafybeifx7yeb55armcsxwwitkymga5xf53dxiarykms3ygqic223w5sk3m';

/// Lo que hace `ipfs daemon` con el Routing.Type de la config
/// (cmd/ipfs/kubo/daemon.go).
kubo_libp2p.RoutingOption routingFor(config.Config cfg) {
  final type = (cfg.json['Routing'] as Map?)?['Type'] as String? ?? '';
  return switch (type) {
    '' ||
    'auto' ||
    'default' =>
      kubo_libp2p.constructDefaultRouting(cfg, kubo_libp2p.dhtOption),
    'autoclient' =>
      kubo_libp2p.constructDefaultRouting(cfg, kubo_libp2p.dhtClientOption),
    'dht' => kubo_libp2p.dhtOption,
    'dhtclient' => kubo_libp2p.dhtClientOption,
    'dhtserver' => kubo_libp2p.dhtServerOption,
    'none' => kubo_libp2p.nilRouterOption,
    _ => throw ArgumentError('Routing.Type "$type" no tratado aquí'),
  };
}

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson17_');
  final ctx = context.background();
  try {
    // 1. Un repositorio con la config normal (peers de bootstrap,
    //    enrutamiento "auto"), solo con puertos aleatorios.
    loadPlugins();
    final cfg = config.initWithIdentity(
        config.createIdentity(null, [options.key.type('ed25519')]));
    config.profiles['randomports']!.transform(cfg);
    fsrepo.init('${tmp.path}/repo', cfg);
    final repo = fsrepo.open('${tmp.path}/repo');
    say('Routing.Type: "${(repo.config().json['Routing'] as Map)['Type']}", '
        '${(repo.config().json['Bootstrap'] as List).length} entradas de '
        'bootstrap');

    // 2. El nodo online: host, bootstrap, enrutamiento, bitswap, todo en
    //    marcha.
    //    Go:  core.NewNode(ctx, &node.BuildCfg{Repo: r, Online: true,
    //             Permanent: true, Routing: routingFor(cfg)})
    final n = await core.newNode(
        ctx,
        node.BuildCfg(
            repo: repo,
            online: true,
            permanent: true,
            routing: routingFor(repo.config())));
    final api = coreapi.newCoreApi(n);
    try {
      say('online como ${(await api.key().self(ctx)).id}');
      // (Solo se muestran las de loopback: las otras son las IPs reales de
      // esta máquina, que no deben ir a un log compartido.)
      final listening = await api.swarm().listenAddrs(ctx);
      say('  escuchando en ${listening.length} direcciones, por ejemplo '
          '${listening.where((a) => '$a'.startsWith('/ip4/127.')).take(2).join(', ')}');

      // 3. Los peers vienen de la lista de bootstrap, luego del DHT.
      var peers = 0;
      for (var i = 0; i < 30 && peers < 8; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        peers = (await api.swarm().peers(ctx)).length;
      }
      say('\nconectado a $peers peers');
      if (peers == 0) {
        say('ningún peer: ¿hay conexión a internet? (el resto la necesita)');
        return;
      }

      // 4. Traer algo que publicó otra persona: el enrutamiento encuentra
      //    sus proveedores, bitswap trae los bloques, cada uno comprobado.
      final (fctx, cancel) =
          context.withTimeout(ctx, const Duration(seconds: 90));
      final watch = Stopwatch()..start();
      try {
        final f = await api.unixfs().get(fctx, path.Path('/ipfs/$known'));
        say('traje /ipfs/$known en ${watch.elapsed.inSeconds} s: '
            '"${utf8.decode(io.readAll(files.toFile(f))).trim()}"');
      } on GolangException catch (e) {
        say('no pude traerlo en 90 s: ${brief(e)}');
      } finally {
        cancel();
      }

      // 5. Publicar: add, y el nodo lo anuncia a la red (aquí pedimos el
      //    anuncio ya en lugar de esperar a la cola).
      final p = await api.unixfs().add(
          ctx,
          files.newBytesFile(utf8.encode('hello from a Dart app over p2p_ffi '
              '${DateTime.now().toUtc()}\n')),
          [options.unixfs.pin(true, 'lesson-17')]);
      say('\nañadí $p; anunciándolo...');
      final (pctx, pcancel) =
          context.withTimeout(ctx, const Duration(seconds: 60));
      try {
        await api.routing().provide(pctx, p);
        say('  anunciado: cualquier nodo (o https://ipfs.io/ipfs/...) puede '
            'traerlo mientras este nodo esté online');
      } on GolangException catch (e) {
        say('  no anunciado a tiempo: ${brief(e)} (el nodo sigue '
            'intentándolo)');
      } finally {
        pcancel();
      }

      say('\n== Errores comunes\n');
      // Un nodo online sin enrutamiento y sin peers de bootstrap: online,
      // pero solo.
      final lonelyCfg = config.initWithIdentity(
          config.createIdentity(null, [options.key.type('ed25519')]));
      config.profiles['test']!.transform(lonelyCfg);
      fsrepo.init('${tmp.path}/lonely', lonelyCfg);
      final lonely = await core.newNode(
          ctx,
          node.BuildCfg(
              repo: fsrepo.open('${tmp.path}/lonely'),
              online: true,
              routing: kubo_libp2p.nilRouterOption));
      final lonelyApi = coreapi.newCoreApi(lonely);
      await mistake('traer con un nodo online sin peers y sin enrutamiento',
          why: '"online" solo significa que bitswap está activo: sin nadie '
              'conectado y sin enrutador, no hay a quién preguntar (el perfil '
              'test quita la lista de bootstrap)',
          instead: 'peers de bootstrap y un enrutador (la config por '
              'defecto), o conectarse a un peer que tenga el contenido',
          action: () async {
        final (tctx, cancel) =
            context.withTimeout(ctx, const Duration(seconds: 5));
        try {
          await lonelyApi.unixfs().get(tctx, path.Path('/ipfs/$known'));
        } finally {
          cancel();
        }
      });
      await lonely.close();
    } finally {
      await n.close();
    }
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
