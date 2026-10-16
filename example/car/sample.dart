// Shared by the examples in example/car/ (index in DOCS.md at the repository
// root): starts the service, creates a temporary repo with an offline node,
// builds the sample folder, adds it to the node and exports its CAR. Also the
// helpers of the `_mistakes` files: `mustFail` (the error has to happen) and
// `silentlyWrong` (nothing fails, but the result is wrong).
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipfs_ffi.dart';
import 'package:ipfs_ffi/kubo.dart' as kubo;
import 'package:ipfs_ffi/multiformats.dart' as mf;

/// What the examples use: the context, an offline node with the sample
/// folder added, and the CARv1 of that folder.
final class Sample {
  Sample._(this.tmp, this.ctx);

  /// The example's temporary directory (deleted by [close]).
  final Directory tmp;
  final go.Context ctx;

  /// The offline node (`test` profile) and its CoreAPI.
  late final kubo.IpfsNode node;
  late final kubo.CoreApi api;

  /// The sample folder on disk: `hello.txt`, `data.bin` (600 000 bytes, 3
  /// distinct 256 KiB chunks) and `sub/note.md`.
  late final String folder;

  /// The bytes of `data.bin`.
  late final Uint8List data;

  /// The root of the folder in the node (CIDv1, 256 KiB chunks).
  late final mf.Cid root;

  /// The CARv1 of the whole folder (what `ipfs dag export` writes).
  late final String car;

  /// The sample's add options: CIDv1 (raw leaves) and 256 KiB chunks.
  static final addOptions = [
    kubo.unixfs.cidVersion(1),
    kubo.unixfs.chunker('size-262144'),
  ];

  /// Starts the service and builds everything.
  static Future<Sample> open() async {
    await IpfsService.start();
    kubo.PluginLoader('') // once per service
      ..initialize()
      ..inject();
    final s = Sample._(
        Directory.systemTemp.createTempSync('ipfs_car_'), go.background());
    s.node = await s.newNode('repo');
    s.api = kubo.newCoreApi(s.node);

    s.folder = s.path('folder');
    Directory('${s.folder}/sub').createSync(recursive: true);
    File('${s.folder}/hello.txt').writeAsStringSync('hello, CAR\n');
    final rnd = Random(42);
    s.data = Uint8List.fromList(List.generate(600000, (_) => rnd.nextInt(256)));
    File('${s.folder}/data.bin').writeAsBytesSync(s.data);
    File('${s.folder}/sub/note.md').writeAsStringSync('# note\n');

    final p = await s.api.unixfs().add(s.ctx,
        boxo.newSerialFile(s.folder, false, go.stat(s.folder)), addOptions);
    s.root = mf.Cid(p.value.substring('/ipfs/'.length));
    s.car = s.path('folder.car');
    await kubo.dagExportFile(s.node, s.ctx, p, s.car);
    return s;
  }

  /// An offline node in a new repo [name] inside the temporary directory
  /// (whoever opens it closes it).
  Future<kubo.IpfsNode> newNode(String name) async {
    final cfg = kubo.initWithIdentity(
        kubo.createIdentity(null, [kubo.key.type('ed25519')]));
    kubo.profiles['test']!.transform(cfg);
    kubo.init(path(name), cfg);
    return kubo.newNode(ctx, kubo.BuildCfg(repo: kubo.open(path(name))));
  }

  /// A path inside the temporary directory.
  String path(String name) => '${tmp.path}/$name';

  Future<void> close() async {
    await node.close();
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}

/// How many blocks the CAR [file] has. The `Reader` maps the file: always
/// close it (on Windows a mapped file cannot be overwritten).
int blockCount(String file) {
  final r = car.openReader(file);
  try {
    return r.inspect(false).blockCount;
  } finally {
    r.close();
  }
}

/// The CIDs of a CAR in bytes, in file order.
List<mf.Cid> cidsOf(Uint8List bytes) {
  final br = car.BlockReader(bytes);
  final out = <mf.Cid>[];
  while (true) {
    try {
      out.add(br.next().cid!);
    } on IpfsEof {
      return out;
    }
  }
}

/// A mistake that fails: runs [action], which has to fail, and prints what
/// was done, the error Go returned, why it is wrong and what to do instead.
/// If it does not fail, the example stops: the documented behavior changed.
Future<void> mustFail(String done,
    {required String why,
    required String instead,
    required FutureOr<void> Function() action}) async {
  try {
    await action();
  } on Object catch (e) {
    print('✗ $done\n'
        '    error:   ${e.runtimeType}: ${brief(e)}\n'
        '    why:     $why\n'
        '    instead: $instead\n');
    return;
  }
  throw StateError('expected an error and got none: "$done" '
      '(the documented behavior changed)');
}

/// A silent mistake: nothing fails, but the result is wrong. Prints the wrong
/// result next to the right one; if both are the same, the example stops.
Future<void> silentlyWrong(String done,
    {required String why,
    required String instead,
    required FutureOr<Object?> Function() wrong,
    required FutureOr<Object?> Function() right}) async {
  final w = '${await wrong()}', r = '${await right()}';
  if (w == r) {
    throw StateError('"$done" gave the same as the right way ($w): '
        'the documented behavior changed');
  }
  print('✗ $done (no error at all)\n'
      '    result:    $w\n'
      '    right way: $r\n'
      '    why:       $why\n'
      '    instead:   $instead\n');
}

/// The first line of [e]'s message, shortened.
String brief(Object e) {
  final m = (e is IpfsException ? e.message : '$e').split('\n').first;
  return m.length > 160 ? '${m.substring(0, 157)}...' : m;
}
