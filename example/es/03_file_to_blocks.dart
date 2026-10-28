// Lección 03 · ¿Cómo se convierte un archivo en bloques?
//
// Pregunta: un CID nombra unos bytes (lección 02), pero un bloque es pequeño
// (256 KiB por defecto, 1-2 MiB como máximo en la red). ¿Cómo obtiene un solo
// CID un archivo de 600 KB, o una carpeta entera?
//
// Respuesta: el archivo se corta en trozos (chunks); cada trozo es un bloque
// (una hoja) con su propio CID; un nodo padre lista los CIDs de las hojas; el
// CID del padre nombra el archivo entero. Una carpeta es un nodo más, que
// lista los CIDs de sus archivos por nombre. Ese árbol de nodos enlazados por
// CID es un DAG (un Merkle DAG: cambiar un byte cambia la hoja, su padre, y
// así hasta la raíz). El formato de archivos y carpetas es UnixFS, escrito en
// nodos dag-pb.
//
// Necesita: la lección 02 (CID). Y, técnicamente, esta pila, de abajo hacia
// arriba; cada capa necesita la que está debajo:
//
//   datastore     clave → bytes. Aquí un mapa en memoria; en un nodo
//                 (lección 07) flatfs, leveldb o pebble en disco.
//   blockstore    CID → bloque, guardado en el datastore.
//   exchange      dónde conseguir un bloque que el blockstore no tiene. Aquí
//                 offline: en ningún sitio. En un nodo, bitswap (lección 16).
//   blockservice  blockstore + exchange: "dame este CID", de aquí o de fuera.
//   DAGService    blockservice + codecs: los bloques pasan a ser nodos con
//                 enlaces.
//   chunker       corta los bytes en trozos.
//   importer      trozos → hojas → padres, escritos en el DAGService.
//
//   dart run example/es/03_file_to_blocks.dart
//
// Siguiente pregunta: "¿Cómo recupero mi archivo de esos bloques, y qué pasa
// si falta uno?" → lección 04.
import 'dart:math';
import 'dart:typed_data';

