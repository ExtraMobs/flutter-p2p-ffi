// Lesson 20 · When do I need to release memory?
//
// Question: the node, a CAR reader, a buffer... every Go object I open lives
// in the p2p_host (lesson 01). Dart's garbage collector frees Dart memory;
// what frees the Go side?
//
// Answer: a handle (GoHandle) is a small Dart object holding a number; the
// p2p_host keeps the real Go object in a table under that number, and Go's
// garbage collector cannot free it while it is there. The entry goes away:
//   - by itself, when Dart's GC collects the handle (a Finalizer). But to
//     Dart a handle weighs a few bytes, whatever it holds in Go (a 64 MiB
//     buffer too): Dart feels no pressure, its GC does not run, and the
//     p2p_host grows ("floating garbage"). Fine for a few long-lived
//     objects, not for loops.
//   - now, with release(): the entry leaves the table at once and Go may
//     free the object. `use(...)` releases at the end of a block;
//     `withGoScope(...)` / GoScope release everything registered in one go.
// close() is something else: it is Go's Close (closes a file, a node, a
// reader); the handle still exists until released or collected. Values (a
// CID, a path, bytes, a struct of data) are copies in Dart: nothing to
// release.
//
// Needs: lesson 01 (values and handles). Technically: the same Go pointer
// seen twice gives the same handle number with two references, so each Dart
// handle can be released on its own.
//
//   dart run example/en_us/20_handles_and_memory.dart
//
// Next question: "Some Go functions take a function (a stream handler, a
// validator). How does Go call my Dart code?" → lesson 21.
import 'dart:io';
import 'dart:typed_data';

import 'package:p2p_ffi/p2p_ffi.dart';

import 'lesson.dart';

/// The p2p_host's resident memory, in MiB.
int hostMiB() {
  final pid = P2pService.hostPid;
  if (Platform.isWindows) {
    final out =
        Process.runSync('tasklist', ['/fi', 'PID eq $pid', '/fo', 'csv', '/nh'])
            .stdout as String;
    return int.parse(out.split('","').last.replaceAll(RegExp(r'[^0-9]'), '')) ~/
        1024;
  }
  for (final line in File('/proc/$pid/status').readAsLinesSync()) {
    if (line.startsWith('VmRSS:')) {
      return int.parse(line.replaceAll(RegExp(r'[^0-9]'), '')) ~/ 1024;
    }
  }
  return -1;
}

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('lesson20_');
  final big = '${tmp.path}/8mib.bin';
  File(big).writeAsBytesSync(Uint8List(8 << 20));
  await P2pService.start();
  try {
    // 1. A handle: a number in Dart, the object in Go.
    final buf = BytesBuffer(Uint8List.fromList([1, 2, 3, 4]));
    say('a bytes.Buffer: handle #${buf.$h}, released: ${buf.isReleased}, '
        '${buf.bytes().length} bytes in Go');
    buf.release();
    buf.release(); // a second release does nothing
    say('  after release(): released ${buf.isReleased}');

    // 2. The same Go pointer twice: one entry, two references.
    final f1 = Go.boxo.files.newBytesFile(Uint8List.fromList([7, 8, 9]));
    final f2 = f1.asBoxoFilesFile()!; // the same Go object, seen as a File
    say('\nf1 #${f1.$h} and f2 #${f2.$h}: the same entry, 2 references');
    f1.release();
    say('  f1 released; f2 still reads ${Go.io.readAll(f2)}');
    f2.release();

    // 3. Floating garbage: 20 × 8 MiB copied into Go buffers.
    say('\nthe p2p_host at the start: ${hostMiB()} MiB');
    for (var i = 0; i < 20; i++) {
      // use(): released at the end of the block, whatever happens inside.
      BytesBuffer(Uint8List(0)).use((b) {
        Go.os.open(big).use((f) {
          try {
            Go.io.copy(b, f);
          } finally {
            f.close(); // Go's Close: the file descriptor
          }
        });
      });
    }
    say('  after 20 copies with use(): ${hostMiB()} MiB');
    for (var i = 0; i < 20; i++) {
      final b = BytesBuffer(Uint8List(0));
      final f = Go.os.open(big);
      Go.io.copy(b, f);
      f.close(); // closed, but neither handle released
    }
    say('  after 20 copies left to the Finalizer: ${hostMiB()} MiB (Dart '
        'saw no reason to collect)');

    // 4. Many handles per iteration: a scope releases them together, in
    //    reverse order, in one message to the p2p_host.
    final total = withGoScope((s) {
      final f = s.manage(Go.os.open(big));
      try {
        final out = s.manage(BytesBuffer(Uint8List(0)));
        return Go.io.copy(out, f);
      } finally {
        f.close();
      }
    });
    say('\nwithGoScope: copied $total bytes; both handles released on exit');
    final scope = GoScope(); // the same, for a lifespan of your own
    final kept = scope.manage(BytesBuffer(Uint8List(16)));
    scope.close();
    say('  GoScope.close(): released ${kept.isReleased}');

    say('\n== Common mistakes\n');
    await mistake('using a handle after release()',
        why: 'the entry left the table: the number points to nothing',
        instead: 'every use before release(), or inside use((h) {...})',
        action: () => buf.bytes());
    final escaped = withGoScope((s) => s.manage(BytesBuffer(Uint8List(16))));
    await mistake('returning a managed handle out of withGoScope',
        why: 'the scope released it on the way out',
        instead: 'return a Dart value (bytes, a CID, a count) from the scope',
        action: () => escaped.bytes());
    if (Platform.isWindows) {
      final locked = '${tmp.path}/locked.bin';
      File(locked).writeAsBytesSync(Uint8List(64));
      final f = Go.os.open(locked);
      f.release();
      await mistake('release() without close() on an open file',
          why: 'release frees the table entry, not the file: Go keeps it '
              'open until its own GC finalizes it (Windows then refuses '
              'to delete it)',
          instead: 'close() in a finally, then release (or use())',
          action: () => File(locked).deleteSync());
    }
  } finally {
    await P2pService.stop();
    tmp.deleteSync(recursive: true);
  }
}
