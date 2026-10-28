// Lição 15 · Como acho quem tem um conteúdo?
//
// Pergunta: na lição 14 dei a um host o endereço do outro na mão. Numa rede
// de milhares de peers, como acho o endereço de um peer a partir do ID dele,
// ou quais peers têm um CID?
//
// Resposta: um DHT (Kademlia, o protocolo `kad-dht`): uma tabela espalhada
// por todos os peers. Cada peer guarda uma tabela de roteamento com alguns
// outros, ordenados pela distância XOR entre os IDs; uma busca pergunta aos
// mais próximos que conhece, que respondem com outros mais próximos, até
// chegar aos peers mais próximos da chave. O que fica guardado lá:
//   - registros de provedor: "o peer P tem o CID X" (Provide, depois
//     FindProviders); eles expiram, então os provedores os reanunciam (o
//     kubo a cada 22 h);
//   - endereços de peers: FindPeer(ID) devolve onde discar;
//   - valores pequenos e assinados, como os registros IPNS (lição 11).
// O DHT público do IPFS usa o prefixo `/ipfs`; esta lição monta um privado
// (com prefixo próprio) no loopback, então ele nunca se mistura com a rede
// pública. Um ponto de encontro (rendezvous) é o mesmo truque para um nome:
// o hash do nome de uma sala vira um CID, que se anuncia e se procura.
//
// Precisa de: lição 14 (hosts que se conectam). Tecnicamente, um DHT precisa
// de um host e de pelo menos um peer por onde começar (um peer de
// bootstrap); em modo servidor ele também atende os outros (o kubo passa ao
// modo cliente atrás de um NAT, lição 17).
//
//   dart run example/pt_br/15_find_on_the_dht.dart
//
// Próxima pergunta: "Achei quem tem o CID. O que traz de fato os blocos até
// mim?" → lição 16.
import 'dart:convert';

import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/libp2p.dart' as libp2p;
import 'package:p2p_ffi/go/libp2p/core/host.dart' as host;
import 'package:p2p_ffi/go/libp2p/p2p/discovery/routing.dart' as discovery;
import 'package:p2p_ffi/go/libp2p_kad_dht.dart' as dht;
import 'package:p2p_ffi/go/multicodec.dart' as multicodec;
import 'package:p2p_ffi/go/multihash.dart' as multihash;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

const prefix = '/p2p-ffi-lesson'; // um DHT privado: não o /ipfs

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = context.background();

    // 1. Cinco hosts, cada um com um DHT em modo servidor. Só o primeiro é
    //    conhecido pelos outros: é o peer de bootstrap deles.
    //    Go:  d, _ := dht.New(ctx, h, dht.Mode(dht.ModeServer), dht.ProtocolPrefix(prefix))
    final hosts = [
      for (var i = 0; i < 5; i++)
        await libp2p.new$([
          libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]),
    ];
    final opts = [dht.mode(dht.modeServer), dht.protocolPrefix(prefix)];
    final dhts = [for (final h in hosts) dht.new$(h, opts)];
    for (final h in hosts.skip(1)) {
      await h.connect(ctx, host.infoFromHost(hosts[0]));
    }
    //    Bootstrap: cada um pede à rede os peers mais próximos de si,
    //    enchendo a tabela de roteamento além do peer de bootstrap.
    for (final d in dhts) {
      await d.bootstrap(ctx);
    }
    for (var i = 0;
        i < 100 && dhts.any((d) => d.routingTable().size() < 4);
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    say('tabelas de roteamento: '
        '${dhts.map((d) => d.routingTable().size()).join(', ')} peers');

    // 2. FindPeer: o host 4 pede o endereço do host 3 só pelo ID.
    //    Go:  pi, _ := d.FindPeer(ctx, id)
    final target = hosts[3].id();
    final found = await () async {
      for (var i = 1;; i++) {
        try {
          return await dhts[4].findPeer(ctx, target);
        } on GolangException {
          // Num DHT tão pequeno uma busca pode falhar enquanto as tabelas enchem:
          // tente de novo.
          if (i == 5) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
      }
    }();
    say('\no host 4 procurou ${target.shortString()}: ${found.addrs}');

    // 3. Provide e FindProviders: o host 1 diz que tem um CID; o host 4
    //    descobre quem o tem.
    //    Go:  d.Provide(ctx, c, true); provs, _ := d.FindProviders(ctx, c)
    final content = cid
        .newPrefixV1(multicodec.raw, multihash.sha2256)
        .sum(utf8.encode('something host 1 has'));
    await dhts[1].provide(ctx, content, true);
    final providers = await dhts[4].findProviders(ctx, content);
    say('\no host 1 anunciou $content');
    say('o host 4 achou os provedores: '
        '${providers.map((p) => p.id!.shortString()).join(', ')} '
        '(o host 1 é ${hosts[1].id().shortString()})');

    // 4. Ponto de encontro por nome: o host 2 anuncia uma sala, o host 4
    //    descobre quem está nela.
    //    Go:  rd := routing.NewRoutingDiscovery(d); rd.Advertise(ctx, "room")
    //         for pi := range rd.FindPeers(ctx, "room") {...}
    final ttl =
        await discovery.RoutingDiscovery(dhts[2]).advertise(ctx, 'room');
    say('\no host 2 anunciou "room" (válido por ${ttl.inHours} h)');
    await for (final pi
        in discovery.RoutingDiscovery(dhts[4]).findPeers(ctx, 'room')) {
      say('o host 4 achou em "room": ${pi.id!.shortString()}');
    }

    say('\n== Erros comuns\n');
    final lonely = await libp2p.new$([
      libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
    ]);
    final lonelyDht = dht.new$(lonely, opts);
    await mistake('anunciar num DHT que não conhece nenhum peer',
        why: 'a tabela de roteamento dele está vazia: não há em quem guardar '
            'o registro',
        instead: 'conecte-se antes a um peer de bootstrap (no kubo: a lista '
            'Bootstrap da config)',
        action: () => lonelyDht.provide(ctx, content, true));
    final other = await libp2p.new$([
      libp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
    ]);
    final otherDht =
        dht.new$(other, [dht.mode(dht.modeServer), dht.protocolPrefix('/x')]);
    await other.connect(ctx, host.infoFromHost(hosts[0]));
    await silentlyWrong('entrar com outro prefixo de protocolo',
        why: 'outro prefixo é outro DHT: os peers estão conectados mas nunca '
            'entram nas tabelas uns dos outros',
        instead: 'o mesmo prefixo em todos os peers (/ipfs para a rede IPFS '
            'pública)',
        wrong: () async {
          await otherDht.bootstrap(ctx);
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return '${otherDht.routingTable().size()} peers na tabela';
        },
        right: () => '${dhts[0].routingTable().size()} peers na tabela');

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
