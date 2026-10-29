// Shared by the lessons (the roadmap is in example/en_us/README.md): the sample DAG
// of lessons 03-06, the helpers that run a common mistake on purpose and show
// what really happens, and say(), which writes the lesson's output.
library;

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

/// The sample of lessons 03 and 04, built in memory with the same stack
/// (datastore → blockstore → offline exchange → blockservice → DAGService):
/// a folder with `data.bin` (600 000 bytes, 3 leaves of 256 KiB) and
/// `hello.txt`.
final class Sample {
  Sample._(this.store, this.dag, this.root, this.data);

  /// Where the blocks are.
  final BoxoBlockstore store;

  /// The DAGService over [store].
  final IpldFormatDagService dag;

  /// The folder's CID.
  final Cid root;

  /// The bytes of `data.bin`.
  final Uint8List data;

  static Future<Sample> build(Context ctx) async {
    final bs =
        BoxoBlockstore(Go.datastore.sync.mutexWrap(DatastoreMapDatastore()));
    final dag = Go.boxo.ipld.merkledag.newDagService(
        Go.boxo.blockservice.new$(bs, Go.boxo.exchange.offline.exchange(bs)));
    IpldFormatNode file(List<int> data) =>
        Go.boxo.ipld.unixfs.importer.buildDagFromReader(
            dag,
            Go.boxo.chunker.newSizeSplitter(
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

  /// The blocks of the DAG under [c], parent before children (lesson 05).
  Future<List<BlockFormatBlock>> blocksOf(Context ctx, Cid c) async => [
        await store.get(ctx, c),
        for (final l in await Go.ipldFormat.getLinks(ctx, dag, c))
          ...await blocksOf(ctx, l.cid!),
      ];

  /// Writes the whole sample as a CARv2 at [path] (lesson 05).
  Future<void> writeCar(Context ctx, String path) async {
    final rw = Go.car.v2.blockstore.openReadWrite(path, [root]);
    await rw.putMany(ctx, await blocksOf(ctx, root));
    rw.finalize();
  }
}

/// Kubo's plugins (the datastores flatfs, leveldb, pebble...): loaded once
/// per service process, before any repo is opened (lesson 07).
void loadPlugins() {
  if (_pluginsFor == P2pService.hostPid) return;
  KuboPluginLoader('')
    ..initialize()
    ..inject();
  _pluginsFor = P2pService.hostPid;
}

int? _pluginsFor;

/// Lessons 07 and 08 in one call: the plugins, a new repo in [dir] with
/// kubo's [profiles] (`test`: random ports, no bootstrap peers, local
/// addresses only) and a node on it, offline unless [online].
Future<KuboCoreIpfsNode> newNode(Context ctx, String dir,
    {bool online = false, List<String> profiles = const ['test']}) async {
  loadPlugins();
  final cfg = Go.kubo.config.initWithIdentity(Go.kubo.config.createIdentity(
      null, [Go.kubo.core.coreiface.options.key.type('ed25519')]));
  for (final p in profiles) {
    Go.kubo.config.profiles[p]!.transform(cfg);
  }
  Go.kubo.repo.fsrepo.init(dir, cfg);
  return openNode(ctx, dir, online: online);
}

/// A node on the repo already in [dir] (after a restart of the service, for
/// one): the plugins, then the node, offline unless [online].
Future<KuboCoreIpfsNode> openNode(Context ctx, String dir,
    {bool online = false}) {
  loadPlugins();
  return Go.kubo.core.newNode(
      ctx,
      KuboCoreNodeBuildCfg(
          repo: Go.kubo.repo.fsrepo.open(dir), online: online));
}

/// Whether [a] and [b] hold the same bytes.
bool sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// A common mistake: runs [action], which has to fail, and prints what was
/// done, the error, why and what to do instead. If it does not fail, the
/// lesson stops: the behavior it teaches changed.
Future<void> mistake(String done,
    {required String why,
    required String instead,
    required FutureOr<void> Function() action}) async {
  try {
    await action();
  } on Object catch (e) {
    say('✗ $done\n'
        '    error:   ${e.runtimeType}: ${brief(e)}\n'
        '    why:     $why\n'
        '    instead: $instead\n');
    return;
  }
  throw StateError('expected an error and got none: "$done" '
      '(the behavior this lesson teaches changed)');
}

/// A silent mistake: nothing fails, but the result is wrong. Prints the wrong
/// result next to the right one; if both are the same, the lesson stops.
Future<void> silentlyWrong(String done,
    {required String why,
    required String instead,
    required FutureOr<Object?> Function() wrong,
    required FutureOr<Object?> Function() right}) async {
  final w = '${await wrong()}', r = '${await right()}';
  if (w == r) {
    throw StateError('"$done" gave the same as the right way ($w): '
        'the behavior this lesson teaches changed');
  }
  say('✗ $done (no error at all)\n'
      '    result:    $w\n'
      '    right way: $r\n'
      '    why:       $why\n'
      '    instead:   $instead\n');
}

/// The first line of [e]'s message, shortened.
String brief(Object e) {
  final m = (e is GolangException ? e.message : '$e').split('\n').first;
  return m.length > 160 ? '${m.substring(0, 157)}...' : m;
}

/// Bytes as hex (`1220ab...`), for showing hashes and CIDs.
String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Writes a line of the lesson: to `dart:developer`'s log, named after the
/// lesson file (filterable in DevTools and in the IDE's debug console), and
/// to the terminal, where `dart run` does not show that log.
void say(Object? message) {
  dev.log('$message', name: Platform.script.pathSegments.last);
  print(message);
}
