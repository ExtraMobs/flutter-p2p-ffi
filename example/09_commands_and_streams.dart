// Step 9: the `ipfs` commands (the same as in the terminal: `ipfs files mkdir`,
// `ipfs pin ls`, `ipfs cat`...) called from Dart, and a tour of `Stream`, which
// is how every command returns its result.
//
//   dart run example/09_commands_and_streams.dart
//
// It does not need example 01: it creates a temporary repo and deletes it at the end.
//
// Before starting, two Dart concepts that show up in the whole file:
//
// - `Future<T>`: the promise of ONE value of type T that is ready later (the
//   IPFS node's answer takes a while). `await f` pauses this function until the
//   value is ready and returns it; meanwhile, the rest of the program keeps
//   running. `await` can only be used inside an `async` function.
//
// - `Stream<T>`: a SEQUENCE of values of type T that arrive over time (zero, one
//   or many), and that ends at some point, with or without an error. Think of a
//   conveyor belt: the items arrive one at a time. An important point: a Stream
//   is "lazy". Creating the Stream does nothing; the command only runs in the
//   node when someone starts listening to the Stream (with `await for`,
//   `.listen`, `.single`, `.toList()`, `.drain()`...). Forgetting to listen = the
//   command never runs.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/boxo/files.dart' as files;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/ipfs_ffi.dart' show IpfsException, IpfsService;
import 'package:ipfs_ffi/kubo.dart' as kubo;

