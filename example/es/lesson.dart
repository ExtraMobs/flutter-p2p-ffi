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
import 'package:p2p_ffi/go/kubo/config.dart' as config;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
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

/// Los plugins de kubo (los datastores flatfs, leveldb, pebble...):
/// cargados una vez por proceso del servicio, antes de abrir cualquier
/// repositorio (lección 07).
void loadPlugins() {
  if (_pluginsFor == P2pService.hostPid) return;
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  _pluginsFor = P2pService.hostPid;
}

int? _pluginsFor;

/// Las lecciones 07 y 08 en una sola llamada: los plugins, un repositorio
/// nuevo en [dir] con los [profiles] de kubo (`test`: puertos aleatorios,
/// sin peers de bootstrap, solo direcciones locales) y un nodo sobre él,
/// offline salvo que [online].
Future<core.IpfsNode> newNode(context.Context ctx, String dir,
    {bool online = false, List<String> profiles = const ['test']}) async {
  loadPlugins();
  final cfg = config.initWithIdentity(
      config.createIdentity(null, [options.key.type('ed25519')]));
  for (final p in profiles) {
    config.profiles[p]!.transform(cfg);
  }
  fsrepo.init(dir, cfg);
  return openNode(ctx, dir, online: online);
}

/// Un nodo sobre el repositorio que ya existe en [dir] (tras reiniciar el
/// servicio, por ejemplo): los plugins, luego el nodo, offline salvo que
/// [online].
Future<core.IpfsNode> openNode(context.Context ctx, String dir,
    {bool online = false}) {
  loadPlugins();
  return core.newNode(
      ctx, node.BuildCfg(repo: fsrepo.open(dir), online: online));
}

/// Si [a] y [b] tienen los mismos bytes.
bool sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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
