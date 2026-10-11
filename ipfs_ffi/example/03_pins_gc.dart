// Passo 3: gerenciar CIDs à mão (`ipfs pin`, `ipfs block`, `ipfs repo gc`).
// O que está pinado fica; o resto o GC apaga. Rode o 01_init_repo.dart antes.
//
//   dart run example/03_pins_gc.dart [repo]
import 'dart:convert';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/context.dart' as context;
import 'package:ipfs_ffi/io.dart' as io;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/corerepo.dart' as corerepo;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;

Future<void> main(List<String> args) async {
  final repoPath = args.isNotEmpty ? args.first : '.ipfs-ffi';

  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final ctx = context.background();
  final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repoPath)));
  try {
    final api = coreapi.newCoreApi(n);

    // arquivo pinado (com nome) e arquivo solto
    final kept = await api.unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('fica\n')),
        [options.unixfs.pin(true, 'exemplo-03')]);
    final loose = await api.unixfs().add(
        ctx, files.newBytesFile(utf8.encode('some no GC ${DateTime.now()}\n')));
    print('pinado: $kept');
    print(
        'solto:  $loose  pinado? ${(await api.pin().isPinned(ctx, loose)).$2}');

    // bloco cru (sem DAG/UnixFS), pinado direto
    final st = await api
        .block()
        .put(ctx, utf8.encode('bloco cru'), [options.block.pin(true)]);
    print('bloco:  ${st.path} (${st.size} B): '
        '${utf8.decode(io.readAll(await api.block().get(ctx, st.path!)))}');

    print('pins com nome:');
    await for (final p in api.pin().ls(ctx, [options.pin.ls.detailed(true)])) {
      if (p.name.isNotEmpty) print('  ${p.path}  ${p.type}  ${p.name}');
    }

    // ipfs repo gc: apaga o que não está pinado
    final removed = await corerepo.garbageCollectAsync(n, ctx).toList();
    print('GC apagou ${removed.length} bloco(s)');
    try {
      await api.block().stat(ctx, loose);
    } on Exception catch (e) {
      print('solto depois do GC: $e');
    }
    print('pinado depois do GC: ${(await api.block().stat(ctx, kept)).size} B');

    final ok = await api.pin().verify(ctx).every((s) => s.ok);
    print('pin verify: ${ok ? 'tudo íntegro' : 'há pins quebrados'}');

    // limpa o que o exemplo pinou
    await api.pin().rm(ctx, kept);
    await api.pin().rm(ctx, st.path!);
  } finally {
    await n.close();
  }
}
