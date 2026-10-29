// Lección 18 · ¿Cómo envío mensajes en tiempo real?
//
// Pregunta: bitswap trae el contenido que alguien pide. ¿Cómo empujan los
// peers mensajes a todos los interesados, en el momento en que ocurren (un
// chat, actualizaciones en vivo)?
//
// Respuesta: pubsub, con el gossipsub de libp2p. Los peers se suscriben a un
// tema (un nombre); un mensaje publicado en él se reenvía de peer en peer por
// una malla de suscriptores, cada uno pasándolo a unos cuantos, hasta que
// todos lo tienen. Los mensajes van firmados por su autor y se deduplican. Un
// validador, una función que cada peer ejecuta sobre cada mensaje, decide
// aceptarlo, ignorarlo o rechazarlo (y penaliza a los peers que envían
// mensajes rechazados). No se guarda nada: quien no estaba suscrito cuando
// salió nunca lo ve; para tener historial, publica un CID (contenido) o un
// nombre IPNS (lección 11).
// Dos caminos en esta lección:
//   - el pubsub de kubo (`ipfs pubsub`): el gossipsub del propio nodo,
//     activado por Pubsub.Enabled en la config o por la opción extra
//     `pubsub`;
//   - gossipsub directamente sobre hosts libp2p, con un validador en Dart.
//
// Necesita: las lecciones 14-15 (peers conectados; los suscriptores se
// encuentran por los peers a los que están conectados, o por el
// descubrimiento DHT/mDNS de un nodo kubo online). Técnicamente: un host, un
// enrutador gossipsub en él, y al menos un camino de suscriptores conectados
// entre autor y lector.
//
//   dart run example/es/18_pubsub.dart
//
// Siguiente pregunta: "Algunas de estas llamadas pueden esperar para
// siempre. ¿Cómo les pongo un plazo, y qué errores pueden volver?" →
// lección 19.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson18_');
  final ctx = Go.context.background();
  try {
    // 1. El pubsub de kubo: dos nodos online en loopback, pubsub activado.
    //    Go:  core.NewNode(ctx, &node.BuildCfg{..., ExtraOpts: map[string]bool{"pubsub": true}})
    loadPlugins();
    Future<KuboCoreIpfsNode> pubsubNode(String name) async {
      final cfg = Go.kubo.config.initWithIdentity(Go.kubo.config.createIdentity(
          null, [Go.kubo.core.coreiface.options.key.type('ed25519')]));
      Go.kubo.config.profiles['test']!.transform(cfg);
      Go.kubo.repo.fsrepo.init('${tmp.path}/$name', cfg);
      return Go.kubo.core.newNode(
          ctx,
          KuboCoreNodeBuildCfg(
              repo: Go.kubo.repo.fsrepo.open('${tmp.path}/$name'),
              online: true,
              routing: Go.kubo.core.node.libp2p.dhtServerOption,
              extraOpts: {'pubsub': true}));
    }

    final na = await pubsubNode('a'), nb = await pubsubNode('b');
    final a = Go.kubo.core.coreapi.newCoreApi(na),
        b = Go.kubo.core.coreapi.newCoreApi(nb);
    final idA = (await a.key().self(ctx)).id!;
    await b.swarm().connect(
        ctx,
        Libp2pCorePeerAddrInfo(
            id: idA, addrs: await a.swarm().localAddrs(ctx)));

    //    a se suscribe; b espera hasta ver a a en el tema, y entonces
    //    publica.
    //    Go:  sub, _ := api.PubSub().Subscribe(ctx, "news")
    final (subCtx, stopSub) = Go.context.withCancel(ctx);
    final sub = await a.pubSub().subscribe(subCtx, 'news');
    while (!(await b
            .pubSub()
            .peers(ctx, [Go.kubo.core.coreiface.options.pubSub.topic('news')]))
        .contains(idA)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    //    Go:  api.PubSub().Publish(ctx, "news", data)
    await b.pubSub().publish(ctx, 'news', utf8.encode('hello from b'));
    final m = await sub.next(subCtx);
    say('pubsub de kubo: a recibió "${utf8.decode(m.data!)}" en '
        '${m.topics.join(', ')} de ${m.from!.shortString()}');
    stopSub();
    sub.close();
    await na.close();
    await nb.close();

    // 2. gossipsub en hosts libp2p: tres hosts en línea (x - y - z), así que
    //    un mensaje de x solo llega a z pasando por y.
    //    Go:  ps, _ := pubsub.NewGossipSub(ctx, h); t, _ := ps.Join("chat")
    final hosts = [
      for (var i = 0; i < 3; i++)
        await Go.libp2p.new$([
          Go.libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]),
    ];
    final [x, y, z] = hosts;
    await x.connect(ctx, Go.libp2p.core.host.infoFromHost(y));
    await z.connect(ctx, Go.libp2p.core.host.infoFromHost(y));
    final routers = [
      for (final h in hosts) await Go.libp2pPubsub.newGossipSub(ctx, h)
    ];
    //    z solo acepta mensajes cortos: una función Dart que Go llama por
    //    cada mensaje (aceptar, ignorar o rechazar; una excepción también
    //    rechaza).
    //    Go:  ps.RegisterTopicValidator("chat", func(ctx, from, m) ValidationResult {...})
    await routers[2].registerTopicValidator(
        'chat',
        (_, from, msg) => msg.message!.getData().length <= 64
            ? Go.libp2pPubsub.validationAccept
            : Go.libp2pPubsub.validationReject);
    final topics = [for (final r in routers) await r.join('chat')];
    final zSub = await topics[2].subscribe();
    final ySub = await topics[1].subscribe(); // y solo reenvía si se suscribe
    while ((await topics[0].listPeers()).isEmpty ||
        (await topics[2].listPeers()).isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await topics[0].publish(ctx, Uint8List.fromList(utf8.encode('hi from x')));
    await topics[0].publish(
        ctx, Uint8List.fromList(utf8.encode('${'x' * 100} (z rejects it)')));
    await topics[0].publish(ctx, Uint8List.fromList(utf8.encode('bye from x')));
    for (var i = 0; i < 2; i++) {
      final (nctx, cancel) =
          Go.context.withTimeout(ctx, const Duration(seconds: 10));
      final got = await zSub.next(nctx);
      cancel();
      say('gossipsub: z recibió "${utf8.decode(got.message!.getData())}" '
          '(autor ${Go.libp2p.core.peer.idFromBytes(got.message!.getFrom()).shortString()}, '
          'reenviado por ${got.receivedFrom!.shortString()})');
    }

    say('\n== Errores comunes\n');
    final late = await topics[2].subscribe();
    await mistake('esperar un mensaje publicado antes de suscribirte',
        why: 'pubsub no guarda nada: "hi from x" salió antes de que esta '
            'suscripción existiera',
        instead: 'publica un CID o un nombre IPNS para el historial; pubsub '
            'solo para lo que pasa ahora', action: () async {
      final (nctx, cancel) =
          Go.context.withTimeout(ctx, const Duration(seconds: 2));
      try {
        await late.next(nctx);
      } finally {
        cancel();
      }
    });
    late.cancel();
    await mistake('unirse dos veces al mismo tema en un enrutador',
        why: 'un enrutador guarda un Topic por nombre; join lo devuelve una '
            'sola vez',
        instead: 'guarda el Topic del primer join y reutilízalo',
        action: () => routers[0].join('chat'));

    zSub.cancel();
    ySub.cancel();
    for (final h in hosts) {
      await h.close();
    }
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
