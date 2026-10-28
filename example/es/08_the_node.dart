// Lección 08 · ¿Qué arma el nodo por mí?
//
// Pregunta: la lección 07 hizo un repositorio. ¿Qué es un "nodo" encima de
// él, y qué relación tiene con la pila que armé a mano en las lecciones
// 03-06?
//
// Respuesta: el nodo (el IpfsNode de kubo) abre el repositorio y arma toda la
// pila a partir de él, las mismas capas de la lección 03, en disco:
//   blockstore → n.blockstore (con un bloqueo de GC, lección 09)
//   blockservice (blockstore + exchange) → n.blocks; aquí el exchange es
//     offline, y es bitswap cuando el nodo está online (lecciones 16-17)
//   MFS, un árbol de archivos mutable sobre el DAG → n.filesRoot (lección 10)
//   y, solo online, el host libp2p, el enrutamiento, el pubsub (parte C).
// La CoreAPI es la cara amable de todo eso: `unixfs().add/get/ls`, `pin()`,
// `block()`, `dag()`, `name()`, `key()`... las mismas funciones que la línea
// de comandos `ipfs` llama por dentro.
//
// Necesita: la lección 07 (un repositorio inicializado, los plugins).
// Técnicamente, un nodo offline solo necesita el repositorio; uno online
// necesita además un host libp2p, que necesita la identidad y las
// direcciones de la config.
//
//   dart run example/es/08_the_node.dart
//
// Siguiente pregunta: "Añadí un archivo sin fijarlo; ¿se va a quedar?" →
// lección 09.
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
import 'package:p2p_ffi/go/multihash.dart' as multihash;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson08_');
  final ctx = context.background();
  try {
    // 1. Un repositorio como en la lección 07, y el nodo sobre él.
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
    say('un nodo offline en ${tmp.path}/repo');

    // 2. add: el importer de la lección 03, con los valores por defecto de
    //    kubo (CIDv0, trozos de 256 KiB), en el blockstore del nodo. Los
    //    mismos bytes dan el mismo CID que el ejemplo armado a mano.
    //    Go:  p, _ := api.Unixfs().Add(ctx, files.NewBytesFile(data))
    final s = await Sample.build(ctx);
    final byHand = (await s.dag.get(ctx, s.root)).links().first.cid!;
    final p = await api.unixfs().add(ctx, files.newBytesFile(s.data));
    say('\nadd de data.bin por el nodo: $p');
    say('  el mismo CID que data.bin en la lección 03: '
        '${p.value == '/ipfs/$byHand'}');

    // CIDv1 cambia los valores por defecto: hojas raw, una raíz `bafy...`.
    final v1 = await api
        .unixfs()
        .add(ctx, files.newBytesFile(s.data), [options.unixfs.cidVersion(1)]);
    final v1Root = cid.decode(v1.value.substring('/ipfs/'.length));
    final leaves = await api.unixfs().ls(ctx, v1).toList();
    say('con CIDv1: $v1');
    say('  hojas: ${leaves.map((e) => e.size).join(', ')} bytes, codec de '
        'una hoja 0x${leaves.first.cid!.type().toRadixString(16)} (raw: '
        '${leaves.first.cid!.type() == multicodec.raw}), codec de la raíz 0x'
        '${v1Root.type().toRadixString(16)} (dag-pb)');

    // 3. get por la CoreAPI.
    //    Go:  nd, _ := api.Unixfs().Get(ctx, p); data, _ := io.ReadAll(files.ToFile(nd))
    final back = io.readAll(files.toFile(await api.unixfs().get(ctx, p)));
    say('\nget: ${back.length} bytes, iguales: ${sameBytes(back, s.data)}');

    // 4. Las capas del propio nodo son la pila de la lección 03: un
    //    DAGService sobre n.blocks lee el mismo archivo, sin la CoreAPI.
    //    Go:  dag := merkledag.NewDAGService(n.Blocks)
    final nodeDag = merkledag.newDagService(n.blocks);
    final f = await unixfs_file.newUnixfsFile(
        ctx, nodeDag, await nodeDag.get(ctx, byHand));
    say('leído por n.blocks + merkledag: '
        '${io.readAll(files.toFile(f)).length} bytes');
    say('  está en n.blockstore: ${await n.blockstore.has(ctx, byHand)}');

    // 5. Exportar e importar un CAR con el nodo (la lección 05 con kubo
    //    haciendo el recorrido): `ipfs dag export` e `ipfs dag import`.
    final out = '${tmp.path}/data.car';
    await dag.dagExportFile(n, ctx, p, out);
    final other = await newNode(ctx, '${tmp.path}/other');
    final imported = await dag.dagImportFiles(other, ctx, [out]);
    final otherApi = coreapi.newCoreApi(other);
    final copied =
        io.readAll(files.toFile(await otherApi.unixfs().get(ctx, p)));
    say('\nexporté $p a un CAR y lo importé en un segundo nodo: '
        '${imported.blockCount} bloques, el archivo lee ${copied.length} '
        'bytes allí');
    await other.close();

    say('\n== Errores comunes\n');
    final never = path.Path(
        '/ipfs/${cid.newPrefixV1(multicodec.raw, multihash.sha2256).sum(utf8.encode('never added'))}');
    await mistake('pedir, offline, un CID que el nodo nunca tuvo',
        why: 'un nodo offline tiene el exchange offline de la lección 04: '
            'nadie a quien preguntar',
        instead: 'añádelo o impórtalo antes, o arranca el nodo online '
            '(lección 17)',
        action: () async =>
            io.readAll(files.toFile(await api.unixfs().get(ctx, never))));
    await n.close();
    await mistake('usar la CoreAPI después de cerrar su nodo',
        why: 'close() cerró el blockstore, el repositorio y todo lo armado '
            'sobre ellos',
        instead: 'cierra el nodo al final, cuando ya nada lo use',
        action: () => api.unixfs().add(ctx, files.newBytesFile(s.data)));
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
