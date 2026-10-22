// Step 7: CAR files (`ipfs dag export` / `ipfs dag import`): carrying a whole
// DAG (file, directory, IPLD object) from one repo to another in a single file.
// Run 01_init_repo.dart first (for both repos).
//
//   dart run example/07_car.dart export [repo] <cid-or-path> <out.car>
//   dart run example/07_car.dart import [repo] <file.car>...
import 'dart:io';

import 'package:p2p_ffi/go/boxo/files.dart' as files;
import 'package:p2p_ffi/go/boxo/path.dart' as path;
import 'package:p2p_ffi/go/context.dart' as context;
import 'package:p2p_ffi/go/os.dart' as os;
import 'package:p2p_ffi/go/kubo/core.dart' as core;
import 'package:p2p_ffi/go/kubo/core/commands/dag.dart' as dag;
import 'package:p2p_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:p2p_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:p2p_ffi/go/kubo/core/node.dart' as node;
import 'package:p2p_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:p2p_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:p2p_ffi/p2p_ffi.dart' show P2pService;

Future<void> main(List<String> args) async {
  if (args.length < 3 || !{'export', 'import'}.contains(args[0])) {
    stderr.writeln(
        'usage: export <repo> <cid-or-path> <out.car> | import <repo> <file.car>...');
    exit(64);
  }
  // Kubo runs in the p2p_host, in another process (dart run tool/build.dart).
  await P2pService.start();
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final ctx = context.background();
  final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(args[1])));
  try {
    if (args[0] == 'export') {
      // a CID (/ipfs/... or just the CID) or a local directory/file, added first
      var p = args[2].startsWith('/ipfs/') ||
              !FileSystemEntity.isDirectorySync(args[2]) &&
                  !FileSystemEntity.isFileSync(args[2])
          ? path.Path(args[2].startsWith('/') ? args[2] : '/ipfs/${args[2]}')
          : null;
      if (p == null) {
        final api = coreapi.newCoreApi(n);
        p = await api.unixfs().add(
            ctx,
            files.newSerialFile(args[2], false, os.stat(args[2])),
            [options.unixfs.pin(true, '')]);
        print('add ${args[2]}: $p');
      }
      await dag.dagExportFile(n, ctx, p, args[3]);
      print('export $p → ${args[3]} (${File(args[3]).lengthSync()} B)');
    } else {
      final r = await dag.dagImportFiles(n, ctx, args.sublist(2));
      for (final root in r.roots) {
        print(
            'root ${root.cid}: ${root.pinErrorMsg.isEmpty ? 'pinned' : root.pinErrorMsg}');
      }
      print('${r.blockCount} blocks, ${r.blockBytesCount} B imported');
    }
  } finally {
    await n.close();
  }
  await P2pService.stop();
}
