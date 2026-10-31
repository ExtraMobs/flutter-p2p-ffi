// Lição 04 · Como leio de volta? E se faltar um bloco?
//
// Pergunta: a lição 03 transformou uma pasta em blocos sob um CID. Como
// recupero os bytes de um arquivo, como `<cid-da-pasta>/data.bin` encontra o
// arquivo, e o que acontece quando um dos blocos não está aqui?
//
// Resposta: ler é percorrer o DAG a partir da raiz: pegar o nó raiz, seguir os
// links, pegar cada filho, até as folhas; o arquivo são as folhas em ordem. Um
// nome dentro de uma pasta é só um link com esse nome. Todo "get" vai para o
// blockservice: ele procura no blockstore e, se o bloco não estiver lá,
// pergunta ao exchange. Com o exchange offline não há a quem perguntar, então
// um bloco faltando é um erro; só os blocos do caminho que você lê são
// necessários, o resto do DAG pode estar ausente.
//
// Precisa de: lição 03 (a mesma pilha: datastore → blockstore → exchange
// offline → blockservice → DAGService, e o importer para montar o exemplo).
// Para ler um arquivo, o leitor UnixFS também precisa do DAGService, para
// buscar os filhos.
//
//   dart run example/pt_br/04_blocks_to_file.dart
//
// Próxima pergunta: "Posso levar esses blocos para outra máquina sem rede?"
// → lição 05 (arquivos CAR). E "a quem o exchange perguntaria?" → lição 16.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = go.context.background();

    // A pilha e o exemplo da lição 03: uma pasta com data.bin (600 000
    // bytes, 3 folhas) e hello.txt (um bloco).
    final ds = go.ipfs.datastore.sync.mutexWrap(DatastoreMapDatastore());
    final bs = BoxoBlockstore(ds);
    final dag = go.ipfs.boxo.ipld.merkledag.newDagService(go
        .ipfs.boxo.blockservice
        .new$(bs, go.ipfs.boxo.exchange.offline.exchange(bs)));
    IpldFormatNode importBytes(List<int> data) =>
        go.ipfs.boxo.ipld.unixfs.importer.buildDagFromReader(
            dag,
            go.ipfs.boxo.chunker.newSizeSplitter(
                BytesBuffer(Uint8List.fromList(data)),
                go.ipfs.boxo.chunker.defaultBlockSize));
    final rnd = Random(42);
    final data =
        Uint8List.fromList(List.generate(600000, (_) => rnd.nextInt(256)));
    final dir = BoxoIpldUnixfsIoDirectory(dag);
    await dir.addChild(ctx, 'data.bin', importBytes(data));
    await dir.addChild(ctx, 'hello.txt', importBytes(utf8.encode('hello\n')));
    final folderNode = dir.getNode();
    await dag.add(ctx, folderNode);
    final root = folderNode.cid();
    say('a pasta: $root');

    // 1. Um nome dentro de uma pasta é um link: pegue o nó da pasta, ache o
    //    link pelo nome, pegue o nó para onde ele aponta. É o que faz
    //    resolver o caminho /ipfs/<raiz>/data.bin.
    //    Go:  nd, _ := dag.Get(ctx, root)
    //         lnk, _, _ := nd.ResolveLink([]string{"data.bin"})
    Future<IpldFormatNode> resolve(String name) async {
      final folder = await dag.get(ctx, root);
      final link = folder.links().firstWhere((l) => l.name == name);
      return dag.get(ctx, link.cid!);
    }

    // 2. Ler um arquivo: o leitor UnixFS percorre a árvore dele e junta as
    //    folhas, pegando cada bloco pelo DAGService à medida que avança.
    //    Go:  f, _ := unixfile.NewUnixfsFile(ctx, dag, nd)
    //         data, _ := io.ReadAll(files.ToFile(f))
    Future<Uint8List> read(String name) async {
      final f = await go.ipfs.boxo.ipld.unixfs.file
          .newUnixfsFile(ctx, dag, await resolve(name));
      return go.io.readAll(go.ipfs.boxo.files.toFile(f));
    }

    final back = await read('data.bin');
    say('\nli data.bin: ${back.length} bytes, iguais aos gravados: '
        '${_same(back, data)}');
    say('li hello.txt: "${utf8.decode(await read('hello.txt')).trim()}"');

    // 3. Os blocos de que uma leitura precisa: o caminho da raiz às folhas.
    Future<void> walk(Cid c, String name, String indent) async {
      say('$indent$c  ${await bs.getSize(ctx, c)} bytes  $name');
      for (final l in await go.ipfs.ipldFormat.getLinks(ctx, dag, c)) {
        await walk(l.cid!, l.name.isEmpty ? '(folha)' : l.name, '$indent  ');
      }
    }

    say('\no DAG inteiro, bloco a bloco:');
    await walk(root, '(pasta)', '  ');

    // 4. Tire uma folha de data.bin, como se ela nunca tivesse chegado.
    final dataNode = await resolve('data.bin');
    final leaf = dataNode.links()[1].cid!;
    final saved = await bs.get(ctx, leaf);
    await bs.deleteBlock(ctx, leaf);
    say('\napaguei a 2ª folha de data.bin: $leaf');
    say('  hello.txt ainda se lê (outro galho): '
        '"${utf8.decode(await read('hello.txt')).trim()}"');
    await mistake('ler data.bin com uma folha faltando',
        why: 'o blockstore não tem o bloco e o exchange offline não tem a '
            'quem perguntar',
        instead: 'traga o bloco (um CAR, lição 05) ou use um exchange que '
            'busca de outros peers (bitswap, lição 16)',
        action: () => read('data.bin'));

    // 5. Devolva o bloco (aqui, a cópia guardada acima): volta a ler.
    //    O bloco pode vir de qualquer lugar; o CID prova que é o certo.
    final again = leaf.prefix().sum(saved.rawData!).equals(leaf);
    await bs.put(ctx, saved);
    say('devolvi a folha (os bytes batem com o CID: $again): '
        'data.bin lê ${(await read('data.bin')).length} bytes');

    say('\n== Erros comuns\n');
    final never = go.ipfs.cid
        .newPrefixV1(go.multiformats.multicodec.enums.raw,
            go.multiformats.multihash.consts.sha2256)
        .sum(utf8.encode('never stored'));
    await mistake('pegar um CID que nunca foi guardado',
        why: 'offline, "não está aqui" é definitivo: não há mais a quem '
            'perguntar',
        instead: 'confira bs.has(ctx, c) antes, ou fique online (lição 16)',
        action: () => dag.get(ctx, never));
  } finally {
    await P2pService.stop();
  }
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