import 'package:p2p_ffi/go/boxo/blockservice.dart' as blockservice;
import 'package:p2p_ffi/go/boxo/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/boxo/chunker.dart' as chunker;
import 'package:p2p_ffi/go/boxo/exchange/offline.dart' as offline;
import 'package:p2p_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/importer.dart' as importer;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/io.dart' as unixfs_io;
import 'package:p2p_ffi/go/bytes.dart' as bytes;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/datastore.dart' as datastore;
import 'package:p2p_ffi/go/datastore/sync.dart' as sync;
import 'package:p2p_ffi/go/ipld_format.dart' as ipld_format;
import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  try {
    final ctx = context.background();

    // 1. La pila, de abajo hacia arriba.
    //    Go:  ds := sync.MutexWrap(datastore.NewMapDatastore())
    //         bs := blockstore.NewBlockstore(ds)
    //         bserv := blockservice.New(bs, offline.Exchange(bs))
    //         dag := merkledag.NewDAGService(bserv)
    final ds = sync.mutexWrap(datastore.MapDatastore());
    final bs = blockstore.Blockstore(ds);
    final bserv = blockservice.new$(bs, offline.exchange(bs));
    final dag = merkledag.newDagService(bserv);
    Future<int> blocksStored() => bs.allKeysChan(ctx).length;

    // 2. Un archivo de 600 000 bytes, cortado en trozos de 256 KiB.
    //    Go:  nd, _ := importer.BuildDagFromReader(dag,
    //             chunker.NewSizeSplitter(bytes.NewBuffer(data), chunker.DefaultBlockSize))
    final chunk = chunker
        .defaultBlockSize; // el tamaño de trozo por defecto de `ipfs add`
    ipld_format.Node importBytes(Uint8List data, [int? size]) =>
        importer.buildDagFromReader(
            dag, chunker.newSizeSplitter(bytes.Buffer(data), size ?? chunk));
    final rnd = Random(42);
    final data =
        Uint8List.fromList(List.generate(600000, (_) => rnd.nextInt(256)));
    final file = importBytes(data);
    say('un archivo de ${data.length} bytes → raíz ${file.cid()}');
    for (final l in file.links()) {
      say('  hoja ${l.cid}  ${l.size} bytes');
    }
    say('  ${file.links().length} hojas + 1 raíz = '
        '${await blocksStored()} bloques en el blockstore');
    // 262 158 = 262 144 bytes de datos + 14 de envoltorio UnixFS: estos
    // valores por defecto (CIDv0, `Qm...`) envuelven cada hoja en un nodo
    // dag-pb. Con CIDv1 (`ipfs add --cid-version=1`, lección 08) las hojas son
    // raw, 262 144 exactos.
    say('  (una hoja llena tiene 262 158 bytes: 262 144 de datos + el '
        'envoltorio dag-pb del CIDv0)');

    // 3. Mismo trozo, mismo bloque: un archivo hecho de los mismos 256 KiB
    //    tres veces tiene tres enlaces a UNA hoja, guardada una sola vez
    //    (deduplicación gratis).
    final repeated = Uint8List(3 * chunk)
      ..setAll(0, data.sublist(0, chunk))
      ..setAll(chunk, data.sublist(0, chunk))
      ..setAll(2 * chunk, data.sublist(0, chunk));
    final before = await blocksStored();
    final rep = importBytes(repeated);
    say('\n3 × el primer trozo → raíz ${rep.cid()}');
    say('  enlaces: ${rep.links().map((l) => l.cid).toSet().length} '
        'distinto(s) de ${rep.links().length}; bloques nuevos guardados: '
        '${await blocksStored() - before} (la raíz; la hoja ya estaba, es la '
        'primera hoja del archivo de arriba)');

    // 4. El CID depende de cómo se cortó el archivo: los mismos bytes con
    //    otro tamaño de trozo son otro DAG, con otra raíz.
    final before128 = await blocksStored();
    final other = importBytes(data, 128 * 1024);
    say('\nel mismo archivo a 128 KiB → raíz ${other.cid()} '
        '(${other.links().length} hojas)');
    say('  mismos bytes, ¿misma raíz? ${other.cid() == file.cid()}');
    // Su última hoja son los mismos 75 712 bytes que la última hoja de
    // 256 KiB (600 000 = 2 × 256 KiB + 75 712 = 4 × 128 KiB + 75 712).
    final shared = other.links().last.cid == file.links().last.cid;
    say('  bloques nuevos guardados: ${await blocksStored() - before128} '
        '(5 hojas + raíz, pero la última hoja es compartida: $shared)');

    // 5. Una carpeta: un nodo más, que enlaza sus entradas por nombre.
    //    Go:  dir, _ := uio.NewDirectory(dag)
    //         dir.AddChild(ctx, "data.bin", file); dir.AddChild(...)
    //         nd, _ := dir.GetNode(); dag.Add(ctx, nd)
    final dir = unixfs_io.Directory(dag);
    await dir.addChild(ctx, 'data.bin', file);
    await dir.addChild(ctx, 'repeated.bin', rep);
    final folder = dir.getNode();
    await dag.add(ctx, folder);
    say('\nuna carpeta → raíz ${folder.cid()}');
    for (final l in folder.links()) {
      say('  ${l.name.padRight(12)} ${l.cid}  ${l.size} bytes (con su '
          'árbol)');
    }
    say('  bloques en el blockstore ahora: ${await blocksStored()}');
    say('\nel CID de la carpeta nombra todo lo que hay debajo: cambia un byte '
        'de data.bin y la hoja, data.bin y la carpeta reciben CIDs nuevos.');
  } finally {
    await P2pService.stop();
  }
}
