// Compartido por las lecciones (la hoja de ruta está en example/es/README.md):
// el DAG de ejemplo de las lecciones 03-06, los auxiliares que ejecutan un
// error común a propósito y muestran lo que pasa de verdad, y say(), que
// escribe la salida de la lección.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:p2p_ffi/go/block_format.dart' as blocks;
import 'package:p2p_ffi/go/boxo/blockservice.dart' as blockservice;
import 'package:p2p_ffi/go/boxo/blockstore.dart' as blockstore;
import 'package:p2p_ffi/go/boxo/chunker.dart' as chunker;
import 'package:p2p_ffi/go/boxo/exchange/offline.dart' as offline;
import 'package:p2p_ffi/go/boxo/ipld/merkledag.dart' as merkledag;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/importer.dart' as importer;
import 'package:p2p_ffi/go/boxo/ipld/unixfs/io.dart' as unixfs_io;
import 'package:p2p_ffi/go/bytes.dart' as bytes;
import 'package:p2p_ffi/go/car/v2/blockstore.dart' as car_blockstore;
import 'package:p2p_ffi/go/cid.dart' as cid;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/datastore.dart' as datastore;
import 'package:p2p_ffi/go/datastore/sync.dart' as sync;
import 'package:p2p_ffi/go/ipld_format.dart' as ipld_format;
import 'package:p2p_ffi/p2p_ffi.dart';

/// El ejemplo de las lecciones 03 y 04, armado en memoria con la misma pila
/// (datastore → blockstore → exchange offline → blockservice → DAGService):
/// una carpeta con `data.bin` (600 000 bytes, 3 hojas de 256 KiB) y
/// `hello.txt`.
final class Sample {
  Sample._(this.store, this.dag, this.root, this.data);

  /// Dónde están los bloques.
  final blockstore.Blockstore store;

  /// El DAGService sobre [store].
  final ipld_format.DagService dag;

  /// El CID de la carpeta.
  final cid.Cid root;

  /// Los bytes de `data.bin`.
  final Uint8List data;

  static Future<Sample> build(context.Context ctx) async {
    final bs = blockstore.Blockstore(sync.mutexWrap(datastore.MapDatastore()));
    final dag =
        merkledag.newDagService(blockservice.new$(bs, offline.exchange(bs)));
    ipld_format.Node file(List<int> data) => importer.buildDagFromReader(
        dag,
        chunker.newSizeSplitter(
            bytes.Buffer(Uint8List.fromList(data)), 256 * 1024));
    final rnd = Random(42);
    final data =
        Uint8List.fromList(List.generate(600000, (_) => rnd.nextInt(256)));
    final dir = unixfs_io.Directory(dag);
    await dir.addChild(ctx, 'data.bin', file(data));
    await dir.addChild(ctx, 'hello.txt', file(utf8.encode('hello\n')));
    final folder = dir.getNode();
    await dag.add(ctx, folder);
    return Sample._(bs, dag, folder.cid(), data);
  }

  /// Los bloques del DAG debajo de [c], el padre antes que los hijos
  /// (lección 05).
  Future<List<blocks.Block>> blocksOf(context.Context ctx, cid.Cid c) async => [
        await store.get(ctx, c),
        for (final l in await ipld_format.getLinks(ctx, dag, c))
          ...await blocksOf(ctx, l.cid!),
      ];

  /// Escribe el ejemplo entero como un CARv2 en [path] (lección 05).
  Future<void> writeCar(context.Context ctx, String path) async {
    final rw = car_blockstore.openReadWrite(path, [root]);
    await rw.putMany(ctx, await blocksOf(ctx, root));
    rw.finalize();
  }
}

/// Un error común: ejecuta [action], que tiene que fallar, y muestra qué se
/// hizo, el error, el porqué y qué hacer en su lugar. Si no falla, la lección
/// se detiene: el comportamiento que enseña cambió.
Future<void> mistake(String done,
    {required String why,
    required String instead,
    required FutureOr<void> Function() action}) async {
  try {
    await action();
  } on Object catch (e) {
    say('✗ $done\n'
        '    error:        ${e.runtimeType}: ${brief(e)}\n'
        '    por qué:      $why\n'
        '    en su lugar:  $instead\n');
    return;
  }
  throw StateError('se esperaba un error y no hubo ninguno: "$done" '
      '(el comportamiento que enseña esta lección cambió)');
}

/// Un error silencioso: nada falla, pero el resultado está mal. Muestra el
/// resultado incorrecto junto al correcto; si los dos son iguales, la lección
/// se detiene.
Future<void> silentlyWrong(String done,
    {required String why,
    required String instead,
    required FutureOr<Object?> Function() wrong,
    required FutureOr<Object?> Function() right}) async {
  final w = '${await wrong()}', r = '${await right()}';
  if (w == r) {
    throw StateError('"$done" dio lo mismo que la forma correcta ($w): '
        'el comportamiento que enseña esta lección cambió');
  }
  say('✗ $done (sin ningún error)\n'
      '    resultado:    $w\n'
      '    lo correcto:  $r\n'
      '    por qué:      $why\n'
      '    en su lugar:  $instead\n');
}

/// La primera línea del mensaje de [e], acortada.
String brief(Object e) {
  final m = (e is GolangException ? e.message : '$e').split('\n').first;
  return m.length > 160 ? '${m.substring(0, 157)}...' : m;
}

/// Bytes en hexadecimal (`1220ab...`), para mostrar hashes y CIDs.
String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Escribe una línea de la lección: en el log de `dart:developer`, con el
/// nombre del archivo de la lección (filtrable en DevTools y en la consola de
/// depuración del IDE), y en la terminal, donde `dart run` no muestra ese log.
void say(Object? message) {
  dev.log('$message', name: Platform.script.pathSegments.last);
  print(message);
}
