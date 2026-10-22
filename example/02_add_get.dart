// Kubo step 2: opens the repo, starts the node (offline) and uses the CoreAPI
// to add and read files, without HTTP. Run 01_init_repo.dart first.
//
//   dart run example/02_add_get.dart [repo] [file-or-directory]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/io.dart' as io;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface.dart' as iface;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/go/os.dart' as os;
import 'package:p2p_ffi/p2p_ffi.dart' show P2pService;

Future<void> main(List<String> args) async {
  final repoPath = args.isNotEmpty ? args.first : '.ipfs-ffi';

  // Kubo runs in the p2p_host, in another process (dart run tool/build.dart).
  await P2pService.start();
  final plugins = loader.PluginLoader('');
  plugins.initialize();
  plugins.inject();

  final ctx = context.background();
  final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repoPath)));
  try {
    final api = coreapi.newCoreApi(n);

    // bytes → CID (kubo splits them into blocks and builds the DAG; the CoreAPI
    // does not pin by default: see example 03)
    final p = await api.unixfs().add(
        ctx, files.newBytesFile(utf8.encode('hello from Dart over FFI\n')));
    print('add: $p');
    final file = files.toFile(await api.unixfs().get(ctx, p));
    print('get: ${utf8.decode(io.readAll(file)).trim()}');

    // a file or directory on disk, with kubo's progress (like `ipfs add`)
    if (args.length > 1) {
      final src = args[1];
      final total = FileSystemEntity.isFileSync(src)
          ? File(src).lengthSync()
          : Directory(src)
              .listSync(recursive: true)
              .whereType<File>()
              .fold<int>(0, (s, f) => s + f.lengthSync());
      final events = StreamController<iface.AddEvent>();
      final perFile = <String, int>{}; // `bytes` is the progress of each file
      events.stream.listen((e) {
        if (e.path == null) {
          perFile[e.name] = e.bytes;
          final done = perFile.values.fold<int>(0, (s, b) => s + b);
          stdout.write(
              '\r  ${(100 * done / (total == 0 ? 1 : total)).clamp(0, 100).toStringAsFixed(0)}%');
        } else {
          stdout.write('\r  ${e.name.isEmpty ? src : e.name} → ${e.path}\n');
        }
      });
      final root = await api.unixfs().add(
          ctx,
          files.newSerialFile(src, false, os.stat(src)),
          [options.unixfs.events(events.sink), options.unixfs.progress(true)]);
      print('add $src: $root');
      await for (final e in api.unixfs().ls(ctx, root)) {
        print('  ${e.name}  ${e.size} B  ${e.cid}');
      }
    }
  } finally {
    await n.close();
  }
  await P2pService.stop();
}
