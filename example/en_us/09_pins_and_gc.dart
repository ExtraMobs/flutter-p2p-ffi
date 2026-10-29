// Lesson 09 · Why do my blocks disappear?
//
// Question: I added a file, and later it was gone from the node. Why, and
// how do I keep what matters?
//
// Answer: a node's disk is a cache. The garbage collector (`ipfs repo gc`,
// or automatically when Datastore.StorageMax fills up with GC enabled)
// deletes every block nothing protects. What protects a block:
//   - a recursive pin: the root and everything below it (what
//     `ipfs add` does by default on the command line; the CoreAPI does NOT
//     pin unless asked);
//   - a direct pin: that one block only;
//   - being below a recursive pin: an "indirect" pin;
//   - being in MFS, the node's file tree (lesson 10).
// Unpinning does not delete; the next GC does.
//
// Needs: lesson 08 (a node and its CoreAPI). Technically, GC needs the
// node's GC-aware blockstore (n.blockstore) and its pinner: it takes the GC
// lock (no add or pin runs meanwhile), marks everything reachable from the
// pins and from MFS, and deletes the rest.
//
//   dart run example/en_us/09_pins_and_gc.dart
//
// Next question: "Pinning each CID by hand is clumsy; can I just have
// folders?" → lesson 10.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson09_');
  final ctx = goContext.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = goKubo.core.coreapi.newCoreApi(n);
    Future<BoxoPath> add(String text,
            [List<KuboCoreCoreifaceOptionsUnixfsAddOption> o = const []]) =>
        api.unixfs().add(ctx, goBoxo.files.newBytesFile(utf8.encode(text)), o);
    // Not found is ipld's ErrNotFound, thrown as GolangNotFoundException; any
    // other error (a broken store, a closed node) goes up.
    //    Go:  _, err := api.Block().Stat(ctx, p)
    //         return !ipld.IsNotFound(err)
    Future<bool> here(BoxoPath p) async {
      try {
        await api.block().stat(ctx, p);
        return true;
      } on GolangNotFoundException {
        return false;
      }
    }

    // 1. Four files, four fates.
    //    Go:  api.Unixfs().Add(ctx, f, options.Unixfs.Pin(true, "name"))
    final pinned = await add('kept by a pin\n',
        [goKubo.core.coreiface.options.unixfs.pin(true, 'lesson-09')]);
    final loose = await add('nothing protects me\n');
    final inMfs = await add('kept by MFS\n');
    final unpinned = await add('pinned, then unpinned\n',
        [goKubo.core.coreiface.options.unixfs.pin(true, '')]);
    //    Go:  mfs.PutNode(n.FilesRoot, "/kept.txt", nd)
    goBoxo.mfs
        .putNode(n.filesRoot, '/kept.txt', await api.resolveNode(ctx, inMfs));
    //    Go:  api.Pin().Rm(ctx, p)
    await api.pin().rm(ctx, unpinned);

    // A raw block (`ipfs block put --pin`): kubo pins it as recursive.
    final raw = await api.block().put(ctx, utf8.encode('a raw block'),
        [goKubo.core.coreiface.options.block.pin(true)]);

    Future<void> show(String when) async {
      say('\n$when:');
      for (final (name, p) in [
        ('pinned', pinned),
        ('loose', loose),
        ('in MFS', inMfs),
        ('unpinned', unpinned),
        ('raw block', raw.path!),
      ]) {
        final (how, isPinned) = await api.pin().isPinned(ctx, p);
        say('  ${name.padRight(10)} here: ${(await here(p)).toString().padRight(5)} '
            'pinned: ${isPinned ? how : 'no'}');
      }
    }

    await show('before GC');

    // 2. The pins, with their names and types.
    //    Go:  api.Pin().Ls(ctx, options.Pin.Ls.Detailed(true))
    say('\npin ls:');
    await for (final p in api
        .pin()
        .ls(ctx, [goKubo.core.coreiface.options.pin.ls.detailed(true)])) {
      say('  ${p.type.padRight(9)} ${p.path} ${p.name}');
    }

    // 3. GC: everything not reachable from a pin or from MFS goes.
    //    Go:  for r := range corerepo.GarbageCollectAsync(n, ctx) { ... }
    final removed =
        await goKubo.core.corerepo.garbageCollectAsync(n, ctx).toList();
    say('\nGC removed ${removed.length} block(s): '
        '${removed.map((r) => r.keyRemoved).join(', ')}');
    await show('after GC');

    // 4. Pins can be checked: is every block under them still here?
    //    Go:  for s := range api.Pin().Verify(ctx) { s.Ok() }
    final intact = await api.pin().verify(ctx).every((s) => s.ok);
    say('\npin verify: all intact: $intact');

    say('\n== Common mistakes\n');
    await mistake('unpinning something that is not pinned',
        why: 'the pinner has no pin for it (it is only here by luck, or not '
            'at all)',
        instead: 'check api.pin().isPinned first',
        action: () => api.pin().rm(ctx, loose));
    await mistake('deleting a pinned block by hand (`ipfs block rm`)',
        why: 'the pin protects it: kubo refuses to delete a pinned block',
        instead: 'unpin it first; the next GC deletes it',
        action: () => api.block().rm(ctx, raw.path!));
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
