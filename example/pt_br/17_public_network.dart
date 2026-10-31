// Lição 17 · Como entro na rede IPFS pública?
//
// Pergunta: as lições 13-16 usaram os meus próprios hosts no loopback. Como
// o meu nó entra na rede IPFS de verdade e busca conteúdo que qualquer um
// publicou?
//
// Resposta: um nó kubo online com uma config normal faz por você tudo o que
// está na parte C:
//   - bootstrap: ele disca os peers conhecidos da lista Bootstrap da config
//     (o AutoConf do kubo mantém essa lista e os roteadores atualizados);
//   - roteamento: o Routing.Type decide como ele acha conteúdo: o DHT
//     público (`/ipfs/kad/1.0.0`), roteadores HTTP delegados (cid.contact),
//     ou os dois ("auto", o padrão);
//   - o bitswap sobre o host dele e esse roteamento (lição 16) é o
//     n.exchange;
//   - alcançabilidade: o AutoNAT pede a outros peers que disquem de volta;
//     atrás de um NAT ele fica cliente do DHT e pode usar relays e hole
//     punching para ser alcançado. Ele anuncia (provide) o que adiciona,
//     para que outros possam buscar.
// No Android, o Go não acha o resolvedor de DNS do sistema: configure
// DNS.Resolvers na config (DNS sobre HTTPS), senão nomes como
// `/dnsaddr/bootstrap.libp2p.io` não resolvem.
//
// Precisa de: lições 08 (um nó) e 13-16 (o que ele faz online), mais uma
// rede que o deixe chegar à internet. O perfil `randomports` o mantém fora
// da porta 4001, que o IPFS Desktop (ou outro kubo) pode estar usando.
//
//   dart run example/pt_br/17_public_network.dart
//
// Próxima pergunta: "Buscar é puxar. Os peers podem empurrar mensagens uns
// para os outros na hora em que acontecem?" → lição 18.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

/// Um arquivo pequeno publicado pelo verificador de gateways públicos do
/// IPFS: qualquer um na rede pode buscá-lo.
const known = 'bafybeifx7yeb55armcsxwwitkymga5xf53dxiarykms3ygqic223w5sk3m';

