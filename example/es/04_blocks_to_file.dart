// Lección 04 · ¿Cómo lo leo de vuelta? ¿Y si falta un bloque?
//
// Pregunta: la lección 03 convirtió una carpeta en bloques bajo un CID. ¿Cómo
// recupero los bytes de un archivo, cómo encuentra `<cid-de-la-carpeta>/data.bin`
// el archivo, y qué pasa cuando uno de los bloques no está aquí?
//
// Respuesta: leer es recorrer el DAG desde la raíz: obtener el nodo raíz,
// seguir sus enlaces, obtener cada hijo, hasta las hojas; el archivo son las
// hojas en orden. Un nombre dentro de una carpeta es solo un enlace con ese
// nombre. Cada "get" va al blockservice: busca en el blockstore y, si el
// bloque no está, le pregunta al exchange. Con el exchange offline no hay a
// quién preguntar, así que un bloque que falta es un error; solo hacen falta
// los bloques del camino que lees, el resto del DAG puede no estar.
//
// Necesita: la lección 03 (la misma pila: datastore → blockstore → exchange
// offline → blockservice → DAGService, y el importer para armar el ejemplo).
// Para leer un archivo, el lector UnixFS también necesita el DAGService, para
// traer los hijos.
//
//   dart run example/es/04_blocks_to_file.dart
//
// Siguiente pregunta: "¿Puedo llevar esos bloques a otra máquina sin red?"
// → lección 05 (archivos CAR). Y "¿a quién le preguntaría el exchange?" →
// lección 16.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:p2p_ffi/go/boxo/blockservice.dart' as blockservice;
import 'package:p2p_ffi/go/boxo/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/boxo/chunker.dart' as chunker;
import 'package:p2p_ffi/go/boxo/exchange/offline.dart' as offline;
import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/file.dart' as unixfs_file;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/importer.dart' as importer;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/io.dart' as unixfs_io;
import 'package:p2p_ffi/go/bytes.dart' as bytes;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/datastore.dart' as datastore;
import 'package:p2p_ffi/go/datastore/sync.dart' as sync;
import 'package:p2p_ffi/go/io.dart' as io;
import 'package:p2p_ffi/go/ipld_format.dart' as ipld_format;
import 'package:p2p_ffi/go/multicodec.dart' as multicodec;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = context.background();

    // La pila y el ejemplo de la lección 03: una carpeta con data.bin
    // (600 000 bytes, 3 hojas) y hello.txt (un bloque).
    final ds = sync.mutexWrap(datastore.MapDatastore());
    final bs = blockstore.Blockstore(ds);
    final dag =
        merkledag.newDagService(blockservice.new$(bs, offline.exchange(bs)));
    ipld_format.Node importBytes(List<int> data) => importer.buildDagFromReader(
        dag,
        chunker.newSizeSplitter(
            bytes.Buffer(Uint8List.fromList(data)), 256 * 1024));
    final rnd = Random(42);
    final data =
        Uint8List.fromList(List.generate(600000, (_) => rnd.nextInt(256)));
    final dir = unixfs_io.Directory(dag);
    await dir.addChild(ctx, 'data.bin', importBytes(data));
    await dir.addChild(ctx, 'hello.txt', importBytes(utf8.encode('hello\n')));
    final folderNode = dir.getNode();
    await dag.add(ctx, folderNode);
    final root = folderNode.cid();
    say('la carpeta: $root');

    // 1. Un nombre dentro de una carpeta es un enlace: obtén el nodo de la
    //    carpeta, busca el enlace por nombre, obtén el nodo al que apunta. Es
    //    lo que hace resolver la ruta /ipfs/<raíz>/data.bin.
    //    Go:  nd, _ := dag.Get(ctx, root)
    //         lnk, _, _ := nd.ResolveLink([]string{"data.bin"})
    Future<ipld_format.Node> resolve(String name) async {
      final folder = await dag.get(ctx, root);
      final link = folder.links().firstWhere((l) => l.name == name);
      return dag.get(ctx, link.cid!);
    }

    // 2. Leer un archivo: el lector UnixFS recorre su árbol y une las hojas,
    //    obteniendo cada bloque por el DAGService a medida que avanza.
    //    Go:  f, _ := unixfile.NewUnixfsFile(ctx, dag, nd)
    //         data, _ := io.ReadAll(files.ToFile(f))
    Future<Uint8List> read(String name) async {
      final f = await unixfs_file.newUnixfsFile(ctx, dag, await resolve(name));
      return io.readAll(files.toFile(f));
    }

    final back = await read('data.bin');
    say('\nleí data.bin: ${back.length} bytes, iguales a los escritos: '
        '${_same(back, data)}');
    say('leí hello.txt: "${utf8.decode(await read('hello.txt')).trim()}"');

    // 3. Los bloques que necesita una lectura: el camino de la raíz a las
    //    hojas.
    Future<void> walk(cid.Cid c, String name, String indent) async {
      say('$indent$c  ${await bs.getSize(ctx, c)} bytes  $name');
      for (final l in await ipld_format.getLinks(ctx, dag, c)) {
        await walk(l.cid!, l.name.isEmpty ? '(hoja)' : l.name, '$indent  ');
      }
    }

    say('\nel DAG entero, bloque por bloque:');
    await walk(root, '(carpeta)', '  ');

    // 4. Quita una hoja de data.bin, como si nunca hubiera llegado.
    final dataNode = await resolve('data.bin');
    final leaf = dataNode.links()[1].cid!;
    final saved = await bs.get(ctx, leaf);
    await bs.deleteBlock(ctx, leaf);
    say('\nborré la 2ª hoja de data.bin: $leaf');
    say('  hello.txt se sigue leyendo (otra rama): '
        '"${utf8.decode(await read('hello.txt')).trim()}"');
    await mistake('leer data.bin con una hoja faltante',
        why: 'el blockstore no tiene el bloque y el exchange offline no tiene '
            'a quién preguntar',
        instead: 'trae el bloque (un CAR, lección 05) o usa un exchange que lo '
            'pida a otros peers (bitswap, lección 16)',
        action: () => read('data.bin'));

    // 5. Devuelve el bloque (aquí, la copia guardada arriba): se vuelve a
    //    leer. El bloque puede venir de cualquier sitio; su CID prueba que es
    //    el correcto.
    final again = leaf.prefix().sum(saved.rawData!).equals(leaf);
    await bs.put(ctx, saved);
    say('devolví la hoja (sus bytes coinciden con su CID: $again): '
        'data.bin lee ${(await read('data.bin')).length} bytes');

    say('\n== Errores comunes\n');
    final never = cid
        .newPrefixV1(multicodec.raw, multicodec.sha2256)
        .sum(utf8.encode('never stored'));
    await mistake('obtener un CID que nunca se guardó',
        why: 'offline, "no está aquí" es definitivo: no hay nadie más a quien '
            'preguntar',
        instead: 'comprueba bs.has(ctx, c) antes, o conéctate (lección 16)',
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
