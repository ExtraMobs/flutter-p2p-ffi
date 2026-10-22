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

import 'package:ipfs_ffi/go/car/v2.dart' as car;
import 'package:ipfs_ffi/go/car/v2/blockstore.dart' as blockstore;
import 'package:ipfs_ffi/go/bytes.dart' as bytes;
import 'package:ipfs_ffi/go/context.dart' as context;
import 'package:ipfs_ffi/go/io.dart' as io;
import 'package:ipfs_ffi/go/os.dart' as os;
import 'package:ipfs_ffi/go/block_format.dart' as block_format;
import 'package:ipfs_ffi/go/cid.dart' as cid;
import 'package:ipfs_ffi/ipfs_ffi.dart';

Future<void> main() async {
  final tmp = Directory.systemTemp.createTempSync('ipfs_ffi_mem03_');
  await IpfsService.start();
  try {
    final ctx = context.background();
    final prefix = cid.newPrefixV1(0x55, 0x12); // raw + sha2-256

    // Build a small CAR file with 5 blocks to iterate over.
    final carPath = '${tmp.path}/blocks.car';
    final payloads = [
      for (var i = 0; i < 5; i++) utf8.encode('block-payload-$i' * 200)
    ];
    final cids = [for (final p in payloads) prefix.sum(p)];

    await withGoScope((s) async {
      final rw = s.manage(blockstore.openReadWrite(carPath, [cids.first]));
      for (var i = 0; i < payloads.length; i++) {
        await rw.put(ctx, block_format.Block(cid: cids[i], rawData: payloads[i]));
      }
      rw.finalize();
    });

    print('== 1. Multi-handle loop with withGoScope ==');
    // Each iteration opens a go.File, wraps it in a car.BlockReader, and copies
    // into a go.Buffer. Registering all 3 in `s` releases them in reverse order
    // (buf -> br -> f) in one batch at the end of each iteration.
    for (var round = 1; round <= 3; round++) {
      final totalBytes = withGoScope((s) {
        final f = s.manage(os.open(carPath));
        try {
          final br = s.manage(car.BlockReader(f));
          final scratch = s.manage(bytes.Buffer(Uint8List(0)));
          var bytesRead = 0;
          while (true) {
            try {
              final block = br.next();
              bytesRead += block.rawData!.length;
            } on IpfsEof {
              break;
            }
          }
          bytes.Buffer(Uint8List.fromList([1, 2, 3]))
              .use((b) => io.copy(scratch, b));
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
    final b1 = scope.manage(bytes.Buffer(Uint8List(4096)));
    final b2 = scope.manage(bytes.Buffer(Uint8List(8192)));
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