Future<void> main() async {
  // A temporary directory just for this example (the IPFS repo lives in it).
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_ex09_');
  final repoPath = '${tmp.path}/repo';

  // Starts the service: launches the ipfs_host (kubo, in another process; build
  // it first with `dart run tool/build.dart`). Everything below talks to it.
  await IpfsService.start();

  // Kubo's plugins (the repo's database types etc.): once per service, before
  // opening any repo. The `..` call two methods on the same object, one after
  // the other.
  kubo.PluginLoader('')
    ..initialize()
    ..inject();

  // Creates the repo: a new identity (the node's key pair) and kubo's default
  // config, with the `test` profile (no network, random ports).
  final cfg = kubo
      .initWithIdentity(kubo.createIdentity(null, [kubo.key.type('ed25519')]));
  kubo.profiles['test']!.transform(cfg);
  kubo.init(repoPath, cfg);

  // Go's "context": every call that may take a while gets one. `background()`
  // is the context that never expires nor is canceled (example 11 shows
  // deadlines and cancellation).
  final ctx = context.background();

  // Starts the IPFS node (offline: without `online: true` it does not talk to
  // the network). `newNode` returns a Future, so we wait with `await`.
  final n = await kubo.newNode(ctx, kubo.BuildCfg(repo: kubo.open(repoPath)));

  // `try { ... } finally { ... }`: the `finally` block ALWAYS runs at the end,
  // whether it worked or failed, and it is where we close the node and the
  // service.
  try {
    // ------------------------------------------------------------------
    // 1. A command without a useful result: `.drain()`
    // ------------------------------------------------------------------
    // `ipfs files mkdir -p /docs`. The command returns a Stream, but here only
    // the effect matters (creating the directory). `.drain()` listens to the
    // Stream until the end, throwing the items away, and returns a Future that
    // completes when the command ends. Without `.drain()`, the directory would
    // NOT be created (the Stream is lazy: nobody listened, nothing ran).
    await kubo.filesMkdir(n, ctx, '/docs', parents: true).drain<void>();
    print('1. created /docs');

    // `ipfs files write --create /docs/note.txt`: writes bytes to a file in the
    // MFS (the IPFS node's "file system"). `utf8.encode` turns the text into
    // bytes; `files.newBytesFile` wraps the bytes as a file.
    await kubo
        .filesWrite(n, ctx, '/docs/note.txt',
            files.newBytesFile(utf8.encode('hello, IPFS!\n')),
            create: true)
        .drain<void>();
    print('   wrote /docs/note.txt');

    // ------------------------------------------------------------------
    // 2. A command that returns ONE value: `.single`
    // ------------------------------------------------------------------
    // `ipfs files stat /docs/note.txt` emits a single item (a StatOutput).
    // `.single` listens to the whole Stream and returns a Future with the only
    // item. Careful: if the Stream comes empty, or with more than one item,
    // `.single` fails (StateError). Use it when the command, by nature, answers
    // once.
    final st = await kubo.filesStat(n, ctx, '/docs/note.txt').single;
    print('2. stat: ${st.type}, ${st.size} bytes, CID ${st.hash}');

    // `ipfs files ls /docs`: also a single item, which carries the `entries` list.
    final ls = await kubo.filesLs(n, ctx, '/docs', long: true).single;
    for (final e in ls.entries) {
      print('   ls: ${e.name} (${e.size} bytes)');
    }

    // ------------------------------------------------------------------
    // 3. A command that returns BYTES in pieces: `await for`
    // ------------------------------------------------------------------
    // `ipfs files read` emits the content in pieces (Uint8List, a list of
    // bytes); a large file arrives in several pieces. `await for` is a `for`
    // loop that waits for each item of the Stream: the body runs once per piece,
    // and the loop ends when the Stream ends.
    final content = BytesBuilder(); // joins the pieces into a single buffer
    await for (final chunk in kubo.filesRead(n, ctx, '/docs/note.txt')) {
      print('3. a piece of ${chunk.length} bytes arrived');
      content.add(chunk);
    }
    print('   content: ${utf8.decode(content.takeBytes()).trim()}');

    // ------------------------------------------------------------------
    // 4. Collecting every item: `.toList()`
    // ------------------------------------------------------------------
    // A pinned file (the pin keeps the garbage collector from deleting it).
    final p = await kubo.newCoreApi(n).unixfs().add(
        ctx,
        files.newBytesFile(utf8.encode('kept around')),
        [kubo.unixfs.pin(true, '')]);
    // `ipfs pin ls --type=recursive` emits the pins (there may be many).
    // `.toList()` waits for the Stream to end and returns every item in a list.
    // Handy, but only use it when you know the list fits in memory.
    final pins = await kubo.pinLs(n, ctx, [], type: 'recursive').toList();
    for (final w in pins) {
      // each item carries a map: CID → pin type
      w.keys.forEach((cid, info) => print('4. pin: $cid (${info.type})'));
    }

    // ------------------------------------------------------------------
    // 5. Listening with `.listen`: callbacks, instead of waiting
    // ------------------------------------------------------------------
    // `await for` pauses the function until the Stream ends. `.listen` does NOT
    // pause: it registers functions (callbacks) that Dart calls later, and the
    // code right below `.listen` goes on immediately. It is the right way when
    // the screen (or another task) must stay alive while the items arrive, like
    // a chat's messages.
    //
    //   onData:  called once for EACH item that arrives
    //   onError: called if the command fails (here, an IpfsException)
    //   onDone:  called once, when the Stream ends
    //
    // `.listen` returns a StreamSubscription: the subscription's "remote
    // control", with `.cancel()` (stop listening) and `.pause()/.resume()`.
    final done = Completer<void>(); // a Future we complete by hand
    var total = 0;
    final subscription = kubo.cat(n, ctx, [p.value]).listen(
      (chunk) {
        // onData: runs for each piece of bytes of `ipfs cat`
        total += chunk.length;
      },
      onError: (Object e) {
        // onError: the command failed; without this callback the error would go
        // to the zone's uncaught error handler and bring the program down
        print('5. cat error: $e');
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        // onDone: the Stream ended (every piece arrived)
        print('5. cat finished: $total bytes');
        done.complete();
      },
      cancelOnError: true, // stop listening on the first error
    );
    print(
        '5. (this line shows up BEFORE "cat finished": listen does not wait)');
    await done.future; // now we do wait for onDone
    // After onDone the subscription is already over; cancel() here does nothing,
    // but it is what you call to stop listening BEFORE the end (e.g. the user
    // left the screen). It does not stop the command in the node: to stop it,
    // cancel the context it was given.
    await subscription.cancel();

    // ------------------------------------------------------------------
    // 6. Errors: the command fails → IpfsException
    // ------------------------------------------------------------------
    // When kubo returns an error (here: the path does not exist), the Stream ends
    // with an error. With `await` (including `.single`, `.toList()`,
    // `await for`), the error becomes an exception that `try/catch` catches.
    try {
      await kubo.filesStat(n, ctx, '/does/not/exist').single;
    } on IpfsException catch (e) {
      print('6. expected error from kubo: $e');
    }

    // `ipfs files rm -r /docs` and check that it is gone
    await kubo.filesRm(n, ctx, ['/docs'], recursive: true).drain<void>();
    final root = await kubo.filesLs(n, ctx, '/').single;
    print('   after rm, the root has ${root.entries.length} entries');
  } finally {
    await n.close(); // closes the node (releases the repo)
    await IpfsService.stop(); // ends the ipfs_host
    tmp.deleteSync(recursive: true); // deletes the temporary directory
  }
}