/// O que o `ipfs daemon` faz com o Routing.Type da config
/// (cmd/ipfs/kubo/daemon.go).
KuboCoreNodeLibp2pRoutingOption routingFor(KuboConfig cfg) {
  final type = (cfg.json['Routing'] as Map?)?['Type'] as String? ?? '';
  return switch (type) {
    '' || 'auto' || 'default' => go.ipfs.kubo.core.node.libp2p.options
        .constructDefaultRouting(
            cfg, go.ipfs.kubo.core.node.libp2p.options.dhtOption),
    'autoclient' => go.ipfs.kubo.core.node.libp2p.options
        .constructDefaultRouting(
            cfg, go.ipfs.kubo.core.node.libp2p.options.dhtClientOption),
    'dht' => go.ipfs.kubo.core.node.libp2p.options.dhtOption,
    'dhtclient' => go.ipfs.kubo.core.node.libp2p.options.dhtClientOption,
    'dhtserver' => go.ipfs.kubo.core.node.libp2p.options.dhtServerOption,
    'none' => go.ipfs.kubo.core.node.libp2p.options.nilRouterOption,
    _ => throw ArgumentError('Routing.Type "$type" não tratado aqui'),
  };
}

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson17_');
  final ctx = go.context.background();
  try {
    // 1. Um repositório com a config normal (peers de bootstrap, roteamento
    //    "auto"), só com portas aleatórias.
    loadPlugins();
    final cfg = go.ipfs.kubo.config.initWithIdentity(go.ipfs.kubo.config
        .createIdentity(
            null, [go.ipfs.kubo.core.coreiface.options.key.type('ed25519')]));
    go.ipfs.kubo.config.profiles['randomports']!.transform(cfg);
    go.ipfs.kubo.repo.fsrepo.init('${tmp.path}/repo', cfg);
    final repo = go.ipfs.kubo.repo.fsrepo.open('${tmp.path}/repo');
    say('Routing.Type: "${(repo.config().json['Routing'] as Map)['Type']}", '
        '${(repo.config().json['Bootstrap'] as List).length} entradas de '
        'bootstrap');

    // 2. O nó online: host, bootstrap, roteamento, bitswap, tudo iniciado.
    //    Go:  core.NewNode(ctx, &node.BuildCfg{Repo: r, Online: true,
    //             Permanent: true, Routing: routingFor(cfg)})
    final n = await go.ipfs.kubo.core.newNode(
        ctx,
        KuboCoreNodeBuildCfg(
            repo: repo,
            online: true,
            permanent: true,
            routing: routingFor(repo.config())));
    final api = go.ipfs.kubo.core.coreapi.newCoreApi(n);
    try {
      say('online como ${(await api.key().self(ctx)).id}');
      // (Só os de loopback são mostrados: os outros são os IPs reais desta
      // máquina, que não devem ir para um log compartilhado.)
      final listening = await api.swarm().listenAddrs(ctx);
      say('  escutando em ${listening.length} endereços, por exemplo '
          '${listening.where((a) => '$a'.startsWith('/ip4/127.')).take(2).join(', ')}');

      // 3. Os peers vêm da lista de bootstrap, depois do DHT.
      var peers = 0;
      for (var i = 0; i < 30 && peers < 8; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        peers = (await api.swarm().peers(ctx)).length;
      }
      say('\nconectado a $peers peers');
      if (peers == 0) {
        say('nenhum peer: há conexão com a internet? (o resto precisa dela)');
        return;
      }

      // 4. Buscar algo que outra pessoa publicou: o roteamento acha os
      //    provedores, o bitswap traz os blocos, cada um conferido.
      final (fctx, cancel) =
          go.context.withTimeout(ctx, const Duration(seconds: 90));
      final watch = Stopwatch()..start();
      try {
        final f = await api.unixfs().get(fctx, BoxoPath('/ipfs/$known'));
        say('busquei /ipfs/$known em ${watch.elapsed.inSeconds} s: '
            '"${utf8.decode(go.io.readAll(go.ipfs.boxo.files.toFile(f))).trim()}"');
      } on GolangException catch (e) {
        say('não consegui buscar em 90 s: ${brief(e)}');
      } finally {
        cancel();
      }

      // 5. Publicar: add, e o nó o anuncia para a rede (aqui pedimos o
      //    anúncio agora em vez de esperar a fila).
      final p = await api.unixfs().add(
          ctx,
          go.ipfs.boxo.files
              .newBytesFile(utf8.encode('hello from a Dart app over p2p_ffi '
                  '${DateTime.now().toUtc()}\n')),
          [go.ipfs.kubo.core.coreiface.options.unixfs.pin(true, 'lesson-17')]);
      say('\nadicionei $p; anunciando...');
      final (pctx, pcancel) =
          go.context.withTimeout(ctx, const Duration(seconds: 60));
      try {
        await api.routing().provide(pctx, p);
        say('  anunciado: qualquer nó (ou https://ipfs.io/ipfs/...) pode '
            'buscá-lo enquanto este nó estiver online');
      } on GolangException catch (e) {
        say('  não anunciado a tempo: ${brief(e)} (o nó continua tentando)');
      } finally {
        pcancel();
      }

      say('\n== Erros comuns\n');
      // Um nó online sem roteamento e sem peers de bootstrap: online, mas
      // sozinho.
      final lonelyCfg = go.ipfs.kubo.config.initWithIdentity(go.ipfs.kubo.config
          .createIdentity(
              null, [go.ipfs.kubo.core.coreiface.options.key.type('ed25519')]));
      go.ipfs.kubo.config.profiles['test']!.transform(lonelyCfg);
      go.ipfs.kubo.repo.fsrepo.init('${tmp.path}/lonely', lonelyCfg);
      final lonely = await go.ipfs.kubo.core.newNode(
          ctx,
          KuboCoreNodeBuildCfg(
              repo: go.ipfs.kubo.repo.fsrepo.open('${tmp.path}/lonely'),
              online: true,
              routing: go.ipfs.kubo.core.node.libp2p.options.nilRouterOption));
      final lonelyApi = go.ipfs.kubo.core.coreapi.newCoreApi(lonely);
      await mistake('buscar com um nó online sem peers e sem roteamento',
          why: '"online" só quer dizer que o bitswap está ligado: sem ninguém '
              'conectado e sem roteador, não há a quem perguntar (o perfil '
              'test tira a lista de bootstrap)',
          instead: 'peers de bootstrap e um roteador (a config padrão), ou '
              'conectar-se a um peer que tenha o conteúdo', action: () async {
        final (tctx, cancel) =
            go.context.withTimeout(ctx, const Duration(seconds: 5));
        try {
          await lonelyApi.unixfs().get(tctx, BoxoPath('/ipfs/$known'));
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
