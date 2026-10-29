// Lição 18 · Como mando mensagens em tempo real?
//
// Pergunta: o bitswap busca o conteúdo que alguém pede. Como os peers
// empurram mensagens para todos os interessados, na hora em que acontecem
// (um chat, atualizações ao vivo)?
//
// Resposta: pubsub, com o gossipsub do libp2p. Os peers assinam um tópico (um
// nome); uma mensagem publicada nele é repassada de peer em peer por uma
// malha de assinantes, cada um passando-a para alguns outros, até todos a
// terem. As mensagens são assinadas pelo autor e deduplicadas. Um validador,
// uma função que cada peer roda em cada mensagem, decide aceitá-la, ignorá-la
// ou rejeitá-la (e penaliza peers que mandam mensagens rejeitadas). Nada é
// guardado: quem não estava inscrito quando ela saiu nunca a vê; para
// histórico, publique um CID (conteúdo) ou um nome IPNS (lição 11).
// Dois caminhos nesta lição:
//   - o pubsub do kubo (`ipfs pubsub`): o gossipsub do próprio nó, ligado
//     pelo Pubsub.Enabled da config ou pela opção extra `pubsub`;
//   - o gossipsub direto em hosts libp2p, com um validador em Dart.
//
// Precisa de: lições 14-15 (peers conectados; os assinantes se acham pelos
// peers a que estão conectados, ou pela descoberta DHT/mDNS de um nó kubo
// online). Tecnicamente: um host, um roteador gossipsub nele, e pelo menos
// um caminho de assinantes conectados entre autor e leitor.
//
//   dart run example/pt_br/18_pubsub.dart
//
// Próxima pergunta: "Algumas destas chamadas podem esperar para sempre. Como
// lhes dou um prazo, e que erros podem voltar?" → lição 19.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson18_');
  final ctx = goContext.background();
  try {
    // 1. O pubsub do kubo: dois nós online no loopback, pubsub ligado.
    //    Go:  core.NewNode(ctx, &node.BuildCfg{..., ExtraOpts: map[string]bool{"pubsub": true}})
    loadPlugins();
    Future<KuboCoreIpfsNode> pubsubNode(String name) async {
      final cfg = goKubo.config.initWithIdentity(goKubo.config.createIdentity(
          null, [goKubo.core.coreiface.options.key.type('ed25519')]));
      goKubo.config.profiles['test']!.transform(cfg);
      goKubo.repo.fsrepo.init('${tmp.path}/$name', cfg);
      return goKubo.core.newNode(
          ctx,
          KuboCoreNodeBuildCfg(
              repo: goKubo.repo.fsrepo.open('${tmp.path}/$name'),
              online: true,
              routing: goKubo.core.node.libp2p.dhtServerOption,
              extraOpts: {'pubsub': true}));
    }

    final na = await pubsubNode('a'), nb = await pubsubNode('b');
    final a = goKubo.core.coreapi.newCoreApi(na),
        b = goKubo.core.coreapi.newCoreApi(nb);
    final idA = (await a.key().self(ctx)).id!;
    await b.swarm().connect(
        ctx,
        Libp2pCorePeerAddrInfo(
            id: idA, addrs: await a.swarm().localAddrs(ctx)));

    //    a assina; b espera até ver a no tópico, e então publica.
    //    Go:  sub, _ := api.PubSub().Subscribe(ctx, "news")
    final (subCtx, stopSub) = goContext.withCancel(ctx);
    final sub = await a.pubSub().subscribe(subCtx, 'news');
    while (!(await b
            .pubSub()
            .peers(ctx, [goKubo.core.coreiface.options.pubSub.topic('news')]))
        .contains(idA)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    //    Go:  api.PubSub().Publish(ctx, "news", data)
    await b.pubSub().publish(ctx, 'news', utf8.encode('hello from b'));
    final m = await sub.next(subCtx);
    say('pubsub do kubo: a recebeu "${utf8.decode(m.data!)}" em '
        '${m.topics.join(', ')} de ${m.from!.shortString()}');
    stopSub();
    sub.close();
    await na.close();
    await nb.close();

    // 2. gossipsub em hosts libp2p: três hosts em linha (x - y - z), então
    //    uma mensagem de x só chega a z passando por y.
    //    Go:  ps, _ := pubsub.NewGossipSub(ctx, h); t, _ := ps.Join("chat")
    final hosts = [
      for (var i = 0; i < 3; i++)
        await goLibp2p.new$([
          goLibp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]),
    ];
    final [x, y, z] = hosts;
    await x.connect(ctx, goLibp2p.core.host.infoFromHost(y));
    await z.connect(ctx, goLibp2p.core.host.infoFromHost(y));
    final routers = [
      for (final h in hosts) await goLibp2pPubsub.newGossipSub(ctx, h)
    ];
    //    z só aceita mensagens curtas: uma função Dart que o Go chama para
    //    cada mensagem (aceitar, ignorar ou rejeitar; uma exceção também
    //    rejeita).
    //    Go:  ps.RegisterTopicValidator("chat", func(ctx, from, m) ValidationResult {...})
    await routers[2].registerTopicValidator(
        'chat',
        (_, from, msg) => msg.message!.getData().length <= 64
            ? goLibp2pPubsub.validationAccept
            : goLibp2pPubsub.validationReject);
    final topics = [for (final r in routers) await r.join('chat')];
    final zSub = await topics[2].subscribe();
    final ySub = await topics[1].subscribe(); // y só repassa se assinar
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
          goContext.withTimeout(ctx, const Duration(seconds: 10));
      final got = await zSub.next(nctx);
      cancel();
      say('gossipsub: z recebeu "${utf8.decode(got.message!.getData())}" '
          '(autor ${goLibp2p.core.peer.idFromBytes(got.message!.getFrom()).shortString()}, '
          'repassada por ${got.receivedFrom!.shortString()})');
    }

    say('\n== Erros comuns\n');
    final late = await topics[2].subscribe();
    await mistake('esperar uma mensagem publicada antes de você assinar',
        why: 'o pubsub não guarda nada: "hi from x" saiu antes de esta '
            'assinatura existir',
        instead: 'publique um CID ou um nome IPNS para histórico; pubsub só '
            'para o que acontece agora', action: () async {
      final (nctx, cancel) =
          goContext.withTimeout(ctx, const Duration(seconds: 2));
      try {
        await late.next(nctx);
      } finally {
        cancel();
      }
    });
    late.cancel();
    await mistake('entrar no mesmo tópico duas vezes num roteador',
        why: 'um roteador guarda um Topic por nome; o join o devolve uma vez',
        instead: 'guarde o Topic do primeiro join e reutilize-o',
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
