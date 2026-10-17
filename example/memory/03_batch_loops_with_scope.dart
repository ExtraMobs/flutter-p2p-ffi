// Memory 03 · Batch loops with GoScope and withGoScope().
//
// What: manage multiple GoHandles created inside a loop or multi-step pipeline
// so all handles of each iteration are released together in reverse order in a
// single shared-memory batch.
//
//   dart run example/memory/03_batch_loops_with_scope.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ipfs_ffi/car.dart' as car;
import 'package:ipfs_ffi/go.dart' as go;
import 'package:ipfs_ffi/ipfs_ffi.dart';
import 'package:ipfs_ffi/ipld.dart' as ipld;
import 'package:ipfs_ffi/multiformats.dart' as mf;

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_mem03_');
  await IpfsService.start();
  try {
    final ctx = go.background();
    final prefix = mf.newPrefixV1(0x55, 0x12); // raw + sha2-256

    // Build a small CAR file with 5 blocks to iterate over.
    final carPath = '${tmp.path}/blocks.car';
    final payloads = [
      for (var i = 0; i < 5; i++) utf8.encode('block-payload-$i' * 200)
    ];
    final cids = [for (final p in payloads) prefix.sum(p)];

    await withGoScope((s) async {
      final rw = s.manage(car.openReadWrite(carPath, [cids.first]));
      for (var i = 0; i < payloads.length; i++) {
        await rw.put(ctx, ipld.Block(cid: cids[i], rawData: payloads[i]));
      }
      rw.finalize();
    });

    print('== 1. Multi-handle loop with withGoScope ==');
    // Each iteration opens a go.File, wraps it in a car.BlockReader, and copies
    // into a go.Buffer. Registering all 3 in `s` releases them in reverse order
    // (buf -> br -> f) in one batch at the end of each iteration.
    for (var round = 1; round <= 3; round++) {
      final totalBytes = withGoScope((s) {
        final f = s.manage(go.open(carPath));
        try {
          final br = s.manage(car.BlockReader(f));
          final scratch = s.manage(go.Buffer(Uint8List(0)));
          var bytesRead = 0;
          while (true) {
            try {
              final block = br.next();
              bytesRead += block.rawData!.length;
            } on IpfsEof {
              break;
            }
          }
          go.Buffer(Uint8List.fromList([1, 2, 3]))
              .use((b) => go.copy(scratch, b));
          return bytesRead;
        } finally {
          f.close();
        }
      });
      print('round $round: read $totalBytes payload bytes '
          '(all iteration handles released in 1 batch)');
    }

    print('\n== 2. Explicit GoScope for custom lifespans ==');
    final scope = GoScope();
    final b1 = scope.manage(go.Buffer(Uint8List(4096)));
    final b2 = scope.manage(go.Buffer(Uint8List(8192)));
    print('before scope.close(): b1.isReleased=${b1.isReleased}, '
        'b2.isReleased=${b2.isReleased}');
    scope.close();
    print('after scope.close():  b1.isReleased=${b1.isReleased}, '
        'b2.isReleased=${b2.isReleased}, scope.isClosed=${scope.isClosed}');
  } finally {
    await IpfsService.stop();
    tmp.deleteSync(recursive: true);
  }
}
