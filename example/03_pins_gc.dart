// Step 3: managing CIDs by hand (`ipfs pin`, `ipfs block`, `ipfs repo gc`).
// What is pinned stays; the GC deletes the rest. Run 01_init_repo.dart first.
//
//   dart run example/03_pins_gc.dart [repo]
import 'dart:convert';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/io.dart' as io;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;
import 'package:ipfs_ffi/kubo/core.dart' as core;
import 'package:ipfs_ffi/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/kubo/core/corerepo.dart' as corerepo;
import 'package:ipfs_ffi/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/kubo/repo/fsrepo.dart' as fsrepo;

Future<void> main(List<String> args) async {
  final repoPath = args.isNotEmpty ? args.first : '.ipfs-ffi';

  // Kubo runs in the ipfs_host, in another process (dart run tool/build.dart).
  await IpfsService.start();
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final ctx = context.background();
  final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repoPath)));
  try {
    final api = coreapi.newCoreApi(n);

    // a pinned file (with a name) and a loose file
    final kept = await api.unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('fica\n')),
        [options.unixfs.pin(true, 'exemplo-03')]);
    final loose = await api.unixfs().add(ctx,
        files.newBytesFile(utf8.encode('gone after GC ${DateTime.now()}\n')));
    print('pinned: $kept');
    print(
        'loose:  $loose  pinned? ${(await api.pin().isPinned(ctx, loose)).$2}');

    // a raw block (no DAG/UnixFS), pinned directly
    final st = await api
        .block()
        .put(ctx, utf8.encode('raw block'), [options.block.pin(true)]);
    print('block:  ${st.path} (${st.size} B): '
        '${utf8.decode(io.readAll(await api.block().get(ctx, st.path!)))}');

    print('named pins:');
    await for (final p in api.pin().ls(ctx, [options.pin.ls.detailed(true)])) {
      if (p.name.isNotEmpty) print('  ${p.path}  ${p.type}  ${p.name}');
    }

    // ipfs repo gc: deletes what is not pinned
    final removed = await corerepo.garbageCollectAsync(n, ctx).toList();
    print('GC removed ${removed.length} block(s)');
    try {
      await api.block().stat(ctx, loose);
    } on Exception catch (e) {
      print('loose after GC: $e');
    }
    print('pinned after GC: ${(await api.block().stat(ctx, kept)).size} B');

    final ok = await api.pin().verify(ctx).every((s) => s.ok);
    print('pin verify: ${ok ? 'all intact' : 'some pins are broken'}');

    // cleans up what the example pinned
    await api.pin().rm(ctx, kept);
    await api.pin().rm(ctx, st.path!);
  } finally {
    await n.close();
  }
  await IpfsService.stop();
}
