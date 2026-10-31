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

import 'package:p2p_ffi/p2p_ffi.dart';

/// El ejemplo de las lecciones 03 y 04, armado en memoria con la misma pila
/// (datastore → blockstore → exchange offline → blockservice → DAGService):
/// una carpeta con `data.bin` (600 000 bytes, 3 hojas de 256 KiB) y
/// `hello.txt`.
final class Sample {
  Sample._(this.store, this.dag, this.root, this.data);

  /// Dónde están los bloques.
  final BoxoBlockstore store;

  /// El DAGService sobre [store].
  final IpldFormatDagService dag;

  /// El CID de la carpeta.
  final Cid root;

  /// Los bytes de `data.bin`.
  final Uint8List data;

  static Future<Sample> build(Context ctx) async {
    final bs = BoxoBlockstore(
        go.ipfs.datastore.sync.mutexWrap(DatastoreMapDatastore()));
    final dag = go.ipfs.boxo.ipld.merkledag.newDagService(go
        .ipfs.boxo.blockservice
        .new$(bs, go.ipfs.boxo.exchange.offline.exchange(bs)));
    IpldFormatNode file(List<int> data) =>
        go.ipfs.boxo.ipld.unixfs.importer.buildDagFromReader(
            dag,
            go.ipfs.boxo.chunker.newSizeSplitter(
                BytesBuffer(Uint8List.fromList(data)), 256 * 1024));
    final rnd = Random(42);
    final data =
        Uint8List.fromList(List.generate(600000, (_) => rnd.nextInt(256)));
    final dir = BoxoIpldUnixfsIoDirectory(dag);
    await dir.addChild(ctx, 'data.bin', file(data));
    await dir.addChild(ctx, 'hello.txt', file(utf8.encode('hello\n')));
    final folder = dir.getNode();
    await dag.add(ctx, folder);
    return Sample._(bs, dag, folder.cid(), data);
  }

  /// Los bloques del DAG debajo de [c], el padre antes que los hijos
  /// (lección 05).
  Future<List<BlockFormatBlock>> blocksOf(Context ctx, Cid c) async => [
        await store.get(ctx, c),
        for (final l in await go.ipfs.ipldFormat.getLinks(ctx, dag, c))
          ...await blocksOf(ctx, l.cid!),
      ];

  /// Escribe el ejemplo entero como un CARv2 en [path] (lección 05).
  Future<void> writeCar(Context ctx, String path) async {
    final rw = go.ipld.car.v2.blockstore.openReadWrite(path, [root]);
    await rw.putMany(ctx, await blocksOf(ctx, root));
    rw.finalize();
  }
}

/// Los plugins de kubo (los datastores flatfs, leveldb, pebble...):
/// cargados una vez por proceso del servicio, antes de abrir cualquier
/// repositorio (lección 07).
void loadPlugins() {
  if (_pluginsFor == P2pService.hostPid) return;
  KuboPluginLoader('')
    ..initialize()
    ..inject();
  _pluginsFor = P2pService.hostPid;
}

int? _pluginsFor;

/// Las lecciones 07 y 08 en una sola llamada: los plugins, un repositorio
/// nuevo en [dir] con los [profiles] de kubo (`test`: puertos aleatorios,
/// sin peers de bootstrap, solo direcciones locales) y un nodo sobre él,
/// offline salvo que [online].
Future<KuboCoreIpfsNode> newNode(Context ctx, String dir,
    {bool online = false, List<String> profiles = const ['test']}) async {
  loadPlugins();
  final cfg = go.ipfs.kubo.config.initWithIdentity(go.ipfs.kubo.config
      .createIdentity(
          null, [go.ipfs.kubo.core.coreiface.options.key.type('ed25519')]));
  for (final p in profiles) {
    go.ipfs.kubo.config.profiles[p]!.transform(cfg);
  }
  go.ipfs.kubo.repo.fsrepo.init(dir, cfg);
  return openNode(ctx, dir, online: online);
}

/// Un nodo sobre el repositorio que ya existe en [dir] (tras reiniciar el
/// servicio, por ejemplo): los plugins, luego el nodo, offline salvo que
/// [online].
Future<KuboCoreIpfsNode> openNode(Context ctx, String dir,
    {bool online = false}) {
  loadPlugins();
  return go.ipfs.kubo.core.newNode(
      ctx,
      KuboCoreNodeBuildCfg(
          repo: go.ipfs.kubo.repo.fsrepo.open(dir), online: online));
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
