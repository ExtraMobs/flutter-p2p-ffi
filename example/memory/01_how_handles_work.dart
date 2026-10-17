// Memory 01 · How GoHandle, reference counting, close() and release() work.
//
// What: inspect the lifecycle of a GoHandle across the Dart <-> Go bridge,
// see how Go deduplicates handles for the same pointer, and compare host RSS
// memory when relying only on Dart's Finalizer vs deterministic release.
//
//   dart run example/memory/01_how_handles_work.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/boxo.dart' as boxo;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipfs_ffi.dart';

int hostRssMb() {
  final pid = IpfsService.hostPid;
  if (Platform.isWindows) {
    final out = Process.runSync(
      'tasklist',
      ['/fi', 'PID eq $pid', '/fo', 'csv', '/nh'],
    ).stdout as String;
    final kb = out.split('","').last.replaceAll(RegExp(r'[^0-9]'), '');
    return int.parse(kb) ~/ 1024;
  }
  for (final line in File('/proc/$pid/status').readAsLinesSync()) {
    if (line.startsWith('VmRSS:')) {
      return int.parse(line.replaceAll(RegExp(r'[^0-9]'), '')) ~/ 1024;
    }
  }
  return -1;
}

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_mem01_');
  final big = '${tmp.path}/8mib.bin';
  File(big).writeAsBytesSync(Uint8List(8 << 20)); // 8 MiB
  await IpfsService.start();
  try {
    print('== 1. Anatomy of a GoHandle ==');
    final buf = go.Buffer(Uint8List.fromList([1, 2, 3, 4]));
    print('handle ID (\$h): ${buf.$h}, epoch (\$e): ${buf.$e}, '
        'isReleased: ${buf.isReleased}');
    print('bytes in Go buffer: ${buf.bytes().length}');

    // Release immediately sends Free (_fnFree) to ipfs_host and detaches
    // the Dart Finalizer so it will never double-free when GC runs later.
    buf.release();
    print('after buf.release() -> isReleased: ${buf.isReleased}');

    // Calling release() again is a safe no-op (idempotent).
    buf.release();

    print('\n== 2. Same Go pointer = ref-counted handle in ipfs_host ==');
    // Casting or re-reading the same Go pointer returns the same handle ID
    // ($h) and increments its reference count in ipfs_host's handle table.
    final f1 = boxo.newBytesFile(Uint8List.fromList([7, 8, 9]));
    final f2 = f1.asFile()!;
    print('f1.\$h = ${f1.$h}, f2.\$h = ${f2.$h} '
        '(same Go pointer -> same handle ID, refs = 2)');
    f1.release();
    print('f1 released (isReleased=${f1.isReleased}), '
        'but f2 still holds refs = 1 in Go: readAll=${go.readAll(f2)}');
    f2.release();

    print('\n== 3. Why Finalizer alone accumulates Go memory in loops ==');
    print('Start host RSS: ${hostRssMb()} MB');

    // Allocate 20 Go buffers of 8 MiB each (160 MiB) WITH deterministic use():
    for (var i = 0; i < 20; i++) {
      go.Buffer(Uint8List(0)).use((b) {
        go.open(big).use((f) {
          go.copy(b, f);
          f.close();
        });
      });
    }
    print('After 20 x 8 MiB with .use() (deterministic): '
        'host RSS = ${hostRssMb()} MB');

    // Allocate 20 Go buffers of 8 MiB each WITHOUT release() (waiting for
    // Dart's Finalizer, which feels no pressure from 20 tiny Dart wrappers):
    for (var i = 0; i < 20; i++) {
      final b = go.Buffer(Uint8List(0));
      final f = go.open(big);
      go.copy(b, f);
      f.close();
    }
    print('After 20 x 8 MiB without release() (floating garbage): '
        'host RSS = ${hostRssMb()} MB');
  } finally {
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}
