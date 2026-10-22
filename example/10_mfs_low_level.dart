// Step 10: MFS (the IPFS node's "file system") at the low level, Go's
// `boxo/mfs` functions, called straight from Dart. It is the same layer that
// `ipfs files` (example 09) uses inside, only without the command's shell: more
// control (opening a file, going to a position, writing a piece), more
// responsibility (closing what you opened, writing to disk with flush).
//
//   dart run example/10_mfs_low_level.dart
//
// Each step carries, in a comment, the same code in Go: the Dart API is Go's,
// generated, with the same functions, in the same argument order. Whoever reads
// boxo's documentation (pkg.go.dev/github.com/ipfs/boxo/mfs) knows how to use this.
import 'dart:convert';
import 'dart:io';

import 'package:ipfs_ffi/go/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/boxo/mfs.dart' as mfs;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/kubo/core/node.dart' as node;
import 'package:ipfs_ffi/go/kubo/plugin/loader.dart' as loader;
import 'package:ipfs_ffi/go/kubo/config.dart' as config;
import 'package:ipfs_ffi/go/kubo/repo/fsrepo.dart' as fsrepo;
import 'package:ipfs_ffi/go/kubo/core/coreiface/options.dart' as options;
import 'package:ipfs_ffi/go/kubo/core/coreapi.dart' as coreapi;
import 'package:ipfs_ffi/go/kubo/core.dart' as core;
import 'package:ipfs_ffi/go/kubo/core/commands.dart' as commands;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsService;

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_ex10_');
  final repoPath = '${tmp.path}/repo';

  // Service, plugins and a new repo: the same as example 09 (every line is
  // explained there).
  await IpfsService.start();
  loader.PluginLoader('')
    ..initialize()
    ..inject();
  final cfg = config
      .initWithIdentity(config.createIdentity(null, [options.key.type('ed25519')]));
  config.profiles['test']!.transform(cfg);
  fsrepo.init(repoPath, cfg);
  final ctx = context.background();
  final n = await core.newNode(ctx, node.BuildCfg(repo: fsrepo.open(repoPath)));
  final api = coreapi.newCoreApi(n);

  try {
    // The node's MFS root. In Go it is a FIELD of the IpfsNode struct; in Dart
    // it becomes a getter (read like a field, without parentheses).
    //   Go:   root := node.FilesRoot
    final root = n.filesRoot;

    // Creates /docs/drafts (and /docs on the way, mkdir's "-p").
    // Go's options are a struct (MkdirOpts); in Dart the same struct, with the
    // fields as named parameters (the name inside the parentheses).
    //   Go:   mfs.Mkdir(root, "/docs/drafts", mfs.MkdirOpts{Mkparents: true, Flush: true})
    mfs.mkdir(
        root, '/docs/drafts', mfs.MkdirOpts(mkparents: true, flush: true));
    print('1. created /docs/drafts');

    // Puts into MFS a file that is already in IPFS: adds the bytes (`ipfs
    // add`), gets the IPLD node (the block the CID points to) and hangs it on an
    // MFS path. Nothing is copied: MFS only points to the CID.
    //   Go:   p, _ := api.Unixfs().Add(ctx, files.NewBytesFile([]byte("first line\n")))
    //         nd, _ := api.ResolveNode(ctx, p)
    //         mfs.PutNode(root, "/docs/note.txt", nd)
    final p = await api
        .unixfs()
        .add(ctx, files.newBytesFile(utf8.encode('first line\n')));
    mfs.putNode(root, '/docs/note.txt', await api.resolveNode(ctx, p));
    print('2. hung $p on /docs/note.txt');

    // Looks up a path. Go returns the FSNode interface (it may be a directory or
    // a file) and the code does a "type assertion" to find out which. In Dart
    // the same becomes `asFile()`/`asDirectory()`, which return `null` when the
    // node is not of that type; the `!` tells Dart "I am sure it is not null"
    // (if it is, it fails right there).
    //   Go:   nd, _ := mfs.Lookup(root, "/docs/note.txt")
    //         file := nd.(*mfs.File)
    final file = mfs.lookup(root, '/docs/note.txt').asFile()!;
    print('3. /docs/note.txt has ${file.size()} bytes');

    // Opens for writing, goes to the end and appends a line. `seek(0, 2)`: 2 is
    // Go's io.SeekEnd ("from the end"); 0 is "from the start", 1 is "from the
    // current position". ALWAYS close what you opened: close is what writes the
    // change into MFS (and frees the file for another writer).
    //   Go:   fd, _ := file.Open(ctx, mfs.Flags{Write: true, Sync: true})
    //         fd.Seek(0, io.SeekEnd)
    //         fd.Write([]byte("second line\n"))
    //         fd.Close()
    final writer = await file.open(ctx, mfs.Flags(write: true, sync: true));
    writer.seek(0, 2);
    writer.write(utf8.encode('second line\n'));
    writer.close();
    // (this is the case of bug ipfs/boxo#1221, which the ipfs_ffi build fixes
    // with a patch: without the fix, the read below would bring only the second
    // line)

    // Opens for reading. Go reads into a buffer you pass ([]byte); in Dart you
    // say how many bytes you want and get the bytes read (fewer, if the file
    // ends first; empty at the end).
    //   Go:   fd, _ := file.Open(ctx, mfs.Flags{Read: true})
    //         buf := make([]byte, 1024)
    //         n, _ := fd.CtxReadFull(ctx, buf)
    //         fmt.Print(string(buf[:n]))
    //         fd.Close()
    final reader = await file.open(ctx, mfs.Flags(read: true));
    final bytes = await reader.ctxReadFull(ctx, 1024);
    reader.close();
    print('4. content now:\n${utf8.decode(bytes)}');

    // Moves the file to another directory (`ipfs files mv`).
    //   Go:   mfs.Mv(root, "/docs/note.txt", "/docs/drafts/note.txt")
    mfs.mv(root, '/docs/note.txt', '/docs/drafts/note.txt');

    // Lists a directory: look up, convert to a directory, list.
    //   Go:   nd, _ := mfs.Lookup(root, "/docs/drafts")
    //         dir := nd.(*mfs.Directory)
    //         entries, _ := dir.List(ctx)
    final dir = mfs.lookup(root, '/docs/drafts').asDirectory()!;
    for (final e in await dir.list(ctx)) {
      print('5. /docs/drafts/${e.name}: ${e.size} bytes, CID ${e.hash}');
    }

    // Writes the changes up to the root and gets the directory's new CID: each
    // change in MFS produces new CIDs, from the leaf up to the root (the content
    // changed, so the address changes).
    //   Go:   nd, _ := mfs.FlushPath(ctx, root, "/docs")
    //         fmt.Println(nd.Cid())
    final docs = await mfs.flushPath(ctx, root, '/docs');
    print('6. /docs is now CID ${docs.cid()}');

    // For comparison, the same read through the high level (example 09): a
    // command, without opening or closing anything, with the result as a Stream
    // of byte pieces. `.fold` walks the Stream's items accumulating into a
    // value: it starts with `[]` (an empty list) and, for each piece that
    // arrives, calls the function with (what was accumulated so far, the new
    // piece); what the function returns becomes the new accumulated value. At
    // the end, it returns a Future with the final value. `all..addAll(chunk)`
    // adds the piece's bytes to the list and returns the list itself (`..`
    // returns the object, not the result of addAll).
    final viaCommand = await commands
        .filesRead(n, ctx, '/docs/drafts/note.txt')
        .fold<List<int>>([], (all, chunk) => all..addAll(chunk));
    print('7. through the ipfs files read command: ${viaCommand.length} bytes');
  } finally {
    await n.close();
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}
