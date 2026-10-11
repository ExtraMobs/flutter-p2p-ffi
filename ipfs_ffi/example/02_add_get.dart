// Passo 2 do kubo: abre o repo, sobe o nó (offline) e usa a CoreAPI para
// adicionar e ler arquivos, sem HTTP. Rode o 01_init_repo.dart antes.
//
//   dart run example/02_add_get.dart [repo] [arquivo-ou-pasta]
import 'dart:convert';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/io.dart' as io;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/os.dart' as os;

Future<void> main(List<String> args) async {
  final repoPath = args.isNotEmpty ? args.first : '.ipfs-ffi';

  final plugins = loader.PluginLoader('');
  plugins.initialize();
  plugins.inject();

  final ctx = context.background();
  final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repoPath)));
  try {
    final api = coreapi.newCoreApi(n);

    // bytes → CID (o kubo quebra em blocos e monta o DAG; a CoreAPI não pina
    // por padrão: ver o exemplo 03)
    final p = await api
        .unixfs()
        .add(ctx, files.newBytesFile(utf8.encode('olá do Dart via FFI\n')));
    print('add: $p');
    final file = files.toFile(await api.unixfs().get(ctx, p));
    print('get: ${utf8.decode(io.readAll(file)).trim()}');

    // arquivo ou pasta do disco
    if (args.length > 1) {
      final src = args[1];
      final root = await api
          .unixfs()
          .add(ctx, files.newSerialFile(src, false, os.stat(src)));
      print('add $src: $root');
      await for (final e in api.unixfs().ls(ctx, root)) {
        print('  ${e.name}  ${e.size} B  ${e.cid}');
      }
    }
  } finally {
    await n.close();
  }
}
