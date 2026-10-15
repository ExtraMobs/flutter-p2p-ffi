// Passo 7: arquivos CAR (`ipfs dag export` / `ipfs dag import`): levar um DAG
// inteiro (arquivo, pasta, objeto IPLD) de um repo para outro num arquivo só.
// Rode o 01_init_repo.dart antes (para os dois repos).
//
//   dart run example/07_car.dart export [repo] <cid-ou-pasta> <saida.car>
//   dart run example/07_car.dart import [repo] <arquivo.car>...
import 'dart:io';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/boxo/path.dart' as path;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/os.dart' as os;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/commands/dag.dart' as dag;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;

Future<void> main(List<String> args) async {
  if (args.length < 3 || !{'export', 'import'}.contains(args[0])) {
    stderr.writeln(
        'uso: export <repo> <cid-ou-pasta> <saida.car> | import <repo> <arquivo.car>...');
    exit(64);
  }
  // O kubo roda no ipfs_host, noutro processo (dart run tool/build.dart).
  await IpfsService.start();
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final ctx = context.background();
  final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(args[1])));
  try {
    if (args[0] == 'export') {
      // um CID (/ipfs/... ou só o CID) ou uma pasta/arquivo local, adicionado antes
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
            'raiz ${root.cid}: ${root.pinErrorMsg.isEmpty ? 'pinada' : root.pinErrorMsg}');
      }
      print('${r.blockCount} blocos, ${r.blockBytesCount} B importados');
    }
  } finally {
    await n.close();
  }
  await IpfsService.stop();
}
