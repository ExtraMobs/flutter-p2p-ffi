// Lição 03 · Como um arquivo vira blocos?
//
// Pergunta: um CID dá nome a alguns bytes (lição 02), mas um bloco é pequeno
// (256 KiB por padrão, 1-2 MiB no máximo na rede). Como um arquivo de 600 KB,
// ou uma pasta inteira, ganha um CID só?
//
// Resposta: o arquivo é cortado em pedaços (chunks); cada pedaço é um bloco
// (uma folha) com o seu próprio CID; um nó pai lista os CIDs das folhas; o CID
// do pai dá nome ao arquivo inteiro. Uma pasta é mais um nó, que lista os CIDs
// dos seus arquivos por nome. Essa árvore de nós ligados por CID é um DAG (um
// Merkle DAG: mudar um byte muda a folha, o pai dela, e assim por diante até a
// raiz). O formato de arquivos e pastas é o UnixFS, escrito em nós dag-pb.
//
// Precisa de: lição 02 (CID). E, tecnicamente, esta pilha, de baixo para
// cima; cada camada precisa da que está abaixo dela:
//
//   datastore     chave → bytes. Aqui um mapa em memória; num nó (lição 07)
//                 flatfs, leveldb ou pebble em disco.
//   blockstore    CID → bloco, guardado no datastore.
//   exchange      onde buscar um bloco que o blockstore não tem. Aqui
//                 offline: em lugar nenhum. Num nó, o bitswap (lição 16).
//   blockservice  blockstore + exchange: "me dê este CID", daqui ou de fora.
//   DAGService    blockservice + codecs: blocos viram nós com links.
//   chunker       corta os bytes em pedaços.
//   importer      pedaços → folhas → pais, gravados no DAGService.
//
//   dart run example/pt_br/03_file_to_blocks.dart
//
// Próxima pergunta: "Como recupero o meu arquivo desses blocos, e se faltar
// um deles?" → lição 04.
import 'dart:math';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = go.context.background();

    // 1. A pilha, de baixo para cima.
    //    Go:  ds := sync.MutexWrap(datastore.NewMapDatastore())
    //         bs := blockstore.NewBlockstore(ds)
    //         bserv := blockservice.New(bs, offline.Exchange(bs))
    //         dag := merkledag.NewDAGService(bserv)
    final ds = go.ipfs.datastore.sync.mutexWrap(DatastoreMapDatastore());
    final bs = BoxoBlockstore(ds);
    final bserv = go.ipfs.boxo.blockservice
        .new$(bs, go.ipfs.boxo.exchange.offline.exchange(bs));
    final dag = go.ipfs.boxo.ipld.merkledag.newDagService(bserv);
    Future<int> blocksStored() => bs.allKeysChan(ctx).length;

    // 2. Um arquivo de 600 000 bytes, cortado em pedaços de 256 KiB.
    //    Go:  nd, _ := importer.BuildDagFromReader(dag,
    //             chunker.NewSizeSplitter(bytes.NewBuffer(data), chunker.DefaultBlockSize))
    final chunk = go.ipfs.boxo.chunker
        .defaultBlockSize; // o tamanho de pedaço padrão do `ipfs add`
    IpldFormatNode importBytes(Uint8List data, [int? size]) =>
        go.ipfs.boxo.ipld.unixfs.importer.buildDagFromReader(
            dag,
            go.ipfs.boxo.chunker
                .newSizeSplitter(BytesBuffer(data), size ?? chunk));
    final rnd = Random(42);
    final data =
        Uint8List.fromList(List.generate(600000, (_) => rnd.nextInt(256)));
    final file = importBytes(data);
    say('um arquivo de ${data.length} bytes → raiz ${file.cid()}');
    for (final l in file.links()) {
      say('  folha ${l.cid}  ${l.size} bytes');
    }
    say('  ${file.links().length} folhas + 1 raiz = '
        '${await blocksStored()} blocos no blockstore');
    // 262 158 = 262 144 bytes de dados + 14 de envelope UnixFS: estes
    // padrões (CIDv0, `Qm...`) embrulham cada folha num nó dag-pb. Com CIDv1
    // (`ipfs add --cid-version=1`, lição 08) as folhas são raw, 262 144 exatos.
    say('  (uma folha cheia tem 262 158 bytes: 262 144 de dados + o envelope '
        'dag-pb do CIDv0)');

    // 3. Mesmo pedaço, mesmo bloco: um arquivo feito dos mesmos 256 KiB três
    //    vezes tem três links para UMA folha, guardada uma vez só
    //    (deduplicação de graça).
    final repeated = Uint8List(3 * chunk)
      ..setAll(0, data.sublist(0, chunk))
      ..setAll(chunk, data.sublist(0, chunk))
      ..setAll(2 * chunk, data.sublist(0, chunk));
    final before = await blocksStored();
    final rep = importBytes(repeated);
    say('\n3 × o primeiro pedaço → raiz ${rep.cid()}');
    say('  links: ${rep.links().map((l) => l.cid).toSet().length} '
        'distinto(s) de ${rep.links().length}; blocos novos guardados: '
        '${await blocksStored() - before} (a raiz; a folha já estava lá, é a '
        'primeira folha do arquivo acima)');

    // 4. O CID depende de como o arquivo foi cortado: os mesmos bytes com
    //    outro tamanho de pedaço são outro DAG, com outra raiz.
    final before128 = await blocksStored();
    final other = importBytes(data, 128 * 1024);
    say('\no mesmo arquivo em 128 KiB → raiz ${other.cid()} '
        '(${other.links().length} folhas)');
    say('  mesmos bytes, mesma raiz? ${other.cid() == file.cid()}');
    // A última folha são os mesmos 75 712 bytes da última folha de 256 KiB
    // (600 000 = 2 × 256 KiB + 75 712 = 4 × 128 KiB + 75 712).
    final shared = other.links().last.cid == file.links().last.cid;
    say('  blocos novos guardados: ${await blocksStored() - before128} '
        '(5 folhas + raiz, mas a última folha é compartilhada: $shared)');

    // 5. Uma pasta: mais um nó, que liga às suas entradas por nome.
    //    Go:  dir, _ := uio.NewDirectory(dag)
    //         dir.AddChild(ctx, "data.bin", file); dir.AddChild(...)
    //         nd, _ := dir.GetNode(); dag.Add(ctx, nd)
    final dir = BoxoIpldUnixfsIoDirectory(dag);
    await dir.addChild(ctx, 'data.bin', file);
    await dir.addChild(ctx, 'repeated.bin', rep);
    final folder = dir.getNode();
    await dag.add(ctx, folder);
    say('\numa pasta → raiz ${folder.cid()}');
    for (final l in folder.links()) {
      say('  ${l.name.padRight(12)} ${l.cid}  ${l.size} bytes (com a sua '
          'árvore)');
    }
    say('  blocos no blockstore agora: ${await blocksStored()}');
    say('\no CID da pasta dá nome a tudo abaixo dela: mude um byte de '
        'data.bin e a folha, data.bin e a pasta ganham CIDs novos.');
  } finally {
    await P2pService.stop();
  }
}
