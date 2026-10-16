// Passo 2 do kubo: abre o repo, sobe o nó (offline) e usa a CoreAPI para
// adicionar e ler arquivos, sem HTTP. Rode o 01_init_repo.dart antes.
//
//   dart run example/02_add_get.dart [repo] [arquivo-ou-pasta]
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/io.dart' as io;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface.dart' as iface;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/go/os.dart' as os;

Future<void> main(List<String> args) async {
  final repoPath = args.isNotEmpty ? args.first : '.ipfs-ffi';

  // O kubo roda no ipfs_host, noutro processo (dart run tool/build.dart).
  await IpfsService.start();
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

    // arquivo ou pasta do disco, com o progresso do kubo (como o `ipfs add`)
    if (args.length > 1) {
      final src = args[1];
      final total = FileSystemEntity.isFileSync(src)
          ? File(src).lengthSync()
          : Directory(src)
              .listSync(recursive: true)
              .whereType<File>()
              .fold<int>(0, (s, f) => s + f.lengthSync());
      final events = StreamController<iface.AddEvent>();
      final porArquivo =
          <String, int>{}; // `bytes` é o progresso de cada arquivo
      events.stream.listen((e) {
        if (e.path == null) {
          porArquivo[e.name] = e.bytes;
          final lido = porArquivo.values.fold<int>(0, (s, b) => s + b);
          stdout.write(
              '\r  ${(100 * lido / (total == 0 ? 1 : total)).clamp(0, 100).toStringAsFixed(0)}%');
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
  await IpfsService.stop();
}
