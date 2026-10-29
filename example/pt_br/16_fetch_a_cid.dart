// Lição 16 · O que o boxo precisa para baixar um CID?
//
// Pergunta: na lição 04 um bloco faltando era um erro: "o exchange offline
// não tem a quem perguntar". O que precisa estar no lugar para um CID vir de
// outra máquina?
//
// Resposta: trocar o exchange offline pelo bitswap, o exchange de blocos do
// boxo. Buscar um arquivo vira então esta corrente, cada elo precisando do
// anterior:
//   1. o DAGService pede ao blockservice o CID raiz;
//   2. o blockservice procura no blockstore local; não achando, pergunta ao
//      exchange (o bitswap);
//   3. o bitswap manda um "want" do CID para cada peer a que está conectado,
//      pela rede dele: um host libp2p falando /ipfs/bitswap;
//   4. se nenhum peer conectado tem, depois de uma pequena espera ele
//      pergunta ao seu localizador de provedores (o DHT da lição 15, ou um
//      roteador delegado) quem tem o CID, conecta-se a eles e o pede a eles;
//   5. um peer que tem o bloco (com o seu próprio bitswap, sobre o seu
//      próprio blockstore) o manda; o bitswap calcula o hash e o confere com
//      o CID (lição 02) antes de guardar: quem manda nunca é confiável;
//   6. o bloco é guardado, os links da raiz dão os próximos CIDs, e a
//      corrente se repete para os filhos (muitos de uma vez).
// Então, tecnicamente: um host (para conversar), um localizador de
// provedores (para achar), um blockstore (para guardar), bitswap dos DOIS
// lados, e alguém que tenha os blocos e esteja conectado ou os tenha
// anunciado (Provide). Um nó kubo online (lição 17) monta exatamente isto
// como n.exchange.
//
// Precisa de: lições 03-04 (a pilha), 13-15 (hosts, conexões, DHT).
//
//   dart run example/pt_br/16_fetch_a_cid.dart
//
// Próxima pergunta: "E para buscar da rede IPFS de verdade, não dos meus
// próprios hosts?" → lição 17.
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = goContext.background();

    // O mundo: a tem o exemplo da lição 03 no seu blockstore; b e c começam
    // vazios. Cada um tem um host e um DHT; b e c conhecem d, o bootstrap.
    // a fica fora da rede até o passo 3.
    final s = await Sample.build(ctx);
    final root = s.root;
    Future<Libp2pCoreHost> newHost() => goLibp2p.new$([
          goLibp2p.listenAddrStrings(['/ip4/127.0.0.1/tcp/0'])
        ]);
    final [a, b, c, d] = [for (var i = 0; i < 4; i++) await newHost()];
    final opts = [
      goLibp2pKadDht.mode(goLibp2pKadDht.modeServer),
      goLibp2pKadDht.protocolPrefix('/lesson16')
    ];
    final [dhtA, dhtB, dhtC, dhtD] = [
      for (final h in [a, b, c, d]) goLibp2pKadDht.new$(h, opts)
    ];
    for (final h in [b, c]) {
      await h.connect(ctx, goLibp2p.core.host.infoFromHost(d));
    }
    for (final x in [dhtB, dhtC, dhtD]) {
      await x.bootstrap(ctx);
    }
    say('a tem a pasta de exemplo ${root.toString().substring(0, 12)}…; b e c '
        'não têm nada');

    // Bitswap num host: a rede dele (o host falando /ipfs/bitswap), um
    // localizador de provedores (o DHT) e o blockstore que ele serve e enche.
    //    Go:  bs := bitswap.New(ctx, bsnet.NewFromIpfsHost(h), finder, bstore)
    Future<BoxoBitswap> bitswapOn(Libp2pCoreHost h, Libp2pKadDhtIpfsDht finder,
            BoxoBlockstore store) =>
        goBoxo.bitswap.new$(ctx,
            goBoxo.bitswap.network.bsnet.newFromIpfsHost(h), finder, store);
    BoxoBlockstore emptyStore() =>
        BoxoBlockstore(goDatastore.sync.mutexWrap(DatastoreMapDatastore()));
    final bsA = await bitswapOn(a, dhtA, s.store); // a serve os seus blocos

    // Lê o data.bin de um blockservice sobre [store] e [ex], com prazo: o
    // leitor da lição 04, sem mudança.
    Future<int> readWith(BoxoBlockstore store, BoxoExchangeInterface ex,
        {Duration within = const Duration(seconds: 20)}) async {
      final (tctx, cancel) = goContext.withTimeout(ctx, within);
      try {
        final dag = goBoxo.ipld.merkledag
            .newDagService(goBoxo.blockservice.new$(store, ex));
        final folder = await dag.get(tctx, root);
        final dataBin = await dag.get(tctx, folder.links().first.cid!);
        final f =
            await goBoxo.ipld.unixfs.file.newUnixfsFile(tctx, dag, dataBin);
        return goIo.readAll(goBoxo.files.toFile(f)).length;
      } finally {
        cancel();
      }
    }

    // 1. b com o exchange offline: a lição 04 de novo.
    final storeB = emptyStore();
    await mistake('b buscando com o exchange offline',
        why: 'o blockstore não tem e o offline não tem a quem perguntar',
        instead: 'um exchange que pergunta aos peers: o bitswap (abaixo)',
        action: () =>
            readWith(storeB, goBoxo.exchange.offline.exchange(storeB)));

    // 2. b com bitswap, mas a nunca anunciou o CID e b não está conectado
    //    a a: os wants não vão para ninguém útil, o DHT não tem registro.
    final bsB = await bitswapOn(b, dhtB, storeB);
    await mistake('b buscando antes de alguém anunciar o CID',
        why: 'o bitswap pergunta aos peers conectados (nenhum tem) e ao DHT '
            '(nenhum registro de provedor): espera até o prazo',
        instead: 'quem tem anuncia (Provide), ou você se conecta a ele',
        action: () =>
            readWith(storeB, bsB, within: const Duration(seconds: 3)));

    // 3. a entra no DHT e anuncia a raiz; b busca de novo: o bitswap acha a
    //    pelo DHT, conecta, pede, recebe, confere.
    //    Go:  dhtA.Provide(ctx, root, true)
    await a.connect(ctx, goLibp2p.core.host.infoFromHost(d));
    await dhtA.bootstrap(ctx);
    await dhtA.provide(ctx, root, true);
    final watch = Stopwatch()..start();
    final viaDht = await readWith(storeB, bsB);
    say('\nb, depois de a anunciar a raiz: leu o data.bin, $viaDht bytes, em '
        '${watch.elapsedMilliseconds} ms (achou a pelo DHT; b agora conectado '
        'a a: ${b.network().connectedness(a.id()) == 1})');

    // 4. c se conecta direto a a: os wants vão direto para a, sem busca.
    final storeC = emptyStore();
    final bsC = await bitswapOn(c, dhtC, storeC);
    await c.connect(ctx, goLibp2p.core.host.infoFromHost(a));
    watch.reset();
    final direct = await readWith(storeC, bsC);
    say('c, conectado a a: $direct bytes em ${watch.elapsedMilliseconds} ms '
        '(sem busca no DHT)');

    // 5. O que o bitswap contou. Agora b tem os blocos: ele também os serve,
    //    como todo nó IPFS que buscou alguma coisa.
    final stA = bsA.stat(), stB = bsB.stat();
    say('\nestatísticas do bitswap: a mandou ${stA.blocksSent} blocos; b '
        'recebeu ${stB.blocksReceived} (${stB.dataReceived} bytes), b tem a '
        'raiz agora: ${await storeB.has(ctx, root)}');

    say('\n== Erros comuns\n');
    // e guarda os mesmos blocos de a (o blockstore de a) mas não roda
    // bitswap; f se conecta só a e e pede a raiz.
    final e = await newHost(), f = await newHost();
    final dhtF = goLibp2pKadDht.new$(f, opts);
    final storeF = emptyStore();
    final bsF = await bitswapOn(f, dhtF, storeF);
    await f.connect(ctx, goLibp2p.core.host.infoFromHost(e));
    await mistake('buscar de um peer que tem os blocos mas não tem bitswap',
        why: 'e nunca ouve os wants: ter os blocos não basta, algo tem de '
            'servi-los por /ipfs/bitswap',
        instead: 'bitswap dos dois lados: quem busca pede, quem tem serve (um '
            'nó kubo online faz os dois)',
        action: () =>
            readWith(storeF, bsF, within: const Duration(seconds: 3)));

    for (final x in [bsA, bsB, bsC, bsF]) {
      x.close();
    }
    for (final x in [dhtA, dhtB, dhtC, dhtD, dhtF]) {
      await x.close();
    }
    for (final h in [a, b, c, d, e, f]) {
      await h.close();
    }
  } finally {
    await P2pService.stop();
  }
}
