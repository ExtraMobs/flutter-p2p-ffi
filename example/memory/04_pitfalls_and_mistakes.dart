// Memory 04 · Pitfalls and mistakes to avoid.
//
// What: each mistake below is made on purpose to show the exact exception
// thrown by ipfs_ffi and the right way to write the code.
//
//   dart run example/memory/04_pitfalls_and_mistakes.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipfs_ffi.dart';

Future<void> mustFail(
  String what, {
  required String why,
  required String instead,
  required FutureOr<void> Function() action,
}) async {
  print('── Mistake: $what');
  print('   why:     $why');
  print('   instead: $instead');
  try {
    await action();
    throw StateError('expected $what to fail, but it succeeded');
  } on Object catch (e) {
    print('   caught:  $e\n');
  }
}

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_mem04_');
  await IpfsService.start();
  try {
    // 1. Calling a method on a handle after .release()
    final buf = go.Buffer(Uint8List.fromList([1, 2, 3]));
    buf.release();
    await mustFail(
      'use a GoHandle after calling .release()',
      why: 'the handle was already removed from Go\'s handle table',
      instead: 'keep all uses of the handle before .release() or inside .use()',
      action: () => buf.bytes(),
    );

    // 2. Returning a scoped GoHandle out of withGoScope()
    final escaped = withGoScope((s) => s.manage(go.Buffer(Uint8List(16))));
    await mustFail(
      'return a managed GoHandle from withGoScope() and use it outside',
      why: 'withGoScope() releases every handle registered in `s` on exit',
      instead: 'return a Dart value (Uint8List, String, Cid, int) from '
          'withGoScope(), or do not pass the returned handle to s.manage()',
      action: () => escaped.bytes(),
    );

    // 3. Registering a handle on an already closed GoScope
    final closedScope = GoScope()..close();
    late go.Buffer orphan;
    await mustFail(
      'call scope.manage() after scope.close()',
      why: 'a closed GoScope cannot accept new handles (it immediately '
          'releases the passed handle so it does not leak, and throws)',
      instead: 'create a new GoScope or use withGoScope()',
      action: () {
        orphan = go.Buffer(Uint8List(8));
        closedScope.manage(orphan);
      },
    );
    print('   (verified orphan handle was auto-released: '
        'orphan.isReleased = ${orphan.isReleased})\n');

    // 4. Confusing release() with close() on OS files (Windows file lock)
    if (Platform.isWindows) {
      final path = '${tmp.path}/locked.bin';
      File(path).writeAsBytesSync(Uint8List(64));
      final f = go.open(path);
      // Calling ONLY f.release() removes the handle from Go's table, but
      // does NOT call os.File.Close() in Go!
      f.release();
      await mustFail(
        'call only f.release() without f.close() on an open file',
        why: 'release() frees the handle table entry, but Go\'s os.File '
            'descriptor remains open until Go\'s GC finalizes the os.File',
        instead: 'always call f.close() inside f.use((f) { try { ... } '
            'finally { f.close(); } })',
        action: () => File(path).deleteSync(),
      );
    }
  } finally {
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}
