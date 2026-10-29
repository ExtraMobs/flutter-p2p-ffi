// Lesson 12 · How do I use the `ipfs` commands I already know?
//
// Question: I know `ipfs add`, `ipfs cat`, `ipfs pin ls`, `ipfs dag put`...
// from the terminal. Can I call them from Dart, without HTTP, and what do I
// do with what they return?
//
// Answer: every kubo command is a Dart function in
// `Go.kubo.core.commands`: the arguments of the command
// line are its positional parameters, the flags its named ones (`ipfs files
// mkdir -p /a` → `filesMkdir(n, ctx, '/a', parents: true)`). They run inside
// the app's own node and return a Stream: one item per result line of the
// command, or pieces of bytes for `cat`. A Stream is consumed in one of a
// few ways:
//   - `.single`: a command with exactly one result (`filesStat`, `id`);
//   - `.toList()` or `await for`: many results (`pinLs`, `refs`);
//   - `.drain()`: run it and ignore the output (`filesMkdir`);
//   - `.fold` or a BytesBuilder: join the pieces of `cat`;
//   - `.listen`: react to each item as it comes, without waiting.
// IPLD data that is not a file, like a JSON object, goes in with `dag put`
// (stored as dag-cbor, with links to other CIDs) and is read back by path.
//
// Needs: lesson 08 (a node: the commands run on it). Technically, each
// command needs what its CoreAPI part needs: the blockstore, the pinner,
// MFS; network commands (`swarm`, `routing`, `pubsub`) need an online node.
//
//   dart run example/en_us/12_ipfs_commands.dart
//
// Next question: "All of this is local. How does my node exist on the
// network?" → lesson 13.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

Future<void> main() async {
  await P2pService.start();
  final tmp = Directory.systemTemp.createTempSync('lesson12_');
  final ctx = Go.context.background();
  final n = await newNode(ctx, '${tmp.path}/repo');
  try {
    final api = Go.kubo.core.coreapi.newCoreApi(n);

    // 1. One result: `.single`.            CLI: ipfs id; ipfs repo stat
    final id = await Go.kubo.core.commands.id(n, ctx, null).single;
    say('ipfs id: ${id.id} (${id.agentVersion})');
    final repo = await Go.kubo.core.commands.repoStat(n, ctx).single;
    say('ipfs repo stat: ${repo.numObjects} objects, ${repo.repoSize} bytes');

    // 2. Many results: `await for`.        CLI: ipfs add -r folder
    final folder = Directory('${tmp.path}/folder')..createSync();
    File('${folder.path}/a.txt').writeAsStringSync('A\n');
    File('${folder.path}/b.txt').writeAsStringSync('B\n');
    say('\nipfs add -r, one event per file:');
    await for (final e in Go.kubo.core.commands.add(
        n,
        ctx,
        [
          Go.boxo.files
              .newSerialFile(folder.path, false, Go.os.stat(folder.path))
        ],
        recursive: true,
        cidVersion: 1)) {
      say('  ${e.name.padRight(12)} ${e.hash}');
    }

    // 3. Bytes in pieces: join them.       CLI: ipfs cat <cid>
    final big = Uint8List(600000);
    final p = await api.unixfs().add(ctx, Go.boxo.files.newBytesFile(big));
    final joined = BytesBuilder();
    var pieces = 0;
    await for (final piece in Go.kubo.core.commands.cat(n, ctx, [p.value])) {
      pieces++;
      joined.add(piece);
    }
    say('\nipfs cat: ${joined.length} bytes in $pieces pieces');

    // 4. React as items come, without waiting: `.listen`.
    //    CLI: ipfs pin ls --type=recursive
    final done = <String>[];
    final sub = Go.kubo.core.commands
        .pinLs(n, ctx, [], type: 'recursive')
        .listen((w) => done.addAll(w.keys.keys),
            onDone: () => say('  (pin ls finished: ${done.length} pins)'));
    say('\nipfs pin ls started; this line prints before it finishes');
    await sub.asFuture<void>();

    // 5. `.drain()`: run and ignore the output.   CLI: ipfs files mkdir -p /a/b
    await Go.kubo.core.commands
        .filesMkdir(n, ctx, '/a/b', parents: true)
        .drain<void>();
    say('\nipfs files mkdir -p /a/b: done');

    // 6. IPLD objects: JSON in, dag-cbor stored, read back by path, links
    //    followed.                         CLI: ipfs dag put / ipfs dag get
    final author = await Go.kubo.core.commands.dag
        .dagPut(api, ctx, utf8.encode('{"name": "Ana", "lang": "pt"}'));
    final post = await Go.kubo.core.commands.dag.dagPut(
        api,
        ctx,
        utf8.encode('{"title": "hi", "tags": ["ipfs", "dart"], '
            '"author": {"/": "$author"}}'),
        pin: true);
    say('\nipfs dag put: post $post (dag-cbor: ${post.type() == Go.multicodec.dagCbor})');
    final tags = await Go.kubo.core.commands.dag
        .dagGet(api, ctx, BoxoPath('/ipfs/$post/tags'));
    final name = await Go.kubo.core.commands.dag
        .dagGet(api, ctx, BoxoPath('/ipfs/$post/author/name'));
    say('  /tags → ${utf8.decode(tags)}');
    say('  /author/name (through the link) → ${utf8.decode(name)}');

    say('\n== Common mistakes\n');
    await mistake('`.single` on a command that gives many results',
        why: 'single wants exactly one item; ipfs add -r gave one per file',
        instead: '`await for` or `.toList()`',
        action: () => Go.kubo.core.commands
            .add(
                n,
                ctx,
                [
                  Go.boxo.files.newSerialFile(
                      folder.path, false, Go.os.stat(folder.path))
                ],
                recursive: true)
            .single);
    await mistake('waiting for an error the Stream already threw',
        why: 'a command error comes through the Stream; no one listened',
        instead: 'await the Stream (or listen with onError) inside a try',
        action: () =>
            Go.kubo.core.commands.filesStat(n, ctx, '/no/such/path').single);
    await mistake('dag put of text that is not JSON',
        why: 'the input codec is dag-json by default',
        instead: 'valid JSON, or inputCodec: matching what you send',
        action: () => Go.kubo.core.commands.dag
            .dagPut(api, ctx, utf8.encode('not json')));
  } finally {
    await n.close();
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
