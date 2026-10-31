// Lesson 10 · How do I work with folders that change?
//
// Question: every CID is immutable (lesson 02): change one byte and it is
// another CID. How do I keep a folder I can edit, like a normal disk?
//
// Answer: MFS (the Mutable File System), the `ipfs files` commands. It is a
// tree of names kept by the node whose root points to a CID; each change
// (write, mkdir, mv, rm) builds the new nodes from the change up to the
// root, so the root gets a new CID, and the old versions stay valid under
// their old CIDs. Nothing is copied: putting a CID into MFS only links it.
// Everything in MFS is protected from GC (lesson 09).
//
// Two layers, the same tree:
//   - the commands (`go.ipfs.kubo.core.commands.filesWrite`, `filesLs`,
//     `filesRead`...): the `ipfs files` of the command line, each a Stream of
//     results;
//   - boxo's mfs package (`go.ipfs.boxo.mfs.mkdir`, `go.ipfs.boxo.mfs.lookup`,
//     `BoxoMfsFile.open`...): the layer the commands use inside, with more
//     control (open a file, seek, write a piece) and more duties (close what
//     you open, flush).
//
// Needs: lesson 08 (a node: its MFS root is n.filesRoot). Technically, MFS
// needs a DAGService to read and write its nodes, and a root CID kept in the
// repo between runs.
//
//   dart run example/en_us/10_mfs.dart
//
// Next question: "The folder's CID changes on every edit; how do I give
// someone one address that always shows the latest version?" → lesson 11.
import 'dart:convert';
import 'dart:io';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson10_');
  final ctx = go.context.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = go.ipfs.kubo.core.coreapi.newCoreApi(n);
    Future<String> rootCid() async =>
        (await go.ipfs.kubo.core.commands.filesStat(n, ctx, '/').single).hash;

    // 1. The commands: mkdir, write, ls, read, as on the command line.
    //    CLI: ipfs files mkdir -p /site; echo ... | ipfs files write --create /site/index.html
    final empty = await rootCid();
    await go.ipfs.kubo.core.commands
        .filesMkdir(n, ctx, '/site', parents: true)
        .drain<void>();
    await go.ipfs.kubo.core.commands
        .filesWrite(n, ctx, '/site/index.html',
            go.ipfs.boxo.files.newBytesFile(utf8.encode('<h1>v1</h1>\n')),
            create: true)
        .drain<void>();
    final v1 = await rootCid();
    say('the MFS root: empty $empty → after one write $v1');
    final ls = await go.ipfs.kubo.core.commands
        .filesLs(n, ctx, '/site', long: true)
        .single;
    for (final e in ls.entries) {
      say('  /site/${e.name}  ${e.size} bytes  ${e.hash}');
    }
    final html = await go.ipfs.kubo.core.commands
        .filesRead(n, ctx, '/site/index.html')
        .fold<List<int>>([], (all, piece) => all..addAll(piece));
    say('  read: ${utf8.decode(html).trim()}');

    // 2. Edit the same name: the root gets a new CID, the old one still
    //    shows v1 (immutable, as always).
    await go.ipfs.kubo.core.commands
        .filesWrite(n, ctx, '/site/index.html',
            go.ipfs.boxo.files.newBytesFile(utf8.encode('<h1>v2</h1>\n')),
            truncate: true)
        .drain<void>();
    final v2 = await rootCid();
    final old = await go.ipfs.kubo.core.commands
        .cat(n, ctx, ['/ipfs/$v1/site/index.html']).fold<List<int>>(
            [], (all, piece) => all..addAll(piece));
    say('\nafter editing: root $v2');
    say('  the old root still reads: ${utf8.decode(old).trim()}');

    // 3. A CID from outside, linked into MFS without copying (`files cp`).
    final logo = await api.unixfs().add(
        ctx, go.ipfs.boxo.files.newBytesFile(utf8.encode('a logo, say\n')));
    await go.ipfs.kubo.core.commands
        .filesCp(n, ctx, logo.value, '/site/logo.txt')
        .drain<void>();
    say('\nlinked $logo as /site/logo.txt (no bytes copied)');

    // 4. The low level: boxo's mfs, on the same tree.
    //    Go:  f := mfs.Lookup(root, "/site/index.html").(*mfs.File)
    //         fd, _ := f.Open(ctx, mfs.Flags{Write: true, Sync: true})
    //         fd.Seek(0, io.SeekEnd); fd.Write(b); fd.Close()
    final root = n.filesRoot;
    final file =
        go.ipfs.boxo.mfs.lookup(root, '/site/index.html').asBoxoMfsFile()!;
    final w = await file.open(ctx, BoxoMfsFlags(write: true, sync: true));
    w.seek(0, 2); // 2 = io.SeekEnd
    w.write(utf8.encode('<p>appended by mfs</p>\n'));
    w.close(); // close is what writes the change into the tree
    final r = await file.open(ctx, BoxoMfsFlags(read: true));
    final now = await r.ctxReadFull(ctx, 1024);
    r.close();
    say('\nmfs, after an append:\n${utf8.decode(now)}');
    //    Go:  mfs.Mv(root, "/site/logo.txt", "/site/img/logo.txt")
    go.ipfs.boxo.mfs
        .mkdir(root, '/site/img', BoxoMfsMkdirOpts(mkparents: true));
    go.ipfs.boxo.mfs.mv(root, '/site/logo.txt', '/site/img/logo.txt');
    //    Go:  nd, _ := mfs.FlushPath(ctx, root, "/site")
    final site = await go.ipfs.boxo.mfs.flushPath(ctx, root, '/site');
    say('/site flushed: ${site.cid()}');
    final dir = go.ipfs.boxo.mfs.lookup(root, '/site').asBoxoMfsDirectory()!;
    say('  entries: ${(await dir.listNames(ctx)).join(', ')}');

    say('\n== Common mistakes\n');
    await mistake('writing to a path whose folder does not exist',
        why: 'files write creates the file (create: true), not its parents',
        instead: 'filesMkdir(..., parents: true) first',
        action: () => go.ipfs.kubo.core.commands
            .filesWrite(n, ctx, '/nope/a.txt',
                go.ipfs.boxo.files.newBytesFile(utf8.encode('x')),
                create: true)
            .drain<void>());
    // (Opening a file for writing while another descriptor is open does not
    // fail: it waits until the first is closed, as in Go. Close each
    // descriptor in a finally, or the next open waits for good.)
    await mistake('removing a folder that is not empty',
        why: 'files rm refuses folders unless told to remove what is inside',
        instead: 'filesRm(..., recursive: true)',
        action: () => go.ipfs.kubo.core.commands
            .filesRm(n, ctx, ['/site']).drain<void>());
    await mistake('reading a path that is not there',
        why: 'MFS paths are names in the tree, not CIDs: a typo is an error',
        instead: 'filesStat or filesLs to check; /ipfs/<cid> paths go to cat',
        action: () => go.ipfs.kubo.core.commands
            .filesStat(n, ctx, '/site/index.htm')
            .single);
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
