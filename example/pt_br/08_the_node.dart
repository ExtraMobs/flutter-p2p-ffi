// Lição 08 · O que o nó monta para mim?
//
// Pergunta: a lição 07 fez um repositório. O que é um "nó" em cima dele, e
// qual a relação com a pilha que montei à mão nas lições 03-06?
//
// Resposta: o nó (o IpfsNode do kubo) abre o repositório e monta a pilha
// inteira a partir dele, as mesmas camadas da lição 03, em disco:
//   blockstore → n.blockstore (com uma trava de GC, lição 09)
//   blockservice (blockstore + exchange) → n.blocks; o exchange aqui é
//     offline, e é o bitswap quando o nó está online (lições 16-17)
//   MFS, uma árvore de arquivos mutável sobre o DAG → n.filesRoot (lição 10)
//   e, só online, o host libp2p, o roteamento, o pubsub (parte C).
// A CoreAPI é a cara amigável de tudo isso: `unixfs().add/get/ls`, `pin()`,
// `block()`, `dag()`, `name()`, `key()`... as mesmas funções que a linha de
// comando `ipfs` chama por dentro.
//
// Precisa de: lição 07 (um repositório inicializado, os plugins).
// Tecnicamente, um nó offline só precisa do repositório; um online precisa
// também de um host libp2p, que precisa da identidade e dos endereços da
// config.
//
//   dart run example/pt_br/08_the_node.dart
//
// Próxima pergunta: "Adicionei um arquivo sem fixá-lo; ele vai ficar?" →
// lição 09.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/file.dart' as unixfs_file;
import 'package:p2p_ffi/go/boxo/path.dart' as path;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/io.dart' as io;
import 'package:p2p_ffi/go/kubo/config.dart' as config;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/go/multicodec.dart' as multicodec;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson08_');
  final ctx = context.background();
  try {
    // 1. Um repositório como na lição 07, e o nó sobre ele.
    //    Go:  n, _ := core.NewNode(ctx, &node.BuildCfg{Repo: r, Online: false})
    //         api, _ := coreapi.NewCoreAPI(n)
    loadPlugins();
    final cfg = config.initWithIdentity(
        config.createIdentity(null, [options.key.type('ed25519')]));
    config.profiles['test']!.transform(cfg);
    fsrepo.init('${tmp.path}/repo', cfg);
    final n = await core.newNode(ctx,
        node.BuildCfg(repo: fsrepo.open('${tmp.path}/repo'), online: false));
    final api = coreapi.newCoreApi(n);
    say('um nó offline em ${tmp.path}/repo');

    // 2. add: o importer da lição 03, com os padrões do kubo (CIDv0, pedaços
    //    de 256 KiB), no blockstore do nó. Os mesmos bytes dão o mesmo CID
    //    do exemplo montado à mão.
    //    Go:  p, _ := api.Unixfs().Add(ctx, files.NewBytesFile(data))
    final s = await Sample.build(ctx);
    final byHand = (await s.dag.get(ctx, s.root)).links().first.cid!;
    final p = await api.unixfs().add(ctx, files.newBytesFile(s.data));
    say('\nadd do data.bin pelo nó: $p');
    say('  o mesmo CID do data.bin da lição 03: ${p.value == '/ipfs/$byHand'}');

    // O CIDv1 muda os padrões: folhas raw, uma raiz `bafy...`.
    final v1 = await api
        .unixfs()
        .add(ctx, files.newBytesFile(s.data), [options.unixfs.cidVersion(1)]);
    final v1Root = cid.decode(v1.value.substring('/ipfs/'.length));
    final leaves = await api.unixfs().ls(ctx, v1).toList();
    say('com CIDv1: $v1');
    say('  folhas: ${leaves.map((e) => e.size).join(', ')} bytes, codec de '
        'uma folha 0x${leaves.first.cid!.type().toRadixString(16)} (raw: '
        '${leaves.first.cid!.type() == multicodec.raw}), codec da raiz 0x'
        '${v1Root.type().toRadixString(16)} (dag-pb)');

    // 3. get pela CoreAPI.
    //    Go:  nd, _ := api.Unixfs().Get(ctx, p); data, _ := io.ReadAll(files.ToFile(nd))
    final back = io.readAll(files.toFile(await api.unixfs().get(ctx, p)));
    say('\nget: ${back.length} bytes, iguais: ${sameBytes(back, s.data)}');

    // 4. As camadas do próprio nó são a pilha da lição 03: um DAGService
    //    sobre n.blocks lê o mesmo arquivo, sem a CoreAPI.
    //    Go:  dag := merkledag.NewDAGService(n.Blocks)
    final nodeDag = merkledag.newDagService(n.blocks);
    final f = await unixfs_file.newUnixfsFile(
        ctx, nodeDag, await nodeDag.get(ctx, byHand));
    say('lido por n.blocks + merkledag: '
        '${io.readAll(files.toFile(f)).length} bytes');
    say('  está no n.blockstore: ${await n.blockstore.has(ctx, byHand)}');

    // 5. Exportar e importar CAR com o nó (a lição 05 com o kubo fazendo o
    //    percurso): `ipfs dag export` e `ipfs dag import`.
    final out = '${tmp.path}/data.car';
    await dag.dagExportFile(n, ctx, p, out);
    final other = await newNode(ctx, '${tmp.path}/other');
    final imported = await dag.dagImportFiles(other, ctx, [out]);
    final otherApi = coreapi.newCoreApi(other);
    final copied =
        io.readAll(files.toFile(await otherApi.unixfs().get(ctx, p)));
    say('\nexportei $p para um CAR e importei num segundo nó: '
        '${imported.blockCount} blocos, o arquivo lê ${copied.length} bytes '
        'lá');
    await other.close();

    say('\n== Erros comuns\n');
    final never = path.Path(
        '/ipfs/${cid.newPrefixV1(multicodec.raw, multicodec.sha2256).sum(utf8.encode('never added'))}');
    await mistake('pedir, offline, um CID que o nó nunca teve',
        why: 'um nó offline tem o exchange offline da lição 04: ninguém a '
            'quem perguntar',
        instead: 'adicione ou importe antes, ou inicie o nó online (lição 17)',
        action: () async =>
            io.readAll(files.toFile(await api.unixfs().get(ctx, never))));
    await n.close();
    await mistake('usar a CoreAPI depois de fechar o nó dela',
        why: 'o close() fechou o blockstore, o repositório e tudo o que foi '
            'montado sobre eles',
        instead: 'feche o nó por último, quando nada mais o usa',
        action: () => api.unixfs().add(ctx, files.newBytesFile(s.data)));
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
